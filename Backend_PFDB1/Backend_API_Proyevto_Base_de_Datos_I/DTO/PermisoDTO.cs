using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Dapper;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    public class PermisoDTO
    {
        public int? RolId { get; set; }

        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        // Lee la vista vw_Permiso (permisos con el nombre del rol).
        // Si viene RolId, filtra los permisos de ese rol.
        public async Task<ResponseDto> Consultar()
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                string sql = @"
                    SELECT PermisoId, RolId, Rol, permiso, activo
                    FROM vw_Permiso
                    WHERE (@RolId IS NULL OR RolId = @RolId)
                    ORDER BY RolId, PermisoId";

                var lista = await connection.QueryAsync(sql, new { RolId });

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
