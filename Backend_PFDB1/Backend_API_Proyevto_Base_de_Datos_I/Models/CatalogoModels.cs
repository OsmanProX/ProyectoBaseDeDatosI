namespace Backend_API_Proyevto_Base_de_Datos_I.Models
{
    // Fila del catálogo de un proveedor (sp_ProveedorRepuesto_Listar)
    public class CatalogoItemModel
    {
        public int RepuestoId { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public string Categoria { get; set; } = string.Empty;
        public string? CodigoProveedor { get; set; }
        public decimal PrecioReferencia { get; set; }
    }

    public class CatalogoItemRequest
    {
        public int RepuestoId { get; set; }
        public decimal? PrecioReferencia { get; set; }
        public string? CodigoProveedor { get; set; }
    }

    // PUT api/inventario/proveedores/5/catalogo
    public class GuardarCatalogoRequest
    {
        public List<CatalogoItemRequest> Catalogo { get; set; } = new();
    }
}
