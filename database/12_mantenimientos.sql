/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 12: Mantenimientos (enunciado 6.1)
   Se ejecuta después del 01..11.
   Procedimientos para crear, editar y activar/inactivar:
     - Categorías de repuesto     sp_Categoria_Guardar, sp_Categoria_CambiarEstado
     - Tipos de equipo            sp_TipoEquipo_Guardar
     - Repuestos                  sp_Repuesto_Guardar, sp_Repuesto_CambiarEstado
     - Stock mínimo por bodega    sp_Inventario_GuardarMinimo
     - Bodegas                    sp_Bodega_Guardar, sp_Bodega_CambiarEstado
     - Proveedores                sp_Proveedor_Guardar, sp_Proveedor_CambiarEstado
     - Usuarios/empleados         sp_Usuario_Guardar, sp_Usuario_CambiarEstado,
                                  sp_Usuario_RestablecerContrasena
     - Clientes y equipos         sp_Cliente_Activar, sp_Equipo_Activar
                                  (reactivan lo que inactivan los SP del 11)
   Reglas:
     - Nada se borra: se inactiva (los históricos siguen apuntando al registro).
     - @UsuarioId es quien hace el cambio; se valida con fn_UsuarioTieneRol.
       Repuestos, mínimos y proveedores: BODEGA o ADMINISTRADOR.
       Bodegas, categorías, tipos de equipo y usuarios: solo ADMINISTRADOR.
     - El precio se cambia con UPDATE normal: trg_Repuesto_AuditoriaPrecio (07)
       guarda el historial en AuditoriaPrecio.
     - Contraseñas: se guarda el SHA2_256, igual que en 02 y sp_LoginUsuario.
   Errores: 51201..51799
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   CATÁLOGOS
   ========================================================== */

/* ----------------------------------------------------------
   sp_Categoria_Guardar
   @CategoriaId NULL = crear; con valor = editar.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Guardar
    @UsuarioId    INT,
    @CategoriaId  INT          = NULL,
    @Nombre       VARCHAR(50),
    @Descripcion  VARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51201, 'Solo el ADMINISTRADOR puede modificar las categorías.', 1;

        SET @Nombre = LTRIM(RTRIM(@Nombre));
        IF @Nombre IS NULL OR @Nombre = ''
            THROW 51202, 'El nombre de la categoría es obligatorio.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Categoria WITH (UPDLOCK, HOLDLOCK)
                   WHERE Nombre = @Nombre AND (@CategoriaId IS NULL OR CategoriaId <> @CategoriaId))
            THROW 51203, 'Ya existe una categoría con ese nombre.', 1;

        IF @CategoriaId IS NULL
        BEGIN
            INSERT INTO dbo.Categoria (Nombre, Descripcion)
            VALUES (@Nombre, NULLIF(LTRIM(RTRIM(@Descripcion)), ''));
            SET @CategoriaId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Categoria WHERE CategoriaId = @CategoriaId)
                THROW 51204, 'La categoría no existe.', 1;

            UPDATE dbo.Categoria
            SET Nombre = @Nombre, Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), '')
            WHERE CategoriaId = @CategoriaId;
        END

        COMMIT TRANSACTION;

        SELECT CategoriaId, Nombre, Descripcion, Activo
        FROM dbo.Categoria WHERE CategoriaId = @CategoriaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Categoria_CambiarEstado
   No se inactiva si tiene repuestos activos.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Categoria_CambiarEstado
    @UsuarioId    INT,
    @CategoriaId  INT,
    @Activo       BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51211, 'Solo el ADMINISTRADOR puede modificar las categorías.', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Categoria WITH (UPDLOCK, HOLDLOCK) WHERE CategoriaId = @CategoriaId)
            THROW 51212, 'La categoría no existe.', 1;

        IF @Activo = 0 AND EXISTS (SELECT 1 FROM dbo.Repuesto
                                   WHERE CategoriaId = @CategoriaId AND Estado = 'ACTIVO')
            THROW 51213, 'La categoría tiene repuestos activos. Inactive o cambie esos repuestos primero.', 1;

        UPDATE dbo.Categoria SET Activo = @Activo WHERE CategoriaId = @CategoriaId;

        COMMIT TRANSACTION;

        SELECT CategoriaId, Nombre, Descripcion, Activo
        FROM dbo.Categoria WHERE CategoriaId = @CategoriaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_TipoEquipo_Guardar
   @TipoEquipoId NULL = crear; con valor = renombrar.
   (La tabla no tiene estado; los tipos usados por equipos no se borran.)
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_TipoEquipo_Guardar
    @UsuarioId     INT,
    @TipoEquipoId  INT = NULL,
    @Nombre        VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51221, 'Solo el ADMINISTRADOR puede modificar los tipos de equipo.', 1;

        SET @Nombre = LTRIM(RTRIM(@Nombre));
        IF @Nombre IS NULL OR @Nombre = ''
            THROW 51222, 'El nombre del tipo de equipo es obligatorio.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.TipoEquipo WITH (UPDLOCK, HOLDLOCK)
                   WHERE Nombre = @Nombre AND (@TipoEquipoId IS NULL OR TipoEquipoId <> @TipoEquipoId))
            THROW 51223, 'Ya existe un tipo de equipo con ese nombre.', 1;

        IF @TipoEquipoId IS NULL
        BEGIN
            INSERT INTO dbo.TipoEquipo (Nombre) VALUES (@Nombre);
            SET @TipoEquipoId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.TipoEquipo WHERE TipoEquipoId = @TipoEquipoId)
                THROW 51224, 'El tipo de equipo no existe.', 1;

            UPDATE dbo.TipoEquipo SET Nombre = @Nombre WHERE TipoEquipoId = @TipoEquipoId;
        END

        COMMIT TRANSACTION;

        SELECT TipoEquipoId, Nombre FROM dbo.TipoEquipo WHERE TipoEquipoId = @TipoEquipoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   REPUESTOS
   ========================================================== */

