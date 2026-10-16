/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 06: facturación, pagos y entrega (Semana 4)
     - sp_CambiarEstadoOrden corregido:
         * LISTO solo con la reparación FINALIZADA
         * al CANCELAR, la reparación en proceso queda CANCELADA
     - sp_GenerarFactura
     - sp_RegistrarPago   (no deja pagar más que el saldo, R12)
     - sp_EntregarOrden   (no entrega con saldo pendiente)
   Se ejecuta después del 01, 02, 03 y 04 (el 05 puede ir antes o después)
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   sp_CambiarEstadoOrden (reemplaza la versión del 03)
   Mismos parámetros y mismos códigos de error, con dos cambios:
   - 50210: para LISTO la reparación tiene que estar FINALIZADA
     (antes bastaba con que existiera)
   - Si se cancela una orden en REPARACION, la reparación en
     proceso queda CANCELADA con su fecha de fin
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

/* ==========================================================
   sp_GenerarFactura
   Factura una orden LISTO (máximo una factura por orden, R11).
   Total = mano de obra de la reparación + repuestos con su
   precio de venta HISTÓRICO (R09) + IVA 12 %.
   NIT y nombre: los del cliente, salvo que se manden otros.
   Número: FAC-AAAA-0001
   Errores 50701 - 50706
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_GenerarFactura
    @OrdenId            INT,
    @UsuarioId          INT,
    @NITFacturacion     VARCHAR(15)  = NULL,
    @NombreFacturacion  VARCHAR(150) = NULL,
    @FacturaId          INT          = NULL OUTPUT,
    @NumeroFactura      VARCHAR(20)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoOrdenId INT;
    DECLARE @ReparacionId  INT;
    DECLARE @EstadoRep     VARCHAR(12);
    DECLARE @ManoObra      DECIMAL(10,2);
    DECLARE @Repuestos     DECIMAL(10,2);
    DECLARE @Subtotal      DECIMAL(10,2);
    DECLARE @Impuesto      DECIMAL(10,2);

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'CAJA') = 0
            THROW 50701, 'El usuario no está autorizado para facturar (rol CAJA o ADMINISTRADOR).', 1;

        BEGIN TRANSACTION;

        SELECT @EstadoOrdenId = EstadoOrdenId
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
        WHERE OrdenId = @OrdenId;

        IF @EstadoOrdenId IS NULL
            THROW 50702, 'La orden no existe.', 1;

        IF @EstadoOrdenId <> 5
            THROW 50703, 'Solo se factura una orden en estado LISTO.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Factura WITH (UPDLOCK, HOLDLOCK) WHERE OrdenId = @OrdenId)
            THROW 50704, 'La orden ya tiene factura (máximo una factura por orden).', 1;

        SELECT @ReparacionId = rp.ReparacionId,
               @EstadoRep    = rp.Estado,
               @ManoObra     = rp.CostoManoObra
        FROM dbo.Reparacion rp
        JOIN dbo.Diagnostico d ON d.DiagnosticoId = rp.DiagnosticoId
        WHERE d.OrdenId = @OrdenId;

        IF @ReparacionId IS NULL OR @EstadoRep <> 'FINALIZADA'
            THROW 50705, 'La reparación de la orden no está finalizada.', 1;

        SELECT @Repuestos = ISNULL(SUM(Cantidad * PrecioVentaUnitario), 0)
        FROM dbo.ReparacionRepuesto
        WHERE ReparacionId = @ReparacionId;

        SET @Subtotal = @ManoObra + @Repuestos;
        SET @Impuesto = ROUND(@Subtotal * 0.12, 2);

        -- NIT y nombre del cliente si no se mandan otros
        SELECT @NITFacturacion    = COALESCE(NULLIF(LTRIM(RTRIM(@NITFacturacion)), ''), c.NIT),
               @NombreFacturacion = COALESCE(NULLIF(LTRIM(RTRIM(@NombreFacturacion)), ''), c.NombreRazonSocial)
        FROM dbo.OrdenServicio o
        JOIN dbo.Cliente c ON c.ClienteId = o.ClienteId
        WHERE o.OrdenId = @OrdenId;

        -- NIT: solo números, guion y K (por ejemplo 1234567-8), o CF
        IF UPPER(@NITFacturacion) <> 'CF'
           AND (@NITFacturacion LIKE '%[^0-9Kk-]%' OR LEN(@NITFacturacion) < 2)
            THROW 50706, 'NIT de facturación inválido. Use el formato 1234567-8 o CF.', 1;

        -- Número de factura: FAC-AAAA-0001
        DECLARE @Prefijo VARCHAR(9) = 'FAC-' + CAST(YEAR(GETDATE()) AS CHAR(4)) + '-';
        DECLARE @Siguiente INT;

        SELECT @Siguiente = ISNULL(MAX(CAST(SUBSTRING(NumeroFactura, 10, 10) AS INT)), 0) + 1
        FROM dbo.Factura WITH (UPDLOCK, HOLDLOCK)
        WHERE NumeroFactura LIKE @Prefijo + '%';

        SET @NumeroFactura = @Prefijo + RIGHT('0000' + CAST(@Siguiente AS VARCHAR(10)),
                                              CASE WHEN @Siguiente > 9999 THEN LEN(CAST(@Siguiente AS VARCHAR(10))) ELSE 4 END);

        INSERT INTO dbo.Factura
            (NumeroFactura, OrdenId, NITFacturacion, NombreFacturacion,
             TotalManoObra, TotalRepuestos, Subtotal, Impuesto, Total, Estado, UsuarioId)
        VALUES
            (@NumeroFactura, @OrdenId, UPPER(@NITFacturacion), @NombreFacturacion,
             @ManoObra, @Repuestos, @Subtotal, @Impuesto, @Subtotal + @Impuesto, 'EMITIDA', @UsuarioId);

        SET @FacturaId = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SELECT f.FacturaId, f.NumeroFactura, o.NumeroOrden, f.NITFacturacion, f.NombreFacturacion,
               f.TotalManoObra, f.TotalRepuestos, f.Subtotal, f.Impuesto, f.Total,
               dbo.fn_SaldoFactura(f.FacturaId) AS SaldoPendiente, f.Estado
        FROM dbo.Factura f
        JOIN dbo.OrdenServicio o ON o.OrdenId = f.OrdenId
        WHERE f.FacturaId = @FacturaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_RegistrarPago
   Registra un pago parcial o total. La suma de pagos nunca
   pasa del total de la factura (R12). Cuando el saldo llega
   a 0, la factura queda PAGADA.
   Tarjeta y transferencia piden número de referencia.
   Errores 50711 - 50718
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarPago
    @FacturaId     INT,
    @MetodoPagoId  INT,
    @Monto         DECIMAL(10,2),
    @UsuarioId     INT,
    @Referencia    VARCHAR(50) = NULL,
    @PagoId        INT         = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoFactura VARCHAR(10);
    DECLARE @Metodo        VARCHAR(30);
    DECLARE @SaldoAntes    DECIMAL(10,2);
    DECLARE @SaldoDespues  DECIMAL(10,2);
    DECLARE @Msg           NVARCHAR(2048);

    BEGIN TRY
        IF @Monto IS NULL OR @Monto <= 0
            THROW 50711, 'El monto del pago debe ser mayor que cero.', 1;

        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'CAJA') = 0
            THROW 50712, 'El usuario no está autorizado para registrar pagos (rol CAJA o ADMINISTRADOR).', 1;

        SELECT @Metodo = Nombre
        FROM dbo.MetodoPago
        WHERE MetodoPagoId = @MetodoPagoId AND Activo = 1;

        IF @Metodo IS NULL
            THROW 50713, 'El método de pago no existe o está inactivo.', 1;

        IF @Metodo <> 'EFECTIVO' AND (@Referencia IS NULL OR LTRIM(RTRIM(@Referencia)) = '')
            THROW 50718, 'Para tarjeta o transferencia indique el número de referencia (voucher o boleta).', 1;

        BEGIN TRANSACTION;

        -- Se bloquea la factura para que dos pagos al mismo tiempo no pasen del total
        SELECT @EstadoFactura = Estado
        FROM dbo.Factura WITH (UPDLOCK, HOLDLOCK)
        WHERE FacturaId = @FacturaId;

        IF @EstadoFactura IS NULL
            THROW 50714, 'La factura no existe.', 1;

        IF @EstadoFactura = 'ANULADA'
            THROW 50715, 'La factura está anulada y no recibe pagos.', 1;

        SET @SaldoAntes = dbo.fn_SaldoFactura(@FacturaId);

        IF @SaldoAntes = 0
            THROW 50716, 'La factura ya está pagada por completo.', 1;

        IF @Monto > @SaldoAntes
        BEGIN
            SET @Msg = CONCAT('El pago de Q', @Monto, ' excede el saldo pendiente de Q', @SaldoAntes, '.');
            THROW 50717, @Msg, 1;
        END;

        INSERT INTO dbo.Pago (FacturaId, MetodoPagoId, Monto, Referencia, Estado, UsuarioId)
        VALUES (@FacturaId, @MetodoPagoId, @Monto, NULLIF(LTRIM(RTRIM(@Referencia)), ''), 'APLICADO', @UsuarioId);

        SET @PagoId = SCOPE_IDENTITY();
        SET @SaldoDespues = dbo.fn_SaldoFactura(@FacturaId);

        IF @SaldoDespues = 0
            UPDATE dbo.Factura SET Estado = 'PAGADA' WHERE FacturaId = @FacturaId;

        COMMIT TRANSACTION;

        SELECT @PagoId AS PagoId, f.NumeroFactura, @Metodo AS Metodo, @Monto AS Monto,
               @SaldoAntes AS SaldoAnterior, @SaldoDespues AS SaldoPendiente, f.Estado AS EstadoFactura
        FROM dbo.Factura f
        WHERE f.FacturaId = @FacturaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_EntregarOrden
   Entrega el equipo y cierra la orden (ENTREGADO), solo si:
     - la orden está LISTO
     - tiene factura y la factura no tiene saldo pendiente
   Guarda quién entrega, quién recibe, fecha y observaciones.
   Errores 50721 - 50727
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_EntregarOrden
    @OrdenId        INT,
    @UsuarioId      INT,
    @NombreRecibe   VARCHAR(100),
    @Observaciones  VARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoOrdenId INT;
    DECLARE @FacturaId     INT;
    DECLARE @Saldo         DECIMAL(10,2);
    DECLARE @Msg           NVARCHAR(2048);

    BEGIN TRY
        IF @NombreRecibe IS NULL OR LTRIM(RTRIM(@NombreRecibe)) = ''
            THROW 50721, 'Indique el nombre de la persona que recibe el equipo.', 1;

        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'RECEPCION') = 0
            THROW 50722, 'El usuario no está autorizado para entregar equipos (rol RECEPCION o ADMINISTRADOR).', 1;

        BEGIN TRANSACTION;

        SELECT @EstadoOrdenId = EstadoOrdenId
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
        WHERE OrdenId = @OrdenId;

        IF @EstadoOrdenId IS NULL
            THROW 50723, 'La orden no existe.', 1;

        IF @EstadoOrdenId <> 5
            THROW 50724, 'Solo se entrega una orden en estado LISTO.', 1;

        SELECT @FacturaId = FacturaId
        FROM dbo.Factura
        WHERE OrdenId = @OrdenId AND Estado <> 'ANULADA';

        IF @FacturaId IS NULL
            THROW 50725, 'La orden no tiene factura. Primero facture la orden.', 1;

        SET @Saldo = dbo.fn_SaldoFactura(@FacturaId);

        IF @Saldo > 0
        BEGIN
            SET @Msg = CONCAT('La factura tiene saldo pendiente de Q', @Saldo, '. No se puede entregar el equipo.');
            THROW 50726, @Msg, 1;
        END;

        IF EXISTS (SELECT 1 FROM dbo.Entrega WHERE OrdenId = @OrdenId)
            THROW 50727, 'La orden ya tiene una entrega registrada.', 1;

        INSERT INTO dbo.Entrega (OrdenId, UsuarioEntregaId, NombreRecibe, Observaciones)
        VALUES (@OrdenId, @UsuarioId, LTRIM(RTRIM(@NombreRecibe)), @Observaciones);

        UPDATE dbo.OrdenServicio
        SET EstadoOrdenId = 6
        WHERE OrdenId = @OrdenId;

        INSERT INTO dbo.HistorialEstadoOrden (OrdenId, EstadoAnteriorId, EstadoNuevoId, UsuarioId, Observacion)
        VALUES (@OrdenId, 5, 6, @UsuarioId, 'Equipo entregado al cliente');

        COMMIT TRANSACTION;

        SELECT o.OrdenId, o.NumeroOrden, 'ENTREGADO' AS Estado,
               en.NombreRecibe, en.FechaEntrega, u.NombreCompleto AS EntregadoPor
        FROM dbo.OrdenServicio o
        JOIN dbo.Entrega en ON en.OrdenId   = o.OrdenId
        JOIN dbo.Usuario u  ON u.UsuarioId  = en.UsuarioEntregaId
        WHERE o.OrdenId = @OrdenId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- Verificar: 4 procedimientos de este script (13 en total)
SELECT name AS Procedimiento, modify_date
FROM sys.procedures
WHERE name IN ('sp_CambiarEstadoOrden', 'sp_GenerarFactura', 'sp_RegistrarPago', 'sp_EntregarOrden')
ORDER BY name;

SELECT COUNT(*) AS TotalProcedimientos FROM sys.procedures WHERE schema_id = SCHEMA_ID('dbo');
GO
