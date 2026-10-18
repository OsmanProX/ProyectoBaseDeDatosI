using System.Data;
using System.Text.Json;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Dapper;
using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    // Semana 3 — Taller. Usa los procedimientos del script 04:
    // sp_RegistrarDiagnostico, sp_IniciarReparacion, sp_RegistrarActividadReparacion,
    // sp_AsignarRepuesto y sp_FinalizarReparacion. Las reglas (estados, roles, stock)
    // las valida la base; aquí solo se revisan los datos obligatorios.
    public class TallerDTO
    {
        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        // La fila que devuelve el SP llega con nombres en PascalCase; se pasa a camelCase
        // para que el frontend reciba lo mismo que en el resto de la API.
        internal static Dictionary<string, object?>? FilaCamel(object? fila)
        {
            if (fila is not IDictionary<string, object> d) return null;
            return d.ToDictionary(k => JsonNamingPolicy.CamelCase.ConvertName(k.Key), v => (object?)v.Value);
        }

        // GET: órdenes activas para el taller (RECIBIDO .. LISTO), las urgentes primero
        public async Task<ResponseDto> ConsultarOrdenes(int? estadoId)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var lista = await connection.QueryAsync<TallerOrdenModel>(
                    @"SELECT OrdenId, NumeroOrden, FechaIngreso, FechaEstimada, DiasAbierta,
                             EstadoOrdenId, Estado, Prioridad, NivelPrioridad, ClienteId, Cliente,
                             TipoEquipo, Equipo, NumeroSerie, RecibidoPor, TecnicoResponsable,
                             ProblemaReportado, TotalSinIVA
                      FROM vw_OrdenesActivas
                      WHERE EstadoOrdenId <= 5
                        AND (@EstadoId IS NULL OR EstadoOrdenId = @EstadoId)
                      ORDER BY NivelPrioridad, FechaIngreso",
                    new { EstadoId = estadoId });

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

        // GET: detalle de una orden en el taller (diagnóstico, reparación, actividades y repuestos)
        public async Task<ResponseDto> ConsultarDetalle(int ordenId)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var orden = await connection.QueryFirstOrDefaultAsync<TallerOrdenModel>(
                    @"SELECT OrdenId, NumeroOrden, FechaIngreso, FechaEstimada, DiasAbierta,
                             EstadoOrdenId, Estado, Prioridad, NivelPrioridad, ClienteId, Cliente,
                             TipoEquipo, Equipo, NumeroSerie, RecibidoPor, TecnicoResponsable,
                             ProblemaReportado, TotalSinIVA
                      FROM vw_OrdenesActivas
                      WHERE OrdenId = @Id",
                    new { Id = ordenId });

                if (orden == null)
                {
                    respuesta.codigo = 404;
                    respuesta.mensaje = "La orden no existe o ya fue entregada/cancelada.";
                    return respuesta;
                }

                var diagnostico = await connection.QueryFirstOrDefaultAsync<DiagnosticoModel>(
                    @"SELECT d.DiagnosticoId, d.OrdenId, u.NombreCompleto AS Tecnico, d.FechaDiagnostico,
                             d.Descripcion, d.CostoManoObraEstimado, d.Observaciones
                      FROM Diagnostico d
                      INNER JOIN Usuario u ON u.UsuarioId = d.TecnicoId
                      WHERE d.OrdenId = @Id",
                    new { Id = ordenId });

                var reparacion = await connection.QueryFirstOrDefaultAsync<ReparacionModel>(
                    @"SELECT r.ReparacionId, u.NombreCompleto AS Tecnico, r.FechaInicio, r.FechaFin,
                             r.DescripcionTrabajo, r.CostoManoObra, r.Estado
                      FROM Reparacion r
                      INNER JOIN Diagnostico d ON d.DiagnosticoId = r.DiagnosticoId
                      INNER JOIN Usuario u ON u.UsuarioId = r.TecnicoId
                      WHERE d.OrdenId = @Id",
                    new { Id = ordenId });

                List<ActividadReparacionModel> actividades = new();
                List<RepuestoUsadoModel> repuestos = new();
                if (reparacion != null)
                {
                    actividades = (await connection.QueryAsync<ActividadReparacionModel>(
                        @"SELECT NumeroActividad, Descripcion, HorasTrabajadas, FechaRegistro
                          FROM ActividadReparacion
                          WHERE ReparacionId = @R
                          ORDER BY NumeroActividad",
                        new { R = reparacion.ReparacionId })).ToList();

                    repuestos = (await connection.QueryAsync<RepuestoUsadoModel>(
                        @"SELECT rr.RepuestoId, rp.Codigo, rp.Nombre AS Repuesto, b.Nombre AS Bodega,
                                 rr.Cantidad, rr.PrecioVentaUnitario,
                                 rr.Cantidad * rr.PrecioVentaUnitario AS Subtotal, rr.FechaRegistro
                          FROM ReparacionRepuesto rr
                          INNER JOIN Repuesto rp ON rp.RepuestoId = rr.RepuestoId
                          INNER JOIN Bodega b ON b.BodegaId = rr.BodegaId
                          WHERE rr.ReparacionId = @R
                          ORDER BY rr.FechaRegistro",
                        new { R = reparacion.ReparacionId })).ToList();
                }

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = new { orden, diagnostico, reparacion, actividades, repuestos };
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

        // GET: repuestos con existencia en alguna bodega (para asignar a la reparación)
        public async Task<ResponseDto> ConsultarRepuestosDisponibles()
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var lista = await connection.QueryAsync<RepuestoDisponibleModel>(
                    @"SELECT v.BodegaId, v.Bodega, v.RepuestoId, v.Codigo, v.Repuesto, v.Categoria,
                             v.Existencia, v.PrecioVenta
                      FROM vw_InventarioActual v
                      INNER JOIN Repuesto r ON r.RepuestoId = v.RepuestoId
                      WHERE v.Existencia > 0 AND r.Estado = 'ACTIVO'
                      ORDER BY v.Repuesto, v.Bodega");

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = lista.ToList();
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "ConsultarRepuestosDisponibles(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarRepuestosDisponibles(): " + ex.Message };
            }
            return respuesta;
        }

        // POST: sp_RegistrarDiagnostico (orden RECIBIDO/DIAGNOSTICO → ESPERANDO_AUTORIZACION)
        public async Task<ResponseDto> RegistrarDiagnostico(DiagnosticoRequest req, int tecnicoId)
        {
            ResponseDto respuesta = new();
            try
            {
                if (req.OrdenId <= 0 || string.IsNullOrWhiteSpace(req.Descripcion))
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "La orden y la descripción del diagnóstico son obligatorias.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var parameters = new DynamicParameters();
                parameters.Add("@OrdenId", req.OrdenId);
                parameters.Add("@TecnicoId", tecnicoId);
                parameters.Add("@Descripcion", req.Descripcion.Trim());
                parameters.Add("@CostoManoObraEstimado", req.CostoManoObraEstimado);
                parameters.Add("@Observaciones", string.IsNullOrWhiteSpace(req.Observaciones) ? null : req.Observaciones.Trim());
                parameters.Add("@DiagnosticoId", dbType: DbType.Int32, direction: ParameterDirection.Output);

                var fila = await connection.QueryFirstOrDefaultAsync(
                    "sp_RegistrarDiagnostico", parameters, commandType: CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Diagnóstico registrado. La orden queda esperando la autorización del cliente.";
                respuesta.data = FilaCamel((object?)fila);
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "RegistrarDiagnostico(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "RegistrarDiagnostico(): " + ex.Message };
            }
            return respuesta;
        }

        // POST: sp_IniciarReparacion (el cliente autorizó → REPARACION)
        public async Task<ResponseDto> IniciarReparacion(IniciarReparacionRequest req, int tecnicoId)
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
                parameters.Add("@TecnicoId", tecnicoId);
                parameters.Add("@DescripcionTrabajo", string.IsNullOrWhiteSpace(req.DescripcionTrabajo) ? null : req.DescripcionTrabajo.Trim());
                parameters.Add("@ReparacionId", dbType: DbType.Int32, direction: ParameterDirection.Output);

                var fila = await connection.QueryFirstOrDefaultAsync(
                    "sp_IniciarReparacion", parameters, commandType: CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Reparación iniciada.";
                respuesta.data = FilaCamel((object?)fila);
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "IniciarReparacion(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "IniciarReparacion(): " + ex.Message };
            }
            return respuesta;
        }

        // POST: sp_RegistrarActividadReparacion
        public async Task<ResponseDto> RegistrarActividad(ActividadRequest req, int usuarioId)
        {
            ResponseDto respuesta = new();
            try
            {
                if (req.ReparacionId <= 0 || string.IsNullOrWhiteSpace(req.Descripcion))
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "La reparación y la descripción de la actividad son obligatorias.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var fila = await connection.QueryFirstOrDefaultAsync(
                    "sp_RegistrarActividadReparacion",
                    new
                    {
                        ReparacionId = req.ReparacionId,
                        UsuarioId = usuarioId,
                        Descripcion = req.Descripcion.Trim(),
                        HorasTrabajadas = req.HorasTrabajadas
                    },
                    commandType: CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Actividad registrada.";
                respuesta.data = FilaCamel((object?)fila);
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "RegistrarActividad(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "RegistrarActividad(): " + ex.Message };
            }
            return respuesta;
        }

        // POST: sp_AsignarRepuesto (descuenta inventario y registra la SALIDA en una transacción)
        public async Task<ResponseDto> AsignarRepuesto(AsignarRepuestoRequest req, int usuarioId)
        {
            ResponseDto respuesta = new();
            try
            {
                if (req.ReparacionId <= 0 || req.RepuestoId <= 0 || req.BodegaId <= 0)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "La reparación, el repuesto y la bodega son obligatorios.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var fila = await connection.QueryFirstOrDefaultAsync(
                    "sp_AsignarRepuesto",
                    new
                    {
                        ReparacionId = req.ReparacionId,
                        RepuestoId = req.RepuestoId,
                        BodegaId = req.BodegaId,
                        Cantidad = req.Cantidad,
                        UsuarioId = usuarioId
                    },
                    commandType: CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Repuesto asignado y descontado del inventario.";
                respuesta.data = FilaCamel((object?)fila);
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "AsignarRepuesto(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "AsignarRepuesto(): " + ex.Message };
            }
            return respuesta;
        }

        // POST: sp_FinalizarReparacion (REPARACION → LISTO)
        public async Task<ResponseDto> FinalizarReparacion(FinalizarReparacionRequest req, int tecnicoId)
        {
            ResponseDto respuesta = new();
            try
            {
                if (req.ReparacionId <= 0)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "La reparación es obligatoria.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var fila = await connection.QueryFirstOrDefaultAsync(
                    "sp_FinalizarReparacion",
                    new
                    {
                        ReparacionId = req.ReparacionId,
                        TecnicoId = tecnicoId,
                        CostoManoObra = req.CostoManoObra,
                        DescripcionTrabajo = string.IsNullOrWhiteSpace(req.DescripcionTrabajo) ? null : req.DescripcionTrabajo.Trim()
                    },
                    commandType: CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Reparación finalizada. La orden queda LISTO para facturar y entregar.";
                respuesta.data = FilaCamel((object?)fila);
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "FinalizarReparacion(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "FinalizarReparacion(): " + ex.Message };
            }
            return respuesta;
        }
    }
}
