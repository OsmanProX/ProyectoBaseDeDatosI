/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 11: SPs de clientes y equipos (listar, actualizar, eliminar)
   Siguiente de 01..10:
     - Crear cliente  -> ya existe dbo.sp_Cliente_Crear (09)
     - Crear equipo   -> ya existe dbo.sp_Equipo_Crear  (09)
     - Listados base  -> vistas dbo.vw_Cliente / dbo.vw_Equipo (09)
   Este script agrega lo que falta para el CRUD completo:
     - sp_Cliente_Listar      (por texto y estado)
     - sp_Cliente_Actualizar  (valida tipo y NIT unico)
     - sp_Cliente_Eliminar    (logico; no si tiene ordenes abiertas)
     - sp_Equipo_Listar       (por cliente, texto y solo activos)
     - sp_Equipo_Actualizar   (valida cliente activo, tipo y serie unica)
     - sp_Equipo_Eliminar     (logico; no si tiene ordenes abiertas)
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   sp_Cliente_Listar
   Lista los clientes desde vw_Cliente.
   @Buscar: filtra por nombre/razon social o NIT.
   @Estado: 'ACTIVO' o 'INACTIVO'. NULL = todos.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_Listar
    @Buscar VARCHAR(100) = NULL,
    @Estado VARCHAR(12)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ClienteId, TipoCliente, NombreRazonSocial, NIT, Telefono,
           Correo, Direccion, Estado, FechaRegistro
    FROM dbo.vw_Cliente
    WHERE (@Estado IS NULL OR Estado = @Estado)
      AND (@Buscar IS NULL OR @Buscar = ''
           OR NombreRazonSocial LIKE '%' + @Buscar + '%'
           OR NIT LIKE '%' + @Buscar + '%')
    ORDER BY ClienteId;
END;
GO

