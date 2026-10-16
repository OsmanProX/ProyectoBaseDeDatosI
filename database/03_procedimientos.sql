/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 03: procedimientos para registrar órdenes y cambiar estado
   Se ejecuta después del 01 y 02
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   sp_RegistrarOrden
   Registra una orden nueva en estado RECIBIDO y guarda el
   primer registro del historial. Todo va en una transacción.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarOrden
    @ClienteId           INT,
    @EquipoId            INT,
    @UsuarioRecepcionId  INT,
    @ProblemaReportado   VARCHAR(500),
    @Prioridad           VARCHAR(10)  = 'MEDIA',
    @FechaEstimada       DATE         = NULL,
    @Observaciones       VARCHAR(500) = NULL,
    @OrdenId             INT          = NULL OUTPUT,
    @NumeroOrden         VARCHAR(15)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRecibido INT = 1;

    BEGIN TRY
        -- Validaciones
        IF @ProblemaReportado IS NULL OR LTRIM(RTRIM(@ProblemaReportado)) = ''
            THROW 50101, 'Debe describir el problema reportado por el cliente.', 1;

        IF @Prioridad NOT IN ('BAJA', 'MEDIA', 'ALTA', 'URGENTE')
            THROW 50102, 'Prioridad inválida. Use BAJA, MEDIA, ALTA o URGENTE.', 1;

        IF @FechaEstimada IS NOT NULL AND @FechaEstimada < CAST(GETDATE() AS DATE)
            THROW 50103, 'La fecha estimada no puede ser anterior a hoy.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente
                       WHERE ClienteId = @ClienteId AND Estado = 'ACTIVO')
            THROW 50104, 'El cliente no existe o está inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Equipo
                       WHERE EquipoId = @EquipoId AND Estado = 'ACTIVO')
            THROW 50105, 'El equipo no existe o está inactivo.', 1;

        -- el equipo tiene que ser del cliente
        IF NOT EXISTS (SELECT 1 FROM dbo.Equipo
                       WHERE EquipoId = @EquipoId AND ClienteId = @ClienteId)
            THROW 50106, 'El equipo no pertenece al cliente indicado.', 1;

        -- solo recepción o administrador pueden recibir equipos
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Usuario u
                       JOIN dbo.UsuarioRol ur ON ur.UsuarioId = u.UsuarioId
                       JOIN dbo.Rol r         ON r.RolId      = ur.RolId
                       WHERE u.UsuarioId = @UsuarioRecepcionId
                         AND u.Activo = 1 AND r.Activo = 1
                         AND r.Nombre IN ('RECEPCION', 'ADMINISTRADOR'))
            THROW 50107, 'El usuario no está autorizado para recibir equipos (rol RECEPCION o ADMINISTRADOR).', 1;

        BEGIN TRANSACTION;

        -- no puede haber otra orden abierta del mismo equipo (6 y 7 ya están cerradas)
        IF EXISTS (SELECT 1 FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
                   WHERE EquipoId = @EquipoId AND EstadoOrdenId NOT IN (6, 7))
            THROW 50108, 'El equipo ya tiene una orden abierta. Cierre o cancele esa orden primero.', 1;

        -- Número de orden: OS-AAAA-0001
        DECLARE @Prefijo VARCHAR(8) = 'OS-' + CAST(YEAR(GETDATE()) AS CHAR(4)) + '-';
        DECLARE @Siguiente INT;

        SELECT @Siguiente = ISNULL(MAX(CAST(SUBSTRING(NumeroOrden, 9, 10) AS INT)), 0) + 1
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)   -- para que no se repita el número
        WHERE NumeroOrden LIKE @Prefijo + '%';

        SET @NumeroOrden = @Prefijo + RIGHT('0000' + CAST(@Siguiente AS VARCHAR(10)),
                                            CASE WHEN @Siguiente > 9999 THEN LEN(CAST(@Siguiente AS VARCHAR(10))) ELSE 4 END);

        -- Crear la orden
        INSERT INTO dbo.OrdenServicio
            (NumeroOrden, ClienteId, EquipoId, UsuarioRecepcionId, ProblemaReportado,
             Prioridad, EstadoOrdenId, FechaEstimada, Observaciones)
        VALUES
            (@NumeroOrden, @ClienteId, @EquipoId, @UsuarioRecepcionId, LTRIM(RTRIM(@ProblemaReportado)),
             @Prioridad, @EstadoRecibido, @FechaEstimada, @Observaciones);

        SET @OrdenId = SCOPE_IDENTITY();

        -- Primer registro del historial
        INSERT INTO dbo.HistorialEstadoOrden
            (OrdenId, EstadoAnteriorId, EstadoNuevoId, UsuarioId, Observacion)
        VALUES
            (@OrdenId, NULL, @EstadoRecibido, @UsuarioRecepcionId, 'Orden registrada en recepción');

        COMMIT TRANSACTION;

        -- Lo que devuelve
        SELECT @OrdenId AS OrdenId, @NumeroOrden AS NumeroOrden, 'RECIBIDO' AS Estado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_CambiarEstadoOrden
   Cambia el estado de una orden y guarda el historial.
   Orden: RECIBIDO -> DIAGNOSTICO -> ESPERANDO_AUTORIZACION
          -> REPARACION -> LISTO (se puede cancelar antes de LISTO).
   ENTREGADO no se pone aquí, va en el proceso de entrega
   porque primero hay que revisar los pagos.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_CambiarEstadoOrden
    @OrdenId        INT,
    @EstadoNuevoId  INT,
    @UsuarioId      INT,
    @Observacion    VARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoActualId INT;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.EstadoOrden WHERE EstadoOrdenId = @EstadoNuevoId)
            THROW 50201, 'El estado indicado no existe.', 1;

        IF @EstadoNuevoId = 6
            THROW 50202, 'Para ENTREGAR una orden use el proceso de entrega (valida factura y pagos).', 1;

        IF @EstadoNuevoId = 1
            THROW 50203, 'Una orden no puede regresar al estado RECIBIDO.', 1;

        -- Permisos según el rol
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Usuario u
                       JOIN dbo.UsuarioRol ur ON ur.UsuarioId = u.UsuarioId
                       JOIN dbo.Rol r         ON r.RolId      = ur.RolId
                       WHERE u.UsuarioId = @UsuarioId
                         AND u.Activo = 1 AND r.Activo = 1
                         AND (   r.Nombre = 'ADMINISTRADOR'
                              OR (@EstadoNuevoId IN (2, 3, 4, 5) AND r.Nombre = 'TECNICO')
                              OR (@EstadoNuevoId = 7             AND r.Nombre = 'RECEPCION')))
            THROW 50204, 'El usuario no tiene permiso para asignar ese estado.', 1;

        BEGIN TRANSACTION;

        -- Se bloquea la orden mientras se hace el cambio
        SELECT @EstadoActualId = EstadoOrdenId
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
        WHERE OrdenId = @OrdenId;

        IF @EstadoActualId IS NULL
            THROW 50205, 'La orden no existe.', 1;

        IF @EstadoActualId IN (6, 7)
            THROW 50206, 'La orden ya está cerrada (ENTREGADO o CANCELADO) y no admite cambios.', 1;

        IF @EstadoActualId = @EstadoNuevoId
            THROW 50207, 'La orden ya se encuentra en ese estado.', 1;

        -- Cambios de estado permitidos
        IF NOT (   (@EstadoActualId = 1 AND @EstadoNuevoId IN (2, 7))
                OR (@EstadoActualId = 2 AND @EstadoNuevoId IN (3, 7))
                OR (@EstadoActualId = 3 AND @EstadoNuevoId IN (4, 7))
                OR (@EstadoActualId = 4 AND @EstadoNuevoId IN (5, 7)))
            THROW 50208, 'Cambio de estado no permitido para el estado actual de la orden.', 1;

        -- Validaciones según el nuevo estado
        IF @EstadoNuevoId IN (3, 4)
           AND NOT EXISTS (SELECT 1 FROM dbo.Diagnostico WHERE OrdenId = @OrdenId)
            THROW 50209, 'La orden todavía no tiene diagnóstico registrado.', 1;

        IF @EstadoNuevoId = 5
           AND NOT EXISTS (SELECT 1
                           FROM dbo.Reparacion rp
                           JOIN dbo.Diagnostico d ON d.DiagnosticoId = rp.DiagnosticoId
                           WHERE d.OrdenId = @OrdenId)
            THROW 50210, 'La orden todavía no tiene una reparación registrada.', 1;

        IF @EstadoNuevoId = 7 AND (@Observacion IS NULL OR LTRIM(RTRIM(@Observacion)) = '')
            THROW 50211, 'Indique el motivo de la cancelación en la observación.', 1;

        -- Cambiar el estado y guardar el historial
        UPDATE dbo.OrdenServicio
        SET EstadoOrdenId = @EstadoNuevoId
        WHERE OrdenId = @OrdenId;

        INSERT INTO dbo.HistorialEstadoOrden
            (OrdenId, EstadoAnteriorId, EstadoNuevoId, UsuarioId, Observacion)
        VALUES
            (@OrdenId, @EstadoActualId, @EstadoNuevoId, @UsuarioId, @Observacion);

        COMMIT TRANSACTION;

        -- Lo que devuelve
        SELECT o.OrdenId, o.NumeroOrden,
               ea.Codigo AS EstadoAnterior,
               en.Codigo AS EstadoNuevo
        FROM dbo.OrdenServicio o
        JOIN dbo.EstadoOrden ea ON ea.EstadoOrdenId = @EstadoActualId
        JOIN dbo.EstadoOrden en ON en.EstadoOrdenId = o.EstadoOrdenId
        WHERE o.OrdenId = @OrdenId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_LoginUsuario
   Login por correo + contraseña (método normal).
   Compara el SHA256 de la contraseña con ContrasenaHash.
   Si es exitoso devuelve los datos del usuario, sus roles
   y sus permisos activos (regla: cada usuario solo ve y
   ejecuta las opciones de su rol); si falla devuelve 0 filas.
   ========================================================== */
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
           (SELECT STRING_AGG(r.Nombre, ', ') WITHIN GROUP (ORDER BY r.RolId)
            FROM UsuarioRol ur
            INNER JOIN Rol r ON r.RolId = ur.RolId
            WHERE ur.UsuarioId = u.UsuarioId) AS Roles,
           (SELECT STRING_AGG(x.permiso, ', ') WITHIN GROUP (ORDER BY x.permiso)
            FROM (SELECT DISTINCT p.permiso
                  FROM Permiso p
                  INNER JOIN UsuarioRol ur ON ur.RolId = p.RolId
                  WHERE ur.UsuarioId = u.UsuarioId
                    AND p.activo = 1) x) AS Permisos
    FROM Usuario u
    WHERE u.Correo = @Correo
      AND u.Activo = 1
      AND (u.ContrasenaHash = @Hash OR u.ContrasenaHash = @Contrasena);
END;
GO

-- Verificar que se crearon los 3 procedimientos
SELECT name AS Procedimiento, create_date, modify_date
FROM sys.procedures
WHERE name IN ('sp_RegistrarOrden', 'sp_CambiarEstadoOrden', 'sp_LoginUsuario')
ORDER BY name;
GO
