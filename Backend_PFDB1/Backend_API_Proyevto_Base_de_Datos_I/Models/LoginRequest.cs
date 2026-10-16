using System.ComponentModel.DataAnnotations;

namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    public class LoginRequest
    {
        [Required(ErrorMessage = "El correo es obligatorio")]
        [EmailAddress(ErrorMessage = "El correo no tiene un formato valido")]
        public string Correo { get; set; } = string.Empty;

        [Required(ErrorMessage = "La contrasena es obligatoria")]
        public string Password { get; set; } = string.Empty;
    }
}
