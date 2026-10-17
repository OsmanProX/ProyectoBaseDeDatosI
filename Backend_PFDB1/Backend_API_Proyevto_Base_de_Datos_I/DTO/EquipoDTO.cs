using System.ComponentModel.DataAnnotations;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Dapper;
using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    public class EquipoDTO
    {
        public int? EquipoId { get; set; }

        [Required(ErrorMessage = "ClienteId es obligatorio")]
        public int? ClienteId { get; set; }

        [Required(ErrorMessage = "TipoEquipoId es obligatorio")]
        public int? TipoEquipoId { get; set; }

        [Required(ErrorMessage = "Marca es obligatoria")]
        public string? Marca { get; set; }

        [Required(ErrorMessage = "Modelo es obligatorio")]
        public string? Modelo { get; set; }

        [Required(ErrorMessage = "NumeroSerie es obligatorio")]
        public string? NumeroSerie { get; set; }

        public string? Descripcion { get; set; }
        public string? Estado { get; set; }

        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        // Usa sp_Equipo_Listar (script 11): lista desde vw_Equipo por cliente/texto.
        public async Task<ResponseDto> Consultar(int? clienteId)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var lista = await connection.QueryAsync<EquipoModel>(
                    "sp_Equipo_Listar",
                    new { ClienteId = clienteId, Buscar = (string?)null, SoloActivos = false },
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

        public async Task<ResponseDto> ConsultarPorId(int id)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var equipo = await connection.QueryFirstOrDefaultAsync<EquipoModel>(
                    @"SELECT e.EquipoId, e.ClienteId, e.TipoEquipoId,
                             te.Nombre AS NombreTipoEquipo,
                             c.NombreRazonSocial AS NombreCliente,
                             e.Marca, e.Modelo, e.NumeroSerie, e.Descripcion, e.Estado
                      FROM Equipo e
                      INNER JOIN TipoEquipo te ON te.TipoEquipoId = e.TipoEquipoId
                      INNER JOIN Cliente c ON c.ClienteId = e.ClienteId
                      WHERE e.EquipoId = @Id",
                    new { Id = id });

                if (equipo == null)
                {
                    respuesta.codigo = 404;
                    respuesta.mensaje = "Equipo no encontrado.";
                    return respuesta;
                }

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = equipo;
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarPorId(): " + ex.Message };
            }
            return respuesta;
        }

        // Usa sp_Equipo_Crear (script 09): valida cliente activo (50311), tipo (50312) y serie única (50313/50314).
        public async Task<ResponseDto> Crear()
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var parameters = new DynamicParameters();
                parameters.Add("@ClienteId", ClienteId);
                parameters.Add("@TipoEquipoId", TipoEquipoId);
                parameters.Add("@Marca", Marca);
                parameters.Add("@Modelo", Modelo);
                parameters.Add("@NumeroSerie", NumeroSerie);
                parameters.Add("@Descripcion", Descripcion);
                parameters.Add("@EquipoId", dbType: System.Data.DbType.Int32, direction: System.Data.ParameterDirection.Output);

                await connection.ExecuteAsync(
                    "sp_Equipo_Crear", parameters,
                    commandType: System.Data.CommandType.StoredProcedure);

                EquipoId = parameters.Get<int>("@EquipoId");

                respuesta.codigo = 200;
                respuesta.mensaje = "Equipo registrado exitosamente.";
                respuesta.data = new { EquipoId };
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

        // Usa sp_Equipo_Actualizar (script 11): valida existencia, cliente activo, tipo y serie única (51121-51125).
        public async Task<ResponseDto> Actualizar()
        {
            ResponseDto respuesta = new();
            try
            {
                if (EquipoId is null or <= 0)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "EquipoId es obligatorio.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var parameters = new DynamicParameters();
                parameters.Add("@EquipoId", EquipoId);
                parameters.Add("@ClienteId", ClienteId);
                parameters.Add("@TipoEquipoId", TipoEquipoId);
                parameters.Add("@Marca", Marca);
                parameters.Add("@Modelo", Modelo);
                parameters.Add("@NumeroSerie", NumeroSerie);
                parameters.Add("@Descripcion", Descripcion);

                await connection.ExecuteAsync(
                    "sp_Equipo_Actualizar", parameters,
                    commandType: System.Data.CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Equipo actualizado exitosamente.";
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

        // Borrado lógico con sp_Equipo_Eliminar (script 11): no inactiva si tiene órdenes abiertas (51132).
        public async Task<ResponseDto> Eliminar(int id)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                await connection.ExecuteAsync(
                    "sp_Equipo_Eliminar",
                    new { EquipoId = id },
                    commandType: System.Data.CommandType.StoredProcedure);

                respuesta.codigo = 200;
                respuesta.mensaje = "Equipo desactivado exitosamente.";
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

        public async Task<ResponseDto> ConsultarTipos()
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var lista = await connection.QueryAsync<TipoEquipoModel>(
                    "SELECT TipoEquipoId, Nombre FROM TipoEquipo ORDER BY TipoEquipoId");

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = lista.ToList();
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarTipos(): " + ex.Message };
            }
            return respuesta;
        }
    }
}
