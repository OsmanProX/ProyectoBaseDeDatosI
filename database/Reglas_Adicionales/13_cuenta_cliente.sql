/* ==========================================================
   13_cuenta_cliente.sql
   Cuenta de acceso para clientes (rol CLIENTE).
   - Rol CLIENTE y permiso VER_MIS_ORDENES
   - Usuario.ClienteId: liga la cuenta con su cliente (NULL = empleado)
   - sp_Cliente_CrearAcceso: crea la cuenta al registrar un cliente
   - sp_Cliente_MisOrdenes: órdenes del cliente que inició sesión
   Se puede ejecutar más de una vez (no duplica nada).
   Probar primero en Docker (localhost,1441).
   ========================================================== */

-- 1. Rol CLIENTE
IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Nombre = 'CLIENTE')
    INSERT INTO dbo.Rol (Nombre, Descripcion) VALUES ('CLIENTE', 'Cliente: consulta el estado de sus órdenes');
GO

-- 2. Permiso VER_MIS_ORDENES para el rol CLIENTE
IF NOT EXISTS (SELECT 1 FROM dbo.Permiso WHERE Codigo = 'VER_MIS_ORDENES')
    INSERT INTO dbo.Permiso (Codigo, Descripcion) VALUES ('VER_MIS_ORDENES', 'Ver sus propias órdenes, estado y saldo');

INSERT INTO dbo.RolPermiso (RolId, PermisoId)
SELECT r.RolId, p.PermisoId
FROM dbo.Rol r CROSS JOIN dbo.Permiso p
WHERE r.Nombre = 'CLIENTE' AND p.Codigo = 'VER_MIS_ORDENES'
  AND NOT EXISTS (SELECT 1 FROM dbo.RolPermiso x WHERE x.RolId = r.RolId AND x.PermisoId = p.PermisoId);
GO

-- 3. Usuario.ClienteId (una sola cuenta por cliente)
IF COL_LENGTH('dbo.Usuario', 'ClienteId') IS NULL
    ALTER TABLE dbo.Usuario ADD ClienteId INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Usuario_Cliente')
    ALTER TABLE dbo.Usuario ADD CONSTRAINT FK_Usuario_Cliente
        FOREIGN KEY (ClienteId) REFERENCES dbo.Cliente (ClienteId) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO
-- 4. Contraseña temporal: obliga a cambiarla al iniciar sesión
IF COL_LENGTH('dbo.Usuario', 'DebeCambiarContrasena') IS NULL
    ALTER TABLE dbo.Usuario ADD DebeCambiarContrasena BIT NOT NULL
        CONSTRAINT DF_Usuario_DebeCambiarContrasena DEFAULT (0);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Usuario_ClienteId')
    CREATE UNIQUE NONCLUSTERED INDEX UX_Usuario_ClienteId ON dbo.Usuario (ClienteId) WHERE ClienteId IS NOT NULL;
GO

