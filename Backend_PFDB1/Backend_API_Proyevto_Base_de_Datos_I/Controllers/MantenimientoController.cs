using System.Security.Claims;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers
{
    // Mantenimientos (enunciado 6.1).
    //   Repuestos, mínimos por bodega y proveedores: ADMINISTRADOR y BODEGA (policy "Inventario").
    //   Bodegas, categorías y tipos de equipo: los consulta BODEGA, los modifica solo ADMINISTRADOR.
    // La base vuelve a validar el rol en cada procedimiento (fn_UsuarioTieneRol).
    [Authorize]
    [ApiController]
    [Route("api/[controller]")]
    public class MantenimientoController : ControllerBase
    {
        private readonly DBContext _dbConnectionFactory;

        public MantenimientoController(DBContext dbConnectionFactory)
        {
            _dbConnectionFactory = dbConnectionFactory;
        }

        private int? UsuarioIdToken()
        {
            var texto = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
            return int.TryParse(texto, out var id) ? id : null;
        }

        private MantenimientoDTO NuevoDTO()
        {
            var dto = new MantenimientoDTO();
            dto.SetConexion(_dbConnectionFactory);
            return dto;
        }

        private IActionResult Responder(ResponseDto r) =>
            StatusCode(r.codigo, new { r.codigo, r.mensaje, r.data });

        // Ejecuta la acción con el UsuarioId del token y el mismo manejo de errores en todos los endpoints
        private async Task<IActionResult> Ejecutar(string metodo, Func<MantenimientoDTO, int, Task<ResponseDto>> accion)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                return Responder(await accion(NuevoDTO(), usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = metodo + "(): " + ex.Message });
            }
        }

        // ================= Categorías =================
        // GET: api/mantenimiento/categorias
        [Authorize(Policy = "Inventario")]
        [HttpGet("categorias")]
        public Task<IActionResult> ConsultarCategorias() =>
            Ejecutar("ConsultarCategorias", (d, _) => d.ConsultarCategorias());

        [Authorize(Roles = "ADMINISTRADOR")]
        [HttpPost("categorias")]
        public Task<IActionResult> CrearCategoria([FromBody] CategoriaRequest req) =>
            Ejecutar("CrearCategoria", (d, u) => d.GuardarCategoria(null, req, u));

        [Authorize(Roles = "ADMINISTRADOR")]
        [HttpPut("categorias/{id:int}")]
        public Task<IActionResult> EditarCategoria(int id, [FromBody] CategoriaRequest req) =>
            Ejecutar("EditarCategoria", (d, u) => d.GuardarCategoria(id, req, u));

        [Authorize(Roles = "ADMINISTRADOR")]
        [HttpPut("categorias/{id:int}/estado")]
        public Task<IActionResult> EstadoCategoria(int id, [FromBody] ActivoRequest req) =>
            Ejecutar("EstadoCategoria", (d, u) => d.EstadoCategoria(id, req.Activo, u));

        // ================= Tipos de equipo =================
        // GET: api/mantenimiento/tipos-equipo
        [Authorize(Roles = "ADMINISTRADOR")]
        [HttpGet("tipos-equipo")]
        public Task<IActionResult> ConsultarTiposEquipo() =>
            Ejecutar("ConsultarTiposEquipo", (d, _) => d.ConsultarTiposEquipo());

        [Authorize(Roles = "ADMINISTRADOR")]
        [HttpPost("tipos-equipo")]
        public Task<IActionResult> CrearTipoEquipo([FromBody] TipoEquipoRequest req) =>
            Ejecutar("CrearTipoEquipo", (d, u) => d.GuardarTipoEquipo(null, req, u));

        [Authorize(Roles = "ADMINISTRADOR")]
        [HttpPut("tipos-equipo/{id:int}")]
        public Task<IActionResult> EditarTipoEquipo(int id, [FromBody] TipoEquipoRequest req) =>
            Ejecutar("EditarTipoEquipo", (d, u) => d.GuardarTipoEquipo(id, req, u));

        // ================= Repuestos =================
        // GET: api/mantenimiento/repuestos?buscar=RAM&categoriaId=2&estado=ACTIVO
        [Authorize(Policy = "Inventario")]
        [HttpGet("repuestos")]
        public Task<IActionResult> ConsultarRepuestos([FromQuery] string? buscar, [FromQuery] int? categoriaId, [FromQuery] string? estado) =>
            Ejecutar("ConsultarRepuestos", (d, _) => d.ConsultarRepuestos(buscar, categoriaId, estado));

        [Authorize(Policy = "Inventario")]
        [HttpPost("repuestos")]
        public Task<IActionResult> CrearRepuesto([FromBody] RepuestoRequest req) =>
            Ejecutar("CrearRepuesto", (d, u) => d.GuardarRepuesto(null, req, u));

        [Authorize(Policy = "Inventario")]
        [HttpPut("repuestos/{id:int}")]
        public Task<IActionResult> EditarRepuesto(int id, [FromBody] RepuestoRequest req) =>
            Ejecutar("EditarRepuesto", (d, u) => d.GuardarRepuesto(id, req, u));

        [Authorize(Policy = "Inventario")]
        [HttpPut("repuestos/{id:int}/estado")]
        public Task<IActionResult> EstadoRepuesto(int id, [FromBody] EstadoRequest req) =>
            Ejecutar("EstadoRepuesto", (d, u) => d.EstadoRepuesto(id, req.Estado, u));

        // GET: api/mantenimiento/repuestos/5/inventario  (existencia y mínimo por bodega)
        [Authorize(Policy = "Inventario")]
        [HttpGet("repuestos/{id:int}/inventario")]
        public Task<IActionResult> InventarioRepuesto(int id) =>
            Ejecutar("InventarioRepuesto", (d, _) => d.ConsultarInventarioRepuesto(id));

        // PUT: api/mantenimiento/repuestos/5/inventario/2  { stockMinimo }
        [Authorize(Policy = "Inventario")]
        [HttpPut("repuestos/{id:int}/inventario/{bodegaId:int}")]
        public Task<IActionResult> GuardarMinimo(int id, int bodegaId, [FromBody] StockMinimoRequest req) =>
            Ejecutar("GuardarMinimo", (d, u) => d.GuardarMinimo(id, bodegaId, req.StockMinimo, u));

        // ================= Bodegas =================
        // GET: api/mantenimiento/bodegas  (activas e inactivas, con su inventario)
        [Authorize(Policy = "Inventario")]
        [HttpGet("bodegas")]
        public Task<IActionResult> ConsultarBodegas() =>
            Ejecutar("ConsultarBodegas", (d, _) => d.ConsultarBodegas());

        [Authorize(Roles = "ADMINISTRADOR")]
        [HttpPost("bodegas")]
        public Task<IActionResult> CrearBodega([FromBody] BodegaRequest req) =>
            Ejecutar("CrearBodega", (d, u) => d.GuardarBodega(null, req, u));

        [Authorize(Roles = "ADMINISTRADOR")]
        [HttpPut("bodegas/{id:int}")]
        public Task<IActionResult> EditarBodega(int id, [FromBody] BodegaRequest req) =>
            Ejecutar("EditarBodega", (d, u) => d.GuardarBodega(id, req, u));

        [Authorize(Roles = "ADMINISTRADOR")]
        [HttpPut("bodegas/{id:int}/estado")]
        public Task<IActionResult> EstadoBodega(int id, [FromBody] ActivoRequest req) =>
            Ejecutar("EstadoBodega", (d, u) => d.EstadoBodega(id, req.Activo, u));

        // ================= Proveedores =================
        // GET: api/mantenimiento/proveedores?buscar=Maya&estado=ACTIVO
        [Authorize(Policy = "Inventario")]
        [HttpGet("proveedores")]
        public Task<IActionResult> ConsultarProveedores([FromQuery] string? buscar, [FromQuery] string? estado) =>
            Ejecutar("ConsultarProveedores", (d, _) => d.ConsultarProveedores(buscar, estado));

        [Authorize(Policy = "Inventario")]
        [HttpPost("proveedores")]
        public Task<IActionResult> CrearProveedor([FromBody] ProveedorRequest req) =>
            Ejecutar("CrearProveedor", (d, u) => d.GuardarProveedor(null, req, u));

        [Authorize(Policy = "Inventario")]
        [HttpPut("proveedores/{id:int}")]
        public Task<IActionResult> EditarProveedor(int id, [FromBody] ProveedorRequest req) =>
            Ejecutar("EditarProveedor", (d, u) => d.GuardarProveedor(id, req, u));

        [Authorize(Policy = "Inventario")]
        [HttpPut("proveedores/{id:int}/estado")]
        public Task<IActionResult> EstadoProveedor(int id, [FromBody] EstadoRequest req) =>
            Ejecutar("EstadoProveedor", (d, u) => d.EstadoProveedor(id, req.Estado, u));
    }
}
