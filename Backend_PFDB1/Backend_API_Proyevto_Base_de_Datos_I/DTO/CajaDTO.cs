using System.Data;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Dapper;
using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    // Semana 4 — Caja. Usa los procedimientos del script 06:
    // sp_GenerarFactura, sp_RegistrarPago y sp_EntregarOrden.
    // Las reglas (orden LISTO, una factura por orden, no pagar de más,
    // no entregar con saldo) las valida la base.
    public class CajaDTO
    {
        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        // Columnas comunes de la lista de caja
        private const string SelectOrdenes = @"
            SELECT o.OrdenId, o.NumeroOrden, o.FechaIngreso, o.EstadoOrdenId, eo.Codigo AS Estado, o.Prioridad,
                   c.ClienteId, c.NombreRazonSocial AS Cliente, c.NIT,
                   te.Nombre + ' ' + e.Marca + ' ' + e.Modelo AS Equipo, e.NumeroSerie,
                   ISNULL(rp.CostoManoObra, 0) AS ManoObra,
                   ISNULL(rr.Venta, 0) AS Repuestos,
                   dbo.fn_TotalOrden(o.OrdenId) AS TotalSinIVA,
                   f.FacturaId, f.NumeroFactura, f.Total AS TotalFactura,
                   dbo.fn_SaldoFactura(f.FacturaId) AS SaldoPendiente, f.Estado AS EstadoFactura,
                   en.FechaEntrega
            FROM OrdenServicio o
            INNER JOIN EstadoOrden eo ON eo.EstadoOrdenId = o.EstadoOrdenId
            INNER JOIN Cliente c ON c.ClienteId = o.ClienteId
            INNER JOIN Equipo e ON e.EquipoId = o.EquipoId
            INNER JOIN TipoEquipo te ON te.TipoEquipoId = e.TipoEquipoId
            LEFT JOIN Diagnostico d ON d.OrdenId = o.OrdenId
            LEFT JOIN Reparacion rp ON rp.DiagnosticoId = d.DiagnosticoId
            LEFT JOIN (SELECT ReparacionId, SUM(Cantidad * PrecioVentaUnitario) AS Venta
                       FROM ReparacionRepuesto GROUP BY ReparacionId) rr ON rr.ReparacionId = rp.ReparacionId
            LEFT JOIN Factura f ON f.OrdenId = o.OrdenId AND f.Estado <> 'ANULADA'
            LEFT JOIN Entrega en ON en.OrdenId = o.OrdenId";

        // GET: órdenes LISTO (pendientes de facturar, cobrar o entregar) o las últimas entregadas
        public async Task<ResponseDto> ConsultarOrdenes(bool entregadas)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var sql = entregadas
                    ? $"SELECT TOP (50) * FROM ({SelectOrdenes} WHERE o.EstadoOrdenId = 6) x ORDER BY FechaEntrega DESC"
                    : $"{SelectOrdenes} WHERE o.EstadoOrdenId = 5 ORDER BY o.FechaIngreso";

                var lista = await connection.QueryAsync<OrdenCajaModel>(sql);

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = lista.ToList();
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "ConsultarOrdenes(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarOrdenes(): " + ex.Message };
            }
            return respuesta;
        }

        // GET: detalle de una orden en caja (factura, pagos y entrega)
        public async Task<ResponseDto> ConsultarDetalle(int ordenId)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var orden = await connection.QueryFirstOrDefaultAsync<OrdenCajaModel>(
                    $"{SelectOrdenes} WHERE o.OrdenId = @Id", new { Id = ordenId });

                if (orden == null)
                {
                    respuesta.codigo = 404;
                    respuesta.mensaje = "La orden no existe.";
                    return respuesta;
                }

                FacturaModel? factura = null;
                List<PagoModel> pagos = new();
                if (orden.FacturaId != null)
                {
                    factura = await connection.QueryFirstOrDefaultAsync<FacturaModel>(
                        @"SELECT f.FacturaId, f.NumeroFactura, f.FechaEmision, f.NITFacturacion, f.NombreFacturacion,
                                 f.TotalManoObra, f.TotalRepuestos, f.Subtotal, f.Impuesto, f.Total,
                                 dbo.fn_SaldoFactura(f.FacturaId) AS SaldoPendiente, f.Estado,
                                 u.NombreCompleto AS EmitidaPor
                          FROM Factura f
                          INNER JOIN Usuario u ON u.UsuarioId = f.UsuarioId
                          WHERE f.FacturaId = @F",
                        new { F = orden.FacturaId });

                    pagos = (await connection.QueryAsync<PagoModel>(
                        @"SELECT p.PagoId, p.FechaPago, mp.Nombre AS Metodo, p.Monto, p.Referencia, p.Estado,
                                 u.NombreCompleto AS CobradoPor
                          FROM Pago p
                          INNER JOIN MetodoPago mp ON mp.MetodoPagoId = p.MetodoPagoId
                          INNER JOIN Usuario u ON u.UsuarioId = p.UsuarioId
                          WHERE p.FacturaId = @F
                          ORDER BY p.FechaPago",
                        new { F = orden.FacturaId })).ToList();
                }

                var entrega = await connection.QueryFirstOrDefaultAsync<EntregaModel>(
                    @"SELECT en.FechaEntrega, en.NombreRecibe, en.Observaciones, u.NombreCompleto AS EntregadoPor
                      FROM Entrega en
                      INNER JOIN Usuario u ON u.UsuarioId = en.UsuarioEntregaId
                      WHERE en.OrdenId = @Id",
                    new { Id = ordenId });

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = new { orden, factura, pagos, entrega };
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "ConsultarDetalle(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarDetalle(): " + ex.Message };
            }
            return respuesta;
        }

        public async Task<ResponseDto> ConsultarMetodosPago()
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var lista = await connection.QueryAsync<MetodoPagoModel>(
                    "SELECT MetodoPagoId, Nombre FROM MetodoPago WHERE Activo = 1 ORDER BY MetodoPagoId");

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = lista.ToList();
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarMetodosPago(): " + ex.Message };
            }
            return respuesta;
        }

        // POST: sp_GenerarFactura (orden LISTO, IVA 12 %, número FAC-AAAA-0001)
        public async Task<ResponseDto> Facturar(FacturarRequest req, int usuarioId)
        {
            ResponseDto respuesta = new();
            try
            {
                if (req.OrdenId <= 0)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "La orden es obligatoria.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var parameters = new DynamicParameters();
                parameters.Add("@OrdenId", req.OrdenId);
                parameters.Add("@UsuarioId", usuarioId);
                parameters.Add("@NITFacturacion", string.IsNullOrWhiteSpace(req.NitFacturacion) ? null : req.NitFacturacion.Trim());
                parameters.Add("@NombreFacturacion", string.IsNullOrWhiteSpace(req.NombreFacturacion) ? null : req.NombreFacturacion.Trim());
                parameters.Add("@FacturaId", dbType: DbType.Int32, direction: ParameterDirection.Output);
                parameters.Add("@NumeroFactura", dbType: DbType.String, direction: ParameterDirection.Output, size: 20);

                var fila = await connection.QueryFirstOrDefaultAsync(
                    "sp_GenerarFactura", parameters, commandType: CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Factura emitida.";
                respuesta.data = TallerDTO.FilaCamel((object?)fila);
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "Facturar(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Facturar(): " + ex.Message };
            }
            return respuesta;
        }

        // POST: sp_RegistrarPago (no deja pagar más que el saldo; al llegar a 0 la factura queda PAGADA)
        public async Task<ResponseDto> RegistrarPago(PagoRequest req, int usuarioId)
        {
            ResponseDto respuesta = new();
            try
            {
                if (req.FacturaId <= 0 || req.MetodoPagoId <= 0)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "La factura y el método de pago son obligatorios.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var parameters = new DynamicParameters();
                parameters.Add("@FacturaId", req.FacturaId);
                parameters.Add("@MetodoPagoId", req.MetodoPagoId);
                parameters.Add("@Monto", req.Monto);
                parameters.Add("@UsuarioId", usuarioId);
                parameters.Add("@Referencia", string.IsNullOrWhiteSpace(req.Referencia) ? null : req.Referencia.Trim());
                parameters.Add("@PagoId", dbType: DbType.Int32, direction: ParameterDirection.Output);

                var fila = await connection.QueryFirstOrDefaultAsync(
                    "sp_RegistrarPago", parameters, commandType: CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Pago registrado.";
                respuesta.data = TallerDTO.FilaCamel((object?)fila);
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "RegistrarPago(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "RegistrarPago(): " + ex.Message };
            }
            return respuesta;
        }

        // POST: sp_EntregarOrden (solo LISTO, con factura y sin saldo → ENTREGADO)
        public async Task<ResponseDto> Entregar(EntregaRequest req, int usuarioId)
        {
            ResponseDto respuesta = new();
            try
            {
                if (req.OrdenId <= 0 || string.IsNullOrWhiteSpace(req.NombreRecibe))
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "La orden y el nombre de quien recibe son obligatorios.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var fila = await connection.QueryFirstOrDefaultAsync(
                    "sp_EntregarOrden",
                    new
                    {
                        OrdenId = req.OrdenId,
                        UsuarioId = usuarioId,
                        NombreRecibe = req.NombreRecibe.Trim(),
                        Observaciones = string.IsNullOrWhiteSpace(req.Observaciones) ? null : req.Observaciones.Trim()
                    },
                    commandType: CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Equipo entregado. La orden queda ENTREGADO.";
                respuesta.data = TallerDTO.FilaCamel((object?)fila);
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "Entregar(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Entregar(): " + ex.Message };
            }
            return respuesta;
        }
    }
}
