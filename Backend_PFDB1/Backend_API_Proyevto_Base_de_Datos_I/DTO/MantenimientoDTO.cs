using System.Data;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Dapper;
using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    // Mantenimientos (enunciado 6.1). Las listas son consultas con columnas explícitas;
    // crear, editar y activar/inactivar van por los procedimientos del script 12
    // (el backend solo envía parámetros; las reglas están en la base).
    public class MantenimientoDTO
    {
        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        private static string? Texto(string? valor) => string.IsNullOrWhiteSpace(valor) ? null : valor.Trim();

        // Consulta de lista con el formato de respuesta de la API
        private async Task<ResponseDto> Lista<T>(string metodo, string sql, object? parametros = null)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var lista = await connection.QueryAsync<T>(sql, parametros);

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = lista.ToList();
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = metodo + "(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = metodo + "(): " + ex.Message };
            }
            return respuesta;
        }

        // Ejecuta un procedimiento del script 12 y devuelve la fila que regresa
        private async Task<ResponseDto> Procedimiento(string metodo, string sp, object parametros, string mensaje)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var fila = await connection.QueryFirstOrDefaultAsync(sp, parametros, commandType: CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = mensaje;
                respuesta.data = TallerDTO.FilaCamel((object?)fila);
            }
            catch (SqlException ex)
            {
                // Los THROW 51xxx del procedimiento llegan con su mensaje
                respuesta = new ResponseDto { codigo = 400, mensaje = metodo + "(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = metodo + "(): " + ex.Message };
            }
            return respuesta;
        }

        // ================= Categorías =================
        public Task<ResponseDto> ConsultarCategorias() =>
            Lista<CategoriaModel>("ConsultarCategorias",
                @"SELECT c.CategoriaId, c.Nombre, c.Descripcion, c.Activo, COUNT(r.RepuestoId) AS Repuestos
                  FROM Categoria c
                  LEFT JOIN Repuesto r ON r.CategoriaId = c.CategoriaId AND r.Estado = 'ACTIVO'
                  GROUP BY c.CategoriaId, c.Nombre, c.Descripcion, c.Activo
                  ORDER BY c.Nombre");

        public Task<ResponseDto> GuardarCategoria(int? id, CategoriaRequest req, int usuarioId) =>
            Procedimiento("GuardarCategoria", "sp_Categoria_Guardar",
                new { UsuarioId = usuarioId, CategoriaId = id, Nombre = Texto(req.Nombre), Descripcion = Texto(req.Descripcion) },
                id is null ? "Categoría creada." : "Categoría actualizada.");

        public Task<ResponseDto> EstadoCategoria(int id, bool activo, int usuarioId) =>
            Procedimiento("EstadoCategoria", "sp_Categoria_CambiarEstado",
                new { UsuarioId = usuarioId, CategoriaId = id, Activo = activo },
                activo ? "Categoría activada." : "Categoría inactivada.");

        // ================= Tipos de equipo =================
        public Task<ResponseDto> ConsultarTiposEquipo() =>
            Lista<TipoEquipoMantenimientoModel>("ConsultarTiposEquipo",
                @"SELECT t.TipoEquipoId, t.Nombre, COUNT(e.EquipoId) AS Equipos
                  FROM TipoEquipo t
                  LEFT JOIN Equipo e ON e.TipoEquipoId = t.TipoEquipoId
                  GROUP BY t.TipoEquipoId, t.Nombre
                  ORDER BY t.Nombre");

        public Task<ResponseDto> GuardarTipoEquipo(int? id, TipoEquipoRequest req, int usuarioId) =>
            Procedimiento("GuardarTipoEquipo", "sp_TipoEquipo_Guardar",
                new { UsuarioId = usuarioId, TipoEquipoId = id, Nombre = Texto(req.Nombre) },
                id is null ? "Tipo de equipo creado." : "Tipo de equipo actualizado.");

        // ================= Repuestos =================
        public Task<ResponseDto> ConsultarRepuestos(string? buscar, int? categoriaId, string? estado) =>
            Lista<RepuestoMantenimientoModel>("ConsultarRepuestos",
                @"SELECT r.RepuestoId, r.CategoriaId, c.Nombre AS Categoria, r.Codigo, r.Nombre, r.Descripcion,
                         r.PrecioCompraReferencia, r.PrecioVenta, r.Estado,
                         ISNULL(SUM(i.Existencia), 0) AS Existencia, COUNT(i.BodegaId) AS Bodegas
                  FROM Repuesto r
                  INNER JOIN Categoria c ON c.CategoriaId = r.CategoriaId
                  LEFT JOIN Inventario i ON i.RepuestoId = r.RepuestoId
                  WHERE (@CategoriaId IS NULL OR r.CategoriaId = @CategoriaId)
                    AND (@Estado IS NULL OR r.Estado = @Estado)
                    AND (@Buscar IS NULL OR r.Codigo LIKE @Buscar OR r.Nombre LIKE @Buscar)
                  GROUP BY r.RepuestoId, r.CategoriaId, c.Nombre, r.Codigo, r.Nombre, r.Descripcion,
                           r.PrecioCompraReferencia, r.PrecioVenta, r.Estado
                  ORDER BY r.Codigo",
                new
                {
                    Buscar = Texto(buscar) is { } b ? "%" + b + "%" : null,
                    CategoriaId = categoriaId is > 0 ? categoriaId : null,
                    Estado = Texto(estado)?.ToUpper()
                });

        // Existencia y mínimo del repuesto en cada bodega activa (aunque todavía no tenga fila)
        public Task<ResponseDto> ConsultarInventarioRepuesto(int repuestoId) =>
            Lista<RepuestoBodegaModel>("ConsultarInventarioRepuesto",
                @"SELECT b.BodegaId, b.Nombre AS Bodega,
                         ISNULL(i.Existencia, 0) AS Existencia, ISNULL(i.StockMinimo, 0) AS StockMinimo,
                         CAST(CASE WHEN i.RepuestoId IS NULL THEN 0 ELSE 1 END AS BIT) AS Registrado
                  FROM Bodega b
                  LEFT JOIN Inventario i ON i.BodegaId = b.BodegaId AND i.RepuestoId = @RepuestoId
                  WHERE b.Activo = 1
                  ORDER BY b.BodegaId",
                new { RepuestoId = repuestoId });

        public Task<ResponseDto> GuardarRepuesto(int? id, RepuestoRequest req, int usuarioId) =>
            Procedimiento("GuardarRepuesto", "sp_Repuesto_Guardar",
                new
                {
                    UsuarioId = usuarioId,
                    RepuestoId = id,
                    req.CategoriaId,
                    Codigo = Texto(req.Codigo),
                    Nombre = Texto(req.Nombre),
                    Descripcion = Texto(req.Descripcion),
                    req.PrecioCompraReferencia,
                    req.PrecioVenta,
                    BodegaId = req.BodegaId is > 0 ? req.BodegaId : null,
                    req.StockMinimo
                },
                id is null ? "Repuesto creado." : "Repuesto actualizado.");

        public Task<ResponseDto> EstadoRepuesto(int id, string? estado, int usuarioId) =>
            Procedimiento("EstadoRepuesto", "sp_Repuesto_CambiarEstado",
                new { UsuarioId = usuarioId, RepuestoId = id, Estado = Texto(estado) },
                "Estado del repuesto actualizado.");

        public Task<ResponseDto> GuardarMinimo(int repuestoId, int bodegaId, int stockMinimo, int usuarioId) =>
            Procedimiento("GuardarMinimo", "sp_Inventario_GuardarMinimo",
                new { UsuarioId = usuarioId, RepuestoId = repuestoId, BodegaId = bodegaId, StockMinimo = stockMinimo },
                "Stock mínimo actualizado.");

        // ================= Bodegas =================
        public Task<ResponseDto> ConsultarBodegas() =>
            Lista<BodegaMantenimientoModel>("ConsultarBodegas",
                @"SELECT b.BodegaId, b.Nombre, b.Ubicacion, b.Activo,
                         COUNT(CASE WHEN i.Existencia > 0 THEN 1 END) AS RepuestosConExistencia,
                         ISNULL(SUM(i.Existencia), 0) AS Unidades,
                         ISNULL(SUM(i.Existencia * r.PrecioCompraReferencia), 0) AS ValorInventario
                  FROM Bodega b
                  LEFT JOIN Inventario i ON i.BodegaId = b.BodegaId
                  LEFT JOIN Repuesto r ON r.RepuestoId = i.RepuestoId
                  GROUP BY b.BodegaId, b.Nombre, b.Ubicacion, b.Activo
                  ORDER BY b.BodegaId");

        public Task<ResponseDto> GuardarBodega(int? id, BodegaRequest req, int usuarioId) =>
            Procedimiento("GuardarBodega", "sp_Bodega_Guardar",
                new { UsuarioId = usuarioId, BodegaId = id, Nombre = Texto(req.Nombre), Ubicacion = Texto(req.Ubicacion) },
                id is null ? "Bodega creada." : "Bodega actualizada.");

        public Task<ResponseDto> EstadoBodega(int id, bool activo, int usuarioId) =>
            Procedimiento("EstadoBodega", "sp_Bodega_CambiarEstado",
                new { UsuarioId = usuarioId, BodegaId = id, Activo = activo },
                activo ? "Bodega activada." : "Bodega inactivada.");

        // ================= Proveedores =================
        public Task<ResponseDto> ConsultarProveedores(string? buscar, string? estado) =>
            Lista<ProveedorMantenimientoModel>("ConsultarProveedores",
                @"SELECT p.ProveedorId, p.NIT, p.Nombre, p.Contacto, p.Telefono, p.Correo, p.Direccion, p.Estado,
                         COUNT(c.CompraId) AS Compras,
                         COUNT(CASE WHEN c.Estado = 'PENDIENTE' THEN 1 END) AS ComprasPendientes
                  FROM Proveedor p
                  LEFT JOIN Compra c ON c.ProveedorId = p.ProveedorId
                  WHERE (@Estado IS NULL OR p.Estado = @Estado)
                    AND (@Buscar IS NULL OR p.Nombre LIKE @Buscar OR p.NIT LIKE @Buscar OR p.Contacto LIKE @Buscar)
                  GROUP BY p.ProveedorId, p.NIT, p.Nombre, p.Contacto, p.Telefono, p.Correo, p.Direccion, p.Estado
                  ORDER BY p.Nombre",
                new
                {
                    Buscar = Texto(buscar) is { } b ? "%" + b + "%" : null,
                    Estado = Texto(estado)?.ToUpper()
                });

        public Task<ResponseDto> GuardarProveedor(int? id, ProveedorRequest req, int usuarioId) =>
            Procedimiento("GuardarProveedor", "sp_Proveedor_Guardar",
                new
                {
                    UsuarioId = usuarioId,
                    ProveedorId = id,
                    NIT = Texto(req.NIT),
                    Nombre = Texto(req.Nombre),
                    Contacto = Texto(req.Contacto),
                    Telefono = Texto(req.Telefono),
                    Correo = Texto(req.Correo),
                    Direccion = Texto(req.Direccion)
                },
                id is null ? "Proveedor creado." : "Proveedor actualizado.");

        public Task<ResponseDto> EstadoProveedor(int id, string? estado, int usuarioId) =>
            Procedimiento("EstadoProveedor", "sp_Proveedor_CambiarEstado",
                new { UsuarioId = usuarioId, ProveedorId = id, Estado = Texto(estado) },
                "Estado del proveedor actualizado.");

        // ================= Usuarios =================
        public Task<ResponseDto> ConsultarRoles() =>
            Lista<RolModel>("ConsultarRoles",
                "SELECT RolId, Nombre, Descripcion FROM Rol WHERE Activo = 1 ORDER BY RolId");

        public Task<ResponseDto> GuardarUsuario(int? id, UsuarioRequest req, int usuarioId) =>
            Procedimiento("GuardarUsuario", "sp_Usuario_Guardar",
                new
                {
                    UsuarioId = usuarioId,
                    UsuarioEditarId = id,
                    NombreUsuario = Texto(req.NombreUsuario),
                    NombreCompleto = Texto(req.NombreCompleto),
                    Correo = Texto(req.Correo),
                    Telefono = Texto(req.Telefono),
                    // VARCHAR igual que sp_LoginUsuario, para que el hash coincida
                    Contrasena = id is null
                        ? new DbString { Value = req.Contrasena, IsAnsi = true, Length = 255 }
                        : null,
                    Roles = string.Join(",", req.Roles.Distinct())
                },
                id is null ? "Usuario creado." : "Usuario actualizado.");

        public Task<ResponseDto> EstadoUsuario(int id, bool activo, int usuarioId) =>
            Procedimiento("EstadoUsuario", "sp_Usuario_CambiarEstado",
                new { UsuarioId = usuarioId, UsuarioEditarId = id, Activo = activo },
                activo ? "Usuario activado." : "Usuario inactivado.");

        public Task<ResponseDto> RestablecerContrasena(int id, string? contrasena, int usuarioId) =>
            Procedimiento("RestablecerContrasena", "sp_Usuario_RestablecerContrasena",
                new
                {
                    UsuarioId = usuarioId,
                    UsuarioEditarId = id,
                    Contrasena = new DbString { Value = contrasena, IsAnsi = true, Length = 255 }
                },
                "Contraseña actualizada.");
    }
}
