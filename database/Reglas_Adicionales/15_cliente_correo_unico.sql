/* ==========================================================
   15_cliente_correo_unico.sql
   Un correo no se puede repetir entre clientes.
   Índice único FILTRADO: permite varios clientes sin correo (NULL),
   pero no dos clientes con el mismo correo.
   Antes de crearlo se verifica que no existan duplicados.
   ========================================================== */
IF EXISTS (SELECT 1 FROM dbo.Cliente WHERE Correo IS NOT NULL
           GROUP BY LOWER(LTRIM(RTRIM(Correo))) HAVING COUNT(*) > 1)
BEGIN
    SELECT LOWER(LTRIM(RTRIM(Correo))) AS CorreoRepetido, COUNT(*) AS Veces
    FROM dbo.Cliente WHERE Correo IS NOT NULL
    GROUP BY LOWER(LTRIM(RTRIM(Correo))) HAVING COUNT(*) > 1;
    THROW 51871, 'Hay correos repetidos entre clientes: corríjalos antes de crear el índice.', 1;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Cliente_Correo')
    CREATE UNIQUE NONCLUSTERED INDEX UX_Cliente_Correo ON dbo.Cliente (Correo) WHERE Correo IS NOT NULL;
GO

/* ----------------------------------------------------------
   sp_Cliente_Actualizar (versión del script 15)
   Igual que la original, más:
   - correo vacío = NULL (el índice único lo ignora)
   - si el cliente tiene cuenta (rol CLIENTE), su Usuario.Correo cambia también,
     para que pueda iniciar sesión y recuperar contraseña con el correo nuevo
   - transacción con rollback (R15)
   ---------------------------------------------------------- */
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
    SET XACT_ABORT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteId = @ClienteId)
            THROW 51101, 'El cliente no existe.', 1;

        IF @TipoCliente NOT IN ('INDIVIDUAL', 'EMPRESARIAL')
            THROW 51102, 'Tipo de cliente inválido. Use INDIVIDUAL o EMPRESARIAL.', 1;

        IF @NombreRazonSocial IS NULL OR LTRIM(RTRIM(@NombreRazonSocial)) = ''
            THROW 51103, 'El nombre o razón social es obligatorio.', 1;

        IF @NIT IS NULL OR LTRIM(RTRIM(@NIT)) = ''
            THROW 51104, 'El NIT es obligatorio.', 1;

        -- CF (consumidor final) se puede repetir: el índice UX_Cliente_NIT lo excluye
        IF @NIT <> 'CF' AND EXISTS (SELECT 1 FROM dbo.Cliente WHERE NIT = @NIT AND ClienteId <> @ClienteId)
            THROW 51105, 'Ya existe otro cliente con ese NIT.', 1;

        -- Correo: vacío = NULL; si cambia, también cambia el de su cuenta (login y recuperación)
        SET @Correo = NULLIF(LOWER(LTRIM(RTRIM(@Correo))), '');
        IF @Correo IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Usuario
                   WHERE Correo = @Correo AND (ClienteId IS NULL OR ClienteId <> @ClienteId))
            THROW 51106, 'Ese correo ya lo usa otro usuario del sistema.', 1;

        BEGIN TRANSACTION;

        UPDATE dbo.Cliente
        SET TipoCliente       = @TipoCliente,
            NombreRazonSocial = LTRIM(RTRIM(@NombreRazonSocial)),
            NIT               = LTRIM(RTRIM(@NIT)),
            Telefono          = @Telefono,
            Correo            = @Correo,
            Direccion         = @Direccion
        WHERE ClienteId = @ClienteId;

        IF @Correo IS NOT NULL
            UPDATE dbo.Usuario SET Correo = @Correo WHERE ClienteId = @ClienteId;

        COMMIT TRANSACTION;

        SELECT @ClienteId AS ClienteId, 'CLIENTE ACTUALIZADO' AS Resultado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Verificación: debe salir UX_Cliente_Correo con is_unique = 1
SELECT OBJECT_NAME(object_id) AS Tabla, name AS Indice, is_unique, filter_definition
FROM sys.indexes WHERE name IN ('UQ_Usuario_Correo', 'UX_Cliente_Correo');
GO
