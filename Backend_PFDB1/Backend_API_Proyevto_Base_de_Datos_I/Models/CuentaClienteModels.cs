namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    // Resultado de sp_Cliente_CrearAcceso
    public class CuentaClienteModel
    {
        public int UsuarioId { get; set; }
        public string NombreUsuario { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string NombreCompleto { get; set; } = string.Empty;
    }

    // Fila de sp_Cliente_MisOrdenes (portal del cliente, solo lectura)
    public class MiOrdenModel
    {
        public int OrdenId { get; set; }
        public string NumeroOrden { get; set; } = string.Empty;
        public DateTime FechaIngreso { get; set; }
        public DateTime? FechaEstimada { get; set; }
        public string Prioridad { get; set; } = string.Empty;
        public string Estado { get; set; } = string.Empty;
        public string? EstadoDescripcion { get; set; }
        public string TipoEquipo { get; set; } = string.Empty;
        public string Equipo { get; set; } = string.Empty;
        public string NumeroSerie { get; set; } = string.Empty;
        public string ProblemaReportado { get; set; } = string.Empty;
        public string? NumeroFactura { get; set; }
        public decimal? Total { get; set; }
        public decimal? Saldo { get; set; }
    }
}
