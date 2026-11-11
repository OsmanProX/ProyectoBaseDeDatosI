using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Dapper;
using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    public class OrdenDTO
    {
        public int? OrdenId { get; set; }
        public int? ClienteId { get; set; }
        public int? EquipoId { get; set; }
        public int? UsuarioRecepcionId { get; set; }
        public string? ProblemaReportado { get; set; }

        public string? Prioridad { get; set; } = "MEDIA";
        public DateTime? FechaEstimada { get; set; }
        public string? Observaciones { get; set; }

        // Campos para cambiar estado
        public int? EstadoNuevoId { get; set; }
        public int? UsuarioId { get; set; }
        public string? Observacion { get; set; }

        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        // Usa sp_ListarOrdenes (script 10): filtra por texto y por código de estado o 'ABIERTAS'.
        public async Task<ResponseDto> Consultar(string? buscar, string? estado)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var lista = await connection.QueryAsync<OrdenListaModel>(
                    "sp_ListarOrdenes",
                    new
                    {
                        Buscar = string.IsNullOrWhiteSpace(buscar) ? null : buscar.Trim(),
                        Estado = string.IsNullOrWhiteSpace(estado) ? null : estado.Trim()
                    },
                    commandType: System.Data.CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = lista.ToList();
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "Consultar(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Consultar(): " + ex.Message };
            }
            return respuesta;
        }

        // Solo el historial de estados de una orden (para la vista de detalle).
        public async Task<ResponseDto> ConsultarHistorial(int id)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var historial = await connection.QueryAsync<HistorialOrdenModel>(
                    @"SELECT h.HistorialId,
                             ea.Codigo AS EstadoAnterior,
                             en.Codigo AS EstadoNuevo,
                             h.FechaCambio,
                             u.NombreCompleto AS Usuario,
                             h.Observacion
                      FROM HistorialEstadoOrden h
                      INNER JOIN EstadoOrden en ON en.EstadoOrdenId = h.EstadoNuevoId
                      LEFT JOIN EstadoOrden ea ON ea.EstadoOrdenId = h.EstadoAnteriorId
                      INNER JOIN Usuario u ON u.UsuarioId = h.UsuarioId
                      WHERE h.OrdenId = @Id
                      ORDER BY h.HistorialId",
                    new { Id = id });

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = historial.ToList();
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarHistorial(): " + ex.Message };
            }
            return respuesta;
        }

        // Resumen del proceso de la orden (solo lectura, no modifica nada):
        // último diagnóstico, su reparación, la factura vigente con lo pagado y saldo, y la entrega.
        public async Task<ResponseDto> ConsultarResumen(int id)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var resumen = await connection.QueryFirstOrDefaultAsync<ResumenOrdenModel>(
                    @"SELECT d.FechaDiagnostico, td.NombreCompleto AS TecnicoDiagnostico,
                             d.Descripcion AS Diagnostico, d.CostoManoObraEstimado,
                             r.Estado AS EstadoReparacion, tr.NombreCompleto AS TecnicoReparacion,
                             r.FechaInicio, r.FechaFin, r.DescripcionTrabajo AS TrabajoRealizado, r.CostoManoObra,
                             (SELECT COUNT(*) FROM ActividadReparacion a WHERE a.ReparacionId = r.ReparacionId) AS Actividades,
                             (SELECT ISNULL(SUM(a.HorasTrabajadas), 0) FROM ActividadReparacion a WHERE a.ReparacionId = r.ReparacionId) AS Horas,
                             (SELECT ISNULL(SUM(rr.Cantidad), 0) FROM ReparacionRepuesto rr WHERE rr.ReparacionId = r.ReparacionId) AS UnidadesRepuesto,
                             (SELECT ISNULL(SUM(rr.Cantidad * rr.PrecioVentaUnitario), 0) FROM ReparacionRepuesto rr WHERE rr.ReparacionId = r.ReparacionId) AS VentaRepuestos,
                             f.NumeroFactura, f.FechaEmision, f.Total AS TotalFactura, f.Estado AS EstadoFactura,
                             (SELECT ISNULL(SUM(p.Monto), 0) FROM Pago p WHERE p.FacturaId = f.FacturaId AND p.Estado = 'APLICADO') AS Pagado,
                             dbo.fn_SaldoFactura(f.FacturaId) AS Saldo,
                             e.FechaEntrega, e.NombreRecibe, ue.NombreCompleto AS EntregadoPor
                      FROM OrdenServicio o
                      OUTER APPLY (SELECT TOP 1 * FROM Diagnostico x WHERE x.OrdenId = o.OrdenId ORDER BY x.DiagnosticoId DESC) d
                      LEFT JOIN Usuario td ON td.UsuarioId = d.TecnicoId
                      OUTER APPLY (SELECT TOP 1 * FROM Reparacion x WHERE x.DiagnosticoId = d.DiagnosticoId ORDER BY x.ReparacionId DESC) r
                      LEFT JOIN Usuario tr ON tr.UsuarioId = r.TecnicoId
                      OUTER APPLY (SELECT TOP 1 * FROM Factura x WHERE x.OrdenId = o.OrdenId AND x.Estado <> 'ANULADA' ORDER BY x.FacturaId DESC) f
                      OUTER APPLY (SELECT TOP 1 * FROM Entrega x WHERE x.OrdenId = o.OrdenId ORDER BY x.EntregaId DESC) e
                      LEFT JOIN Usuario ue ON ue.UsuarioId = e.UsuarioEntregaId
                      WHERE o.OrdenId = @Id",
                    new { Id = id });

                if (resumen is null)
                    return new ResponseDto { codigo = 404, mensaje = "La orden no existe." };

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = resumen;
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarResumen(): " + ex.Message };
            }
            return respuesta;
        }

        public async Task<ResponseDto> ConsultarPorId(int id)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var orden = await connection.QueryFirstOrDefaultAsync<OrdenModel>(
                    @"SELECT o.OrdenId, o.NumeroOrden, o.ClienteId,
                             c.NombreRazonSocial AS NombreCliente,
                             o.EquipoId,
                             e.NumeroSerie,
                             te.Nombre + ' ' + e.Marca + ' ' + e.Modelo AS Equipo,
                             o.UsuarioRecepcionId,
                             u.NombreCompleto AS Recepcionista,
                             o.FechaIngreso, o.ProblemaReportado, o.Prioridad,
                             o.EstadoOrdenId, eo.Codigo AS Estado,
                             o.FechaEstimada, o.Observaciones
                      FROM OrdenServicio o
                      INNER JOIN Cliente c ON c.ClienteId = o.ClienteId
                      INNER JOIN Equipo e ON e.EquipoId = o.EquipoId
                      INNER JOIN TipoEquipo te ON te.TipoEquipoId = e.TipoEquipoId
                      INNER JOIN EstadoOrden eo ON eo.EstadoOrdenId = o.EstadoOrdenId
                      INNER JOIN Usuario u ON u.UsuarioId = o.UsuarioRecepcionId
                      WHERE o.OrdenId = @Id",
                    new { Id = id });

                if (orden == null)
                {
                    respuesta.codigo = 404;
                    respuesta.mensaje = "Orden no encontrada.";
                    return respuesta;
                }

                var historial = await connection.QueryAsync<HistorialOrdenModel>(
                    @"SELECT h.HistorialId,
                             ea.Codigo AS EstadoAnterior,
                             en.Codigo AS EstadoNuevo,
                             h.FechaCambio,
                             u.NombreCompleto AS Usuario,
                             h.Observacion
                      FROM HistorialEstadoOrden h
                      INNER JOIN EstadoOrden en ON en.EstadoOrdenId = h.EstadoNuevoId
                      LEFT JOIN EstadoOrden ea ON ea.EstadoOrdenId = h.EstadoAnteriorId
                      INNER JOIN Usuario u ON u.UsuarioId = h.UsuarioId
                      WHERE h.OrdenId = @Id
                      ORDER BY h.HistorialId",
                    new { Id = id });

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = new { orden, historial = historial.ToList() };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarPorId(): " + ex.Message };
            }
            return respuesta;
        }

        // Usa sp_RegistrarOrden (valida cliente/equipo/rol y genera el número de orden).
        public async Task<ResponseDto> Registrar()
        {
            ResponseDto respuesta = new();
            try
            {
                if (ClienteId is null or <= 0 || EquipoId is null or <= 0 || UsuarioRecepcionId is null or <= 0)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "ClienteId, EquipoId y UsuarioRecepcionId son obligatorios.";
                    return respuesta;
                }
                if (string.IsNullOrWhiteSpace(ProblemaReportado))
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "ProblemaReportado es obligatorio.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var parameters = new DynamicParameters();
                parameters.Add("@ClienteId", ClienteId);
                parameters.Add("@EquipoId", EquipoId);
                parameters.Add("@UsuarioRecepcionId", UsuarioRecepcionId);
                parameters.Add("@ProblemaReportado", ProblemaReportado);
                parameters.Add("@Prioridad", Prioridad ?? "MEDIA");
                parameters.Add("@FechaEstimada", FechaEstimada);
                parameters.Add("@Observaciones", Observaciones);
                parameters.Add("@OrdenId", dbType: System.Data.DbType.Int32, direction: System.Data.ParameterDirection.Output);
                parameters.Add("@NumeroOrden", dbType: System.Data.DbType.String, direction: System.Data.ParameterDirection.Output, size: 15);

                await connection.ExecuteAsync(
                    "sp_RegistrarOrden", parameters,
                    commandType: System.Data.CommandType.StoredProcedure);

                OrdenId = parameters.Get<int>("@OrdenId");
                string numeroOrden = parameters.Get<string>("@NumeroOrden");

                respuesta.codigo = 200;
                respuesta.mensaje = "Orden registrada exitosamente.";
                respuesta.data = new { OrdenId, NumeroOrden = numeroOrden, Estado = "RECIBIDO" };
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "Registrar(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Registrar(): " + ex.Message };
            }
            return respuesta;
        }

        // Usa sp_CambiarEstadoOrden (valida transición, permisos por rol y guarda historial).
        public async Task<ResponseDto> CambiarEstado()
        {
            ResponseDto respuesta = new();
            try
            {
                if (OrdenId is null or <= 0 || EstadoNuevoId is null || UsuarioId is null)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "OrdenId, EstadoNuevoId y UsuarioId son obligatorios.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var parameters = new DynamicParameters();
                parameters.Add("@OrdenId", OrdenId);
                parameters.Add("@EstadoNuevoId", EstadoNuevoId);
                parameters.Add("@UsuarioId", UsuarioId);
                parameters.Add("@Observacion", Observacion);

                var resultado = await connection.QueryFirstOrDefaultAsync(
                    "sp_CambiarEstadoOrden", parameters,
                    commandType: System.Data.CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Estado de la orden actualizado exitosamente.";
                respuesta.data = resultado;
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "CambiarEstado(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "CambiarEstado(): " + ex.Message };
            }
            return respuesta;
        }

        public async Task<ResponseDto> ConsultarEstados()
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var lista = await connection.QueryAsync<EstadoOrdenModel>(
                    "SELECT EstadoOrdenId, Codigo, Descripcion FROM EstadoOrden ORDER BY EstadoOrdenId");

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = lista.ToList();
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarEstados(): " + ex.Message };
            }
            return respuesta;
        }
    }
}