/* ----------------------------------------------------------
   sp_Repuesto_Guardar
   @RepuestoId NULL = crear; con valor = editar.
   Al crear, si se indica @BodegaId, se crea su fila de inventario
   en esa bodega con existencia 0 y el @StockMinimo indicado
   (la existencia solo sube con una compra recibida).
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Repuesto_Guardar
    @UsuarioId               INT,
    @RepuestoId              INT           = NULL,
    @CategoriaId             INT,
    @Codigo                  VARCHAR(20),
    @Nombre                  VARCHAR(100),
    @Descripcion             VARCHAR(200)  = NULL,
    @PrecioCompraReferencia  DECIMAL(10,2),
    @PrecioVenta             DECIMAL(10,2),
    @BodegaId                INT           = NULL,
    @StockMinimo             INT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 51301, 'El usuario no está autorizado para modificar repuestos (rol BODEGA o ADMINISTRADOR).', 1;

        SET @Codigo = UPPER(LTRIM(RTRIM(@Codigo)));
        SET @Nombre = LTRIM(RTRIM(@Nombre));

        IF @Codigo IS NULL OR @Codigo = ''
            THROW 51302, 'El código del repuesto es obligatorio.', 1;

        IF @Nombre IS NULL OR @Nombre = ''
            THROW 51303, 'El nombre del repuesto es obligatorio.', 1;

        IF @PrecioCompraReferencia IS NULL OR @PrecioCompraReferencia < 0
           OR @PrecioVenta IS NULL OR @PrecioVenta < 0
            THROW 51304, 'Los precios no pueden ser negativos.', 1;

        IF @PrecioVenta < @PrecioCompraReferencia
            THROW 51305, 'El precio de venta no puede ser menor al precio de compra.', 1;

        IF ISNULL(@StockMinimo, 0) < 0
            THROW 51306, 'El stock mínimo no puede ser negativo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Categoria WHERE CategoriaId = @CategoriaId AND Activo = 1)
            THROW 51307, 'La categoría no existe o está inactiva.', 1;

        IF @RepuestoId IS NULL AND @BodegaId IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.Bodega WHERE BodegaId = @BodegaId AND Activo = 1)
            THROW 51308, 'La bodega no existe o está inactiva.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Repuesto WITH (UPDLOCK, HOLDLOCK)
                   WHERE Codigo = @Codigo AND (@RepuestoId IS NULL OR RepuestoId <> @RepuestoId))
            THROW 51309, 'Ya existe otro repuesto con ese código.', 1;

        IF @RepuestoId IS NULL
        BEGIN
            INSERT INTO dbo.Repuesto (CategoriaId, Codigo, Nombre, Descripcion, PrecioCompraReferencia, PrecioVenta)
            VALUES (@CategoriaId, @Codigo, @Nombre, NULLIF(LTRIM(RTRIM(@Descripcion)), ''),
                    @PrecioCompraReferencia, @PrecioVenta);
            SET @RepuestoId = SCOPE_IDENTITY();

            IF @BodegaId IS NOT NULL
                INSERT INTO dbo.Inventario (RepuestoId, BodegaId, Existencia, StockMinimo)
                VALUES (@RepuestoId, @BodegaId, 0, ISNULL(@StockMinimo, 0));
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Repuesto WHERE RepuestoId = @RepuestoId)
                THROW 51310, 'El repuesto no existe.', 1;

            -- Si cambia el precio, trg_Repuesto_AuditoriaPrecio lo registra
            UPDATE dbo.Repuesto
            SET CategoriaId            = @CategoriaId,
                Codigo                 = @Codigo,
                Nombre                 = @Nombre,
                Descripcion            = NULLIF(LTRIM(RTRIM(@Descripcion)), ''),
                PrecioCompraReferencia = @PrecioCompraReferencia,
                PrecioVenta            = @PrecioVenta
            WHERE RepuestoId = @RepuestoId;
        END

        COMMIT TRANSACTION;

        SELECT RepuestoId, Codigo, Nombre, PrecioCompraReferencia, PrecioVenta, Estado
        FROM dbo.Repuesto WHERE RepuestoId = @RepuestoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Repuesto_CambiarEstado
   @Estado: 'ACTIVO' o 'INACTIVO'.
   No se inactiva si está en una compra PENDIENTE.
   Para activarlo su categoría debe estar activa.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Repuesto_CambiarEstado
    @UsuarioId   INT,
    @RepuestoId  INT,
    @Estado      VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 51321, 'El usuario no está autorizado para modificar repuestos (rol BODEGA o ADMINISTRADOR).', 1;

        SET @Estado = UPPER(LTRIM(RTRIM(@Estado)));
        IF @Estado NOT IN ('ACTIVO', 'INACTIVO')
            THROW 51322, 'Estado inválido. Use ACTIVO o INACTIVO.', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Repuesto WITH (UPDLOCK, HOLDLOCK) WHERE RepuestoId = @RepuestoId)
            THROW 51323, 'El repuesto no existe.', 1;

        IF @Estado = 'INACTIVO' AND EXISTS (
               SELECT 1 FROM dbo.DetalleCompra dc
               JOIN dbo.Compra c ON c.CompraId = dc.CompraId
               WHERE dc.RepuestoId = @RepuestoId AND c.Estado = 'PENDIENTE')
            THROW 51324, 'El repuesto está en una compra pendiente. Reciba o anule la compra primero.', 1;

        IF @Estado = 'ACTIVO' AND EXISTS (
               SELECT 1 FROM dbo.Repuesto r
               JOIN dbo.Categoria c ON c.CategoriaId = r.CategoriaId
               WHERE r.RepuestoId = @RepuestoId AND c.Activo = 0)
            THROW 51325, 'La categoría del repuesto está inactiva. Actívela primero.', 1;

        UPDATE dbo.Repuesto SET Estado = @Estado WHERE RepuestoId = @RepuestoId;

        COMMIT TRANSACTION;

        SELECT RepuestoId, Codigo, Nombre, Estado FROM dbo.Repuesto WHERE RepuestoId = @RepuestoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Inventario_GuardarMinimo
   Cambia el stock mínimo de un repuesto en una bodega.
   Si el repuesto aún no tiene fila en esa bodega, la crea con existencia 0.
   La existencia NO se toca aquí (solo compras y reparaciones la mueven).
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Inventario_GuardarMinimo
    @UsuarioId    INT,
    @RepuestoId   INT,
    @BodegaId     INT,
    @StockMinimo  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 51401, 'El usuario no está autorizado para modificar el inventario (rol BODEGA o ADMINISTRADOR).', 1;

        IF @StockMinimo IS NULL OR @StockMinimo < 0
            THROW 51402, 'El stock mínimo no puede ser negativo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Repuesto WHERE RepuestoId = @RepuestoId AND Estado = 'ACTIVO')
            THROW 51403, 'El repuesto no existe o está inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Bodega WHERE BodegaId = @BodegaId AND Activo = 1)
            THROW 51404, 'La bodega no existe o está inactiva.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Inventario WITH (UPDLOCK, HOLDLOCK)
                   WHERE RepuestoId = @RepuestoId AND BodegaId = @BodegaId)
            UPDATE dbo.Inventario
            SET StockMinimo = @StockMinimo, FechaActualizacion = GETDATE()
            WHERE RepuestoId = @RepuestoId AND BodegaId = @BodegaId;
        ELSE
            INSERT INTO dbo.Inventario (RepuestoId, BodegaId, Existencia, StockMinimo)
            VALUES (@RepuestoId, @BodegaId, 0, @StockMinimo);

        COMMIT TRANSACTION;

        SELECT RepuestoId, BodegaId, Existencia, StockMinimo
        FROM dbo.Inventario
        WHERE RepuestoId = @RepuestoId AND BodegaId = @BodegaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   BODEGAS
   ========================================================== */

