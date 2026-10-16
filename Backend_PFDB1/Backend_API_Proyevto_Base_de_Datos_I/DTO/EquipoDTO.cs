using System.ComponentModel.DataAnnotations;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Dapper;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    public class EquipoDTO
    {
        public int? EquipoId { get; set; }

        [Required(ErrorMessage = "ClienteId es obligatorio")]
        public int? ClienteId { get; set; }

        [Required(ErrorMessage = "TipoEquipoId es obligatorio")]
        public int? TipoEquipoId { get; set; }

        [Required(ErrorMessage = "Marca es obligatoria")]
        public string? Marca { get; set; }

        [Required(ErrorMessage = "Modelo es obligatorio")]
        public string? Modelo { get; set; }

        [Required(ErrorMessage = "NumeroSerie es obligatorio")]
        public string? NumeroSerie { get; set; }

        public string? Descripcion { get; set; }
        public string? Estado { get; set; }

        private DBContext _dbConnectionFactory = null!;

        public void SetConexion(DBContext dbConexion)
        {
            _dbConnectionFactory = dbConexion;
        }

        public async Task<ResponseDto> Consultar(int? clienteId)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                string sql = @"
                    SELECT e.EquipoId, e.ClienteId, e.TipoEquipoId,
                           te.Nombre AS NombreTipoEquipo,
                           c.NombreRazonSocial AS NombreCliente,
                           e.Marca, e.Modelo, e.NumeroSerie, e.Descripcion, e.Estado
                    FROM Equipo e
                    INNER JOIN TipoEquipo te ON te.TipoEquipoId = e.TipoEquipoId
                    INNER JOIN Cliente c ON c.ClienteId = e.ClienteId
                    WHERE (@ClienteId IS NULL OR e.ClienteId = @ClienteId)
                    ORDER BY e.EquipoId";

                var lista = await connection.QueryAsync<EquipoModel>(sql, new { ClienteId = clienteId });

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

        public async Task<ResponseDto> ConsultarPorId(int id)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var equipo = await connection.QueryFirstOrDefaultAsync<EquipoModel>(
                    @"SELECT e.EquipoId, e.ClienteId, e.TipoEquipoId,
                             te.Nombre AS NombreTipoEquipo,
                             c.NombreRazonSocial AS NombreCliente,
                             e.Marca, e.Modelo, e.NumeroSerie, e.Descripcion, e.Estado
                      FROM Equipo e
                      INNER JOIN TipoEquipo te ON te.TipoEquipoId = e.TipoEquipoId
                      INNER JOIN Cliente c ON c.ClienteId = e.ClienteId
                      WHERE e.EquipoId = @Id",
                    new { Id = id });

                if (equipo == null)
                {
                    respuesta.codigo = 404;
                    respuesta.mensaje = "Equipo no encontrado.";
                    return respuesta;
                }

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = equipo;
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarPorId(): " + ex.Message };
            }
            return respuesta;
        }

        public async Task<ResponseDto> Crear()
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                int clienteExiste = await connection.ExecuteScalarAsync<int>(
                    "SELECT COUNT(1) FROM Cliente WHERE ClienteId = @Id AND Estado = 'ACTIVO'",
                    new { Id = ClienteId });
                if (clienteExiste == 0)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "El cliente no existe o está inactivo.";
                    return respuesta;
                }

                int tipoExiste = await connection.ExecuteScalarAsync<int>(
                    "SELECT COUNT(1) FROM TipoEquipo WHERE TipoEquipoId = @Id",
                    new { Id = TipoEquipoId });
                if (tipoExiste == 0)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "El tipo de equipo no existe.";
                    return respuesta;
                }

                int nuevoId = await connection.ExecuteScalarAsync<int>(@"
                    INSERT INTO Equipo (ClienteId, TipoEquipoId, Marca, Modelo, NumeroSerie, Descripcion)
                    VALUES (@ClienteId, @TipoEquipoId, @Marca, @Modelo, @NumeroSerie, @Descripcion);
                    SELECT CAST(SCOPE_IDENTITY() AS INT);",
                    new { ClienteId, TipoEquipoId, Marca, Modelo, NumeroSerie, Descripcion });

                EquipoId = nuevoId;
                respuesta.codigo = 200;
                respuesta.mensaje = "Equipo registrado exitosamente.";
                respuesta.data = new { EquipoId = nuevoId };
            }
            catch (Exception ex)
            {
                string mensaje = ex.Message.Contains("UNIQUE") || ex.Message.Contains("duplicate")
                    ? "Ya existe un equipo con ese número de serie."
                    : ex.Message;
                respuesta = new ResponseDto { codigo = 500, mensaje = "Crear(): " + mensaje };
            }
            return respuesta;
        }

        public async Task<ResponseDto> Actualizar()
        {
            ResponseDto respuesta = new();
            try
            {
                if (EquipoId is null or <= 0)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "EquipoId es obligatorio.";
                    return respuesta;
                }

                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                int filas = await connection.ExecuteAsync(@"
                    UPDATE Equipo
                    SET TipoEquipoId = @TipoEquipoId,
                        Marca = @Marca,
                        Modelo = @Modelo,
                        Descripcion = @Descripcion
                    WHERE EquipoId = @EquipoId",
                    new { EquipoId, TipoEquipoId, Marca, Modelo, Descripcion });

                if (filas == 0)
                {
                    respuesta.codigo = 404;
                    respuesta.mensaje = "Equipo no encontrado.";
                    return respuesta;
                }

                respuesta.codigo = 200;
                respuesta.mensaje = "Equipo actualizado exitosamente.";
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Actualizar(): " + ex.Message };
            }
            return respuesta;
        }

        // Borrado lógico: no se borra si tiene órdenes asociadas.
        public async Task<ResponseDto> Eliminar(int id)
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                int conOrdenes = await connection.ExecuteScalarAsync<int>(
                    "SELECT COUNT(1) FROM OrdenServicio WHERE EquipoId = @Id",
                    new { Id = id });
                if (conOrdenes > 0)
                {
                    respuesta.codigo = 400;
                    respuesta.mensaje = "El equipo tiene órdenes de servicio asociadas; no se puede desactivar.";
                    return respuesta;
                }

                int filas = await connection.ExecuteAsync(
                    "UPDATE Equipo SET Estado = 'INACTIVO' WHERE EquipoId = @Id",
                    new { Id = id });

                if (filas == 0)
                {
                    respuesta.codigo = 404;
                    respuesta.mensaje = "Equipo no encontrado.";
                    return respuesta;
                }

                respuesta.codigo = 200;
                respuesta.mensaje = "Equipo desactivado exitosamente.";
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "Eliminar(): " + ex.Message };
            }
            return respuesta;
        }

        public async Task<ResponseDto> ConsultarTipos()
        {
            ResponseDto respuesta = new();
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();

                var lista = await connection.QueryAsync<TipoEquipoModel>(
                    "SELECT TipoEquipoId, Nombre FROM TipoEquipo ORDER BY TipoEquipoId");

                respuesta.codigo = 200;
                respuesta.mensaje = "Operación realizada exitosamente.";
                respuesta.data = lista.ToList();
            }
            catch (Exception ex)
            {
                respuesta = new ResponseDto { codigo = 500, mensaje = "ConsultarTipos(): " + ex.Message };
            }
            return respuesta;
        }
    }
}
