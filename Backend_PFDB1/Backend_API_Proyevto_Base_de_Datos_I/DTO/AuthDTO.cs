using System.Security.Cryptography;
using System.Text;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Dapper;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    public class AuthDTO
    {
        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        public async Task<ResponseDto> Login(LoginRequest request)
        {
            ResponseDto respuesta = new ResponseDto();
            try
            {
                using (var connection = _dbConnectionFactory.CreateConnection())
                {
                    await connection.OpenAsync();

                    string sql = @"
                        SELECT u.UsuarioId, u.NombreUsuario, u.ContrasenaHash,
                               u.NombreCompleto, u.Correo, u.Activo,
                               STUFF((
                                   SELECT ', ' + r.Nombre
                                   FROM UsuarioRol ur
                                   INNER JOIN Rol r ON r.RolId = ur.RolId
                                   WHERE ur.UsuarioId = u.UsuarioId
                                   FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '') AS Roles
                        FROM Usuario u
                        WHERE u.NombreUsuario = @Usuario AND u.Activo = 1";

                    var usuario = await connection.QueryFirstOrDefaultAsync<VwUsuarioModel>(
                        sql, new { request.Usuario });

                    if (usuario == null)
                    {
                        respuesta.codigo = 401;
                        respuesta.data = null;
                        respuesta.mensaje = "Usuario o contrasena incorrectos.";
                        return respuesta;
                    }

                    string hashIngresado = CalcularHash(request.Password);
                    bool contrasenaValida =
                        string.Equals(hashIngresado, usuario.ContrasenaHash, StringComparison.OrdinalIgnoreCase)
                        || request.Password == usuario.ContrasenaHash;

                    if (!contrasenaValida)
                    {
                        respuesta.codigo = 401;
                        respuesta.data = null;
                        respuesta.mensaje = "Usuario o contrasena incorrectos.";
                        return respuesta;
                    }

                    respuesta.codigo = 200;
                    respuesta.mensaje = "Operacion realizada exitosamente.";
                    respuesta.data = new
                    {
                        usuario.UsuarioId,
                        usuario.NombreUsuario,
                        usuario.NombreCompleto,
                        usuario.Correo,
                        Roles = usuario.Roles ?? "SIN_ROL"
                    };
                }
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto
                {
                    codigo = 500,
                    data = null,
                    mensaje = "Login(): " + ex.Message
                };
            }
            return respuesta;
        }

        private static string CalcularHash(string texto)
        {
            using var sha = SHA256.Create();
            byte[] bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(texto));
            return Convert.ToHexString(bytes);
        }
    }
}
