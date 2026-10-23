using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
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

                // vw_UsuarioLista (script 10): usuarios con sus roles ya concatenados.
                // RolIds: los Id de sus roles, para el formulario de edición.
                var lista = await connection.QueryAsync<UsuarioListaModel>(
                    @"SELECT v.UsuarioId, v.NombreUsuario, v.NombreCompleto, v.Correo, v.Telefono, v.Activo, v.Roles,
                             (SELECT STRING_AGG(CAST(ur.RolId AS VARCHAR(10)), ',')
                              FROM UsuarioRol ur WHERE ur.UsuarioId = v.UsuarioId) AS RolIds
                      FROM vw_UsuarioLista v
                      ORDER BY v.UsuarioId");

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
