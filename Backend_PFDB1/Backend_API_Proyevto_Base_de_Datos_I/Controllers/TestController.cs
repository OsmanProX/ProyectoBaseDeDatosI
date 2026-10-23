using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TestController : ControllerBase
{
    private readonly IConfiguration _configuration;

    public TestController(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    // GET: api/test
    // Verifica que la API este funcionando.
    [HttpGet]
    public IActionResult VerificarApi()
    {
        return Ok(new
        {
            mensaje = "API funcionando correctamente",
            fecha = DateTime.UtcNow
        });
    }

    // GET: api/test/conexion
    // Verifica la conexion a la base de datos.
    [HttpGet("conexion")]
    public async Task<IActionResult> VerificarConexion()
    {
        var connectionString = _configuration.GetConnectionString("DefaultConnection");

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return StatusCode(500, new
            {
                conectado = false,
                error = "No se encontró la cadena de conexión DefaultConnection. Guárdela en los secretos de usuario (ver README, paso 2)."
            });
        }

        try
        {
            using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync();

            using var command = new SqlCommand(
                "SELECT DB_NAME() AS BaseDatos, GETUTCDATE() AS FechaServidor",
                connection);

            using var reader = await command.ExecuteReaderAsync();
            await reader.ReadAsync();

            return Ok(new
            {
                conectado = true,
                baseDatos = reader.GetString(0),
                fechaServidor = reader.GetDateTime(1)
            });
        }
        catch (SqlException ex)
        {
            return StatusCode(500, new
            {
                conectado = false,
                error = "No fue posible conectar con SQL Server.",
                detalle = ex.Message
            });
        }
    }
}