/* ----------------------------------------------------------
   sp_Bodega_Guardar
   @BodegaId NULL = crear; con valor = editar.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Bodega_Guardar
    @UsuarioId  INT,
    @BodegaId   INT          = NULL,
    @Nombre     VARCHAR(50),
    @Ubicacion  VARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51501, 'Solo el ADMINISTRADOR puede modificar las bodegas.', 1;

        SET @Nombre = LTRIM(RTRIM(@Nombre));
        IF @Nombre IS NULL OR @Nombre = ''
            THROW 51502, 'El nombre de la bodega es obligatorio.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Bodega WITH (UPDLOCK, HOLDLOCK)
                   WHERE Nombre = @Nombre AND (@BodegaId IS NULL OR BodegaId <> @BodegaId))
            THROW 51503, 'Ya existe una bodega con ese nombre.', 1;

        IF @BodegaId IS NULL
        BEGIN
            INSERT INTO dbo.Bodega (Nombre, Ubicacion)
            VALUES (@Nombre, NULLIF(LTRIM(RTRIM(@Ubicacion)), ''));
            SET @BodegaId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Bodega WHERE BodegaId = @BodegaId)
                THROW 51504, 'La bodega no existe.', 1;

            UPDATE dbo.Bodega
            SET Nombre = @Nombre, Ubicacion = NULLIF(LTRIM(RTRIM(@Ubicacion)), '')
            WHERE BodegaId = @BodegaId;
        END

        COMMIT TRANSACTION;

        SELECT BodegaId, Nombre, Ubicacion, Activo FROM dbo.Bodega WHERE BodegaId = @BodegaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Bodega_CambiarEstado
   No se inactiva si tiene existencias, compras pendientes
   o si es la última bodega activa.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Bodega_CambiarEstado
    @UsuarioId  INT,
    @BodegaId   INT,
    @Activo     BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51511, 'Solo el ADMINISTRADOR puede modificar las bodegas.', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Bodega WITH (UPDLOCK, HOLDLOCK) WHERE BodegaId = @BodegaId)
            THROW 51512, 'La bodega no existe.', 1;

        IF @Activo = 0
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Inventario WHERE BodegaId = @BodegaId AND Existencia > 0)
                THROW 51513, 'La bodega todavía tiene existencias. No se puede inactivar.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Compra WHERE BodegaId = @BodegaId AND Estado = 'PENDIENTE')
                THROW 51514, 'La bodega tiene compras pendientes de recibir.', 1;

            IF NOT EXISTS (SELECT 1 FROM dbo.Bodega WHERE Activo = 1 AND BodegaId <> @BodegaId)
                THROW 51515, 'Debe quedar al menos una bodega activa.', 1;
        END

        UPDATE dbo.Bodega SET Activo = @Activo WHERE BodegaId = @BodegaId;

        COMMIT TRANSACTION;

        SELECT BodegaId, Nombre, Ubicacion, Activo FROM dbo.Bodega WHERE BodegaId = @BodegaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   PROVEEDORES
   ========================================================== */

