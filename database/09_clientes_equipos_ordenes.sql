/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 09: SPs básicos y vistas de clientes, equipos y órdenes
   Se ejecuta después del 01, 02 y 03
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   VISTAS
   ========================================================== */

-- vw_Cliente: clientes con su estado
CREATE OR ALTER VIEW dbo.vw_Cliente
AS
    SELECT ClienteId,
           TipoCliente,
           NombreRazonSocial,
           NIT,
           Telefono,
           Correo,
           Direccion,
           Estado,
           FechaRegistro
    FROM dbo.Cliente;
GO

-- vw_Equipo: equipos con el nombre del cliente y del tipo
CREATE OR ALTER VIEW dbo.vw_Equipo
AS
    SELECT e.EquipoId,
           e.ClienteId,
           c.NombreRazonSocial AS NombreCliente,
           e.TipoEquipoId,
           t.Nombre AS TipoEquipo,
           e.Marca,
           e.Modelo,
           e.NumeroSerie,
           e.Descripcion,
           e.Estado
    FROM dbo.Equipo e
    INNER JOIN dbo.Cliente c ON c.ClienteId = e.ClienteId
    INNER JOIN dbo.TipoEquipo t ON t.TipoEquipoId = e.TipoEquipoId;
GO

-- vw_Orden: órdenes con cliente, equipo, estado y recepcionista
-- (las reglas usan LEFT JOIN cuando lo opcional; aquí todo es NOT NULL)
CREATE OR ALTER VIEW dbo.vw_Orden
AS
    SELECT o.OrdenId,
           o.NumeroOrden,
           o.ClienteId,
           c.NombreRazonSocial AS NombreCliente,
           o.EquipoId,
           e.NumeroSerie,
           t.Nombre + ' ' + e.Marca + ' ' + e.Modelo AS Equipo,
           o.UsuarioRecepcionId,
           u.NombreCompleto AS Recepcionista,
           o.FechaIngreso,
           o.ProblemaReportado,
           o.Prioridad,
           o.EstadoOrdenId,
           eo.Codigo AS Estado,
           o.FechaEstimada,
           o.Observaciones
    FROM dbo.OrdenServicio o
    INNER JOIN dbo.Cliente c ON c.ClienteId = o.ClienteId
    INNER JOIN dbo.Equipo e ON e.EquipoId = o.EquipoId
    INNER JOIN dbo.TipoEquipo t ON t.TipoEquipoId = e.TipoEquipoId
    INNER JOIN dbo.EstadoOrden eo ON eo.EstadoOrdenId = o.EstadoOrdenId
    INNER JOIN dbo.Usuario u ON u.UsuarioId = o.UsuarioRecepcionId;
GO

/* ==========================================================
   sp_Cliente_Crear
   Registra un cliente (individual o empresarial).
   Valida el tipo de cliente y que el NIT no esté duplicado.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_Crear
    @TipoCliente       VARCHAR(15),
    @NombreRazonSocial VARCHAR(150),
    @NIT               VARCHAR(15),
    @Telefono          VARCHAR(15),
    @Correo            VARCHAR(100) = NULL,
    @Direccion         VARCHAR(200) = NULL,
    @ClienteId         INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @TipoCliente NOT IN ('INDIVIDUAL', 'EMPRESARIAL')
            THROW 50301, 'Tipo de cliente inválido. Use INDIVIDUAL o EMPRESARIAL.', 1;

        IF @NombreRazonSocial IS NULL OR LTRIM(RTRIM(@NombreRazonSocial)) = ''
            THROW 50302, 'El nombre o razón social es obligatorio.', 1;

        IF @NIT IS NULL OR LTRIM(RTRIM(@NIT)) = ''
            THROW 50303, 'El NIT es obligatorio.', 1;

        -- CF (consumidor final) se puede repetir: el índice UX_Cliente_NIT lo excluye
        IF @NIT <> 'CF' AND EXISTS (SELECT 1 FROM dbo.Cliente WHERE NIT = @NIT)
            THROW 50304, 'Ya existe un cliente con ese NIT.', 1;

        INSERT INTO dbo.Cliente (TipoCliente, NombreRazonSocial, NIT, Telefono, Correo, Direccion)
        VALUES (@TipoCliente, LTRIM(RTRIM(@NombreRazonSocial)), LTRIM(RTRIM(@NIT)),
                @Telefono, @Correo, @Direccion);

        SET @ClienteId = SCOPE_IDENTITY();

        SELECT @ClienteId AS ClienteId, @NIT AS NIT, 'CLIENTE REGISTRADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_Equipo_Crear
   Registra un equipo de un cliente.
   Valida que el cliente esté activo, que el tipo exista
   y que el número de serie sea único (R01).
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Equipo_Crear
    @ClienteId    INT,
    @TipoEquipoId INT,
    @Marca        VARCHAR(50),
    @Modelo       VARCHAR(50),
    @NumeroSerie  VARCHAR(50),
    @Descripcion  VARCHAR(200) = NULL,
    @EquipoId     INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente
                       WHERE ClienteId = @ClienteId AND Estado = 'ACTIVO')
            THROW 50311, 'El cliente no existe o está inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.TipoEquipo WHERE TipoEquipoId = @TipoEquipoId)
            THROW 50312, 'El tipo de equipo no existe.', 1;

        IF @NumeroSerie IS NULL OR LTRIM(RTRIM(@NumeroSerie)) = ''
            THROW 50313, 'El número de serie es obligatorio.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Equipo WHERE NumeroSerie = @NumeroSerie)
            THROW 50314, 'Ya existe un equipo con ese número de serie.', 1;

        INSERT INTO dbo.Equipo (ClienteId, TipoEquipoId, Marca, Modelo, NumeroSerie, Descripcion)
        VALUES (@ClienteId, @TipoEquipoId, @Marca, @Modelo,
                LTRIM(RTRIM(@NumeroSerie)), @Descripcion);

        SET @EquipoId = SCOPE_IDENTITY();

        SELECT @EquipoId AS EquipoId, @NumeroSerie AS NumeroSerie, 'EQUIPO REGISTRADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- Verificación
-- SELECT name FROM sys.views WHERE name IN ('vw_Cliente', 'vw_Equipo', 'vw_Orden');
-- SELECT name FROM sys.procedures WHERE name IN ('sp_Cliente_Crear', 'sp_Equipo_Crear');
