using System.ComponentModel.DataAnnotations;

namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    // ===== Semana 4: Caja (factura, pagos y entrega) =====

    // Orden lista para facturar/entregar (o ya entregada) con el estado de su factura
    public class OrdenCajaModel
    {
        public int OrdenId { get; set; }
        public string NumeroOrden { get; set; } = string.Empty;
        public DateTime FechaIngreso { get; set; }
        public int EstadoOrdenId { get; set; }
        public string Estado { get; set; } = string.Empty;
        public string Prioridad { get; set; } = string.Empty;
        public int ClienteId { get; set; }
        public string Cliente { get; set; } = string.Empty;
        public string NIT { get; set; } = string.Empty;
        public string Equipo { get; set; } = string.Empty;
        public string NumeroSerie { get; set; } = string.Empty;
        public decimal ManoObra { get; set; }
        public decimal Repuestos { get; set; }
        public decimal TotalSinIVA { get; set; }
        public int? FacturaId { get; set; }
        public string? NumeroFactura { get; set; }
        public decimal? TotalFactura { get; set; }
        public decimal? SaldoPendiente { get; set; }
        public string? EstadoFactura { get; set; }
        public DateTime? FechaEntrega { get; set; }
    }

    public class FacturaModel
    {
        public int FacturaId { get; set; }
        public string NumeroFactura { get; set; } = string.Empty;
        public DateTime FechaEmision { get; set; }
        public string NITFacturacion { get; set; } = string.Empty;
        public string NombreFacturacion { get; set; } = string.Empty;
        public decimal TotalManoObra { get; set; }
        public decimal TotalRepuestos { get; set; }
        public decimal Subtotal { get; set; }
        public decimal Impuesto { get; set; }
        public decimal Total { get; set; }
        public decimal SaldoPendiente { get; set; }
        public string Estado { get; set; } = string.Empty;
        public string EmitidaPor { get; set; } = string.Empty;
    }

    public class PagoModel
    {
        public int PagoId { get; set; }
        public DateTime FechaPago { get; set; }
        public string Metodo { get; set; } = string.Empty;
        public decimal Monto { get; set; }
        public string? Referencia { get; set; }
        public string Estado { get; set; } = string.Empty;
        public string CobradoPor { get; set; } = string.Empty;
    }

    public class EntregaModel
    {
        public DateTime FechaEntrega { get; set; }
        public string NombreRecibe { get; set; } = string.Empty;
        public string? Observaciones { get; set; }
        public string EntregadoPor { get; set; } = string.Empty;
    }

    public class MetodoPagoModel
    {
        public int MetodoPagoId { get; set; }
        public string Nombre { get; set; } = string.Empty;
    }

    // ----- Cuerpos de las peticiones (el usuario sale del token) -----

    public class FacturarRequest
    {
        [Range(1, int.MaxValue, ErrorMessage = "Indique la orden.")]
        public int OrdenId { get; set; }
        public string? NitFacturacion { get; set; }
        public string? NombreFacturacion { get; set; }
    }

    public class PagoRequest
    {
        [Range(1, int.MaxValue, ErrorMessage = "Indique la factura.")]
        public int FacturaId { get; set; }
        [Range(1, int.MaxValue, ErrorMessage = "Indique el método de pago.")]
        public int MetodoPagoId { get; set; }
        [Range(typeof(decimal), "0.01", "99999999", ParseLimitsInInvariantCulture = true, ConvertValueInInvariantCulture = true, ErrorMessage = "El monto debe ser mayor que cero.")]
        public decimal Monto { get; set; }
        [RegularExpression(@"^[A-Za-z0-9-]{4,50}$", ErrorMessage = "Referencia inválida: use de 4 a 50 caracteres, solo letras, números y guiones.")]
        public string? Referencia { get; set; }
    }

    public class EntregaRequest
    {
        [Range(1, int.MaxValue, ErrorMessage = "Indique la orden.")]
        public int OrdenId { get; set; }
        [Required(ErrorMessage = "Indique el nombre de quien recibe.")]
        public string? NombreRecibe { get; set; }
        public string? Observaciones { get; set; }
    }
}
