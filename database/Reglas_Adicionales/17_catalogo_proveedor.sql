/* ==========================================================
   17_catalogo_proveedor.sql
   Catálogo del proveedor (tabla ProveedorRepuesto: qué proveedor vende qué repuesto).
   - sp_ProveedorRepuesto_Listar: catálogo de un proveedor
   - sp_ProveedorRepuesto_Guardar: guarda el catálogo completo (JSON)
   - trg_DetalleCompra_CatalogoProveedor: una compra solo puede incluir
     repuestos que el proveedor vende (aun insertando desde SQL, R16)
   Se puede ejecutar más de una vez.
   ========================================================== */

CREATE OR ALTER PROCEDURE dbo.sp_ProveedorRepuesto_Listar
    @ProveedorId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT pr.RepuestoId, r.Codigo, r.Nombre, cat.Nombre AS Categoria,
           pr.CodigoProveedor,
           ISNULL(pr.PrecioReferencia, r.PrecioCompraReferencia) AS PrecioReferencia
    FROM dbo.ProveedorRepuesto pr
    JOIN dbo.Repuesto r    ON r.RepuestoId    = pr.RepuestoId
    JOIN dbo.Categoria cat ON cat.CategoriaId = r.CategoriaId
    WHERE pr.ProveedorId = @ProveedorId AND r.Estado = 'ACTIVO'
    ORDER BY r.Codigo;
END;
GO

/* @Catalogo (JSON): [{"repuestoId":1,"precioReferencia":250.00,"codigoProveedor":"ABC-1"}, ...]
   Reemplaza el catálogo: agrega los nuevos, actualiza precios y quita los que ya no ofrece.
   Errores 51881 - 51884 */
CREATE OR ALTER PROCEDURE dbo.sp_ProveedorRepuesto_Guardar
    @UsuarioId    INT,
    @ProveedorId  INT,
    @Catalogo     NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Items TABLE (RepuestoId INT PRIMARY KEY, PrecioReferencia DECIMAL(10,2) NULL, CodigoProveedor VARCHAR(30) NULL);

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 51881, 'Solo BODEGA o ADMINISTRADOR pueden modificar el catálogo del proveedor.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE ProveedorId = @ProveedorId)
            THROW 51882, 'El proveedor no existe.', 1;

        IF ISJSON(ISNULL(@Catalogo, '[]')) = 0
            THROW 51883, 'Catálogo inválido.', 1;

        INSERT INTO @Items (RepuestoId, PrecioReferencia, CodigoProveedor)
        SELECT DISTINCT j.repuestoId, j.precioReferencia, NULLIF(LTRIM(RTRIM(j.codigoProveedor)), '')
        FROM OPENJSON(ISNULL(@Catalogo, '[]'))
             WITH (repuestoId INT, precioReferencia DECIMAL(10,2), codigoProveedor VARCHAR(30)) j
        WHERE j.repuestoId IS NOT NULL;

        IF EXISTS (SELECT 1 FROM @Items i LEFT JOIN dbo.Repuesto r ON r.RepuestoId = i.RepuestoId
                   WHERE r.RepuestoId IS NULL OR i.PrecioReferencia < 0)
            THROW 51884, 'Hay repuestos que no existen o precios negativos en el catálogo.', 1;

        BEGIN TRANSACTION;

        DELETE pr FROM dbo.ProveedorRepuesto pr
        WHERE pr.ProveedorId = @ProveedorId
          AND NOT EXISTS (SELECT 1 FROM @Items i WHERE i.RepuestoId = pr.RepuestoId);

        UPDATE pr SET pr.PrecioReferencia = i.PrecioReferencia, pr.CodigoProveedor = i.CodigoProveedor
        FROM dbo.ProveedorRepuesto pr JOIN @Items i ON i.RepuestoId = pr.RepuestoId
        WHERE pr.ProveedorId = @ProveedorId;

        INSERT INTO dbo.ProveedorRepuesto (ProveedorId, RepuestoId, CodigoProveedor, PrecioReferencia)
        SELECT @ProveedorId, i.RepuestoId, i.CodigoProveedor, i.PrecioReferencia
        FROM @Items i
        WHERE NOT EXISTS (SELECT 1 FROM dbo.ProveedorRepuesto pr
                          WHERE pr.ProveedorId = @ProveedorId AND pr.RepuestoId = i.RepuestoId);

        COMMIT TRANSACTION;

        EXEC dbo.sp_ProveedorRepuesto_Listar @ProveedorId = @ProveedorId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* Regla del grupo: una compra solo incluye repuestos del catálogo de su proveedor */
CREATE OR ALTER TRIGGER dbo.trg_DetalleCompra_CatalogoProveedor
ON dbo.DetalleCompra
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1
               FROM inserted d
               JOIN dbo.Compra c ON c.CompraId = d.CompraId
               WHERE NOT EXISTS (SELECT 1 FROM dbo.ProveedorRepuesto pr
                                 WHERE pr.ProveedorId = c.ProveedorId AND pr.RepuestoId = d.RepuestoId))
        THROW 51885, 'La compra incluye un repuesto que el proveedor no vende. Agréguelo primero a su catálogo.', 1;
END;
GO

-- Verificación: deben salir 3 objetos
SELECT name, type_desc FROM sys.objects
WHERE name IN ('sp_ProveedorRepuesto_Listar', 'sp_ProveedorRepuesto_Guardar', 'trg_DetalleCompra_CatalogoProveedor');
GO
