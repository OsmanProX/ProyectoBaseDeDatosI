namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    public class ClienteModel
    {
        public int ClienteId { get; set; }
        public string TipoCliente { get; set; } = string.Empty;
        public string NombreRazonSocial { get; set; } = string.Empty;
        public string NIT { get; set; } = string.Empty;
        public string Telefono { get; set; } = string.Empty;
        public string? Correo { get; set; }
        public string? Direccion { get; set; }
        public string Estado { get; set; } = "ACTIVO";
        public DateTime FechaRegistro { get; set; }
    }
}
