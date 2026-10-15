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
    // Verifica que la API este funcionando
    [HttpGet]
    public IActionResult VerificarApi()
    {
        return Ok(new
        {
            mensaje = "API funcionando correctamente",
            fecha = DateTime.Now
        });
    }

    // GET: api/test/conexion
    // Verifica la conexion a la base de datos
    [HttpGet("conexion")]
    public IActionResult VerificarConexion()
    {
        var connectionString = _configuration.GetConnectionString("DefaultConnection");

        try
        {
            using var connection = new SqlConnection(connectionString);
            connection.Open();

            using var command = new SqlCommand(
                "SELECT DB_NAME() AS BaseDatos, GETDATE() AS FechaServidor",
                connection);

            using var reader = command.ExecuteReader();
            reader.Read();

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
                error = ex.Message
            });
        }
    }
}
