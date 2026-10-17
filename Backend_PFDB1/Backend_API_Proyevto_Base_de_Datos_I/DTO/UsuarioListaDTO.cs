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
                var lista = await connection.QueryAsync<UsuarioListaModel>(
                    "SELECT UsuarioId, NombreUsuario, NombreCompleto, Correo, Telefono, Activo, Roles FROM vw_UsuarioLista ORDER BY UsuarioId");

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
