/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 18: Taller — quitar una actividad o un repuesto (revirtiendo) y R14 completa

   1. sp_QuitarRepuesto: devuelve a la bodega un repuesto asignado por error.
      No se pierde el rastro: el stock vuelve con un movimiento de ENTRADA
      (tipo ENTRADA, ReparacionId = la reparación, con el motivo).
   2. sp_QuitarActividad: quita una actividad registrada por error.
   Las dos solo funcionan mientras la reparación está EN_PROCESO
   (antes de finalizar y facturar) y solo para TECNICO o ADMINISTRADOR.

   3. R14 (la información transaccional no se borra): triggers que impiden
      DELETE en ReparacionRepuesto, ActividadReparacion, DetalleCompra,
      Entrega, Diagnostico y Reparacion. Los dos procedimientos de arriba son
      la única vía permitida para quitar una línea: avisan al trigger con
      SESSION_CONTEXT('TechCare.Quitar') = 1 durante su transacción.

   No crea tablas ni columnas: el diagrama ER no cambia.
   Requiere los scripts 01 a 17. Se puede ejecutar más de una vez.
   ========================================================== */

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ----------------------------------------------------------
   1. Quitar repuesto (devolución a la bodega)
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_QuitarRepuesto
    @ReparacionId  INT,
    @RepuestoId    INT,
    @BodegaId      INT,
    @Cantidad      INT,
    @UsuarioId     INT,
    @Motivo        VARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRep      VARCHAR(12);
    DECLARE @EstadoOrdenId  INT;
    DECLARE @NumeroOrden    VARCHAR(15);
    DECLARE @Asignada       INT;
    DECLARE @Existencia     INT;
    DECLARE @Resultante     INT;
    DECLARE @Msg            NVARCHAR(2048);

    BEGIN TRY
        IF @Cantidad IS NULL OR @Cantidad <= 0
            THROW 50511, 'La cantidad a quitar debe ser mayor que cero.', 1;

        IF @Motivo IS NULL OR LEN(LTRIM(RTRIM(@Motivo))) < 5
            THROW 50512, 'Escriba el motivo de la devolución (mínimo 5 caracteres).', 1;

        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'TECNICO') = 0
            THROW 50513, 'El usuario no está autorizado para quitar repuestos (rol TECNICO o ADMINISTRADOR).', 1;

        BEGIN TRANSACTION;

        SELECT @EstadoRep     = rp.Estado,
               @EstadoOrdenId = o.EstadoOrdenId,
               @NumeroOrden   = o.NumeroOrden
        FROM dbo.Reparacion rp WITH (UPDLOCK, HOLDLOCK)
        JOIN dbo.Diagnostico d   ON d.DiagnosticoId = rp.DiagnosticoId
        JOIN dbo.OrdenServicio o ON o.OrdenId       = d.OrdenId
        WHERE rp.ReparacionId = @ReparacionId;

        IF @EstadoRep IS NULL
            THROW 50514, 'La reparación no existe.', 1;

        IF @EstadoRep <> 'EN_PROCESO' OR @EstadoOrdenId <> 4
            THROW 50515, 'Solo se quitan repuestos mientras la reparación está EN_PROCESO.', 1;

        SELECT @Asignada = Cantidad
        FROM dbo.ReparacionRepuesto WITH (UPDLOCK, HOLDLOCK)
        WHERE ReparacionId = @ReparacionId AND RepuestoId = @RepuestoId AND BodegaId = @BodegaId;

        IF @Asignada IS NULL
            THROW 50516, 'Ese repuesto no está asignado a esta reparación desde esa bodega.', 1;

        IF @Cantidad > @Asignada
        BEGIN
            SET @Msg = CONCAT('Solo hay ', @Asignada, ' unidad(es) asignada(s); no se pueden quitar ', @Cantidad, '.');
            THROW 50517, @Msg, 1;
        END;

        SELECT @Existencia = Existencia
        FROM dbo.Inventario WITH (UPDLOCK, HOLDLOCK)
        WHERE RepuestoId = @RepuestoId AND BodegaId = @BodegaId;

        SET @Resultante = @Existencia + @Cantidad;

        -- 1. Devolver al inventario
        UPDATE dbo.Inventario
        SET Existencia         = @Resultante,
            FechaActualizacion = GETDATE()
        WHERE RepuestoId = @RepuestoId AND BodegaId = @BodegaId;

        -- 2. Quitar del detalle: baja la cantidad, o se quita la línea si se devuelve todo
        IF @Cantidad < @Asignada
            UPDATE dbo.ReparacionRepuesto
            SET Cantidad = Cantidad - @Cantidad
            WHERE ReparacionId = @ReparacionId AND RepuestoId = @RepuestoId AND BodegaId = @BodegaId;
        ELSE
        BEGIN
            EXEC sys.sp_set_session_context @key = N'TechCare.Quitar', @value = 1;
            DELETE FROM dbo.ReparacionRepuesto
            WHERE ReparacionId = @ReparacionId AND RepuestoId = @RepuestoId AND BodegaId = @BodegaId;
            EXEC sys.sp_set_session_context @key = N'TechCare.Quitar', @value = NULL;
        END;

        -- 3. Rastro: movimiento de ENTRADA ligado a la reparación, con el motivo
        INSERT INTO dbo.MovimientoInventario
            (RepuestoId, BodegaId, TipoMovimiento, Cantidad, ExistenciaResultante,
             CompraId, ReparacionId, UsuarioId, Observacion)
        VALUES
            (@RepuestoId, @BodegaId, 'ENTRADA', @Cantidad, @Resultante,
             NULL, @ReparacionId, @UsuarioId,
             LEFT('Devolución orden ' + @NumeroOrden + ': ' + LTRIM(RTRIM(@Motivo)), 200));

        COMMIT TRANSACTION;

        SELECT @ReparacionId AS ReparacionId, @RepuestoId AS RepuestoId, @BodegaId AS BodegaId,
               @Cantidad AS CantidadDevuelta, @Asignada - @Cantidad AS CantidadQueda,
               @Resultante AS ExistenciaResultante;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'TechCare.Quitar', @value = NULL;
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   2. Quitar actividad
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_QuitarActividad
    @ReparacionId     INT,
    @NumeroActividad  INT,
    @UsuarioId        INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRep VARCHAR(12);

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'TECNICO') = 0
            THROW 50416, 'El usuario no está autorizado para quitar actividades (rol TECNICO o ADMINISTRADOR).', 1;

        BEGIN TRANSACTION;

        SELECT @EstadoRep = Estado
        FROM dbo.Reparacion WITH (UPDLOCK, HOLDLOCK)
        WHERE ReparacionId = @ReparacionId;

        IF @EstadoRep IS NULL
            THROW 50417, 'La reparación no existe.', 1;

        IF @EstadoRep <> 'EN_PROCESO'
            THROW 50418, 'Solo se quitan actividades mientras la reparación está EN_PROCESO.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.ActividadReparacion
                       WHERE ReparacionId = @ReparacionId AND NumeroActividad = @NumeroActividad)
            THROW 50419, 'La actividad no existe en esta reparación.', 1;

        EXEC sys.sp_set_session_context @key = N'TechCare.Quitar', @value = 1;
        DELETE FROM dbo.ActividadReparacion
        WHERE ReparacionId = @ReparacionId AND NumeroActividad = @NumeroActividad;
        EXEC sys.sp_set_session_context @key = N'TechCare.Quitar', @value = NULL;

        COMMIT TRANSACTION;

        SELECT @ReparacionId AS ReparacionId, @NumeroActividad AS NumeroActividad;
    END TRY
    BEGIN CATCH
        EXEC sys.sp_set_session_context @key = N'TechCare.Quitar', @value = NULL;
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   3. R14: no se borra información transaccional
   ---------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_ReparacionRepuesto_NoEliminar
