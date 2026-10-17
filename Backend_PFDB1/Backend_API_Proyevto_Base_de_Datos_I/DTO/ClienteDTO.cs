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
                    @"SELECT EquipoId, TipoEquipo, Marca, Modelo, NumeroSerie
                      FROM vw_Equipo
                      WHERE ClienteId = @Id AND Estado = 'ACTIVO'
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
    }
}
