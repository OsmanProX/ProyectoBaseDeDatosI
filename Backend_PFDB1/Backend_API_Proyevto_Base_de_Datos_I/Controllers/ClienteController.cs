using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
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

        public ClienteController(DBContext dbConnectionFactory)
        {
            _dbConnectionFactory = dbConnectionFactory;
        }

        // GET: api/cliente?busqueda=juan
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

        // POST: api/cliente/crear
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
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Crear(): " + ex.Message });
            }
        }

        // PUT: api/cliente/actualizar
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
    }
}
