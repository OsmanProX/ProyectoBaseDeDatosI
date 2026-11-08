using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Dapper;
using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    // Cuentas desde el login: registro del cliente, recuperar y cambiar contraseña (script 14).
    public class CuentaDTO
    {
        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        // VARCHAR igual que sp_LoginUsuario, para que el hash coincida
        private static DbString Clave(string? valor) => new() { Value = valor, IsAnsi = true, Length = 255 };

        public async Task<ResponseDto> Registrarse(RegistroClienteRequest r)
        {
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();
                var cuenta = await connection.QueryFirstAsync<CuentaClienteModel>(
                    "sp_Cliente_Registrarse",
                    new
                    {
                        r.TipoCliente, r.NombreRazonSocial, r.NIT, r.Telefono, r.Correo, r.Direccion,
                        Contrasena = Clave(r.Contrasena),
                    },
                    commandType: System.Data.CommandType.StoredProcedure);
                return new ResponseDto { codigo = 200, mensaje = "Cuenta creada.", data = cuenta };
            }
            catch (SqlException ex)
            {
                return new ResponseDto { codigo = 400, mensaje = ex.Message };
            }
        }

        // Devuelve la cuenta si el correo existe; null si no (no se revela al usuario)
        public async Task<CuentaClienteModel?> Recuperar(string correo, string temporal)
        {
            using var connection = _dbConnectionFactory.CreateConnection();
            await connection.OpenAsync();
            return await connection.QueryFirstOrDefaultAsync<CuentaClienteModel>(
                "sp_Usuario_RecuperarContrasena",
                new { Correo = correo, Contrasena = Clave(temporal) },
                commandType: System.Data.CommandType.StoredProcedure);
        }

        // Si el correo de recuperación falla, se devuelve la contraseña anterior (la cuenta no queda inutilizable)
        public async Task Restaurar(CuentaClienteModel cuenta)
        {
            using var connection = _dbConnectionFactory.CreateConnection();
            await connection.OpenAsync();
            await connection.ExecuteAsync(
                "UPDATE dbo.Usuario SET ContrasenaHash = @Hash, DebeCambiarContrasena = @Debe WHERE UsuarioId = @Id",
                new { Hash = cuenta.HashAnterior, Debe = cuenta.DebeCambiarAnterior, Id = cuenta.UsuarioId });
        }

        public async Task<ResponseDto> MiCuenta(int usuarioId, MiCuentaRequest? cambios = null)
        {
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();
                var cuenta = cambios is null
                    ? await connection.QueryFirstOrDefaultAsync<MiCuentaModel>(
                        "sp_MiCuenta_Obtener", new { UsuarioId = usuarioId },
                        commandType: System.Data.CommandType.StoredProcedure)
                    : await connection.QueryFirstOrDefaultAsync<MiCuentaModel>(
                        "sp_MiCuenta_Actualizar",
                        new { UsuarioId = usuarioId, cambios.NombreCompleto, cambios.Telefono, cambios.Direccion },
                        commandType: System.Data.CommandType.StoredProcedure);
                return cuenta is null
                    ? new ResponseDto { codigo = 404, mensaje = "No se encontró la cuenta." }
                    : new ResponseDto { codigo = 200, mensaje = cambios is null ? "OK" : "Datos actualizados.", data = cuenta };
            }
            catch (SqlException ex)
            {
                return new ResponseDto { codigo = 400, mensaje = ex.Message };
            }
        }

        public async Task<ResponseDto> CambiarMiContrasena(int usuarioId, string? actual, string? nueva)
        {
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();
                await connection.ExecuteAsync(
                    "sp_Usuario_CambiarMiContrasena",
                    new { UsuarioId = usuarioId, Actual = Clave(actual), Nueva = Clave(nueva) },
                    commandType: System.Data.CommandType.StoredProcedure);
                return new ResponseDto { codigo = 200, mensaje = "Contraseña actualizada.", data = new { mensaje = "Contraseña actualizada." } };
            }
            catch (SqlException ex)
            {
                return new ResponseDto { codigo = 400, mensaje = ex.Message };
            }
        }
    }
}
