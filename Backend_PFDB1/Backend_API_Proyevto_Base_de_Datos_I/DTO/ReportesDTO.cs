using System.Data;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Dapper;
using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    // Semana 4 — Los 12 reportes del proyecto. Cada reporte ya existe en la base
    // como vista, función o procedimiento (scripts 04 y 07); aquí solo se filtra
    // con parámetros (nunca concatenando texto del usuario).
    public class ReportesDTO
    {
        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        // Filtro de fechas reutilizable: @Desde y @Hasta son opcionales (hasta incluye el día completo)
        private static string Rango(string columna) =>
            $"(@Desde IS NULL OR {columna} >= @Desde) AND (@Hasta IS NULL OR {columna} < DATEADD(DAY, 1, @Hasta))";

        // Consulta de cada reporte (1 al 11). El 12 usa sp_TrazabilidadOrden.
        // @Estado filtra por estado en los reportes 1 y 2 (orden) y 8 (compra).
        private static string? Consulta(int numero) => numero switch
        {
            1 => @"SELECT NumeroOrden, FechaIngreso, DiasAbierta, Estado, Prioridad, Cliente, TipoEquipo, Equipo,
                          NumeroSerie, RecibidoPor, TecnicoResponsable, ProblemaReportado, TotalSinIVA
                   FROM vw_OrdenesActivas
                   WHERE (@Buscar IS NULL OR NumeroOrden LIKE @Buscar OR Cliente LIKE @Buscar OR TecnicoResponsable LIKE @Buscar)
                     AND (@Estado IS NULL OR Estado = @Estado)
                   ORDER BY NivelPrioridad, FechaIngreso",
            2 => @"SELECT Cliente, TipoCliente, NIT, NumeroOrden, FechaIngreso, Estado, TipoEquipo, Equipo, NumeroSerie,
                          ProblemaReportado, NumeroFactura, TotalFacturado, SaldoPendiente, FechaEntrega
                   FROM vw_HistorialCliente
                   WHERE (@Buscar IS NULL OR Cliente LIKE @Buscar OR NIT LIKE @Buscar)
                     AND (@Estado IS NULL OR Estado = @Estado)
                   ORDER BY Cliente, FechaIngreso DESC",
            3 => @"SELECT NumeroSerie, TipoEquipo, Marca, Modelo, Propietario, NumeroOrden, FechaIngreso, EstadoOrden,
                          ProblemaReportado, TecnicoDiagnostico, Diagnostico, TecnicoReparacion, EstadoReparacion,
                          TrabajoRealizado, NumeroFactura, TotalFacturado
                   FROM vw_HistorialEquipo
                   WHERE (@Buscar IS NULL OR NumeroSerie LIKE @Buscar OR Propietario LIKE @Buscar)
                   ORDER BY NumeroSerie, FechaIngreso DESC",
            4 => $@"SELECT Tecnico, TipoTrabajo, Fecha, FechaFin, NumeroOrden, Cliente, NumeroSerie, Detalle, ManoObra, Estado
                    FROM vw_TrabajoTecnicos
                    WHERE {Rango("Fecha")} AND (@Buscar IS NULL OR Tecnico LIKE @Buscar)
                    ORDER BY Tecnico, Fecha DESC",
            5 => $@"SELECT NumeroOrden, Cliente, Tecnico, Bodega, Categoria, Codigo, Repuesto, Cantidad,
                           CostoHistorico, VentaHistorica, CostoTotal, VentaTotal, PrecioVentaActual, FechaRegistro
                    FROM vw_RepuestosUtilizados
                    WHERE {Rango("FechaRegistro")} AND (@BodegaId IS NULL OR BodegaId = @BodegaId)
                      AND (@Buscar IS NULL OR NumeroOrden LIKE @Buscar OR Tecnico LIKE @Buscar OR Repuesto LIKE @Buscar)
                    ORDER BY FechaRegistro DESC",
            6 => @"SELECT Bodega, Categoria, Codigo, Repuesto, Existencia, StockMinimo, PrecioCompraReferencia,
                          PrecioVenta, ValorInventario, EstadoStock
                   FROM vw_InventarioActual
                   WHERE (@BodegaId IS NULL OR BodegaId = @BodegaId)
                     AND (@Buscar IS NULL OR Codigo LIKE @Buscar OR Repuesto LIKE @Buscar OR Categoria LIKE @Buscar)
                   ORDER BY Bodega, Categoria, Repuesto",
            7 => @"SELECT Bodega, Categoria, Codigo, Repuesto, Existencia, StockMinimo, Faltante, EstadoStock
                   FROM vw_RepuestosBajoMinimo
                   WHERE (@BodegaId IS NULL OR BodegaId = @BodegaId)
                   ORDER BY Faltante DESC, Repuesto",
            8 => $@"SELECT Proveedor, NITProveedor, NumeroCompra, FechaCompra, FechaRecepcion, Estado, Bodega, RegistradaPor,
                           Codigo, Repuesto, Cantidad, CostoHistorico, Subtotal, CostoActual
                    FROM vw_ComprasProveedor
                    WHERE {Rango("FechaCompra")} AND (@Buscar IS NULL OR Proveedor LIKE @Buscar OR NumeroCompra LIKE @Buscar)
                      AND (@Estado IS NULL OR Estado = @Estado)
                    ORDER BY FechaCompra DESC, NumeroCompra",
            9 => $@"SELECT FechaMovimiento, TipoMovimiento, Bodega, Codigo, Repuesto, Cantidad, ExistenciaResultante,
                           TipoDocumento, DocumentoOrigen, Proveedor, Usuario, Observacion
                    FROM vw_MovimientosInventario
                    WHERE {Rango("FechaMovimiento")} AND (@BodegaId IS NULL OR BodegaId = @BodegaId)
                      AND (@Buscar IS NULL OR Repuesto LIKE @Buscar OR Codigo LIKE @Buscar OR DocumentoOrigen LIKE @Buscar)
                    ORDER BY FechaMovimiento DESC",
            10 => @"SELECT NumeroFactura, FechaEmision, NumeroOrden, Cliente, Total, TotalPagado, SaldoPendiente,
                           FechaPago, MetodoPago, MontoPago, Referencia, CobradoPor
                    FROM vw_FacturasSaldoPendiente
                    WHERE (@Buscar IS NULL OR Cliente LIKE @Buscar OR NumeroFactura LIKE @Buscar OR NumeroOrden LIKE @Buscar)
                    ORDER BY FechaEmision, NumeroFactura, FechaPago",
            11 => @"SELECT Anio, Mes, Facturas, ManoObra, Repuestos, Subtotal, IVA, TotalFacturado, Cobrado,
                           TotalFacturado - Cobrado AS PorCobrar
                    FROM dbo.fn_ReporteIngresos(ISNULL(@Desde, '2000-01-01'), ISNULL(@Hasta, '2100-12-31'))
                    ORDER BY Anio, Mes",
            _ => null
        };

        public async Task<ResponseDto> Generar(int numero, DateTime? desde, DateTime? hasta, string? buscar, int? bodegaId, string? estado = null)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                if (numero == 12)
                {
                    if (string.IsNullOrWhiteSpace(buscar))
                    {
                        respuesta.codigo = 400;
                        respuesta.mensaje = "Escriba el número de orden (por ejemplo OS-2026-0001).";
                        return respuesta;
                    }

                    using var multi = await connection.QueryMultipleAsync(
                        "sp_TrazabilidadOrden",
                        new { NumeroOrden = buscar.Trim().ToUpper() },
                        commandType: CommandType.StoredProcedure);

                    var resumen = (await multi.ReadAsync()).Select(f => TallerDTO.FilaCamel((object?)f)).FirstOrDefault();
                    var lineaTiempo = (await multi.ReadAsync()).Select(f => TallerDTO.FilaCamel((object?)f)).ToList();

                    respuesta.codigo = 200;
                    respuesta.mensaje = "Operación realizada exitosamente.";
                    respuesta.data = new { resumen, lineaTiempo };
                    return respuesta;
                }

                var sql = Consulta(numero);
                if (sql == null)
                {
                    respuesta.codigo = 404;
                    respuesta.mensaje = "El reporte no existe (use del 1 al 12).";
                    return respuesta;
                }

                var filas = await connection.QueryAsync(sql, new
                {
                    Desde = desde?.Date,
                    Hasta = hasta?.Date,
                    Buscar = string.IsNullOrWhiteSpace(buscar) ? null : "%" + buscar.Trim() + "%",
                    BodegaId = bodegaId is > 0 ? bodegaId : null,
                    Estado = string.IsNullOrWhiteSpace(estado) ? null : estado.Trim().ToUpper()
                });

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = filas.Select(f => TallerDTO.FilaCamel((object?)f)).ToList();
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "Generar(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Generar(): " + ex.Message };
            }
            return respuesta;
        }

        // Pantalla de inicio: números del día (vw_Dashboard) y actividad reciente
        public async Task<ResponseDto> Dashboard()
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var resumen = await connection.QueryFirstOrDefaultAsync("SELECT OrdenesAbiertas, Recibidas, EnDiagnostico, EsperandoAutorizacion, EnReparacion, ListasParaEntregar, FacturasConSaldo, SaldoPorCobrar, RepuestosBajoMinimo FROM vw_Dashboard");
                var actividad = await connection.QueryAsync(
                    "SELECT TOP (10) Fecha, Tipo, Detalle, Usuario FROM vw_ActividadReciente ORDER BY Fecha DESC");

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = new
                {
                    resumen = TallerDTO.FilaCamel((object?)resumen),
                    actividad = actividad.Select(f => TallerDTO.FilaCamel((object?)f)).ToList()
                };
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "Dashboard(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Dashboard(): " + ex.Message };
            }
            return respuesta;
        }
    }
}
