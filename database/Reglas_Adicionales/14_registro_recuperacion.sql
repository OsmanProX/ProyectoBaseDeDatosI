/* ==========================================================
   14_registro_recuperacion.sql   (requiere el script 13)
   - sp_Cliente_Registrarse: el cliente crea su propia cuenta desde el login
   - sp_Usuario_RecuperarContrasena: "¿Olvidó su contraseña?" (asigna una temporal)
   - sp_Usuario_CambiarMiContrasena: cada usuario cambia su propia contraseña
   Las contraseñas se guardan solo en hash SHA2_256 (igual que sp_LoginUsuario).
   - sp_LoginUsuario: ahora devuelve DebeCambiarContrasena
   - sp_MiCuenta_Obtener / sp_MiCuenta_Actualizar: "Mi cuenta" (editar mis datos)
   Se puede ejecutar más de una vez.
   ========================================================== */

/* ----------------------------------------------------------
   sp_LoginUsuario (versión con DebeCambiarContrasena)
   Igual que la original + la marca de contraseña temporal:
   si es 1, el sistema obliga a cambiarla antes de continuar.
   @Correo acepta el correo o el nombre de usuario.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_LoginUsuario
    @Correo     VARCHAR(100),
    @Contrasena VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Hash VARCHAR(64) =
        UPPER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @Contrasena), 2));

    SELECT u.UsuarioId,
           u.NombreUsuario,
           u.NombreCompleto,
           u.Correo,
           u.Telefono,
           u.DebeCambiarContrasena,
           (SELECT STRING_AGG(r.Nombre, ', ') WITHIN GROUP (ORDER BY r.RolId)
            FROM UsuarioRol ur
            INNER JOIN Rol r ON r.RolId = ur.RolId
            WHERE ur.UsuarioId = u.UsuarioId) AS Roles,
           (SELECT STRING_AGG(x.Codigo, ', ') WITHIN GROUP (ORDER BY x.Codigo)
            FROM (SELECT p.Codigo
                  FROM UsuarioRol ur
                  INNER JOIN RolPermiso rp ON rp.RolId    = ur.RolId
                  INNER JOIN Permiso p     ON p.PermisoId = rp.PermisoId
                  WHERE ur.UsuarioId = u.UsuarioId
                    AND p.Activo = 1
                  GROUP BY p.Codigo) x) AS Permisos
    FROM Usuario u
    WHERE (u.Correo = LOWER(LTRIM(RTRIM(@Correo))) OR u.NombreUsuario = LOWER(LTRIM(RTRIM(@Correo))))
      AND u.Activo = 1
      AND u.ContrasenaHash = @Hash;
END;
GO

/* ----------------------------------------------------------
   sp_Cliente_Registrarse   (errores 51831 - 51838)
   Registra el cliente y su cuenta (rol CLIENTE) en una sola transacción.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_Registrarse
    @TipoCliente       VARCHAR(15),
    @NombreRazonSocial VARCHAR(150),
    @NIT               VARCHAR(15),
    @Telefono          VARCHAR(15),
    @Correo            VARCHAR(100),
    @Direccion         VARCHAR(200),
    @Contrasena        VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ClienteId INT, @UsuarioId INT, @Base VARCHAR(30), @NombreUsuario VARCHAR(30), @n INT = 1;

    BEGIN TRY
        SET @NombreRazonSocial = LTRIM(RTRIM(@NombreRazonSocial));
        SET @NIT       = UPPER(LTRIM(RTRIM(@NIT)));
        SET @Telefono  = LTRIM(RTRIM(@Telefono));
        SET @Correo    = LOWER(LTRIM(RTRIM(@Correo)));
        SET @Direccion = LTRIM(RTRIM(@Direccion));

        IF @TipoCliente NOT IN ('INDIVIDUAL', 'EMPRESARIAL')
            THROW 51831, 'Tipo de cliente inválido.', 1;
        IF ISNULL(@NombreRazonSocial, '') = ''
            THROW 51832, 'El nombre o razón social es obligatorio.', 1;
        IF ISNULL(@NIT, '') = '' OR ISNULL(@Telefono, '') = '' OR ISNULL(@Direccion, '') = ''
            THROW 51833, 'NIT, teléfono y dirección son obligatorios.', 1;
        IF @Correo IS NULL OR @Correo NOT LIKE '%_@_%._%'
            THROW 51834, 'Correo inválido.', 1;
        IF @Contrasena IS NULL OR LEN(@Contrasena) < 8
            THROW 51835, 'La contraseña debe tener al menos 8 caracteres.', 1;

        BEGIN TRANSACTION;

        IF @NIT <> 'CF' AND EXISTS (SELECT 1 FROM dbo.Cliente WITH (UPDLOCK, HOLDLOCK) WHERE NIT = @NIT)
            THROW 51836, 'Ya existe un cliente con ese NIT. Si es usted, acérquese a TechCare para activar su cuenta.', 1;
        IF EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK) WHERE Correo = @Correo)
            THROW 51837, 'Ese correo ya tiene una cuenta. Use "¿Olvidó su contraseña?" si no la recuerda.', 1;

        INSERT INTO dbo.Cliente (TipoCliente, NombreRazonSocial, NIT, Telefono, Correo, Direccion)
        VALUES (@TipoCliente, @NombreRazonSocial, @NIT, @Telefono, @Correo, @Direccion);
        SET @ClienteId = SCOPE_IDENTITY();

        -- Usuario a partir del correo (igual que sp_Cliente_CrearAcceso)
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

        INSERT INTO dbo.Usuario (NombreUsuario, ContrasenaHash, NombreCompleto, Correo, Telefono, ClienteId)
        VALUES (@NombreUsuario, UPPER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @Contrasena), 2)),
                LEFT(@NombreRazonSocial, 100), @Correo, @Telefono, @ClienteId);
        SET @UsuarioId = SCOPE_IDENTITY();

        IF NOT EXISTS (SELECT 1 FROM dbo.Rol WHERE Nombre = 'CLIENTE')
            THROW 51838, 'Falta el rol CLIENTE: ejecute el script 13.', 1;

        INSERT INTO dbo.UsuarioRol (UsuarioId, RolId)
        SELECT @UsuarioId, RolId FROM dbo.Rol WHERE Nombre = 'CLIENTE';

        COMMIT TRANSACTION;

        SELECT @UsuarioId AS UsuarioId, @NombreUsuario AS NombreUsuario, @Correo AS Correo,
               LEFT(@NombreRazonSocial, 100) AS NombreCompleto;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Usuario_RecuperarContrasena
   Si el correo pertenece a un usuario activo, le asigna la contraseña
   temporal que genera el backend y devuelve sus datos para el correo.
   Si no existe, no devuelve filas (el sistema responde igual en ambos
   casos, para no revelar qué correos están registrados).
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Usuario_RecuperarContrasena
    @Correo      VARCHAR(100),
    @Contrasena  VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Contrasena IS NULL OR LEN(@Contrasena) < 8
        THROW 51841, 'La contraseña temporal debe tener al menos 8 caracteres.', 1;

    UPDATE dbo.Usuario
    SET ContrasenaHash = UPPER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @Contrasena), 2)),
        DebeCambiarContrasena = 1   -- es temporal: se obliga a cambiarla al entrar
    OUTPUT inserted.UsuarioId, inserted.NombreUsuario, inserted.Correo, inserted.NombreCompleto,
           deleted.ContrasenaHash AS HashAnterior, deleted.DebeCambiarContrasena AS DebeCambiarAnterior
    WHERE Correo = LOWER(LTRIM(RTRIM(@Correo))) AND Activo = 1;
END;
GO

/* ----------------------------------------------------------
   sp_Usuario_CambiarMiContrasena   (errores 51851 - 51853)
   El usuario que inició sesión cambia su contraseña (pide la actual).
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Usuario_CambiarMiContrasena
    @UsuarioId  INT,
    @Actual     VARCHAR(255),
    @Nueva      VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    IF @Nueva IS NULL OR LEN(@Nueva) < 8
        THROW 51851, 'La contraseña nueva debe tener al menos 8 caracteres.', 1;
    IF @Nueva = @Actual
        THROW 51852, 'La contraseña nueva debe ser distinta de la actual.', 1;

    UPDATE dbo.Usuario
    SET ContrasenaHash = UPPER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @Nueva), 2)),
        DebeCambiarContrasena = 0
    WHERE UsuarioId = @UsuarioId AND Activo = 1
      AND ContrasenaHash = UPPER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @Actual), 2));

    IF @@ROWCOUNT = 0
        THROW 51853, 'La contraseña actual no es correcta.', 1;

    SELECT 'CONTRASEÑA ACTUALIZADA' AS Resultado;
END;
GO

/* ----------------------------------------------------------
   sp_MiCuenta_Obtener / sp_MiCuenta_Actualizar   (errores 51861 - 51864)
   "Mi cuenta": cada usuario ve y edita sus propios datos.
   Si la cuenta es de un cliente, también se actualiza la tabla Cliente.
   El correo no se cambia aquí (es con el que inicia sesión).
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_MiCuenta_Obtener
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.UsuarioId, u.NombreUsuario, u.NombreCompleto, u.Correo, u.Telefono, u.ClienteId,
           c.TipoCliente, c.NIT, c.Direccion
    FROM dbo.Usuario u
    LEFT JOIN dbo.Cliente c ON c.ClienteId = u.ClienteId
    WHERE u.UsuarioId = @UsuarioId AND u.Activo = 1;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_MiCuenta_Actualizar
    @UsuarioId       INT,
    @NombreCompleto  VARCHAR(150),
    @Telefono        VARCHAR(15),
    @Direccion       VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ClienteId INT;

    BEGIN TRY
        SET @NombreCompleto = LTRIM(RTRIM(@NombreCompleto));
        SET @Telefono  = LTRIM(RTRIM(@Telefono));
        SET @Direccion = NULLIF(LTRIM(RTRIM(@Direccion)), '');

        IF ISNULL(@NombreCompleto, '') = ''
            THROW 51861, 'El nombre es obligatorio.', 1;
        IF @Telefono IS NULL OR @Telefono LIKE '%[^0-9]%' OR LEN(@Telefono) <> 8
            THROW 51862, 'El teléfono debe tener 8 números.', 1;

        BEGIN TRANSACTION;

        SELECT @ClienteId = ClienteId FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK)
        WHERE UsuarioId = @UsuarioId AND Activo = 1;
        IF @@ROWCOUNT = 0
            THROW 51863, 'El usuario no existe o está inactivo.', 1;

        IF @ClienteId IS NOT NULL AND @Direccion IS NULL
            THROW 51864, 'La dirección es obligatoria.', 1;

        UPDATE dbo.Usuario
        SET NombreCompleto = LEFT(@NombreCompleto, 100), Telefono = @Telefono
        WHERE UsuarioId = @UsuarioId;

        IF @ClienteId IS NOT NULL
            UPDATE dbo.Cliente
            SET NombreRazonSocial = @NombreCompleto, Telefono = @Telefono, Direccion = @Direccion
            WHERE ClienteId = @ClienteId;

        COMMIT TRANSACTION;

        EXEC dbo.sp_MiCuenta_Obtener @UsuarioId = @UsuarioId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Verificación: deben salir 6 filas
SELECT name AS Procedimiento FROM sys.procedures
WHERE name IN ('sp_LoginUsuario', 'sp_Cliente_Registrarse', 'sp_Usuario_RecuperarContrasena', 'sp_Usuario_CambiarMiContrasena',
               'sp_MiCuenta_Obtener', 'sp_MiCuenta_Actualizar');
GO
