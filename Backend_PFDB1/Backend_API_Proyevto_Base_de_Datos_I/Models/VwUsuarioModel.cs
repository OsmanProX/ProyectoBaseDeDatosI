namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    public class VwUsuarioModel
    {
        public int UsuarioId { get; set; }
        public string NombreUsuario { get; set; } = string.Empty;
        public string ContrasenaHash { get; set; } = string.Empty;
        public string NombreCompleto { get; set; } = string.Empty;
        public string? Correo { get; set; }
        public string? Telefono { get; set; }
        public int Activo { get; set; }
        public string? Roles { get; set; }
        // 1 = entró con contraseña temporal: debe cambiarla (script 13/14)
        public bool DebeCambiarContrasena { get; set; }
    }
}
