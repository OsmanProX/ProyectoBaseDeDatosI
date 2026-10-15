using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.BD
{
    public class DBContext
    {
        private readonly string _connectionString;

        public DBContext(IConfiguration configuration)
        {
            _connectionString = configuration.GetConnectionString("DefaultConnection")
                ?? throw new InvalidOperationException("No se encontro la cadena de conexion DefaultConnection.");
        }

        public SqlConnection CreateConnection()
        {
            return new SqlConnection(_connectionString);
        }

        public async Task OpenConnectionAsync(SqlConnection connection)
        {
            await connection.OpenAsync();
        }
    }
}
