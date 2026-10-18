namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    // ===== Semana 3: Taller (diagnóstico, reparación, actividades, repuestos) =====

    // Fila de vw_OrdenesActivas (script 04)
    public class TallerOrdenModel
    {
        public int OrdenId { get; set; }
        public string NumeroOrden { get; set; } = string.Empty;
        public DateTime FechaIngreso { get; set; }
        public DateTime? FechaEstimada { get; set; }
        public int DiasAbierta { get; set; }
        public int EstadoOrdenId { get; set; }
        public string Estado { get; set; } = string.Empty;
        public string Prioridad { get; set; } = string.Empty;
        public int NivelPrioridad { get; set; }
        public int ClienteId { get; set; }
        public string Cliente { get; set; } = string.Empty;
        public string TipoEquipo { get; set; } = string.Empty;
        public string Equipo { get; set; } = string.Empty;
        public string NumeroSerie { get; set; } = string.Empty;
        public string RecibidoPor { get; set; } = string.Empty;
        public string TecnicoResponsable { get; set; } = string.Empty;
        public string ProblemaReportado { get; set; } = string.Empty;
        public decimal? TotalSinIVA { get; set; }
    }

    public class DiagnosticoModel
    {
        public int DiagnosticoId { get; set; }
        public int OrdenId { get; set; }
        public string Tecnico { get; set; } = string.Empty;
        public DateTime FechaDiagnostico { get; set; }
        public string Descripcion { get; set; } = string.Empty;
        public decimal CostoManoObraEstimado { get; set; }
        public string? Observaciones { get; set; }
    }

    public class ReparacionModel
    {
        public int ReparacionId { get; set; }
        public string Tecnico { get; set; } = string.Empty;
        public DateTime FechaInicio { get; set; }
        public DateTime? FechaFin { get; set; }
        public string? DescripcionTrabajo { get; set; }
        public decimal CostoManoObra { get; set; }
        public string Estado { get; set; } = string.Empty;
    }

    public class ActividadReparacionModel
    {
        public int NumeroActividad { get; set; }
        public string Descripcion { get; set; } = string.Empty;
        public decimal? HorasTrabajadas { get; set; }
        public DateTime FechaRegistro { get; set; }
    }

    public class RepuestoUsadoModel
    {
        public int RepuestoId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Repuesto { get; set; } = string.Empty;
        public string Bodega { get; set; } = string.Empty;
        public int Cantidad { get; set; }
        public decimal PrecioVentaUnitario { get; set; }
        public decimal Subtotal { get; set; }
        public DateTime FechaRegistro { get; set; }
    }

    // Repuestos con existencia, para asignarlos a una reparación (vw_InventarioActual)
    public class RepuestoDisponibleModel
    {
        public int BodegaId { get; set; }
        public string Bodega { get; set; } = string.Empty;
        public int RepuestoId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Repuesto { get; set; } = string.Empty;
        public string Categoria { get; set; } = string.Empty;
        public int Existencia { get; set; }
        public decimal PrecioVenta { get; set; }
    }

    // ----- Cuerpos de las peticiones (el técnico sale del token, no del cuerpo) -----

    public class DiagnosticoRequest
    {
        public int OrdenId { get; set; }
        public string? Descripcion { get; set; }
        public decimal CostoManoObraEstimado { get; set; }
        public string? Observaciones { get; set; }
    }

    public class IniciarReparacionRequest
    {
        public int OrdenId { get; set; }
        public string? DescripcionTrabajo { get; set; }
    }

    public class ActividadRequest
    {
        public int ReparacionId { get; set; }
        public string? Descripcion { get; set; }
        public decimal? HorasTrabajadas { get; set; }
    }

    public class AsignarRepuestoRequest
    {
        public int ReparacionId { get; set; }
        public int RepuestoId { get; set; }
        public int BodegaId { get; set; }
        public int Cantidad { get; set; }
    }

    public class FinalizarReparacionRequest
    {
        public int ReparacionId { get; set; }
        public decimal? CostoManoObra { get; set; }
        public string? DescripcionTrabajo { get; set; }
    }
}
