using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class PermisoController : ControllerBase
    {
        private readonly DBContext _dbConnectionFactory;

        public PermisoController(DBContext dbConnectionFactory)
        {
            _dbConnectionFactory = dbConnectionFactory;
        }

        // GET: api/permiso           (todos los permisos)
        // GET: api/permiso?rolId=2   (permisos de un rol)
        // Solo ADMINISTRADOR: cada usuario consulta los suyos con /api/permiso/mios
        [Authorize(Roles = "ADMINISTRADOR")]
        [HttpGet]
        public async Task<IActionResult> Consultar([FromQuery] int? rolId)
        {
            try
            {
                var request = new PermisoDTO { RolId = rolId };
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.Consultar();
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Consultar(): " + ex.Message });
            }
        }

        // GET: api/permiso/mios
        // Permisos activos del usuario del token (lee UsuarioId del JWT).
        // El frontend lo usa al iniciar sesión para menú y acciones por rol.
        [HttpGet("mios")]
        public async Task<IActionResult> Mios()
        {
            try
            {
                var usuarioIdTexto = User.FindFirstValue(ClaimTypes.NameIdentifier)
                    ?? User.FindFirstValue("sub");
                var request = new PermisoDTO();

                if (!int.TryParse(usuarioIdTexto, out var usuarioId))
                {
                    return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                }

                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.ConsultarPorUsuario(usuarioId);
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Mios(): " + ex.Message });
            }
        }
    }
}
