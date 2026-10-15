using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Backend_API_Proyevto_Base_de_Datos_I.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly DBContext _dbConnectionFactory;
        private readonly JwtService _jwtService;

        public AuthController(DBContext dbConnectionFactory, JwtService jwtService)
        {
            _dbConnectionFactory = dbConnectionFactory;
            _jwtService = jwtService;
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

        // GET: api/auth/token-demo
        // Genera un JWT de prueba sin consultar la base de datos.
        [HttpGet("token-demo")]
        public IActionResult GenerarTokenDemo()
        {
            var usuario = new Usuario
            {
                Id = 0,
                UsuarioLogin = "demo",
                Rol = "DEMO"
            };

            var loginResponse = _jwtService.GenerarToken(usuario);

            return Ok(new
            {
                codigo = 200,
                mensaje = "Token de prueba generado.",
                token = loginResponse.Token,
                expira = loginResponse.Expira
            });
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
                mensaje = "Token valido.",
                usuario = User.Identity?.Name,
                roles = User.Claims
                    .Where(c => c.Type == System.Security.Claims.ClaimTypes.Role)
                    .Select(c => c.Value)
            });
        }
    }
}
