using System.Data;
using System.Text.Json;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Dapper;
using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    // Semana 3 — Inventario y compras. Usa las vistas y procedimientos del script 04:
    // vw_InventarioActual, vw_MovimientosInventario, sp_RegistrarCompra,
    // sp_RecibirCompra y sp_AnularCompra.
    public class InventarioDTO
    {
        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        // Ejecuta una consulta de lista con el formato de respuesta de la API
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

        // GET: existencias por bodega (vw_InventarioActual). soloBajo = SIN STOCK o BAJO MINIMO
        public Task<ResponseDto> ConsultarStock(int? bodegaId, bool soloBajo) =>
            Lista<InventarioModel>("ConsultarStock",
                @"SELECT BodegaId, Bodega, CategoriaId, Categoria, RepuestoId, Codigo, Repuesto,
                         Existencia, StockMinimo, PrecioCompraReferencia, PrecioVenta,
                         ValorInventario, EstadoStock, FechaActualizacion
                  FROM vw_InventarioActual
                  WHERE (@BodegaId IS NULL OR BodegaId = @BodegaId)
                    AND (@SoloBajo = 0 OR EstadoStock <> 'OK')
                  ORDER BY Bodega, Repuesto",
                new { BodegaId = bodegaId, SoloBajo = soloBajo });

        public Task<ResponseDto> ConsultarBodegas() =>
            Lista<BodegaModel>("ConsultarBodegas",
                "SELECT BodegaId, Nombre, Ubicacion FROM Bodega WHERE Activo = 1 ORDER BY BodegaId");

        public Task<ResponseDto> ConsultarProveedores() =>
            Lista<ProveedorModel>("ConsultarProveedores",
                "SELECT ProveedorId, NIT, Nombre FROM Proveedor WHERE Estado = 'ACTIVO' ORDER BY Nombre");

        public Task<ResponseDto> ConsultarRepuestos() =>
            Lista<RepuestoCatalogoModel>("ConsultarRepuestos",
                @"SELECT r.RepuestoId, r.Codigo, r.Nombre, c.Nombre AS Categoria, r.PrecioCompraReferencia
                  FROM Repuesto r
                  INNER JOIN Categoria c ON c.CategoriaId = r.CategoriaId
                  WHERE r.Estado = 'ACTIVO'
                  ORDER BY r.Nombre");

        // GET: compras con su total (estado opcional: PENDIENTE, RECIBIDA, ANULADA)
        public Task<ResponseDto> ConsultarCompras(string? estado) =>
            Lista<CompraModel>("ConsultarCompras",
                @"SELECT c.CompraId, c.NumeroCompra, c.FechaCompra, c.FechaRecepcion, c.Estado,
                         c.ProveedorId, p.Nombre AS Proveedor, c.BodegaId, b.Nombre AS Bodega,
                         u.NombreCompleto AS RegistradaPor, c.Observaciones,
                         COUNT(dc.RepuestoId) AS Lineas,
                         ISNULL(SUM(dc.Cantidad * dc.CostoUnitario), 0) AS Total
                  FROM Compra c
                  INNER JOIN Proveedor p ON p.ProveedorId = c.ProveedorId
                  INNER JOIN Bodega b ON b.BodegaId = c.BodegaId
                  INNER JOIN Usuario u ON u.UsuarioId = c.UsuarioId
                  LEFT JOIN DetalleCompra dc ON dc.CompraId = c.CompraId
                  WHERE (@Estado IS NULL OR c.Estado = @Estado)
                  GROUP BY c.CompraId, c.NumeroCompra, c.FechaCompra, c.FechaRecepcion, c.Estado,
                           c.ProveedorId, p.Nombre, c.BodegaId, b.Nombre, u.NombreCompleto, c.Observaciones
                  ORDER BY c.CompraId DESC",
                new { Estado = string.IsNullOrWhiteSpace(estado) ? null : estado.Trim().ToUpper() });

        // GET: últimos movimientos (vw_MovimientosInventario). tipo = ENTRADA o SALIDA
        public Task<ResponseDto> ConsultarMovimientos(int? bodegaId, string? tipo) =>
            Lista<MovimientoInventarioModel>("ConsultarMovimientos",
                @"SELECT TOP (200) MovimientoId, FechaMovimiento, TipoMovimiento, BodegaId, Bodega,
                         Codigo, Repuesto, Cantidad, ExistenciaResultante, TipoDocumento,
                         DocumentoOrigen, Proveedor, Usuario, Observacion
                  FROM vw_MovimientosInventario
                  WHERE (@BodegaId IS NULL OR BodegaId = @BodegaId)
                    AND (@Tipo IS NULL OR TipoMovimiento = @Tipo)
                  ORDER BY FechaMovimiento DESC, MovimientoId DESC",
                new { BodegaId = bodegaId, Tipo = string.IsNullOrWhiteSpace(tipo) ? null : tipo.Trim().ToUpper() });

        // GET: una compra con su detalle
        public async Task<ResponseDto> ConsultarCompra(int compraId)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var detalle = (await connection.QueryAsync<DetalleCompraModel>(
                    @"SELECT dc.RepuestoId, r.Codigo, r.Nombre AS Repuesto, dc.Cantidad, dc.CostoUnitario,
                             dc.Cantidad * dc.CostoUnitario AS Subtotal
                      FROM DetalleCompra dc
                      INNER JOIN Repuesto r ON r.RepuestoId = dc.RepuestoId
                      WHERE dc.CompraId = @Id
                      ORDER BY r.Nombre",
                    new { Id = compraId })).ToList();

                if (!await connection.ExecuteScalarAsync<bool>(
                        "SELECT CAST(COUNT(*) AS BIT) FROM Compra WHERE CompraId = @Id", new { Id = compraId }))
                {
                    respuesta.codigo = 404;
                    respuesta.mensaje = "Compra no encontrada.";
                    return respuesta;
                }

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = detalle;
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "ConsultarCompra(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarCompra(): " + ex.Message };
            }
            return respuesta;
        }

        // POST: sp_RegistrarCompra (queda PENDIENTE; todavía no mueve inventario)
        public async Task<ResponseDto> RegistrarCompra(RegistrarCompraRequest req, int usuarioId)
        {
            ResponseDto respuesta = new();
            try
            {
                if (req.ProveedorId <= 0 || req.BodegaId <= 0 || req.Detalle.Count == 0)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "Proveedor, bodega y al menos un repuesto son obligatorios.";
                    return respuesta;
                }

                // El SP lee el detalle con OPENJSON: [{"repuestoId":1,"cantidad":5,"costoUnitario":350.00}]
                var detalleJson = JsonSerializer.Serialize(req.Detalle,
                    new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase });

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var parameters = new DynamicParameters();
                parameters.Add("@ProveedorId", req.ProveedorId);
                parameters.Add("@BodegaId", req.BodegaId);
                parameters.Add("@UsuarioId", usuarioId);
                parameters.Add("@Detalle", detalleJson);
                parameters.Add("@Observaciones", string.IsNullOrWhiteSpace(req.Observaciones) ? null : req.Observaciones.Trim());
                parameters.Add("@CompraId", dbType: DbType.Int32, direction: ParameterDirection.Output);
                parameters.Add("@NumeroCompra", dbType: DbType.String, direction: ParameterDirection.Output, size: 20);

                var fila = await connection.QueryFirstOrDefaultAsync(
                    "sp_RegistrarCompra", parameters, commandType: CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Compra registrada como PENDIENTE.";
                respuesta.data = TallerDTO.FilaCamel((object?)fila);
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "RegistrarCompra(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "RegistrarCompra(): " + ex.Message };
            }
            return respuesta;
        }

        // POST: sp_RecibirCompra (suma al inventario y registra las ENTRADAS en una transacción)
        public async Task<ResponseDto> RecibirCompra(int compraId, int usuarioId)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var fila = await connection.QueryFirstOrDefaultAsync(
                    "sp_RecibirCompra",
                    new { CompraId = compraId, UsuarioId = usuarioId, SimularError = false },
                    commandType: CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Compra recibida. El inventario se actualizó.";
                respuesta.data = TallerDTO.FilaCamel((object?)fila);
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "RecibirCompra(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "RecibirCompra(): " + ex.Message };
            }
            return respuesta;
        }

        // POST: sp_AnularCompra (solo PENDIENTE; no se borra nada)
        public async Task<ResponseDto> AnularCompra(int compraId, string? motivo, int usuarioId)
        {
            ResponseDto respuesta = new();
            try
            {
                if (string.IsNullOrWhiteSpace(motivo))
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "Indique el motivo de la anulación.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var fila = await connection.QueryFirstOrDefaultAsync(
                    "sp_AnularCompra",
                    new { CompraId = compraId, UsuarioId = usuarioId, Motivo = motivo.Trim() },
                    commandType: CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Compra anulada.";
                respuesta.data = TallerDTO.FilaCamel((object?)fila);
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "AnularCompra(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "AnularCompra(): " + ex.Message };
            }
            return respuesta;
        }
    }
}
