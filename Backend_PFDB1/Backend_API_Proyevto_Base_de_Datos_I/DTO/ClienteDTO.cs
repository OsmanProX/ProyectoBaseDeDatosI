using System.ComponentModel.DataAnnotations;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Dapper;
using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    public class ClienteDTO
    {
        public int? ClienteId { get; set; }

        [Required(ErrorMessage = "TipoCliente es obligatorio")]
        public string? TipoCliente { get; set; }

        [Required(ErrorMessage = "NombreRazonSocial es obligatorio")]
        public string? NombreRazonSocial { get; set; }

        [Required(ErrorMessage = "NIT es obligatorio")]
        public string? NIT { get; set; }

        [Required(ErrorMessage = "Telefono es obligatorio")]
        public string? Telefono { get; set; }

        public string? Correo { get; set; }
        public string? Direccion { get; set; }
        public string? Estado { get; set; }

        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        // Usa sp_Cliente_Listar (script 11): filtra por nombre/NIT desde vw_Cliente.
        public async Task<ResponseDto> Consultar(string? busqueda)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var lista = await connection.QueryAsync<ClienteModel>(
                    "sp_Cliente_Listar",
                    new
                    {
                        Buscar = string.IsNullOrWhiteSpace(busqueda) ? null : busqueda.Trim(),
                        Estado = (string?)null
                    },
                    commandType: System.Data.CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = lista.ToList();
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Consultar(): " + ex.Message };
            }
            return respuesta;
        }

        // Equipos ACTIVOS de un cliente (para el formulario de nueva orden). Usa vw_Equipo.
        public async Task<ResponseDto> ConsultarEquipos(int id)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var lista = await connection.QueryAsync<EquipoDeClienteModel>(
                    // OrdenAbierta: número de la orden sin cerrar (no ENTREGADO=6 ni CANCELADO=7), igual que la regla 50108
                    @"SELECT e.EquipoId, e.TipoEquipo, e.Marca, e.Modelo, e.NumeroSerie,
                             (SELECT TOP 1 o.NumeroOrden FROM OrdenServicio o
                              WHERE o.EquipoId = e.EquipoId AND o.EstadoOrdenId NOT IN (6, 7)) AS OrdenAbierta
                      FROM vw_Equipo e
                      WHERE e.ClienteId = @Id AND e.Estado = 'ACTIVO'
                      ORDER BY EquipoId",
                    new { Id = id });

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = lista.ToList();
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarEquipos(): " + ex.Message };
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

                var cliente = await connection.QueryFirstOrDefaultAsync<ClienteModel>(
                    @"SELECT ClienteId, TipoCliente, NombreRazonSocial, NIT, Telefono,
                             Correo, Direccion, Estado, FechaRegistro
                      FROM Cliente WHERE ClienteId = @Id",
                    new { Id = id });

                if (cliente == null)
                {
                    respuesta.codigo = 404;
                    respuesta.mensaje = "Cliente no encontrado.";
                    return respuesta;
                }

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = cliente;
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarPorId(): " + ex.Message };
            }
            return respuesta;
        }

        // Usa sp_Cliente_Crear (script 09): valida tipo, nombre y NIT único (50301-50304).
        public async Task<ResponseDto> Crear()
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var parameters = new DynamicParameters();
                parameters.Add("@TipoCliente", TipoCliente);
                parameters.Add("@NombreRazonSocial", NombreRazonSocial);
                parameters.Add("@NIT", NIT);
                parameters.Add("@Telefono", Telefono);
                parameters.Add("@Correo", Correo);
                parameters.Add("@Direccion", Direccion);
                parameters.Add("@ClienteId", dbType: System.Data.DbType.Int32, direction: System.Data.ParameterDirection.Output);

                await connection.ExecuteAsync(
                    "sp_Cliente_Crear", parameters,
                    commandType: System.Data.CommandType.StoredProcedure);

                ClienteId = parameters.Get<int>("@ClienteId");

                respuesta.codigo = 200;
                respuesta.mensaje = "Cliente registrado exitosamente.";
                respuesta.data = new { ClienteId };
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "Crear(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Crear(): " + ex.Message };
            }
            return respuesta;
        }

        // Usa sp_Cliente_CrearAcceso (script 13): crea la cuenta con rol CLIENTE (51801-51806).
        public async Task<ResponseDto> CrearAcceso(int usuarioId, string contrasenaTemporal)
        {
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();
                var cuenta = await connection.QueryFirstAsync<CuentaClienteModel>(
                    "sp_Cliente_CrearAcceso",
                    new
                    {
                        UsuarioId = usuarioId,
                        ClienteId,
                        // VARCHAR igual que sp_LoginUsuario, para que el hash coincida
                        Contrasena = new DbString { Value = contrasenaTemporal, IsAnsi = true, Length = 255 },
                    },
                    commandType: System.Data.CommandType.StoredProcedure);
                return new ResponseDto { codigo = 200, mensaje = "Cuenta creada.", data = cuenta };
            }
            catch (SqlException ex)
            {
                return new ResponseDto { codigo = 400, mensaje = ex.Message };
            }
        }

        // ¿La orden pertenece al cliente ligado a esta cuenta? (para que un cliente no vea órdenes ajenas)
        public async Task<bool> EsMiOrden(int usuarioId, int ordenId)
        {
            using var connection = _dbConnectionFactory.CreateConnection();
            await connection.OpenAsync();
            return await connection.ExecuteScalarAsync<int>(
                @"SELECT COUNT(*) FROM OrdenServicio o
                  JOIN Usuario u ON u.ClienteId = o.ClienteId
                  WHERE u.UsuarioId = @UsuarioId AND u.Activo = 1 AND o.OrdenId = @OrdenId",
                new { UsuarioId = usuarioId, OrdenId = ordenId }) > 0;
        }

        // Usa sp_Cliente_MisOrdenes (script 13): órdenes del cliente que inició sesión.
        public async Task<ResponseDto> MisOrdenes(int usuarioId)
        {
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();
                var filas = (await connection.QueryAsync<MiOrdenModel>(
                    "sp_Cliente_MisOrdenes", new { UsuarioId = usuarioId },
                    commandType: System.Data.CommandType.StoredProcedure)).ToList();

                // Detalle extra (solo lectura y solo de las órdenes del cliente de esta cuenta):
                // diagnóstico y costo estimado, lo pagado, el último cambio de estado
                // (con el motivo si se canceló) y la entrega.
                var extras = (await connection.QueryAsync<MiOrdenExtraModel>(
                    @"SELECT o.OrdenId,
                             d.Descripcion AS Diagnostico,
                             d.CostoManoObraEstimado AS CostoEstimado,
                             (SELECT SUM(p.Monto) FROM Pago p
                               JOIN Factura f ON f.FacturaId = p.FacturaId
                              WHERE f.OrdenId = o.OrdenId AND f.Estado <> 'ANULADA' AND p.Estado = 'APLICADO') AS Pagado,
                             h.FechaCambio AS UltimoCambio,
                             CASE WHEN o.EstadoOrdenId = 7 THEN h.Observacion END AS MotivoCancelacion,
                             en.FechaEntrega, en.NombreRecibe
                      FROM OrdenServicio o
                      JOIN Usuario u ON u.ClienteId = o.ClienteId AND u.UsuarioId = @UsuarioId
                      OUTER APPLY (SELECT TOP 1 x.Descripcion, x.CostoManoObraEstimado FROM Diagnostico x
                                   WHERE x.OrdenId = o.OrdenId ORDER BY x.DiagnosticoId DESC) d
                      OUTER APPLY (SELECT TOP 1 x.FechaCambio, x.Observacion FROM HistorialEstadoOrden x
                                   WHERE x.OrdenId = o.OrdenId ORDER BY x.HistorialId DESC) h
                      OUTER APPLY (SELECT TOP 1 x.FechaEntrega, x.NombreRecibe FROM Entrega x
                                   WHERE x.OrdenId = o.OrdenId ORDER BY x.EntregaId DESC) en",
                    new { UsuarioId = usuarioId })).ToDictionary(x => x.OrdenId);

                foreach (var o in filas)
                {
                    if (!extras.TryGetValue(o.OrdenId, out var x)) continue;
                    o.Diagnostico = x.Diagnostico;
                    o.CostoEstimado = x.CostoEstimado;
                    o.Pagado = x.Pagado;
                    o.UltimoCambio = x.UltimoCambio;
                    o.MotivoCancelacion = x.MotivoCancelacion;
                    o.FechaEntrega = x.FechaEntrega;
                    o.NombreRecibe = x.NombreRecibe;
                }
                return new ResponseDto { codigo = 200, mensaje = "OK", data = filas };
            }
            catch (SqlException ex)
            {
                return new ResponseDto { codigo = 400, mensaje = "MisOrdenes(): " + ex.Message };
            }
        }

        // Usa sp_Cliente_Actualizar (script 11): valida existencia, tipo y NIT único (51101-51105).
        public async Task<ResponseDto> Actualizar()
        {
            ResponseDto respuesta = new();
            try
            {
                if (ClienteId is null or <= 0)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "ClienteId es obligatorio.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var parameters = new DynamicParameters();
                parameters.Add("@ClienteId", ClienteId);
                parameters.Add("@TipoCliente", TipoCliente);
                parameters.Add("@NombreRazonSocial", NombreRazonSocial);
                parameters.Add("@NIT", NIT);
                parameters.Add("@Telefono", Telefono);
                parameters.Add("@Correo", Correo);
                parameters.Add("@Direccion", Direccion);

                await connection.ExecuteAsync(
                    "sp_Cliente_Actualizar", parameters,
                    commandType: System.Data.CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Cliente actualizado exitosamente.";
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "Actualizar(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Actualizar(): " + ex.Message };
            }
            return respuesta;
        }

        // Borrado lógico con sp_Cliente_Eliminar (script 11): no inactiva si tiene órdenes abiertas (51112).
        public async Task<ResponseDto> Eliminar(int id)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                await connection.ExecuteAsync(
                    "sp_Cliente_Eliminar",
                    new { ClienteId = id },
                    commandType: System.Data.CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Cliente desactivado exitosamente.";
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "Eliminar(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Eliminar(): " + ex.Message };
            }
            return respuesta;
        }

        // Vuelve a ACTIVO con sp_Cliente_Activar (script 12)
        public async Task<ResponseDto> Activar(int id)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                await connection.ExecuteAsync(
                    "sp_Cliente_Activar",
                    new { ClienteId = id },
                    commandType: System.Data.CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Cliente activado exitosamente.";
            }
            catch (SqlException ex)
            {
                respuesta = new ResponseDto { codigo = 400, mensaje = "Activar(): " + ex.Message };
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Activar(): " + ex.Message };
            }
            return respuesta;
        }
    }
}
