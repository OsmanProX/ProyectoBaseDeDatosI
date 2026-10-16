namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    public class OrdenModel
    {
        public int OrdenId { get; set; }
        public string NumeroOrden { get; set; } = string.Empty;
        public int ClienteId { get; set; }
        public string? NombreCliente { get; set; }
        public int EquipoId { get; set; }
        public string? NumeroSerie { get; set; }
        public string? Equipo { get; set; }
        public int UsuarioRecepcionId { get; set; }
        public string? Recepcionista { get; set; }
        public DateTime FechaIngreso { get; set; }
        public string ProblemaReportado { get; set; } = string.Empty;
        public string Prioridad { get; set; } = "MEDIA";
        public int EstadoOrdenId { get; set; }
        public string? Estado { get; set; }
        public DateTime? FechaEstimada { get; set; }
        public string? Observaciones { get; set; }
    }

    public class EstadoOrdenModel
    {
        public int EstadoOrdenId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string? Descripcion { get; set; }
    }

    public class HistorialOrdenModel
    {
        public int HistorialId { get; set; }
        public string? EstadoAnterior { get; set; }
        public string EstadoNuevo { get; set; } = string.Empty;
        public DateTime FechaCambio { get; set; }
        public string? Usuario { get; set; }
        public string? Observacion { get; set; }
    }
}
