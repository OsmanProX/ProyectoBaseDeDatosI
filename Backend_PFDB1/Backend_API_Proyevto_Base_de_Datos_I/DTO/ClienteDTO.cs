using System.ComponentModel.DataAnnotations;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Dapper;

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

        public async Task<ResponseDto> Consultar(string? busqueda)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                string sql = @"
                    SELECT ClienteId, TipoCliente, NombreRazonSocial, NIT, Telefono,
                           Correo, Direccion, Estado, FechaRegistro
                    FROM Cliente
                    WHERE (@Busqueda IS NULL
                           OR NombreRazonSocial LIKE @Patron
                           OR NIT LIKE @Patron)
                    ORDER BY ClienteId";

                var lista = await connection.QueryAsync<ClienteModel>(sql, new
                {
                    Busqueda = string.IsNullOrWhiteSpace(busqueda) ? null : busqueda,
                    Patron = $"%{busqueda}%"
                });

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

        public async Task<ResponseDto> Crear()
        {
            ResponseDto respuesta = new();
            try
            {
                if (TipoCliente is not ("INDIVIDUAL" or "EMPRESARIAL"))
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "TipoCliente debe ser INDIVIDUAL o EMPRESARIAL.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                int nuevoId = await connection.ExecuteScalarAsync<int>(@"
                    INSERT INTO Cliente (TipoCliente, NombreRazonSocial, NIT, Telefono, Correo, Direccion)
                    VALUES (@TipoCliente, @NombreRazonSocial, @NIT, @Telefono, @Correo, @Direccion);
                    SELECT CAST(SCOPE_IDENTITY() AS INT);",
                    new
                    {
                        TipoCliente,
                        NombreRazonSocial,
                        NIT,
                        Telefono,
                        Correo,
                        Direccion
                    });

                ClienteId = nuevoId;
                respuesta.codigo = 200;
                respuesta.mensaje = "Cliente registrado exitosamente.";
                respuesta.data = new { ClienteId = nuevoId };
            }
            catch (Exception ex)
            {
                string mensaje = ex.Message.Contains("UX_Cliente_NIT") || ex.Message.Contains("duplicate")
                    ? "Ya existe un cliente con ese NIT."
                    : ex.Message;
                respuesta = new ResponseDto { codigo = 500, mensaje = "Crear(): " + mensaje };
            }
            return respuesta;
        }

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
                if (TipoCliente is not ("INDIVIDUAL" or "EMPRESARIAL"))
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "TipoCliente debe ser INDIVIDUAL o EMPRESARIAL.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                int filas = await connection.ExecuteAsync(@"
                    UPDATE Cliente
                    SET TipoCliente = @TipoCliente,
                        NombreRazonSocial = @NombreRazonSocial,
                        NIT = @NIT,
                        Telefono = @Telefono,
                        Correo = @Correo,
                        Direccion = @Direccion
                    WHERE ClienteId = @ClienteId",
                    new
                    {
                        ClienteId,
                        TipoCliente,
                        NombreRazonSocial,
                        NIT,
                        Telefono,
                        Correo,
                        Direccion
                    });

                if (filas == 0)
                {
                    respuesta.codigo = 404;
                    respuesta.mensaje = "Cliente no encontrado.";
                    return respuesta;
                }

                respuesta.codigo = 200;
                respuesta.mensaje = "Cliente actualizado exitosamente.";
            }
            catch (Exception ex)
            {
                string mensaje = ex.Message.Contains("UX_Cliente_NIT") || ex.Message.Contains("duplicate")
                    ? "Ya existe otro cliente con ese NIT."
                    : ex.Message;
                respuesta = new ResponseDto { codigo = 500, mensaje = "Actualizar(): " + mensaje };
            }
            return respuesta;
        }

        // Borrado lógico: el cliente pasa a INACTIVO para no romper órdenes e historial.
        public async Task<ResponseDto> Eliminar(int id)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                int filas = await connection.ExecuteAsync(
                    "UPDATE Cliente SET Estado = 'INACTIVO' WHERE ClienteId = @Id",
                    new { Id = id });

                if (filas == 0)
                {
                    respuesta.codigo = 404;
                    respuesta.mensaje = "Cliente no encontrado.";
                    return respuesta;
                }

                respuesta.codigo = 200;
                respuesta.mensaje = "Cliente desactivado exitosamente.";
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Eliminar(): " + ex.Message };
            }
            return respuesta;
        }
    }
}
