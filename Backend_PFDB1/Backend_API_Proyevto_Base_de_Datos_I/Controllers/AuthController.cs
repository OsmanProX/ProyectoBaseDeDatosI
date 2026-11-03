using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Backend_API_Proyevto_Base_de_Datos_I.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly DBContext _dbConnectionFactory;
        private readonly JwtService _jwtService;
        private readonly CorreoService _correo;

        public AuthController(DBContext dbConnectionFactory, JwtService jwtService, CorreoService correo)
        {
            _dbConnectionFactory = dbConnectionFactory;
            _jwtService = jwtService;
            _correo = correo;
        }

        private string ErroresModelo() =>
            string.Join(" | ", ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage));

        // POST: api/auth/registro  (público) — el cliente crea su cuenta (sp_Cliente_Registrarse)
        [AllowAnonymous]
        [HttpPost("registro")]
        public async Task<IActionResult> Registro([FromBody] RegistroClienteRequest request)
        {
            try
            {
                if (!ModelState.IsValid) return StatusCode(400, new { codigo = 400, mensaje = ErroresModelo() });
                var dto = new CuentaDTO();
                dto.SetConexion(_dbConnectionFactory);
                var r = await dto.Registrarse(request);
                if (r.codigo != 200 || r.data is not CuentaClienteModel c)
                    return StatusCode(r.codigo, new { r.codigo, r.mensaje });

                string correo;
                try
                {
                    // Sin contraseña en el correo: el cliente ya la eligió
                    await _correo.EnviarBienvenidaAsync(c.Correo, c.NombreCompleto, request.TipoCliente ?? "INDIVIDUAL", c.NombreUsuario, null);
                    correo = $" Le enviamos un correo de bienvenida a {c.Correo}.";
                }
                catch
                {
                    correo = "";
                }
                var mensaje = $"Cuenta creada (usuario {c.NombreUsuario}). Ya puede iniciar sesión.{correo}";
                return Ok(new { codigo = 200, mensaje, data = new { mensaje } });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Registro(): " + ex.Message });
            }
        }

        // POST: api/auth/recuperar  (público) — asigna una contraseña temporal y la envía por correo.
        // Responde lo mismo exista o no el correo, para no revelar qué cuentas existen.
        [AllowAnonymous]
        [HttpPost("recuperar")]
        public async Task<IActionResult> Recuperar([FromBody] RecuperarRequest request)
        {
            const string generico = "Si el correo está registrado, le enviamos una contraseña. Revise también la carpeta de spam.";
            try
            {
                if (!ModelState.IsValid) return StatusCode(400, new { codigo = 400, mensaje = ErroresModelo() });
                if (!_correo.Configurado)
                    return StatusCode(500, new { codigo = 500, mensaje = "El envío de correos no está configurado. Contacte a TechCare." });

                var dto = new CuentaDTO();
                dto.SetConexion(_dbConnectionFactory);
                var temporal = CorreoService.GenerarContrasenaTemporal();
                var cuenta = await dto.Recuperar(request.Correo!, temporal);
                if (cuenta is not null)
                    await _correo.EnviarRecuperacionAsync(cuenta.Correo, cuenta.NombreCompleto, cuenta.NombreUsuario, temporal);

                return Ok(new { codigo = 200, mensaje = generico, data = new { mensaje = generico } });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Recuperar(): " + ex.Message });
            }
        }

        private int UsuarioActual() =>
            int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub"), out var id) ? id : 0;

        // GET: api/auth/mi-cuenta — datos del usuario que inició sesión
        [Authorize]
        [HttpGet("mi-cuenta")]
        public async Task<IActionResult> MiCuenta()
        {
            try
            {
                var dto = new CuentaDTO();
                dto.SetConexion(_dbConnectionFactory);
                var r = await dto.MiCuenta(UsuarioActual());
                return StatusCode(r.codigo, new { r.codigo, r.mensaje, r.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "MiCuenta(): " + ex.Message });
            }
        }

        // PUT: api/auth/mi-cuenta — edita nombre, teléfono y (si es cliente) dirección
        [Authorize]
        [HttpPut("mi-cuenta")]
        public async Task<IActionResult> ActualizarMiCuenta([FromBody] MiCuentaRequest request)
        {
            try
            {
                if (!ModelState.IsValid) return StatusCode(400, new { codigo = 400, mensaje = ErroresModelo() });
                var dto = new CuentaDTO();
                dto.SetConexion(_dbConnectionFactory);
                var r = await dto.MiCuenta(UsuarioActual(), request);
                return StatusCode(r.codigo, new { r.codigo, r.mensaje, r.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "ActualizarMiCuenta(): " + ex.Message });
            }
        }

        // PUT: api/auth/mi-contrasena — el usuario que inició sesión cambia su contraseña
        [Authorize]
        [HttpPut("mi-contrasena")]
        public async Task<IActionResult> CambiarMiContrasena([FromBody] CambiarContrasenaRequest request)
        {
            try
            {
                if (!ModelState.IsValid) return StatusCode(400, new { codigo = 400, mensaje = ErroresModelo() });
                var texto = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
                var dto = new CuentaDTO();
                dto.SetConexion(_dbConnectionFactory);
                var r = await dto.CambiarMiContrasena(int.TryParse(texto, out var id) ? id : 0, request.Actual, request.Nueva);
                return StatusCode(r.codigo, new { r.codigo, r.mensaje, r.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "CambiarMiContrasena(): " + ex.Message });
            }
        }

        // POST: api/auth/login
        // Valida el usuario contra la tabla Usuario y genera un JWT.
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            ResponseDto respuesta = new ResponseDto();

            try
            {
                if (!ModelState.IsValid)
                {
                    var mensaje = ModelState.Values
                        .SelectMany(v => v.Errors)
                        .Select(e => e.ErrorMessage);
                    throw new Exception(string.Join(" | ", mensaje));
                }

                AuthDTO authDTO = new AuthDTO();
                authDTO.SetConexion(_dbConnectionFactory);

                respuesta = await authDTO.Login(request);
                if (respuesta.codigo != 200)
                {
                    return StatusCode(respuesta.codigo, new
                    {
                        respuesta.codigo,
                        respuesta.mensaje
                    });
                }

                dynamic data = (dynamic)respuesta.data!;
                var usuario = new Usuario
                {
                    Id = data.UsuarioId,
                    UsuarioLogin = data.NombreUsuario,
                    Password = string.Empty,
                    NombreCompleto = data.NombreCompleto,
                    Correo = data.Correo,
                    Rol = (string)data.Roles
                };

                var loginResponse = _jwtService.GenerarToken(usuario);

                return Ok(new
                {
                    codigo = 200,
                    mensaje = "Login exitoso.",
                    token = loginResponse.Token,
                    expira = loginResponse.Expira,
                    usuario = respuesta.data
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    codigo = 500,
                    mensaje = "Login(): " + ex.Message
                });
            }
        }

        // GET: api/auth/perfil
        // Endpoint protegido: requiere Authorization: Bearer <token>.
        [Authorize]
        [HttpGet("perfil")]
        public IActionResult Perfil()
        {
            return Ok(new
            {
                codigo = 200,
                mensaje = "Token válido.",
                usuario = User.Identity?.Name,
                roles = User.Claims
                    .Where(c => c.Type == System.Security.Claims.ClaimTypes.Role)
                    .Select(c => c.Value)
            });
        }
    }
}
