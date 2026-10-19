using System.ComponentModel.DataAnnotations;

namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    // Mantenimientos (enunciado 6.1): repuestos, proveedores, bodegas, categorías y tipos de equipo.
    // Las escrituras van por los procedimientos del script 12.

    // ---------- listas ----------
    public class CategoriaModel
    {
        public int CategoriaId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string? Descripcion { get; set; }
        public bool Activo { get; set; }
        public int Repuestos { get; set; }
    }

    public class TipoEquipoMantenimientoModel
    {
        public int TipoEquipoId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public int Equipos { get; set; }
    }

    public class RepuestoMantenimientoModel
    {
        public int RepuestoId { get; set; }
        public int CategoriaId { get; set; }
        public string Categoria { get; set; } = string.Empty;
        public string Codigo { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public string? Descripcion { get; set; }
        public decimal PrecioCompraReferencia { get; set; }
        public decimal PrecioVenta { get; set; }
        public string Estado { get; set; } = string.Empty;
        public int Existencia { get; set; }
        public int Bodegas { get; set; }
    }

    public class RepuestoBodegaModel
    {
        public int BodegaId { get; set; }
        public string Bodega { get; set; } = string.Empty;
        public int Existencia { get; set; }
        public int StockMinimo { get; set; }
        public bool Registrado { get; set; }
    }

    public class BodegaMantenimientoModel
    {
        public int BodegaId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string? Ubicacion { get; set; }
        public bool Activo { get; set; }
        public int RepuestosConExistencia { get; set; }
        public int Unidades { get; set; }
        public decimal ValorInventario { get; set; }
    }

    public class ProveedorMantenimientoModel
    {
        public int ProveedorId { get; set; }
        public string NIT { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public string? Contacto { get; set; }
        public string Telefono { get; set; } = string.Empty;
        public string? Correo { get; set; }
        public string? Direccion { get; set; }
        public string Estado { get; set; } = string.Empty;
        public int Compras { get; set; }
        public int ComprasPendientes { get; set; }
    }

    // ---------- solicitudes ----------
    public class CategoriaRequest
    {
        [Required(ErrorMessage = "El nombre es obligatorio.")]
        public string? Nombre { get; set; }
        public string? Descripcion { get; set; }
    }

    public class TipoEquipoRequest
    {
        [Required(ErrorMessage = "El nombre es obligatorio.")]
        public string? Nombre { get; set; }
    }

    public class RepuestoRequest
    {
        [Range(1, int.MaxValue, ErrorMessage = "Indique la categoría.")]
        public int CategoriaId { get; set; }
        [Required(ErrorMessage = "El código es obligatorio.")]
        public string? Codigo { get; set; }
        [Required(ErrorMessage = "El nombre es obligatorio.")]
        public string? Nombre { get; set; }
        public string? Descripcion { get; set; }
        [Range(typeof(decimal), "0", "99999999", ParseLimitsInInvariantCulture = true, ConvertValueInInvariantCulture = true, ErrorMessage = "Los precios no pueden ser negativos.")]
        public decimal PrecioCompraReferencia { get; set; }
        [Range(typeof(decimal), "0", "99999999", ParseLimitsInInvariantCulture = true, ConvertValueInInvariantCulture = true, ErrorMessage = "Los precios no pueden ser negativos.")]
        public decimal PrecioVenta { get; set; }
        public int? BodegaId { get; set; }      // solo al crear: bodega donde se registra
        [Range(0, int.MaxValue, ErrorMessage = "El stock mínimo no puede ser negativo.")]
        public int StockMinimo { get; set; }    // solo al crear
    }

    public class BodegaRequest
    {
        [Required(ErrorMessage = "El nombre es obligatorio.")]
        public string? Nombre { get; set; }
        public string? Ubicacion { get; set; }
    }

    public class ProveedorRequest
    {
        [Required(ErrorMessage = "El NIT es obligatorio.")]
        public string? NIT { get; set; }
        [Required(ErrorMessage = "El nombre es obligatorio.")]
        public string? Nombre { get; set; }
        public string? Contacto { get; set; }
        [Required(ErrorMessage = "El teléfono es obligatorio.")]
        public string? Telefono { get; set; }
        public string? Correo { get; set; }   // opcional; el SP valida el formato
        public string? Direccion { get; set; }
    }

    public class ActivoRequest
    {
        public bool Activo { get; set; }
    }

    public class EstadoRequest
    {
        [Required(ErrorMessage = "Indique el estado.")]
        public string? Estado { get; set; }   // ACTIVO o INACTIVO
    }

    public class StockMinimoRequest
    {
        [Range(0, int.MaxValue, ErrorMessage = "El stock mínimo no puede ser negativo.")]
        public int StockMinimo { get; set; }
    }

    // ---------- usuarios ----------
    public class RolModel
    {
        public int RolId { get; set; }
        public string Nombre { get; set; } = string.Empty;
        public string? Descripcion { get; set; }
    }

    public class UsuarioRequest
    {
        [Required(ErrorMessage = "El nombre de usuario es obligatorio.")]
        public string? NombreUsuario { get; set; }
        [Required(ErrorMessage = "El nombre completo es obligatorio.")]
        public string? NombreCompleto { get; set; }
        [Required(ErrorMessage = "El correo es obligatorio.")]
        [EmailAddress(ErrorMessage = "Correo inválido.")]
        public string? Correo { get; set; }
        public string? Telefono { get; set; }
        public string? Contrasena { get; set; }   // obligatoria solo al crear
        public List<int> Roles { get; set; } = new();
    }

    public class ContrasenaRequest
    {
        [Required(ErrorMessage = "Escriba la contraseña.")]
        [MinLength(8, ErrorMessage = "La contraseña debe tener al menos 8 caracteres.")]
        public string? Contrasena { get; set; }
    }
}