/* ==========================================================
   sp_Cliente_Actualizar
   Actualiza los datos del cliente.
   Valida que exista, el tipo y que el NIT no lo use otro cliente.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_Actualizar
    @ClienteId         INT,
    @TipoCliente       VARCHAR(15),
    @NombreRazonSocial VARCHAR(150),
    @NIT               VARCHAR(15),
    @Telefono          VARCHAR(15),
    @Correo            VARCHAR(100) = NULL,
    @Direccion         VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteId = @ClienteId)
            THROW 51101, 'El cliente no existe.', 1;

        IF @TipoCliente NOT IN ('INDIVIDUAL', 'EMPRESARIAL')
            THROW 51102, 'Tipo de cliente invalido. Use INDIVIDUAL o EMPRESARIAL.', 1;

        IF @NombreRazonSocial IS NULL OR LTRIM(RTRIM(@NombreRazonSocial)) = ''
            THROW 51103, 'El nombre o razon social es obligatorio.', 1;

        IF @NIT IS NULL OR LTRIM(RTRIM(@NIT)) = ''
            THROW 51104, 'El NIT es obligatorio.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Cliente WHERE NIT = @NIT AND ClienteId <> @ClienteId)
            THROW 51105, 'Ya existe otro cliente con ese NIT.', 1;

        UPDATE dbo.Cliente
        SET TipoCliente       = @TipoCliente,
            NombreRazonSocial = LTRIM(RTRIM(@NombreRazonSocial)),
            NIT               = LTRIM(RTRIM(@NIT)),
            Telefono          = @Telefono,
            Correo            = @Correo,
            Direccion         = @Direccion
        WHERE ClienteId = @ClienteId;

        SELECT @ClienteId AS ClienteId, 'CLIENTE ACTUALIZADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_Cliente_Eliminar
   Borrado logico (Estado = 'INACTIVO') para no romper ordenes e historial.
   No permite inactivar un cliente con ordenes abiertas.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_Eliminar
    @ClienteId INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteId = @ClienteId)
            THROW 51111, 'El cliente no existe.', 1;

        IF EXISTS (SELECT 1 FROM dbo.OrdenServicio
                   WHERE ClienteId = @ClienteId AND EstadoOrdenId NOT IN (6, 7))
            THROW 51112, 'El cliente tiene ordenes abiertas. Cierre o cancele esas ordenes primero.', 1;

        UPDATE dbo.Cliente SET Estado = 'INACTIVO' WHERE ClienteId = @ClienteId;

        SELECT @ClienteId AS ClienteId, 'CLIENTE INACTIVADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_Equipo_Listar
   Lista los equipos desde vw_Equipo.
   @ClienteId: filtra por cliente. NULL = todos.
   @Buscar: por marca, modelo o numero de serie.
   @SoloActivos: 1 = solo equipos ACTIVO (para el formulario de nueva orden).
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Equipo_Listar
    @ClienteId   INT          = NULL,
    @Buscar      VARCHAR(100) = NULL,
    @SoloActivos BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT EquipoId, ClienteId, NombreCliente, TipoEquipoId,
           TipoEquipo AS NombreTipoEquipo,
           Marca, Modelo, NumeroSerie, Descripcion, Estado
    FROM dbo.vw_Equipo
    WHERE (@ClienteId IS NULL OR ClienteId = @ClienteId)
      AND (@SoloActivos = 0 OR Estado = 'ACTIVO')
      AND (@Buscar IS NULL OR @Buscar = ''
           OR Marca LIKE '%' + @Buscar + '%'
           OR Modelo LIKE '%' + @Buscar + '%'
           OR NumeroSerie LIKE '%' + @Buscar + '%')
    ORDER BY EquipoId;
END;
GO

/* ==========================================================
   sp_Equipo_Actualizar
   Actualiza los datos del equipo.
   Valida que exista, que el cliente este activo, que el tipo
   exista y que el numero de serie sea unico (R01).
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Equipo_Actualizar
    @EquipoId     INT,
    @ClienteId    INT,
    @TipoEquipoId INT,
    @Marca        VARCHAR(50),
    @Modelo       VARCHAR(50),
    @NumeroSerie  VARCHAR(50),
    @Descripcion  VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Equipo WHERE EquipoId = @EquipoId)
            THROW 51121, 'El equipo no existe.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente
                       WHERE ClienteId = @ClienteId AND Estado = 'ACTIVO')
            THROW 51122, 'El cliente no existe o esta inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.TipoEquipo WHERE TipoEquipoId = @TipoEquipoId)
            THROW 51123, 'El tipo de equipo no existe.', 1;

        IF @NumeroSerie IS NULL OR LTRIM(RTRIM(@NumeroSerie)) = ''
            THROW 51124, 'El numero de serie es obligatorio.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Equipo
                   WHERE NumeroSerie = @NumeroSerie AND EquipoId <> @EquipoId)
            THROW 51125, 'Ya existe otro equipo con ese numero de serie.', 1;

        UPDATE dbo.Equipo
        SET ClienteId    = @ClienteId,
            TipoEquipoId = @TipoEquipoId,
            Marca        = LTRIM(RTRIM(@Marca)),
            Modelo       = LTRIM(RTRIM(@Modelo)),
            NumeroSerie  = LTRIM(RTRIM(@NumeroSerie)),
            Descripcion  = @Descripcion
        WHERE EquipoId = @EquipoId;

        SELECT @EquipoId AS EquipoId, 'EQUIPO ACTUALIZADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_Equipo_Eliminar
   Borrado logico (Estado = 'INACTIVO').
   No permite inactivar un equipo con ordenes abiertas.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Equipo_Eliminar
    @EquipoId INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Equipo WHERE EquipoId = @EquipoId)
            THROW 51131, 'El equipo no existe.', 1;

        IF EXISTS (SELECT 1 FROM dbo.OrdenServicio
                   WHERE EquipoId = @EquipoId AND EstadoOrdenId NOT IN (6, 7))
            THROW 51132, 'El equipo tiene ordenes abiertas. Cierre o cancele esas ordenes primero.', 1;

        UPDATE dbo.Equipo SET Estado = 'INACTIVO' WHERE EquipoId = @EquipoId;

        SELECT @EquipoId AS EquipoId, 'EQUIPO INACTIVADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- Verificación (en la base ejecutar descomentado):
-- SELECT name, type_desc FROM sys.objects
-- WHERE name IN ('sp_Cliente_Listar','sp_Cliente_Actualizar','sp_Cliente_Eliminar',
--                'sp_Equipo_Listar','sp_Equipo_Actualizar','sp_Equipo_Eliminar');
-- EXEC dbo.sp_Cliente_Listar;
-- EXEC dbo.sp_Cliente_Listar @Buscar = 'comercial', @Estado = 'ACTIVO';
-- EXEC dbo.sp_Equipo_Listar @ClienteId = 1, @SoloActivos = 1;
