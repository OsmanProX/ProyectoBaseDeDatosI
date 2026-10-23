using System.Security.Claims;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers
{
    // Semana 4 — Caja: facturar, registrar pagos y entregar el equipo.
    // Ver: ADMINISTRADOR, CAJA y RECEPCION (policy "Caja").
    // Facturar y cobrar: ADMINISTRADOR y CAJA. Entregar: ADMINISTRADOR y RECEPCION.
    [Authorize(Policy = "Caja")]
    [ApiController]
    [Route("api/[controller]")]
    public class CajaController : ControllerBase
    {
        private readonly DBContext _dbConnectionFactory;

        public CajaController(DBContext dbConnectionFactory)
        {
            _dbConnectionFactory = dbConnectionFactory;
        }

        private int? UsuarioIdToken()
        {
            var texto = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
            return int.TryParse(texto, out var id) ? id : null;
        }

        private IActionResult Responder(ResponseDto respuesta) =>
            StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });

        private CajaDTO NuevoDTO()
        {
            var dto = new CajaDTO();
            dto.SetConexion(_dbConnectionFactory);
            return dto;
        }

        // GET: api/caja/ordenes?entregadas=false  (LISTO por cobrar/entregar; true = últimas entregadas)
        [HttpGet("ordenes")]
        public async Task<IActionResult> ConsultarOrdenes([FromQuery] bool entregadas = false)
        {
            try { return Responder(await NuevoDTO().ConsultarOrdenes(entregadas)); }
            catch (Exception ex) { return StatusCode(500, new { codigo = 500, mensaje = "ConsultarOrdenes(): " + ex.Message }); }
        }

        // GET: api/caja/orden/5  (orden + factura + pagos + entrega)
        [HttpGet("orden/{id:int}")]
        public async Task<IActionResult> ConsultarDetalle(int id)
        {
            try { return Responder(await NuevoDTO().ConsultarDetalle(id)); }
            catch (Exception ex) { return StatusCode(500, new { codigo = 500, mensaje = "ConsultarDetalle(): " + ex.Message }); }
        }

        // GET: api/caja/metodos-pago
        [HttpGet("metodos-pago")]
        public async Task<IActionResult> ConsultarMetodosPago()
        {
            try { return Responder(await NuevoDTO().ConsultarMetodosPago()); }
            catch (Exception ex) { return StatusCode(500, new { codigo = 500, mensaje = "ConsultarMetodosPago(): " + ex.Message }); }
        }

        // POST: api/caja/facturar  (sp_GenerarFactura)
        [Authorize(Policy = "Facturar")]
        [HttpPost("facturar")]
        public async Task<IActionResult> Facturar([FromBody] FacturarRequest request)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                return Responder(await NuevoDTO().Facturar(request, usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Facturar(): " + ex.Message });
            }
        }

        // POST: api/caja/pagos  (sp_RegistrarPago)
        [Authorize(Policy = "Facturar")]
        [HttpPost("pagos")]
        public async Task<IActionResult> RegistrarPago([FromBody] PagoRequest request)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                return Responder(await NuevoDTO().RegistrarPago(request, usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "RegistrarPago(): " + ex.Message });
            }
        }

        // POST: api/caja/entregar  (sp_EntregarOrden)
        [Authorize(Policy = "EntregarEquipo")]
        [HttpPost("entregar")]
        public async Task<IActionResult> Entregar([FromBody] EntregaRequest request)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                return Responder(await NuevoDTO().Entregar(request, usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Entregar(): " + ex.Message });
            }
        }
    }
}
