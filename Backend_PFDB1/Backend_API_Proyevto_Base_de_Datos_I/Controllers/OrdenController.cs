using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers
{
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class OrdenController : ControllerBase
    {
        private readonly DBContext _dbConnectionFactory;

        public OrdenController(DBContext dbConnectionFactory)
        {
            _dbConnectionFactory = dbConnectionFactory;
        }

        // GET: api/orden?estadoId=1&clienteId=2
        [HttpGet]
        public async Task<IActionResult> Consultar([FromQuery] int? estadoId, [FromQuery] int? clienteId)
        {
            try
            {
                var request = new OrdenDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.Consultar(estadoId, clienteId);
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Consultar(): " + ex.Message });
            }
        }

        // GET: api/orden/5  (incluye historial de estados)
        [HttpGet("{id:int}")]
        public async Task<IActionResult> ConsultarPorId(int id)
        {
            try
            {
                var request = new OrdenDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.ConsultarPorId(id);
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "ConsultarPorId(): " + ex.Message });
            }
        }

        // GET: api/orden/estados
        [HttpGet("estados")]
        public async Task<IActionResult> ConsultarEstados()
        {
            try
            {
                var request = new OrdenDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.ConsultarEstados();
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "ConsultarEstados(): " + ex.Message });
            }
        }

        // POST: api/orden/registrar  (sp_RegistrarOrden)
        [HttpPost("registrar")]
        public async Task<IActionResult> Registrar([FromBody] OrdenDTO request)
        {
            try
            {
                if (!ModelState.IsValid)
                {
                    var errores = string.Join(" | ", ModelState.Values.SelectMany(v => v.Errors).Select(e => e.ErrorMessage));
                    return StatusCode(400, new { codigo = 400, mensaje = errores });
                }
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.Registrar();
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Registrar(): " + ex.Message });
            }
        }

        // POST: api/orden/cambiar-estado  (sp_CambiarEstadoOrden)
        [HttpPost("cambiar-estado")]
        public async Task<IActionResult> CambiarEstado([FromBody] OrdenDTO request)
        {
            try
            {
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.CambiarEstado();
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "CambiarEstado(): " + ex.Message });
            }
        }
    }
}
