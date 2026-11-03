/* ==========================================================
   16_tecnico_cancela_orden.sql
   El TÉCNICO también puede cancelar una orden (estado 7 = CANCELADO),
   para el caso en que el cliente NO autoriza la reparación (Taller).
   Todo lo demás de sp_CambiarEstadoOrden queda igual:
   - solo órdenes abiertas (no ENTREGADO ni CANCELADO)
   - el motivo (observación) es obligatorio al cancelar (50211)
   - el cambio queda en HistorialEstadoOrden
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
                              OR (@EstadoNuevoId = 7             AND r.Nombre IN ('RECEPCION', 'TECNICO'))))   -- script 16: el técnico cancela si el cliente no autoriza
            THROW 50204, 'El usuario no tiene permiso para asignar ese estado.', 1;

        BEGIN TRANSACTION;

        SELECT @EstadoActualId = EstadoOrdenId
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
        WHERE OrdenId = @OrdenId;

        IF @EstadoActualId IS NULL
            THROW 50205, 'La orden no existe.', 1;

        IF @EstadoActualId IN (6, 7)
            THROW 50206, 'La orden ya está cerrada (ENTREGADO o CANCELADO) y no admite cambios.', 1;

        IF @EstadoActualId = @EstadoNuevoId
            THROW 50207, 'La orden ya se encuentra en ese estado.', 1;

        IF NOT (   (@EstadoActualId = 1 AND @EstadoNuevoId IN (2, 7))
                OR (@EstadoActualId = 2 AND @EstadoNuevoId IN (3, 7))
                OR (@EstadoActualId = 3 AND @EstadoNuevoId IN (4, 7))
                OR (@EstadoActualId = 4 AND @EstadoNuevoId IN (5, 7)))
            THROW 50208, 'Cambio de estado no permitido para el estado actual de la orden.', 1;

        IF @EstadoNuevoId IN (3, 4)
           AND NOT EXISTS (SELECT 1 FROM dbo.Diagnostico WHERE OrdenId = @OrdenId)
            THROW 50209, 'La orden todavía no tiene diagnóstico registrado.', 1;

        IF @EstadoNuevoId = 5
           AND NOT EXISTS (SELECT 1
                           FROM dbo.Reparacion rp
                           JOIN dbo.Diagnostico d ON d.DiagnosticoId = rp.DiagnosticoId
                           WHERE d.OrdenId = @OrdenId
                             AND rp.Estado = 'FINALIZADA')
            THROW 50210, 'La reparación no está finalizada. Use el proceso de finalizar reparación.', 1;

        IF @EstadoNuevoId = 7 AND (@Observacion IS NULL OR LTRIM(RTRIM(@Observacion)) = '')
            THROW 50211, 'Indique el motivo de la cancelación en la observación.', 1;

        -- Al cancelar, la reparación en proceso se cierra como CANCELADA
        IF @EstadoNuevoId = 7
            UPDATE rp
            SET rp.Estado   = 'CANCELADA',
                rp.FechaFin = GETDATE()
            FROM dbo.Reparacion rp
            JOIN dbo.Diagnostico d ON d.DiagnosticoId = rp.DiagnosticoId
            WHERE d.OrdenId = @OrdenId
              AND rp.Estado = 'EN_PROCESO';

        UPDATE dbo.OrdenServicio
        SET EstadoOrdenId = @EstadoNuevoId
        WHERE OrdenId = @OrdenId;

        INSERT INTO dbo.HistorialEstadoOrden
            (OrdenId, EstadoAnteriorId, EstadoNuevoId, UsuarioId, Observacion)
        VALUES
            (@OrdenId, @EstadoActualId, @EstadoNuevoId, @UsuarioId, @Observacion);

        COMMIT TRANSACTION;

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

-- Verificación: debe salir sp_CambiarEstadoOrden con la fecha de hoy en modify_date
SELECT name, modify_date FROM sys.procedures WHERE name = 'sp_CambiarEstadoOrden';
GO
