using System.Security.Claims;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers
{
    // Semana 3 — Inventario y compras.
    // Solo ADMINISTRADOR y BODEGA (policy "Inventario"). El usuario se toma del token (UsuarioId).
    [Authorize(Policy = "Inventario")]
    [ApiController]
    [Route("api/[controller]")]
    public class InventarioController : ControllerBase
    {
        private readonly DBContext _dbConnectionFactory;

        public InventarioController(DBContext dbConnectionFactory)
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

        private InventarioDTO NuevoDTO()
        {
            var dto = new InventarioDTO();
            dto.SetConexion(_dbConnectionFactory);
            return dto;
        }

        // GET: api/inventario/stock?bodegaId=1&soloBajo=true  (vw_InventarioActual)
        [HttpGet("stock")]
        public async Task<IActionResult> ConsultarStock([FromQuery] int? bodegaId, [FromQuery] bool soloBajo = false)
        {
            try { return Responder(await NuevoDTO().ConsultarStock(bodegaId, soloBajo)); }
            catch (Exception ex) { return StatusCode(500, new { codigo = 500, mensaje = "ConsultarStock(): " + ex.Message }); }
        }

        // GET: api/inventario/bodegas
        [HttpGet("bodegas")]
        public async Task<IActionResult> ConsultarBodegas()
        {
            try { return Responder(await NuevoDTO().ConsultarBodegas()); }
            catch (Exception ex) { return StatusCode(500, new { codigo = 500, mensaje = "ConsultarBodegas(): " + ex.Message }); }
        }

        // GET: api/inventario/proveedores  (solo activos)
        [HttpGet("proveedores")]
        public async Task<IActionResult> ConsultarProveedores()
        {
            try { return Responder(await NuevoDTO().ConsultarProveedores()); }
            catch (Exception ex) { return StatusCode(500, new { codigo = 500, mensaje = "ConsultarProveedores(): " + ex.Message }); }
        }

        // GET: api/inventario/repuestos  (catálogo de repuestos activos, para las compras)
        [HttpGet("repuestos")]
        public async Task<IActionResult> ConsultarRepuestos()
        {
            try { return Responder(await NuevoDTO().ConsultarRepuestos()); }
            catch (Exception ex) { return StatusCode(500, new { codigo = 500, mensaje = "ConsultarRepuestos(): " + ex.Message }); }
        }

        // GET: api/inventario/compras?estado=PENDIENTE
        [HttpGet("compras")]
        public async Task<IActionResult> ConsultarCompras([FromQuery] string? estado)
        {
            try { return Responder(await NuevoDTO().ConsultarCompras(estado)); }
            catch (Exception ex) { return StatusCode(500, new { codigo = 500, mensaje = "ConsultarCompras(): " + ex.Message }); }
        }

        // GET: api/inventario/compras/3  (detalle de la compra)
        [HttpGet("compras/{id:int}")]
        public async Task<IActionResult> ConsultarCompra(int id)
        {
            try { return Responder(await NuevoDTO().ConsultarCompra(id)); }
            catch (Exception ex) { return StatusCode(500, new { codigo = 500, mensaje = "ConsultarCompra(): " + ex.Message }); }
        }

        // GET: api/inventario/movimientos?bodegaId=1&tipo=ENTRADA  (vw_MovimientosInventario)
        [HttpGet("movimientos")]
        public async Task<IActionResult> ConsultarMovimientos([FromQuery] int? bodegaId, [FromQuery] string? tipo)
        {
            try { return Responder(await NuevoDTO().ConsultarMovimientos(bodegaId, tipo)); }
            catch (Exception ex) { return StatusCode(500, new { codigo = 500, mensaje = "ConsultarMovimientos(): " + ex.Message }); }
        }

        // POST: api/inventario/compras  (sp_RegistrarCompra)
        [HttpPost("compras")]
        public async Task<IActionResult> RegistrarCompra([FromBody] RegistrarCompraRequest request)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                return Responder(await NuevoDTO().RegistrarCompra(request, usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "RegistrarCompra(): " + ex.Message });
            }
        }

        // POST: api/inventario/compras/3/recibir  (sp_RecibirCompra)
        [HttpPost("compras/{id:int}/recibir")]
        public async Task<IActionResult> RecibirCompra(int id)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                return Responder(await NuevoDTO().RecibirCompra(id, usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "RecibirCompra(): " + ex.Message });
            }
        }

        // POST: api/inventario/compras/3/anular  { "motivo": "..." }  (sp_AnularCompra)
        [HttpPost("compras/{id:int}/anular")]
        public async Task<IActionResult> AnularCompra(int id, [FromBody] AnularCompraRequest request)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                return Responder(await NuevoDTO().AnularCompra(id, request.Motivo, usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "AnularCompra(): " + ex.Message });
            }
        }
    }
}
