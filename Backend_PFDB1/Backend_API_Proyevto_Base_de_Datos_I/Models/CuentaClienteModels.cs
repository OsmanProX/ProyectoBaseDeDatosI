namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    // Resultado de sp_Cliente_CrearAcceso
    public class CuentaClienteModel
    {
        public int UsuarioId { get; set; }
        public string NombreUsuario { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string NombreCompleto { get; set; } = string.Empty;
    }

    // Fila de sp_Cliente_MisOrdenes (portal del cliente, solo lectura)
    public class MiOrdenModel
    {
        public int OrdenId { get; set; }
        public string NumeroOrden { get; set; } = string.Empty;
        public DateTime FechaIngreso { get; set; }
        public DateTime? FechaEstimada { get; set; }
        public string Prioridad { get; set; } = string.Empty;
        public string Estado { get; set; } = string.Empty;
        public string? EstadoDescripcion { get; set; }
        public string TipoEquipo { get; set; } = string.Empty;
        public string Equipo { get; set; } = string.Empty;
        public string NumeroSerie { get; set; } = string.Empty;
        public string ProblemaReportado { get; set; } = string.Empty;
        public string? NumeroFactura { get; set; }
        public decimal? Total { get; set; }
        public decimal? Saldo { get; set; }
    }
}

namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    using System.ComponentModel.DataAnnotations;

    // POST api/auth/registro (el cliente crea su cuenta desde el login)
    public class RegistroClienteRequest
    {
        [Required(ErrorMessage = "El tipo de cliente es obligatorio.")] public string? TipoCliente { get; set; }
        [Required(ErrorMessage = "El nombre es obligatorio.")] public string? NombreRazonSocial { get; set; }
        [Required(ErrorMessage = "El NIT es obligatorio.")] public string? NIT { get; set; }
        [Required(ErrorMessage = "El teléfono es obligatorio.")] public string? Telefono { get; set; }
        [Required(ErrorMessage = "El correo es obligatorio.")] public string? Correo { get; set; }
        [Required(ErrorMessage = "La dirección es obligatoria.")] public string? Direccion { get; set; }
        [Required(ErrorMessage = "La contraseña es obligatoria.")] public string? Contrasena { get; set; }
    }

    // POST api/auth/recuperar
    public class RecuperarRequest
    {
        [Required(ErrorMessage = "Escriba su correo.")] public string? Correo { get; set; }
    }

    // GET/PUT api/auth/mi-cuenta (sp_MiCuenta_Obtener / sp_MiCuenta_Actualizar)
    public class MiCuentaModel
    {
        public int UsuarioId { get; set; }
        public string NombreUsuario { get; set; } = string.Empty;
        public string NombreCompleto { get; set; } = string.Empty;
        public string Correo { get; set; } = string.Empty;
        public string? Telefono { get; set; }
        public int? ClienteId { get; set; }
        public string? TipoCliente { get; set; }
        public string? NIT { get; set; }
        public string? Direccion { get; set; }
    }

    public class MiCuentaRequest
    {
        [Required(ErrorMessage = "El nombre es obligatorio.")] public string? NombreCompleto { get; set; }
        [Required(ErrorMessage = "El teléfono es obligatorio.")] public string? Telefono { get; set; }
        public string? Direccion { get; set; }
    }

    // PUT api/auth/mi-contrasena
    public class CambiarContrasenaRequest
    {
        [Required(ErrorMessage = "Escriba su contraseña actual.")] public string? Actual { get; set; }
        [Required(ErrorMessage = "Escriba la contraseña nueva.")] public string? Nueva { get; set; }
    }
}
