using System.Text.Json;
using Backend_API_Proyevto_Base_de_Datos_I.BD;
using Backend_API_Proyevto_Base_de_Datos_I.Models;
using Dapper;
using Microsoft.Data.SqlClient;

namespace Backend_API_Proyevto_Base_de_Datos_I.DTO
{
    // Catálogo del proveedor (tabla ProveedorRepuesto, script 17)
    public class CatalogoDTO
    {
        private DBContext _dbConnectionFactory = null!;
        public void SetConexion(DBContext dbConexion) => _dbConnectionFactory = dbConexion;

        public async Task<ResponseDto> Listar(int proveedorId)
        {
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();
                var lista = await connection.QueryAsync<CatalogoItemModel>(
                    "sp_ProveedorRepuesto_Listar", new { ProveedorId = proveedorId },
                    commandType: System.Data.CommandType.StoredProcedure);
                return new ResponseDto { codigo = 200, mensaje = "OK", data = lista };
            }
            catch (SqlException ex)
            {
                return new ResponseDto { codigo = 400, mensaje = ex.Message };
            }
        }

        public async Task<ResponseDto> Guardar(int usuarioId, int proveedorId, List<CatalogoItemRequest> items)
        {
            try
            {
                using var connection = _dbConnectionFactory.CreateConnection();
                await connection.OpenAsync();
                var json = JsonSerializer.Serialize(items.Select(i => new
                {
                    repuestoId = i.RepuestoId,
                    precioReferencia = i.PrecioReferencia,
                    codigoProveedor = i.CodigoProveedor,
                }));
                var lista = await connection.QueryAsync<CatalogoItemModel>(
                    "sp_ProveedorRepuesto_Guardar",
                    new { UsuarioId = usuarioId, ProveedorId = proveedorId, Catalogo = json },
                    commandType: System.Data.CommandType.StoredProcedure);
                return new ResponseDto { codigo = 200, mensaje = "Catálogo guardado.", data = lista };
            }
            catch (SqlException ex)
            {
                return new ResponseDto { codigo = 400, mensaje = ex.Message };
            }
        }
    }
}