/* ----------------------------------------------------------
   sp_Cliente_CrearAcceso
   Crea la cuenta (rol CLIENTE) de un cliente ya registrado.
   El usuario se arma con el correo (antes de la @); si ya existe
   se le agrega un número. La contraseña llega del backend y se
   guarda solo en hash SHA2_256 (igual que sp_LoginUsuario).
   Errores 51801 - 51806
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_CrearAcceso
    @UsuarioId   INT,            -- quien registra (RECEPCION o ADMINISTRADOR)
    @ClienteId   INT,
    @Contrasena  VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Correo VARCHAR(100), @Nombre VARCHAR(150), @Telefono VARCHAR(15), @Estado VARCHAR(15);
    DECLARE @Base VARCHAR(30), @NombreUsuario VARCHAR(30), @n INT = 1, @NuevoId INT;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'RECEPCION') = 0
            THROW 51801, 'Solo RECEPCION o ADMINISTRADOR pueden crear la cuenta del cliente.', 1;

        IF @Contrasena IS NULL OR LEN(@Contrasena) < 8
            THROW 51802, 'La contraseña temporal debe tener al menos 8 caracteres.', 1;

        BEGIN TRANSACTION;

        SELECT @Correo = LOWER(LTRIM(RTRIM(Correo))), @Nombre = NombreRazonSocial,
               @Telefono = Telefono, @Estado = Estado
        FROM dbo.Cliente WITH (UPDLOCK, HOLDLOCK)
        WHERE ClienteId = @ClienteId;

        IF @Estado IS NULL OR @Estado <> 'ACTIVO'
            THROW 51803, 'El cliente no existe o está inactivo.', 1;

        IF @Correo IS NULL OR @Correo NOT LIKE '%_@_%._%'
            THROW 51804, 'El cliente no tiene un correo válido para crear su cuenta.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK) WHERE ClienteId = @ClienteId)
            THROW 51805, 'Este cliente ya tiene una cuenta de acceso.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK) WHERE Correo = @Correo)
            THROW 51806, 'Ese correo ya está registrado en otro usuario del sistema.', 1;

        -- Usuario a partir del correo: solo letras, números, punto y guion bajo
        SET @Base = LEFT(LEFT(@Correo, CHARINDEX('@', @Correo) - 1), 24);
        WHILE PATINDEX('%[^a-z0-9._]%', @Base) > 0
            SET @Base = STUFF(@Base, PATINDEX('%[^a-z0-9._]%', @Base), 1, '');
        IF LEN(@Base) < 3 SET @Base = CONCAT('cliente', @ClienteId);

        SET @NombreUsuario = @Base;
        WHILE EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK) WHERE NombreUsuario = @NombreUsuario)
        BEGIN
            SET @n += 1;
            SET @NombreUsuario = CONCAT(@Base, @n);
        END;

        -- DebeCambiarContrasena = 1: la contraseña es temporal (llega por correo)
        INSERT INTO dbo.Usuario (NombreUsuario, ContrasenaHash, NombreCompleto, Correo, Telefono, ClienteId, DebeCambiarContrasena)
        VALUES (@NombreUsuario,
                UPPER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @Contrasena), 2)),
                LEFT(@Nombre, 100), @Correo, @Telefono, @ClienteId, 1);
        SET @NuevoId = SCOPE_IDENTITY();

        INSERT INTO dbo.UsuarioRol (UsuarioId, RolId)
        SELECT @NuevoId, RolId FROM dbo.Rol WHERE Nombre = 'CLIENTE';

        COMMIT TRANSACTION;

        SELECT @NuevoId AS UsuarioId, @NombreUsuario AS NombreUsuario, @Correo AS Correo, LEFT(@Nombre, 100) AS NombreCompleto;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Cliente_MisOrdenes
   Órdenes del cliente dueño de la cuenta que inició sesión.
   Solo lectura: estado, equipo, factura y saldo.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_MisOrdenes
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClienteId INT = (SELECT ClienteId FROM dbo.Usuario WHERE UsuarioId = @UsuarioId AND Activo = 1);

    IF @ClienteId IS NULL
        THROW 51811, 'Esta cuenta no está ligada a un cliente.', 1;

    SELECT o.OrdenId,
           o.NumeroOrden,
           o.FechaIngreso,
           o.FechaEstimada,
           o.Prioridad,
           e.Codigo                                   AS Estado,
           e.Descripcion                              AS EstadoDescripcion,
           te.Nombre                                  AS TipoEquipo,
           CONCAT(eq.Marca, ' ', eq.Modelo)           AS Equipo,
           eq.NumeroSerie,
           o.ProblemaReportado,
           f.NumeroFactura,
           f.Total,
           CASE WHEN f.FacturaId IS NULL THEN NULL ELSE dbo.fn_SaldoFactura(f.FacturaId) END AS Saldo
    FROM dbo.OrdenServicio o
    JOIN dbo.EstadoOrden e  ON e.EstadoOrdenId = o.EstadoOrdenId
    JOIN dbo.Equipo eq      ON eq.EquipoId     = o.EquipoId
    JOIN dbo.TipoEquipo te  ON te.TipoEquipoId = eq.TipoEquipoId
    LEFT JOIN dbo.Factura f ON f.OrdenId = o.OrdenId AND f.Estado <> 'ANULADA'
    WHERE o.ClienteId = @ClienteId
    ORDER BY o.FechaIngreso DESC;
END;
GO

-- Verificación
SELECT 'Rol CLIENTE' AS Objeto, COUNT(*) AS Existe FROM dbo.Rol WHERE Nombre = 'CLIENTE'
UNION ALL SELECT 'Usuario.ClienteId', CASE WHEN COL_LENGTH('dbo.Usuario', 'ClienteId') IS NULL THEN 0 ELSE 1 END
UNION ALL SELECT 'sp_Cliente_CrearAcceso', COUNT(*) FROM sys.procedures WHERE name = 'sp_Cliente_CrearAcceso'
UNION ALL SELECT 'sp_Cliente_MisOrdenes',  COUNT(*) FROM sys.procedures WHERE name = 'sp_Cliente_MisOrdenes';
-- Deben salir 4 filas con Existe = 1
GO
