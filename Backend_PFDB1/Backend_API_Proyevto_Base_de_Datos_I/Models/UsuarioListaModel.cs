namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    // Salida de vw_UsuarioLista (GET api/usuario)
    public class UsuarioListaModel
    {
        public int UsuarioId { get; set; }
        public string NombreUsuario { get; set; } = string.Empty;
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string? Telefono { get; set; }
        public bool Activo { get; set; }
        public string? Roles { get; set; }
        public string? RolIds { get; set; }   // ej. "2,5"
    }
}