/* ----------------------------------------------------------
   sp_Proveedor_Guardar
   @ProveedorId NULL = crear; con valor = editar.
   NIT: dígitos con guion opcional y dígito verificador (0-9 o K).
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Proveedor_Guardar
    @UsuarioId    INT,
    @ProveedorId  INT          = NULL,
    @NIT          VARCHAR(15),
    @Nombre       VARCHAR(150),
    @Contacto     VARCHAR(100) = NULL,
    @Telefono     VARCHAR(15),
    @Correo       VARCHAR(100) = NULL,
    @Direccion    VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 51601, 'El usuario no está autorizado para modificar proveedores (rol BODEGA o ADMINISTRADOR).', 1;

        SET @NIT      = UPPER(REPLACE(LTRIM(RTRIM(@NIT)), ' ', ''));
        SET @Nombre   = LTRIM(RTRIM(@Nombre));
        SET @Telefono = LTRIM(RTRIM(@Telefono));
        SET @Correo   = NULLIF(LTRIM(RTRIM(@Correo)), '');

        IF @NIT IS NULL OR @NIT = '' OR @NIT LIKE '%[^0-9K-]%' OR @NIT NOT LIKE '%[0-9K]'
            THROW 51602, 'NIT inválido. Use solo números, guion y dígito verificador (ej. 1234567-8).', 1;

        IF @Nombre IS NULL OR @Nombre = ''
            THROW 51603, 'El nombre del proveedor es obligatorio.', 1;

        IF @Telefono IS NULL OR @Telefono = '' OR @Telefono LIKE '%[^0-9 +-]%'
            THROW 51604, 'Teléfono inválido.', 1;

        IF @Correo IS NOT NULL AND @Correo NOT LIKE '%_@_%._%'
            THROW 51605, 'Correo inválido.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Proveedor WITH (UPDLOCK, HOLDLOCK)
                   WHERE NIT = @NIT AND (@ProveedorId IS NULL OR ProveedorId <> @ProveedorId))
            THROW 51606, 'Ya existe otro proveedor con ese NIT.', 1;

        IF @ProveedorId IS NULL
        BEGIN
            INSERT INTO dbo.Proveedor (NIT, Nombre, Contacto, Telefono, Correo, Direccion)
            VALUES (@NIT, @Nombre, NULLIF(LTRIM(RTRIM(@Contacto)), ''), @Telefono, @Correo,
                    NULLIF(LTRIM(RTRIM(@Direccion)), ''));
            SET @ProveedorId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE ProveedorId = @ProveedorId)
                THROW 51607, 'El proveedor no existe.', 1;

            UPDATE dbo.Proveedor
            SET NIT       = @NIT,
                Nombre    = @Nombre,
                Contacto  = NULLIF(LTRIM(RTRIM(@Contacto)), ''),
                Telefono  = @Telefono,
                Correo    = @Correo,
                Direccion = NULLIF(LTRIM(RTRIM(@Direccion)), '')
            WHERE ProveedorId = @ProveedorId;
        END

        COMMIT TRANSACTION;

        SELECT ProveedorId, NIT, Nombre, Estado FROM dbo.Proveedor WHERE ProveedorId = @ProveedorId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Proveedor_CambiarEstado
   No se inactiva si tiene compras PENDIENTES.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Proveedor_CambiarEstado
    @UsuarioId    INT,
    @ProveedorId  INT,
    @Estado       VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 51611, 'El usuario no está autorizado para modificar proveedores (rol BODEGA o ADMINISTRADOR).', 1;

        SET @Estado = UPPER(LTRIM(RTRIM(@Estado)));
        IF @Estado NOT IN ('ACTIVO', 'INACTIVO')
            THROW 51612, 'Estado inválido. Use ACTIVO o INACTIVO.', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Proveedor WITH (UPDLOCK, HOLDLOCK) WHERE ProveedorId = @ProveedorId)
            THROW 51613, 'El proveedor no existe.', 1;

        IF @Estado = 'INACTIVO' AND EXISTS (SELECT 1 FROM dbo.Compra
                                           WHERE ProveedorId = @ProveedorId AND Estado = 'PENDIENTE')
            THROW 51614, 'El proveedor tiene compras pendientes. Reciba o anule esas compras primero.', 1;

        UPDATE dbo.Proveedor SET Estado = @Estado WHERE ProveedorId = @ProveedorId;

        COMMIT TRANSACTION;

        SELECT ProveedorId, NIT, Nombre, Estado FROM dbo.Proveedor WHERE ProveedorId = @ProveedorId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   USUARIOS / EMPLEADOS
   ========================================================== */

