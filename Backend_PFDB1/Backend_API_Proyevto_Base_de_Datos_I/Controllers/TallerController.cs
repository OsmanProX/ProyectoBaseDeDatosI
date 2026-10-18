using System.Security.Claims;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers
{
    // Semana 3 — Taller: diagnóstico, reparación, actividades y repuestos.
    // Solo ADMINISTRADOR y TECNICO (policy "Taller"). El técnico se toma del token (UsuarioId).
    [Authorize(Policy = "Taller")]
    [ApiController]
    [Route("api/[controller]")]
    public class TallerController : ControllerBase
    {
        private readonly DBContext _dbConnectionFactory;

        public TallerController(DBContext dbConnectionFactory)
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

        private TallerDTO NuevoDTO()
        {
            var dto = new TallerDTO();
            dto.SetConexion(_dbConnectionFactory);
            return dto;
        }

        // GET: api/taller/ordenes?estadoId=3  (vw_OrdenesActivas, estados 1 a 5)
        [HttpGet("ordenes")]
        public async Task<IActionResult> ConsultarOrdenes([FromQuery] int? estadoId)
        {
            try
            {
                return Responder(await NuevoDTO().ConsultarOrdenes(estadoId));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "ConsultarOrdenes(): " + ex.Message });
            }
        }

        // GET: api/taller/orden/5  (orden + diagnóstico + reparación + actividades + repuestos)
        [HttpGet("orden/{id:int}")]
        public async Task<IActionResult> ConsultarDetalle(int id)
        {
            try
            {
                return Responder(await NuevoDTO().ConsultarDetalle(id));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "ConsultarDetalle(): " + ex.Message });
            }
        }

        // GET: api/taller/repuestos  (repuestos con existencia, por bodega)
        [HttpGet("repuestos")]
        public async Task<IActionResult> ConsultarRepuestos()
        {
            try
            {
                return Responder(await NuevoDTO().ConsultarRepuestosDisponibles());
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "ConsultarRepuestos(): " + ex.Message });
            }
        }

        // POST: api/taller/diagnostico  (sp_RegistrarDiagnostico)
        [HttpPost("diagnostico")]
        public async Task<IActionResult> RegistrarDiagnostico([FromBody] DiagnosticoRequest request)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                return Responder(await NuevoDTO().RegistrarDiagnostico(request, usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "RegistrarDiagnostico(): " + ex.Message });
            }
        }

        // POST: api/taller/reparacion/iniciar  (sp_IniciarReparacion)
        [HttpPost("reparacion/iniciar")]
        public async Task<IActionResult> IniciarReparacion([FromBody] IniciarReparacionRequest request)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                return Responder(await NuevoDTO().IniciarReparacion(request, usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "IniciarReparacion(): " + ex.Message });
            }
        }

        // POST: api/taller/reparacion/actividad  (sp_RegistrarActividadReparacion)
        [HttpPost("reparacion/actividad")]
        public async Task<IActionResult> RegistrarActividad([FromBody] ActividadRequest request)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                return Responder(await NuevoDTO().RegistrarActividad(request, usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "RegistrarActividad(): " + ex.Message });
            }
        }

        // POST: api/taller/reparacion/repuesto  (sp_AsignarRepuesto)
        [HttpPost("reparacion/repuesto")]
        public async Task<IActionResult> AsignarRepuesto([FromBody] AsignarRepuestoRequest request)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                return Responder(await NuevoDTO().AsignarRepuesto(request, usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "AsignarRepuesto(): " + ex.Message });
            }
        }

        // POST: api/taller/reparacion/finalizar  (sp_FinalizarReparacion)
        [HttpPost("reparacion/finalizar")]
        public async Task<IActionResult> FinalizarReparacion([FromBody] FinalizarReparacionRequest request)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                return Responder(await NuevoDTO().FinalizarReparacion(request, usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "FinalizarReparacion(): " + ex.Message });
            }
        }
    }
}