ON dbo.ReparacionRepuesto
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
       AND ISNULL(CAST(SESSION_CONTEXT(N'TechCare.Quitar') AS INT), 0) <> 1
        THROW 50810, 'No se pueden eliminar repuestos de una reparación. Use "Quitar" en Taller, que devuelve el stock a la bodega.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_ActividadReparacion_NoEliminar
ON dbo.ActividadReparacion
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
       AND ISNULL(CAST(SESSION_CONTEXT(N'TechCare.Quitar') AS INT), 0) <> 1
        THROW 50811, 'No se pueden eliminar actividades. Use "Quitar" en Taller mientras la reparación está en proceso.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_DetalleCompra_NoEliminar
ON dbo.DetalleCompra
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50812, 'No se puede eliminar el detalle de una compra. Anule la compra.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Entrega_NoEliminar
ON dbo.Entrega
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50813, 'No se puede eliminar una entrega registrada.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Diagnostico_NoEliminar
ON dbo.Diagnostico
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50814, 'No se puede eliminar un diagnóstico.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Reparacion_NoEliminar
ON dbo.Reparacion
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50815, 'No se puede eliminar una reparación. Cancele la orden con su motivo.', 1;
END;
GO

-- Verificación
SELECT name AS Objeto, type_desc AS Tipo
FROM sys.objects
WHERE name IN ('sp_QuitarRepuesto', 'sp_QuitarActividad',
               'trg_ReparacionRepuesto_NoEliminar', 'trg_ActividadReparacion_NoEliminar',
               'trg_DetalleCompra_NoEliminar', 'trg_Entrega_NoEliminar',
               'trg_Diagnostico_NoEliminar', 'trg_Reparacion_NoEliminar')
ORDER BY type_desc, name;
GO