/* ----------------------------------------------------------
   sp_Usuario_Guardar
   @UsuarioEditarId NULL = crear (la contraseña es obligatoria);
   con valor = editar datos y roles (la contraseña se ignora;
   para cambiarla se usa sp_Usuario_RestablecerContrasena).
   @Roles: Ids de rol separados por coma, ej. '2,5'.
   Regla: siempre debe quedar al menos un ADMINISTRADOR activo.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Usuario_Guardar
    @UsuarioId        INT,
    @UsuarioEditarId  INT          = NULL,
    @NombreUsuario    VARCHAR(30),
    @NombreCompleto   VARCHAR(100),
    @Correo           VARCHAR(100),
    @Telefono         VARCHAR(15)  = NULL,
    @Contrasena       VARCHAR(255) = NULL,
    @Roles            VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RolesNuevos TABLE (RolId INT PRIMARY KEY);

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51701, 'Solo el ADMINISTRADOR puede administrar usuarios.', 1;

        SET @NombreUsuario  = LOWER(LTRIM(RTRIM(@NombreUsuario)));
        SET @NombreCompleto = LTRIM(RTRIM(@NombreCompleto));
        SET @Correo         = LOWER(LTRIM(RTRIM(@Correo)));
        SET @Telefono       = NULLIF(LTRIM(RTRIM(@Telefono)), '');

        IF @NombreUsuario IS NULL OR LEN(@NombreUsuario) < 3 OR @NombreUsuario LIKE '%[^a-z0-9._]%'
            THROW 51702, 'Nombre de usuario inválido: mínimo 3 caracteres, solo letras, números, punto o guion bajo.', 1;

        IF @NombreCompleto IS NULL OR @NombreCompleto = ''
            THROW 51703, 'El nombre completo es obligatorio.', 1;

        IF @Correo IS NULL OR @Correo NOT LIKE '%_@_%._%'
            THROW 51704, 'Correo inválido.', 1;

        IF @Telefono IS NOT NULL AND @Telefono LIKE '%[^0-9 +-]%'
            THROW 51705, 'Teléfono inválido.', 1;

        IF @UsuarioEditarId IS NULL AND (@Contrasena IS NULL OR LEN(@Contrasena) < 8)
            THROW 51706, 'La contraseña debe tener al menos 8 caracteres.', 1;

        -- Roles enviados (solo Ids numéricos y roles activos)
        INSERT INTO @RolesNuevos (RolId)
        SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(s.value)) AS INT)
        FROM STRING_SPLIT(ISNULL(@Roles, ''), ',') s
        WHERE TRY_CAST(LTRIM(RTRIM(s.value)) AS INT) IS NOT NULL;

        IF NOT EXISTS (SELECT 1 FROM @RolesNuevos)
            THROW 51707, 'Asigne al menos un rol.', 1;

        IF EXISTS (SELECT 1 FROM @RolesNuevos n
                   LEFT JOIN dbo.Rol r ON r.RolId = n.RolId AND r.Activo = 1
                   WHERE r.RolId IS NULL)
            THROW 51708, 'Uno de los roles no existe o está inactivo.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK)
                   WHERE NombreUsuario = @NombreUsuario
                     AND (@UsuarioEditarId IS NULL OR UsuarioId <> @UsuarioEditarId))
            THROW 51709, 'Ese nombre de usuario ya está en uso.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK)
                   WHERE Correo = @Correo
                     AND (@UsuarioEditarId IS NULL OR UsuarioId <> @UsuarioEditarId))
            THROW 51710, 'Ese correo ya está registrado en otro usuario.', 1;

        IF @UsuarioEditarId IS NULL
        BEGIN
            INSERT INTO dbo.Usuario (NombreUsuario, ContrasenaHash, NombreCompleto, Correo, Telefono)
            VALUES (@NombreUsuario,
                    UPPER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @Contrasena), 2)),
                    @NombreCompleto, @Correo, @Telefono);
            SET @UsuarioEditarId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioEditarId)
                THROW 51711, 'El usuario no existe.', 1;

            UPDATE dbo.Usuario
            SET NombreUsuario  = @NombreUsuario,
                NombreCompleto = @NombreCompleto,
                Correo         = @Correo,
                Telefono       = @Telefono
            WHERE UsuarioId = @UsuarioEditarId;

            -- Quita los roles que ya no tiene
            DELETE ur
            FROM dbo.UsuarioRol ur
            WHERE ur.UsuarioId = @UsuarioEditarId
              AND NOT EXISTS (SELECT 1 FROM @RolesNuevos n WHERE n.RolId = ur.RolId);
        END

        -- Agrega los roles nuevos (los que ya tenía conservan su fecha)
        INSERT INTO dbo.UsuarioRol (UsuarioId, RolId)
        SELECT @UsuarioEditarId, n.RolId
        FROM @RolesNuevos n
        WHERE NOT EXISTS (SELECT 1 FROM dbo.UsuarioRol ur
                          WHERE ur.UsuarioId = @UsuarioEditarId AND ur.RolId = n.RolId);

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario u
                       JOIN dbo.UsuarioRol ur ON ur.UsuarioId = u.UsuarioId
                       JOIN dbo.Rol r ON r.RolId = ur.RolId
                       WHERE u.Activo = 1 AND r.Nombre = 'ADMINISTRADOR')
            THROW 51712, 'Debe quedar al menos un ADMINISTRADOR activo.', 1;

        COMMIT TRANSACTION;

        SELECT UsuarioId, NombreUsuario, NombreCompleto, Correo, Telefono, Activo, Roles
        FROM dbo.vw_UsuarioLista WHERE UsuarioId = @UsuarioEditarId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Usuario_CambiarEstado
   Activa o inactiva un usuario (un usuario inactivo no puede
   iniciar sesión). Nadie se puede inactivar a sí mismo.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Usuario_CambiarEstado
    @UsuarioId        INT,
    @UsuarioEditarId  INT,
    @Activo           BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51721, 'Solo el ADMINISTRADOR puede administrar usuarios.', 1;

        IF @Activo = 0 AND @UsuarioEditarId = @UsuarioId
            THROW 51722, 'No puede inactivar su propio usuario.', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK) WHERE UsuarioId = @UsuarioEditarId)
            THROW 51723, 'El usuario no existe.', 1;

        UPDATE dbo.Usuario SET Activo = @Activo WHERE UsuarioId = @UsuarioEditarId;

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario u
                       JOIN dbo.UsuarioRol ur ON ur.UsuarioId = u.UsuarioId
                       JOIN dbo.Rol r ON r.RolId = ur.RolId
                       WHERE u.Activo = 1 AND r.Nombre = 'ADMINISTRADOR')
            THROW 51724, 'Debe quedar al menos un ADMINISTRADOR activo.', 1;

        COMMIT TRANSACTION;

        SELECT UsuarioId, NombreUsuario, NombreCompleto, Correo, Telefono, Activo, Roles
        FROM dbo.vw_UsuarioLista WHERE UsuarioId = @UsuarioEditarId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Usuario_RestablecerContrasena
   El ADMINISTRADOR asigna una contraseña nueva (mínimo 8 caracteres).
   Se guarda solo el hash SHA2_256.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Usuario_RestablecerContrasena
    @UsuarioId        INT,
    @UsuarioEditarId  INT,
    @Contrasena       VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51731, 'Solo el ADMINISTRADOR puede administrar usuarios.', 1;

        IF @Contrasena IS NULL OR LEN(@Contrasena) < 8
            THROW 51732, 'La contraseña debe tener al menos 8 caracteres.', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK) WHERE UsuarioId = @UsuarioEditarId)
            THROW 51733, 'El usuario no existe.', 1;

        UPDATE dbo.Usuario
        SET ContrasenaHash = UPPER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @Contrasena), 2))
        WHERE UsuarioId = @UsuarioEditarId;

        COMMIT TRANSACTION;

        SELECT @UsuarioEditarId AS UsuarioId, 'CONTRASEÑA ACTUALIZADA' AS Resultado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   CLIENTES Y EQUIPOS: volver a activar
   sp_Cliente_Eliminar y sp_Equipo_Eliminar (script 11) inactivan;
   estos dos procedimientos deshacen ese paso.
   ========================================================== */

