using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Backend_API_Proyevto_Base_de_Datos_I.Services;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ClienteController : ControllerBase
    {
        private readonly DBContext _dbConnectionFactory;
        private readonly CorreoService _correo;

        public ClienteController(DBContext dbConnectionFactory, CorreoService correo)
        {
            _dbConnectionFactory = dbConnectionFactory;
            _correo = correo;
        }

        private int UsuarioActual()
        {
            var texto = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
            return int.TryParse(texto, out var id) ? id : 0;
        }

        // Después de registrar el cliente: crea su cuenta (rol CLIENTE) y le envía el correo de bienvenida con PDF.
        // Si algo falla, el cliente igual queda registrado y el mensaje explica qué pasó.
        private async Task<string> CrearCuentaYEnviarCorreo(ClienteDTO cliente)
        {
            var temporal = CorreoService.GenerarContrasenaTemporal();
            var cuenta = await cliente.CrearAcceso(UsuarioActual(), temporal);
            if (cuenta.codigo != 200 || cuenta.data is not CuentaClienteModel c)
                return " No se creó la cuenta de acceso: " + cuenta.mensaje;
            try
            {
                await _correo.EnviarBienvenidaAsync(c.Correo, c.NombreCompleto, cliente.TipoCliente ?? "INDIVIDUAL",
                                                    c.NombreUsuario, temporal);
                return $" Se creó su cuenta (usuario {c.NombreUsuario}) y se envió el correo de bienvenida a {c.Correo}.";
            }
            catch (Exception ex)
            {
                return $" Se creó su cuenta (usuario {c.NombreUsuario}), pero el correo no se pudo enviar: {ex.Message} " +
                       "Asigne una contraseña desde Usuarios → Contraseña.";
            }
        }

        // GET: api/cliente/mis-ordenes  (portal del cliente: solo sus órdenes)
        [Authorize(Roles = "CLIENTE")]
        [HttpGet("mis-ordenes")]
        public async Task<IActionResult> MisOrdenes()
        {
            try
            {
                var request = new ClienteDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.MisOrdenes(UsuarioActual());
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "MisOrdenes(): " + ex.Message });
            }
        }

        // Datos del comprobante solo si la orden es del cliente y ya se entregó
        private async Task<(OrdenCajaModel o, FacturaModel f, List<PagoModel> pagos, EntregaModel e, string? correo)?> MiComprobante(int ordenId)
        {
            var cliente = new ClienteDTO();
            cliente.SetConexion(_dbConnectionFactory);
            if (!await cliente.EsMiOrden(UsuarioActual(), ordenId)) return null;
            var caja = new CajaDTO();
            caja.SetConexion(_dbConnectionFactory);
            return await caja.DatosComprobante(ordenId);
        }

        // GET: api/cliente/mis-ordenes/5/comprobante  → PDF de su orden entregada
        [Authorize(Roles = "CLIENTE")]
        [HttpGet("mis-ordenes/{id:int}/comprobante")]
        public async Task<IActionResult> MiComprobantePdf(int id)
        {
            try
            {
                if (await MiComprobante(id) is not { } d)
                    return StatusCode(400, new { codigo = 400, mensaje = "El comprobante está disponible cuando la orden se entrega." });
                var pdf = PdfComprobante.Generar(d.o, d.f, d.pagos, d.e);
                return File(pdf, "application/pdf", $"Comprobante_{d.o.NumeroOrden}.pdf");
            }
            catch (Exception ex) { return StatusCode(500, new { codigo = 500, mensaje = "MiComprobantePdf(): " + ex.Message }); }
        }

        // POST: api/cliente/mis-ordenes/5/comprobante/enviar  → al correo registrado del cliente
        [Authorize(Roles = "CLIENTE")]
        [HttpPost("mis-ordenes/{id:int}/comprobante/enviar")]
        public async Task<IActionResult> EnviarMiComprobante(int id)
        {
            try
            {
                if (await MiComprobante(id) is not { } d)
                    return StatusCode(400, new { codigo = 400, mensaje = "El comprobante está disponible cuando la orden se entrega." });
                if (string.IsNullOrWhiteSpace(d.correo))
                    return StatusCode(400, new { codigo = 400, mensaje = "No tiene correo registrado. Solicite a TechCare que lo agregue." });
                var pdf = PdfComprobante.Generar(d.o, d.f, d.pagos, d.e);
                await _correo.EnviarComprobanteAsync(d.correo, d.o.Cliente, d.o.NumeroOrden, pdf);
                var mensaje = $"Comprobante enviado a {d.correo}.";
                return Ok(new { codigo = 200, mensaje, data = new { mensaje } });
            }
            catch (Exception ex) { return StatusCode(500, new { codigo = 500, mensaje = "No se pudo enviar el correo: " + ex.Message }); }
        }

        // GET: api/cliente?busqueda=juan
        [Authorize(Policy = "GestionarClientes")]
        [HttpGet]
        public async Task<IActionResult> Consultar([FromQuery] string? busqueda)
        {
            try
            {
                var request = new ClienteDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.Consultar(busqueda);
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Consultar(): " + ex.Message });
            }
        }

        // GET: api/cliente/5
        [Authorize(Policy = "GestionarClientes")]
        [HttpGet("{id:int}")]
        public async Task<IActionResult> ConsultarPorId(int id)
        {
            try
            {
                var request = new ClienteDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.ConsultarPorId(id);
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "ConsultarPorId(): " + ex.Message });
            }
        }

        // GET: api/cliente/5/equipos  (equipos activos del cliente, para nueva orden)
        [Authorize(Policy = "GestionarClientes")]
        [HttpGet("{id:int}/equipos")]
        public async Task<IActionResult> ConsultarEquipos(int id)
        {
            try
            {
                var request = new ClienteDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.ConsultarEquipos(id);
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "ConsultarEquipos(): " + ex.Message });
            }
        }

        // POST: api/cliente/crear
        [Authorize(Policy = "GestionarClientes")]
        [HttpPost("crear")]
        public async Task<IActionResult> Crear([FromBody] ClienteDTO request)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    var errores = string.Join(" | ", ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage));
                    return StatusCode(400, new { codigo = 400, mensaje = errores });
                }
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.Crear();
                if (respuesta.codigo == 200 && request.ClienteId is > 0)
                {
                    var acceso = await CrearCuentaYEnviarCorreo(request);
                    respuesta.mensaje += acceso;
                    respuesta.data = new { request.ClienteId, Acceso = acceso.Trim() };
                }
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Crear(): " + ex.Message });
            }
        }

        // PUT: api/cliente/actualizar
        [Authorize(Policy = "GestionarClientes")]
        [HttpPut("actualizar")]
        public async Task<IActionResult> Actualizar([FromBody] ClienteDTO request)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    var errores = string.Join(" | ", ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage));
                    return StatusCode(400, new { codigo = 400, mensaje = errores });
                }
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.Actualizar();
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Actualizar(): " + ex.Message });
            }
        }

        // DELETE: api/cliente/eliminar/5  (borrado lógico: Estado = INACTIVO)
        [Authorize(Policy = "GestionarClientes")]
        [HttpDelete("eliminar/{id:int}")]
        public async Task<IActionResult> Eliminar(int id)
        {
            try
            {
                var request = new ClienteDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.Eliminar(id);
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Eliminar(): " + ex.Message });
            }
        }

        // PUT: api/cliente/activar/5  (vuelve a ACTIVO lo que se desactivó)
        [Authorize(Policy = "GestionarClientes")]
        [HttpPut("activar/{id:int}")]
        public async Task<IActionResult> Activar(int id)
        {
            try
            {
                var request = new ClienteDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.Activar(id);
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Activar(): " + ex.Message });
            }
        }
    }
}
