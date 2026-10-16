using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Dapper;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    public class UsuarioListaDTO
    {
        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        public async Task<ResponseDto> Consultar()
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                string sql = @"
                    SELECT u.UsuarioId, u.NombreUsuario, u.NombreCompleto,
                           u.Correo, u.Telefono, u.Activo,
                           (SELECT STRING_AGG(r.Nombre, ', ') WITHIN GROUP (ORDER BY r.RolId)
                            FROM UsuarioRol ur
                            INNER JOIN Rol r ON r.RolId = ur.RolId
                            WHERE ur.UsuarioId = u.UsuarioId) AS Roles
                    FROM Usuario u
                    ORDER BY u.UsuarioId";

                var lista = await connection.QueryAsync(sql);

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
    }
}
