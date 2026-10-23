using System.ComponentModel.DataAnnotations;

namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    // ===== Semana 3: Inventario y compras (bodega) =====

    // Fila de vw_InventarioActual (script 04)
    public class InventarioModel
    {
        public int BodegaId { get; set; }
        public string Bodega { get; set; } = string.Empty;
        public int CategoriaId { get; set; }
        public string Categoria { get; set; } = string.Empty;
        public int RepuestoId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Repuesto { get; set; } = string.Empty;
        public int Existencia { get; set; }
        public int StockMinimo { get; set; }
        public decimal PrecioCompraReferencia { get; set; }
        public decimal PrecioVenta { get; set; }
        public decimal ValorInventario { get; set; }
        public string EstadoStock { get; set; } = string.Empty;
        public DateTime FechaActualizacion { get; set; }
    }

    public class BodegaModel
    {
        public int BodegaId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string? Ubicacion { get; set; }
    }

    public class ProveedorModel
    {
        public int ProveedorId { get; set; }
        public string NIT { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
    }

    public class RepuestoCatalogoModel
    {
        public int RepuestoId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public string Categoria { get; set; } = string.Empty;
        public decimal PrecioCompraReferencia { get; set; }
    }

    public class CompraModel
    {
        public int CompraId { get; set; }
        public string NumeroCompra { get; set; } = string.Empty;
        public DateTime FechaCompra { get; set; }
        public DateTime? FechaRecepcion { get; set; }
        public string Estado { get; set; } = string.Empty;
        public int ProveedorId { get; set; }
        public string Proveedor { get; set; } = string.Empty;
        public int BodegaId { get; set; }
        public string Bodega { get; set; } = string.Empty;
        public string RegistradaPor { get; set; } = string.Empty;
        public string? Observaciones { get; set; }
        public int Lineas { get; set; }
        public decimal Total { get; set; }
    }

    public class DetalleCompraModel
    {
        public int RepuestoId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Repuesto { get; set; } = string.Empty;
        public int Cantidad { get; set; }
        public decimal CostoUnitario { get; set; }
        public decimal Subtotal { get; set; }
    }

    // Fila de vw_MovimientosInventario (script 04)
    public class MovimientoInventarioModel
    {
        public int MovimientoId { get; set; }
        public DateTime FechaMovimiento { get; set; }
        public string TipoMovimiento { get; set; } = string.Empty;
        public int BodegaId { get; set; }
        public string Bodega { get; set; } = string.Empty;
        public string Codigo { get; set; } = string.Empty;
        public string Repuesto { get; set; } = string.Empty;
        public int Cantidad { get; set; }
        public int ExistenciaResultante { get; set; }
        public string TipoDocumento { get; set; } = string.Empty;
        public string? DocumentoOrigen { get; set; }
        public string? Proveedor { get; set; }
        public string Usuario { get; set; } = string.Empty;
        public string? Observacion { get; set; }
    }

    // ----- Cuerpos de las peticiones (el usuario sale del token) -----

    public class LineaCompraRequest
    {
        [Range(1, int.MaxValue, ErrorMessage = "Indique el repuesto.")]
        public int RepuestoId { get; set; }
        [Range(1, int.MaxValue, ErrorMessage = "La cantidad debe ser mayor que cero.")]
        public int Cantidad { get; set; }
        [Range(typeof(decimal), "0", "99999999", ParseLimitsInInvariantCulture = true, ConvertValueInInvariantCulture = true, ErrorMessage = "El costo no puede ser negativo.")]
        public decimal CostoUnitario { get; set; }
    }

    public class RegistrarCompraRequest
    {
        [Range(1, int.MaxValue, ErrorMessage = "Indique el proveedor.")]
        public int ProveedorId { get; set; }
        [Range(1, int.MaxValue, ErrorMessage = "Indique la bodega.")]
        public int BodegaId { get; set; }
        public string? Observaciones { get; set; }
        [MinLength(1, ErrorMessage = "Agregue al menos un repuesto a la compra.")]
        public List<LineaCompraRequest> Detalle { get; set; } = new();
    }

    public class AnularCompraRequest
    {
        [Required(ErrorMessage = "Indique el motivo de la anulación.")]
        public string? Motivo { get; set; }
    }
}