/* ----------------------------------------------------------
   sp_Cliente_Activar
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_Activar
    @ClienteId INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteId = @ClienteId)
            THROW 51801, 'El cliente no existe.', 1;

        UPDATE dbo.Cliente SET Estado = 'ACTIVO' WHERE ClienteId = @ClienteId;

        SELECT @ClienteId AS ClienteId, 'CLIENTE ACTIVADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Equipo_Activar
   El dueño debe estar activo (un equipo activo de un cliente
   inactivo no podría recibir órdenes).
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Equipo_Activar
    @EquipoId INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Equipo WHERE EquipoId = @EquipoId)
            THROW 51811, 'El equipo no existe.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Equipo e
                   JOIN dbo.Cliente c ON c.ClienteId = e.ClienteId
                   WHERE e.EquipoId = @EquipoId AND c.Estado <> 'ACTIVO')
            THROW 51812, 'El cliente de este equipo está inactivo. Active primero al cliente.', 1;

        UPDATE dbo.Equipo SET Estado = 'ACTIVO' WHERE EquipoId = @EquipoId;

        SELECT @EquipoId AS EquipoId, 'EQUIPO ACTIVADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- Verificar que se crearon los procedimientos
SELECT name AS Procedimiento, create_date, modify_date
FROM sys.procedures
WHERE name IN ('sp_Categoria_Guardar', 'sp_Categoria_CambiarEstado', 'sp_TipoEquipo_Guardar',
               'sp_Repuesto_Guardar', 'sp_Repuesto_CambiarEstado', 'sp_Inventario_GuardarMinimo',
               'sp_Bodega_Guardar', 'sp_Bodega_CambiarEstado',
               'sp_Proveedor_Guardar', 'sp_Proveedor_CambiarEstado',
               'sp_Usuario_Guardar', 'sp_Usuario_CambiarEstado', 'sp_Usuario_RestablecerContrasena',
               'sp_Cliente_Activar', 'sp_Equipo_Activar')
ORDER BY name;
GO
