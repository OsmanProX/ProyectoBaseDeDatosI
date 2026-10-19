using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.BD
{
    public class DBContext
    {
        private readonly string _connectionString;

        public DBContext(IConfiguration configuration)
        {
            var cadena = configuration.GetConnectionString("DefaultConnection");
            if (string.IsNullOrWhiteSpace(cadena))
                throw new InvalidOperationException("No se encontró la cadena de conexión DefaultConnection. Guárdela en los secretos de usuario (ver README, paso 2).");
            _connectionString = cadena;
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
