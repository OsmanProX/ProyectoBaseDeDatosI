namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    public class EquipoModel
    {
        public int EquipoId { get; set; }
        public int ClienteId { get; set; }
        public int TipoEquipoId { get; set; }
        public string? NombreTipoEquipo { get; set; }
        public string? NombreCliente { get; set; }
        public string Marca { get; set; } = string.Empty;
        public string Modelo { get; set; } = string.Empty;
        public string NumeroSerie { get; set; } = string.Empty;
        public string? Descripcion { get; set; }
        public string Estado { get; set; } = "ACTIVO";
    }

    public class TipoEquipoModel
    {
        public int TipoEquipoId { get; set; }
        public string Nombre { get; set; } = string.Empty;
    }
}
