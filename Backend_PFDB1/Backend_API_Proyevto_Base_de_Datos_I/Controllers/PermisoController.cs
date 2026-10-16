using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

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
    }
}
