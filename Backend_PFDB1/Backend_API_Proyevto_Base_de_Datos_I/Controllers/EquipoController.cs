using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class EquipoController : ControllerBase
    {
        private readonly DBContext _dbConnectionFactory;

        public EquipoController(DBContext dbConnectionFactory)
        {
            _dbConnectionFactory = dbConnectionFactory;
        }

        // GET: api/equipo?clienteId=1
        [Authorize(Policy = "GestionarEquipos")]
        [HttpGet]
        public async Task<IActionResult> Consultar([FromQuery] int? clienteId)
        {
            try
            {
                var request = new EquipoDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.Consultar(clienteId);
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Consultar(): " + ex.Message });
            }
        }

        // GET: api/equipo/5
        [Authorize(Policy = "GestionarEquipos")]
        [HttpGet("{id:int}")]
        public async Task<IActionResult> ConsultarPorId(int id)
        {
            try
            {
                var request = new EquipoDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.ConsultarPorId(id);
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "ConsultarPorId(): " + ex.Message });
            }
        }

        // GET: api/equipo/tipos
        [Authorize(Policy = "GestionarEquipos")]
        [HttpGet("tipos")]
        public async Task<IActionResult> ConsultarTipos()
        {
            try
            {
                var request = new EquipoDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.ConsultarTipos();
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "ConsultarTipos(): " + ex.Message });
            }
        }

        // POST: api/equipo/crear
        [Authorize(Policy = "GestionarEquipos")]
        [HttpPost("crear")]
        public async Task<IActionResult> Crear([FromBody] EquipoDTO request)
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

        // PUT: api/equipo/actualizar
        [Authorize(Policy = "GestionarEquipos")]
        [HttpPut("actualizar")]
        public async Task<IActionResult> Actualizar([FromBody] EquipoDTO request)
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

        // DELETE: api/equipo/eliminar/5  (borrado lógico; rechaza si tiene órdenes)
        [Authorize(Policy = "GestionarEquipos")]
        [HttpDelete("eliminar/{id:int}")]
        public async Task<IActionResult> Eliminar(int id)
        {
            try
            {
                var request = new EquipoDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.Eliminar(id);
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Eliminar(): " + ex.Message });
            }
        }

        // PUT: api/equipo/activar/5  (vuelve a ACTIVO lo que se desactivó)
        [Authorize(Policy = "GestionarEquipos")]
        [HttpPut("activar/{id:int}")]
        public async Task<IActionResult> Activar(int id)
        {
            try
            {
                var request = new EquipoDTO();
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
