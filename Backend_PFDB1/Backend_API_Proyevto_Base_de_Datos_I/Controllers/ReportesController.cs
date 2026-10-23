using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers
{
    // Semana 4 — Reportes y dashboard.
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class ReportesController : ControllerBase
    {
        private readonly DBContext _dbConnectionFactory;

        public ReportesController(DBContext dbConnectionFactory)
        {
            _dbConnectionFactory = dbConnectionFactory;
        }

        private ReportesDTO NuevoDTO()
        {
            var dto = new ReportesDTO();
            dto.SetConexion(_dbConnectionFactory);
            return dto;
        }

        // GET: api/reportes/3?desde=2026-10-01&hasta=2026-10-31&buscar=HP&bodegaId=1&estado=LISTO
        // Del 1 al 12; solo ADMINISTRADOR (policy "Reportes")
        [Authorize(Policy = "Reportes")]
        [HttpGet("{numero:int}")]
        public async Task<IActionResult> Generar(int numero, [FromQuery] DateTime? desde, [FromQuery] DateTime? hasta,
                                                 [FromQuery] string? buscar, [FromQuery] int? bodegaId,
                                                 [FromQuery] string? estado)
        {
            try
            {
                var respuesta = await NuevoDTO().Generar(numero, desde, hasta, buscar, bodegaId, estado);
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Generar(): " + ex.Message });
            }
        }

        // GET: api/reportes/dashboard  (pantalla de inicio, cualquier usuario con sesión)
        [HttpGet("dashboard")]
        public async Task<IActionResult> Dashboard()
        {
            try
            {
                var respuesta = await NuevoDTO().Dashboard();
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Dashboard(): " + ex.Message });
            }
        }
    }
}
