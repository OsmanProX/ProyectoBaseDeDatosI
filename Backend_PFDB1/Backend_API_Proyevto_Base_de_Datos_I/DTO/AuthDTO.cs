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

        // Login por correo + contraseña vía sp_LoginUsuario.
        // El SP compara SHA256 de la contraseña con ContrasenaHash y,
        // si es exitoso, devuelve los datos del usuario y sus roles.
        public async Task<ResponseDto> Login(LoginRequest request)
        {
            ResponseDto respuesta = new ResponseDto();
            try
            {
                using (var connection = _dbConnectionFactory.CreateConnection())
                {
                    await connection.OpenAsync();

                    var parameters = new DynamicParameters();
                    parameters.Add("@Correo", request.Correo);
                    parameters.Add("@Contrasena", request.Password);

                    var usuario = await connection.QueryFirstOrDefaultAsync<VwUsuarioModel>(
                        "sp_LoginUsuario", parameters,
                        commandType: System.Data.CommandType.StoredProcedure);

                    if (usuario == null)
                    {
                        respuesta.codigo = 401;
                        respuesta.data = null;
                        respuesta.mensaje = "Correo o contrasena incorrectos.";
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
                        usuario.Telefono,
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
    }
}
