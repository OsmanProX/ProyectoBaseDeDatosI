namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    public class Usuario
    {
        public int Id { get; set; }
        public string UsuarioLogin { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string Rol { get; set; } = string.Empty;
    }
}
