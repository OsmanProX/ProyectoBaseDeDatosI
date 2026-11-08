using System.ComponentModel.DataAnnotations;

namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    public class LoginRequest
    {
        // Acepta el correo o el nombre de usuario (sp_LoginUsuario busca por los dos)
        [Required(ErrorMessage = "Escriba su correo o usuario")]
        public string Correo { get; set; } = string.Empty;

        [Required(ErrorMessage = "La contrasena es obligatoria")]
        public string Password { get; set; } = string.Empty;
    }
}
