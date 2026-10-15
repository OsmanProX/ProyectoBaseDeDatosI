namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    public class LoginResponse
    {
        public string Token { get; set; } = string.Empty;
        public DateTime Expira { get; set; }
    }
}
