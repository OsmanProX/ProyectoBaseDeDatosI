using System.Security.Claims;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.DTO;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers
{
    // Usuarios/empleados: solo el rol ADMINISTRADOR.
    // Lista (vw_UsuarioLista) y mantenimiento con los procedimientos del script 12:
    // sp_Usuario_Guardar, sp_Usuario_CambiarEstado y sp_Usuario_RestablecerContrasena.
    [Authorize(Roles = "ADMINISTRADOR")]
    [ApiController]
    [Route("api/[controller]")]
    public class UsuarioController : ControllerBase
    {
        private readonly DBContext _dbConnectionFactory;

        public UsuarioController(DBContext dbConnectionFactory)
        {
            _dbConnectionFactory = dbConnectionFactory;
        }

        private int? UsuarioIdToken()
        {
            var texto = User.FindFirstValue(ClaimTypes.NameIdentifier) ?? User.FindFirstValue("sub");
            return int.TryParse(texto, out var id) ? id : null;
        }

        private IActionResult Responder(ResponseDto r) =>
            StatusCode(r.codigo, new { r.codigo, r.mensaje, r.data });

        private async Task<IActionResult> Ejecutar(string metodo, Func<MantenimientoDTO, int, Task<ResponseDto>> accion)
        {
            try
            {
                var usuarioId = UsuarioIdToken();
                if (usuarioId is null) return StatusCode(401, new { codigo = 401, mensaje = "Token sin UsuarioId válido." });
                var dto = new MantenimientoDTO();
                dto.SetConexion(_dbConnectionFactory);
                return Responder(await accion(dto, usuarioId.Value));
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = metodo + "(): " + ex.Message });
            }
        }

        // GET: api/usuario
        [HttpGet]
        public async Task<IActionResult> Consultar()
        {
            try
            {
                var request = new UsuarioListaDTO();
                request.SetConexion(_dbConnectionFactory);
                var respuesta = await request.Consultar();
                return StatusCode(respuesta.codigo, new { respuesta.codigo, respuesta.mensaje, respuesta.data });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { codigo = 500, mensaje = "Consultar(): " + ex.Message });
            }
        }

        // GET: api/usuario/roles  (roles activos para el formulario)
        [HttpGet("roles")]
        public Task<IActionResult> Roles() =>
            Ejecutar("Roles", (d, _) => d.ConsultarRoles());

        // La sesión (JWT) maneja un rol por usuario, así que se pide exactamente uno.
        // La tabla UsuarioRol y sp_Usuario_Guardar sí aceptan varios.
        private static ResponseDto? ValidarRol(UsuarioRequest req) =>
            req.Roles.Distinct().Count() == 1
                ? null
                : new ResponseDto { codigo = 400, mensaje = "Seleccione un rol para el usuario." };

        // POST: api/usuario  { nombreUsuario, nombreCompleto, correo, telefono, contrasena, roles: [2] }
        [HttpPost]
        public Task<IActionResult> Crear([FromBody] UsuarioRequest req) =>
            Ejecutar("Crear", async (d, u) => ValidarRol(req) ?? await d.GuardarUsuario(null, req, u));

        // PUT: api/usuario/7  (datos y rol; la contraseña no se cambia aquí)
        [HttpPut("{id:int}")]
        public Task<IActionResult> Editar(int id, [FromBody] UsuarioRequest req) =>
            Ejecutar("Editar", async (d, u) => ValidarRol(req) ?? await d.GuardarUsuario(id, req, u));

        // PUT: api/usuario/7/estado  { activo }
        [HttpPut("{id:int}/estado")]
        public Task<IActionResult> Estado(int id, [FromBody] ActivoRequest req) =>
            Ejecutar("Estado", (d, u) => d.EstadoUsuario(id, req.Activo, u));

        // PUT: api/usuario/7/contrasena  { contrasena }
        [HttpPut("{id:int}/contrasena")]
        public Task<IActionResult> Contrasena(int id, [FromBody] ContrasenaRequest req) =>
            Ejecutar("Contrasena", (d, u) => d.RestablecerContrasena(id, req.Contrasena, u));
    }
}
