/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 07: triggers, índices y reportes finales (Semana 4)
     - Triggers: auditoría de precios y protección contra
       borrado de información transaccional (R14)
     - Índices no agrupados para las búsquedas y reportes
     - Reportes 2, 10, 11 y 12 (trazabilidad completa)
     - Dashboard y actividad reciente (sección 6.3)
     - Verificación de los mínimos de la sección 4
   Se ejecuta después del 01 al 06
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   ====================== TRIGGERS ==========================
   ========================================================== */

/* ----------------------------------------------------------
   trg_Repuesto_AuditoriaPrecio
   Cada cambio de precio de compra o de venta del catálogo
   queda guardado en AuditoriaPrecio (precio anterior, nuevo,
   fecha y usuario de la base). Los precios de las compras y
   reparaciones anteriores no cambian (R09).
   ---------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_Repuesto_AuditoriaPrecio
ON dbo.Repuesto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(PrecioCompraReferencia) AND NOT UPDATE(PrecioVenta)
        RETURN;

    INSERT INTO dbo.AuditoriaPrecio
        (RepuestoId, PrecioCompraAnterior, PrecioCompraNuevo, PrecioVentaAnterior, PrecioVentaNuevo)
    SELECT i.RepuestoId,
           d.PrecioCompraReferencia, i.PrecioCompraReferencia,
           d.PrecioVenta,            i.PrecioVenta
    FROM inserted i
    JOIN deleted d ON d.RepuestoId = i.RepuestoId
    WHERE i.PrecioCompraReferencia <> d.PrecioCompraReferencia
       OR i.PrecioVenta            <> d.PrecioVenta;
END;
GO

/* ----------------------------------------------------------
   Triggers de protección (R14): la información transaccional
   no se borra para "corregir" errores; se usa estado,
   cancelación o anulación. Si alguien intenta un DELETE
   (aunque sea directo en SQL Server), se revierte.
   ---------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_OrdenServicio_NoEliminar
ON dbo.OrdenServicio
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50801, 'No se pueden eliminar órdenes de servicio. Cancele la orden con su motivo.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_HistorialEstadoOrden_NoEliminar
ON dbo.HistorialEstadoOrden
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50802, 'No se puede eliminar el historial de estados de una orden.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_MovimientoInventario_NoEliminar
ON dbo.MovimientoInventario
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50803, 'No se pueden eliminar movimientos de inventario.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Compra_NoEliminar
ON dbo.Compra
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50804, 'No se pueden eliminar compras. Anule la compra si todavía está pendiente.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Factura_NoEliminar
ON dbo.Factura
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50805, 'No se pueden eliminar facturas. Use el estado ANULADA.', 1;
END;
GO

CREATE OR ALTER TRIGGER dbo.trg_Pago_NoEliminar
ON dbo.Pago
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted)
        THROW 50806, 'No se pueden eliminar pagos. Use el estado ANULADO.', 1;
END;
GO

/* ==========================================================
   ================= ÍNDICES NO AGRUPADOS ===================
   Las PK, UNIQUE y el NIT ya tienen su propio índice.
   Estos son para las búsquedas y reportes más usados.
   ========================================================== */

-- Reporte 1 y dashboard: órdenes por estado y prioridad
DROP INDEX IF EXISTS IX_OrdenServicio_Estado_Prioridad ON dbo.OrdenServicio;
CREATE NONCLUSTERED INDEX IX_OrdenServicio_Estado_Prioridad
    ON dbo.OrdenServicio (EstadoOrdenId, Prioridad)
    INCLUDE (FechaIngreso, ClienteId, EquipoId);

-- Reporte 3 y validación de orden abierta: órdenes de un equipo
DROP INDEX IF EXISTS IX_OrdenServicio_Equipo_Fecha ON dbo.OrdenServicio;
CREATE NONCLUSTERED INDEX IX_OrdenServicio_Equipo_Fecha
    ON dbo.OrdenServicio (EquipoId, FechaIngreso);

-- Reporte 2: órdenes de un cliente
DROP INDEX IF EXISTS IX_OrdenServicio_Cliente_Fecha ON dbo.OrdenServicio;
CREATE NONCLUSTERED INDEX IX_OrdenServicio_Cliente_Fecha
    ON dbo.OrdenServicio (ClienteId, FechaIngreso);

-- Historial de estados de una orden (detalle y trazabilidad)
DROP INDEX IF EXISTS IX_HistorialEstadoOrden_Orden_Fecha ON dbo.HistorialEstadoOrden;
CREATE NONCLUSTERED INDEX IX_HistorialEstadoOrden_Orden_Fecha
    ON dbo.HistorialEstadoOrden (OrdenId, FechaCambio);

-- Reporte 4: diagnósticos por técnico y fecha
DROP INDEX IF EXISTS IX_Diagnostico_Tecnico_Fecha ON dbo.Diagnostico;
CREATE NONCLUSTERED INDEX IX_Diagnostico_Tecnico_Fecha
    ON dbo.Diagnostico (TecnicoId, FechaDiagnostico);

-- Reporte 4: reparaciones por técnico y fecha
DROP INDEX IF EXISTS IX_Reparacion_Tecnico_Fecha ON dbo.Reparacion;
CREATE NONCLUSTERED INDEX IX_Reparacion_Tecnico_Fecha
    ON dbo.Reparacion (TecnicoId, FechaInicio);

-- Reporte 9: movimientos por rango de fechas
DROP INDEX IF EXISTS IX_MovimientoInventario_Fecha ON dbo.MovimientoInventario;
CREATE NONCLUSTERED INDEX IX_MovimientoInventario_Fecha
    ON dbo.MovimientoInventario (FechaMovimiento)
    INCLUDE (TipoMovimiento, RepuestoId, BodegaId, Cantidad);

-- Kardex de un repuesto en una bodega (y la FK compuesta al inventario)
DROP INDEX IF EXISTS IX_MovimientoInventario_Repuesto_Bodega ON dbo.MovimientoInventario;
CREATE NONCLUSTERED INDEX IX_MovimientoInventario_Repuesto_Bodega
    ON dbo.MovimientoInventario (RepuestoId, BodegaId, FechaMovimiento);

-- Reporte 8: compras por proveedor y fecha
DROP INDEX IF EXISTS IX_Compra_Proveedor_Fecha ON dbo.Compra;
CREATE NONCLUSTERED INDEX IX_Compra_Proveedor_Fecha
    ON dbo.Compra (ProveedorId, FechaCompra)
    INCLUDE (Estado);

-- Reporte 11: facturas por período
DROP INDEX IF EXISTS IX_Factura_FechaEmision ON dbo.Factura;
CREATE NONCLUSTERED INDEX IX_Factura_FechaEmision
    ON dbo.Factura (FechaEmision)
    INCLUDE (Estado, TotalManoObra, TotalRepuestos, Subtotal, Impuesto, Total);

-- fn_SaldoFactura y reporte 10: pagos de una factura
DROP INDEX IF EXISTS IX_Pago_Factura ON dbo.Pago;
CREATE NONCLUSTERED INDEX IX_Pago_Factura
    ON dbo.Pago (FacturaId, Estado)
    INCLUDE (Monto);

-- Pantalla de órdenes: equipos de un cliente
DROP INDEX IF EXISTS IX_Equipo_Cliente ON dbo.Equipo;
CREATE NONCLUSTERED INDEX IX_Equipo_Cliente
    ON dbo.Equipo (ClienteId);

-- Pantalla de clientes: búsqueda por nombre
DROP INDEX IF EXISTS IX_Cliente_Nombre ON dbo.Cliente;
CREATE NONCLUSTERED INDEX IX_Cliente_Nombre
    ON dbo.Cliente (NombreRazonSocial);
GO

/* ==========================================================
   =================== REPORTES FINALES =====================
   ========================================================== */

/* ----------------------------------------------------------
   Reporte 2: historial completo de órdenes de un cliente
   LEFT JOIN: el cliente aparece aunque no tenga órdenes, y la
   orden aunque no tenga factura ni entrega.
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_HistorialCliente
AS
SELECT c.ClienteId,
       c.NombreRazonSocial                AS Cliente,
       c.TipoCliente,
       c.NIT,
       o.OrdenId,
       o.NumeroOrden,
       o.FechaIngreso,
       eo.Codigo                          AS Estado,
       te.Nombre                          AS TipoEquipo,
       e.Marca + ' ' + e.Modelo           AS Equipo,
       e.NumeroSerie,
       o.ProblemaReportado,
       f.NumeroFactura,
       f.Total                            AS TotalFacturado,
       dbo.fn_SaldoFactura(f.FacturaId)   AS SaldoPendiente,
       en.FechaEntrega
FROM dbo.Cliente c
LEFT JOIN dbo.OrdenServicio o ON o.ClienteId      = c.ClienteId
LEFT JOIN dbo.EstadoOrden eo  ON eo.EstadoOrdenId = o.EstadoOrdenId
LEFT JOIN dbo.Equipo e        ON e.EquipoId       = o.EquipoId
LEFT JOIN dbo.TipoEquipo te   ON te.TipoEquipoId  = e.TipoEquipoId
LEFT JOIN dbo.Factura f       ON f.OrdenId        = o.OrdenId
LEFT JOIN dbo.Entrega en      ON en.OrdenId       = o.OrdenId;
GO

/* ----------------------------------------------------------
   Reporte 10: facturas con saldo pendiente y sus pagos
   LEFT JOIN: una factura sin pagos también tiene saldo y
   debe aparecer (con los datos del pago en NULL).
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_FacturasSaldoPendiente
AS
SELECT f.FacturaId,
       f.NumeroFactura,
       f.FechaEmision,
       o.NumeroOrden,
       c.NombreRazonSocial                                    AS Cliente,
       f.Total,
       ISNULL(SUM(p.Monto) OVER (PARTITION BY f.FacturaId), 0) AS TotalPagado,
       dbo.fn_SaldoFactura(f.FacturaId)                       AS SaldoPendiente,
       p.PagoId,
       p.FechaPago,
       mp.Nombre                                              AS MetodoPago,
       p.Monto                                                AS MontoPago,
       p.Referencia,
       uc.NombreCompleto                                      AS CobradoPor
FROM dbo.Factura f
JOIN dbo.OrdenServicio o     ON o.OrdenId       = f.OrdenId
JOIN dbo.Cliente c           ON c.ClienteId     = o.ClienteId
LEFT JOIN dbo.Pago p         ON p.FacturaId     = f.FacturaId AND p.Estado = 'APLICADO'
LEFT JOIN dbo.MetodoPago mp  ON mp.MetodoPagoId = p.MetodoPagoId
LEFT JOIN dbo.Usuario uc     ON uc.UsuarioId    = p.UsuarioId
WHERE f.Estado <> 'ANULADA'
  AND dbo.fn_SaldoFactura(f.FacturaId) > 0;
GO

/* ----------------------------------------------------------
   Reporte 11: ingresos facturados por mes, separando mano de
   obra y repuestos. Los pagos se suman antes del JOIN para
   no duplicar facturas.
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_IngresosPeriodo
AS
SELECT YEAR(f.FechaEmision)                 AS Anio,
       MONTH(f.FechaEmision)                AS Mes,
       COUNT(*)                             AS Facturas,
       SUM(f.TotalManoObra)                 AS ManoObra,
       SUM(f.TotalRepuestos)                AS Repuestos,
       SUM(f.Subtotal)                      AS Subtotal,
       SUM(f.Impuesto)                      AS IVA,
       SUM(f.Total)                         AS TotalFacturado,
       SUM(ISNULL(pg.Pagado, 0))            AS Cobrado,
       SUM(f.Total - ISNULL(pg.Pagado, 0))  AS PorCobrar
FROM dbo.Factura f
LEFT JOIN (SELECT FacturaId, SUM(Monto) AS Pagado
           FROM dbo.Pago
           WHERE Estado = 'APLICADO'
           GROUP BY FacturaId) AS pg ON pg.FacturaId = f.FacturaId
WHERE f.Estado <> 'ANULADA'
GROUP BY YEAR(f.FechaEmision), MONTH(f.FechaEmision);
GO

/* ----------------------------------------------------------
   fn_ReporteIngresos (función de tabla)
   El mismo reporte 11 pero para un rango de fechas cualquiera.
   Uso: SELECT * FROM dbo.fn_ReporteIngresos('2026-08-01', '2026-09-30')
   ---------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_ReporteIngresos (@Desde DATE, @Hasta DATE)
RETURNS TABLE
AS
RETURN
    SELECT YEAR(f.FechaEmision)                 AS Anio,
           MONTH(f.FechaEmision)                AS Mes,
           COUNT(*)                             AS Facturas,
           SUM(f.TotalManoObra)                 AS ManoObra,
           SUM(f.TotalRepuestos)                AS Repuestos,
           SUM(f.Subtotal)                      AS Subtotal,
           SUM(f.Impuesto)                      AS IVA,
           SUM(f.Total)                         AS TotalFacturado,
           SUM(ISNULL(pg.Pagado, 0))            AS Cobrado
    FROM dbo.Factura f
    LEFT JOIN (SELECT FacturaId, SUM(Monto) AS Pagado
               FROM dbo.Pago
               WHERE Estado = 'APLICADO'
               GROUP BY FacturaId) AS pg ON pg.FacturaId = f.FacturaId
    WHERE f.Estado <> 'ANULADA'
      AND f.FechaEmision >= @Desde
      AND f.FechaEmision <  DATEADD(DAY, 1, @Hasta)
    GROUP BY YEAR(f.FechaEmision), MONTH(f.FechaEmision);
GO

/* ----------------------------------------------------------
   Reporte 12: trazabilidad completa de una orden (resumen)
   Cliente, equipo, recepción, diagnóstico, técnico, reparación,
   repuestos, movimientos, factura, pagos y entrega.
   - LEFT JOIN en todo lo opcional: una orden sin diagnóstico,
     sin factura o sin pagos NO desaparece.
   - Repuestos, movimientos y pagos se resumen antes del JOIN,
     así cada orden sale una sola vez sin usar DISTINCT.
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_TrazabilidadOrden
AS
SELECT o.OrdenId,
       o.NumeroOrden,
       o.FechaIngreso,
       eo.Codigo                                 AS EstadoActual,
       o.Prioridad,
       c.NombreRazonSocial                       AS Cliente,
       c.NIT,
       te.Nombre                                 AS TipoEquipo,
       e.Marca + ' ' + e.Modelo                  AS Equipo,
       e.NumeroSerie,
       urec.NombreCompleto                       AS RecibidoPor,
       o.ProblemaReportado,
       d.FechaDiagnostico,
       utd.NombreCompleto                        AS TecnicoDiagnostico,
       d.Descripcion                             AS Diagnostico,
       d.CostoManoObraEstimado,
       rp.FechaInicio                            AS InicioReparacion,
       rp.FechaFin                               AS FinReparacion,
       rp.Estado                                 AS EstadoReparacion,
       utr.NombreCompleto                        AS TecnicoReparacion,
       rp.CostoManoObra,
       ISNULL(rr.Lineas, 0)                      AS RepuestosUsados,
       ISNULL(rr.Unidades, 0)                    AS UnidadesRepuesto,
       ISNULL(rr.Venta, 0)                       AS VentaRepuestos,
       ISNULL(mv.Salidas, 0)                     AS MovimientosSalida,
       f.NumeroFactura,
       f.FechaEmision,
       f.Total                                   AS TotalFactura,
       ISNULL(pg.Pagos, 0)                       AS Pagos,
       ISNULL(pg.Pagado, 0)                      AS TotalPagado,
       f.Total - ISNULL(pg.Pagado, 0)            AS SaldoPendiente,
       en.FechaEntrega,
       en.NombreRecibe,
       uen.NombreCompleto                        AS EntregadoPor
FROM dbo.OrdenServicio o
JOIN dbo.EstadoOrden eo        ON eo.EstadoOrdenId = o.EstadoOrdenId
JOIN dbo.Cliente c             ON c.ClienteId      = o.ClienteId
JOIN dbo.Equipo e              ON e.EquipoId       = o.EquipoId
JOIN dbo.TipoEquipo te         ON te.TipoEquipoId  = e.TipoEquipoId
JOIN dbo.Usuario urec          ON urec.UsuarioId   = o.UsuarioRecepcionId
LEFT JOIN dbo.Diagnostico d    ON d.OrdenId        = o.OrdenId
LEFT JOIN dbo.Usuario utd      ON utd.UsuarioId    = d.TecnicoId
LEFT JOIN dbo.Reparacion rp    ON rp.DiagnosticoId = d.DiagnosticoId
LEFT JOIN dbo.Usuario utr      ON utr.UsuarioId    = rp.TecnicoId
LEFT JOIN (SELECT ReparacionId, COUNT(*) AS Lineas, SUM(Cantidad) AS Unidades,
                  SUM(Cantidad * PrecioVentaUnitario) AS Venta
           FROM dbo.ReparacionRepuesto
           GROUP BY ReparacionId) AS rr ON rr.ReparacionId = rp.ReparacionId
LEFT JOIN (SELECT ReparacionId, COUNT(*) AS Salidas
           FROM dbo.MovimientoInventario
           WHERE TipoMovimiento = 'SALIDA'
           GROUP BY ReparacionId) AS mv ON mv.ReparacionId = rp.ReparacionId
LEFT JOIN dbo.Factura f        ON f.OrdenId        = o.OrdenId
LEFT JOIN (SELECT FacturaId, COUNT(*) AS Pagos, SUM(Monto) AS Pagado
           FROM dbo.Pago
           WHERE Estado = 'APLICADO'
           GROUP BY FacturaId) AS pg ON pg.FacturaId = f.FacturaId
LEFT JOIN dbo.Entrega en       ON en.OrdenId       = o.OrdenId
LEFT JOIN dbo.Usuario uen      ON uen.UsuarioId    = en.UsuarioEntregaId;
GO

/* ----------------------------------------------------------
   sp_TrazabilidadOrden
   Devuelve la trazabilidad de una orden en dos partes:
     1. el resumen (vw_TrazabilidadOrden)
     2. la línea de tiempo: cada cambio de estado, diagnóstico,
        reparación, actividad, repuesto con su movimiento,
        factura, pago y entrega, en orden de fecha
   Error 50901
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_TrazabilidadOrden
    @NumeroOrden VARCHAR(15)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OrdenId INT = (SELECT OrdenId FROM dbo.OrdenServicio WHERE NumeroOrden = @NumeroOrden);

    IF @OrdenId IS NULL
        THROW 50901, 'La orden no existe.', 1;

    -- 1. Resumen
    SELECT NumeroOrden, FechaIngreso, EstadoActual, Prioridad, Cliente, NIT, TipoEquipo, Equipo, NumeroSerie,
           RecibidoPor, ProblemaReportado, TecnicoDiagnostico, Diagnostico, TecnicoReparacion, EstadoReparacion,
           CostoManoObra, RepuestosUsados, VentaRepuestos, MovimientosSalida,
           NumeroFactura, TotalFactura, Pagos, TotalPagado, SaldoPendiente,
           FechaEntrega, NombreRecibe, EntregadoPor
    FROM dbo.vw_TrazabilidadOrden
    WHERE OrdenId = @OrdenId;

    -- 2. Línea de tiempo
    SELECT t.Fecha, t.Etapa, t.Detalle, t.Usuario, t.Monto
    FROM (
        -- Cambios de estado (LEFT JOIN: el primero no tiene estado anterior)
        SELECT h.FechaCambio AS Fecha, CAST('ESTADO' AS VARCHAR(20)) AS Etapa,
               CAST(CONCAT(ISNULL(ea.Codigo, '(inicio)'), ' -> ', en.Codigo,
                           CASE WHEN h.Observacion IS NULL THEN '' ELSE ': ' + h.Observacion END) AS VARCHAR(500)) AS Detalle,
               u.NombreCompleto AS Usuario, CAST(NULL AS DECIMAL(10,2)) AS Monto
        FROM dbo.HistorialEstadoOrden h
        LEFT JOIN dbo.EstadoOrden ea ON ea.EstadoOrdenId = h.EstadoAnteriorId
        JOIN dbo.EstadoOrden en      ON en.EstadoOrdenId = h.EstadoNuevoId
        JOIN dbo.Usuario u           ON u.UsuarioId      = h.UsuarioId
        WHERE h.OrdenId = @OrdenId

        UNION ALL
        -- Diagnóstico
        SELECT d.FechaDiagnostico, 'DIAGNOSTICO', CAST(d.Descripcion AS VARCHAR(500)),
               u.NombreCompleto, d.CostoManoObraEstimado
        FROM dbo.Diagnostico d
        JOIN dbo.Usuario u ON u.UsuarioId = d.TecnicoId
        WHERE d.OrdenId = @OrdenId

        UNION ALL
        -- Inicio de la reparación
        SELECT rp.FechaInicio, 'REPARACION', CAST('Inicio de la reparación' AS VARCHAR(500)),
               u.NombreCompleto, NULL
        FROM dbo.Reparacion rp
        JOIN dbo.Diagnostico d ON d.DiagnosticoId = rp.DiagnosticoId
        JOIN dbo.Usuario u     ON u.UsuarioId     = rp.TecnicoId
        WHERE d.OrdenId = @OrdenId

        UNION ALL
        -- Actividades
        SELECT a.FechaRegistro, 'ACTIVIDAD',
               CAST(CONCAT(a.NumeroActividad, '. ', a.Descripcion,
                           CASE WHEN a.HorasTrabajadas IS NULL THEN ''
                                ELSE CONCAT(' (', a.HorasTrabajadas, ' h)') END) AS VARCHAR(500)),
               u.NombreCompleto, NULL
        FROM dbo.ActividadReparacion a
        JOIN dbo.Reparacion rp ON rp.ReparacionId  = a.ReparacionId
        JOIN dbo.Diagnostico d ON d.DiagnosticoId  = rp.DiagnosticoId
        JOIN dbo.Usuario u     ON u.UsuarioId      = rp.TecnicoId
        WHERE d.OrdenId = @OrdenId

        UNION ALL
        -- Repuestos usados con su movimiento de salida
        SELECT m.FechaMovimiento, 'REPUESTO',
               CAST(CONCAT(r.Codigo, ' ', r.Nombre, ' x', m.Cantidad, ' desde ', b.Nombre,
                           ' (existencia que quedó: ', m.ExistenciaResultante, ')') AS VARCHAR(500)),
               u.NombreCompleto, m.Cantidad * rr.PrecioVentaUnitario
        FROM dbo.MovimientoInventario m
        JOIN dbo.ReparacionRepuesto rr ON rr.ReparacionId = m.ReparacionId
                                      AND rr.RepuestoId   = m.RepuestoId
                                      AND rr.BodegaId     = m.BodegaId
        JOIN dbo.Reparacion rp         ON rp.ReparacionId = m.ReparacionId
        JOIN dbo.Diagnostico d         ON d.DiagnosticoId = rp.DiagnosticoId
        JOIN dbo.Repuesto r            ON r.RepuestoId    = m.RepuestoId
        JOIN dbo.Bodega b              ON b.BodegaId      = m.BodegaId
        JOIN dbo.Usuario u             ON u.UsuarioId     = m.UsuarioId
        WHERE d.OrdenId = @OrdenId

        UNION ALL
        -- Fin de la reparación
        SELECT rp.FechaFin, 'REPARACION',
               CAST(CONCAT('Fin (', rp.Estado, '): ', rp.DescripcionTrabajo) AS VARCHAR(500)),
               u.NombreCompleto, rp.CostoManoObra
        FROM dbo.Reparacion rp
        JOIN dbo.Diagnostico d ON d.DiagnosticoId = rp.DiagnosticoId
        JOIN dbo.Usuario u     ON u.UsuarioId     = rp.TecnicoId
        WHERE d.OrdenId = @OrdenId AND rp.FechaFin IS NOT NULL

        UNION ALL
        -- Factura
        SELECT f.FechaEmision, 'FACTURA',
               CAST(CONCAT(f.NumeroFactura, ' a nombre de ', f.NombreFacturacion, ' (NIT ', f.NITFacturacion,
                           ') - mano de obra Q', f.TotalManoObra, ', repuestos Q', f.TotalRepuestos,
                           ', IVA Q', f.Impuesto) AS VARCHAR(500)),
               u.NombreCompleto, f.Total
        FROM dbo.Factura f
        JOIN dbo.Usuario u ON u.UsuarioId = f.UsuarioId
        WHERE f.OrdenId = @OrdenId

        UNION ALL
        -- Pagos
        SELECT p.FechaPago, 'PAGO',
               CAST(CONCAT(mp.Nombre, CASE WHEN p.Referencia IS NULL THEN '' ELSE ' ref. ' + p.Referencia END,
                           ' (', p.Estado, ')') AS VARCHAR(500)),
               u.NombreCompleto, p.Monto
        FROM dbo.Pago p
        JOIN dbo.Factura f     ON f.FacturaId     = p.FacturaId
        JOIN dbo.MetodoPago mp ON mp.MetodoPagoId = p.MetodoPagoId
        JOIN dbo.Usuario u     ON u.UsuarioId     = p.UsuarioId
        WHERE f.OrdenId = @OrdenId

        UNION ALL
        -- Entrega
        SELECT en.FechaEntrega, 'ENTREGA',
               CAST(CONCAT('Recibió: ', en.NombreRecibe,
                           CASE WHEN en.Observaciones IS NULL THEN '' ELSE '. ' + en.Observaciones END) AS VARCHAR(500)),
               u.NombreCompleto, NULL
        FROM dbo.Entrega en
        JOIN dbo.Usuario u ON u.UsuarioId = en.UsuarioEntregaId
        WHERE en.OrdenId = @OrdenId
    ) AS t
    ORDER BY t.Fecha,
             CASE t.Etapa WHEN 'ESTADO' THEN 0 WHEN 'DIAGNOSTICO' THEN 1 WHEN 'REPARACION' THEN 2
                          WHEN 'ACTIVIDAD' THEN 3 WHEN 'REPUESTO' THEN 4 WHEN 'FACTURA' THEN 5
                          WHEN 'PAGO' THEN 6 ELSE 7 END;
END;
GO

/* ==========================================================
   ============ DASHBOARD Y ACTIVIDAD (sección 6.3) =========
   ========================================================== */

/* ----------------------------------------------------------
   vw_Dashboard: una sola fila con los números de la
   pantalla principal, calculados desde la base
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_Dashboard
AS
SELECT (SELECT COUNT(*) FROM dbo.OrdenServicio WHERE EstadoOrdenId NOT IN (6, 7)) AS OrdenesAbiertas,
       (SELECT COUNT(*) FROM dbo.OrdenServicio WHERE EstadoOrdenId = 1)          AS Recibidas,
       (SELECT COUNT(*) FROM dbo.OrdenServicio WHERE EstadoOrdenId = 2)          AS EnDiagnostico,
       (SELECT COUNT(*) FROM dbo.OrdenServicio WHERE EstadoOrdenId = 3)          AS EsperandoAutorizacion,
       (SELECT COUNT(*) FROM dbo.OrdenServicio WHERE EstadoOrdenId = 4)          AS EnReparacion,
       (SELECT COUNT(*) FROM dbo.OrdenServicio WHERE EstadoOrdenId = 5)          AS ListasParaEntregar,
       (SELECT COUNT(*) FROM dbo.Factura
        WHERE Estado <> 'ANULADA' AND dbo.fn_SaldoFactura(FacturaId) > 0)        AS FacturasConSaldo,
       (SELECT ISNULL(SUM(dbo.fn_SaldoFactura(FacturaId)), 0) FROM dbo.Factura
        WHERE Estado <> 'ANULADA')                                               AS SaldoPorCobrar,
       (SELECT COUNT(*) FROM dbo.vw_RepuestosBajoMinimo)                         AS RepuestosBajoMinimo;
GO

/* ----------------------------------------------------------
   vw_ActividadReciente: cambios de estado, movimientos de
   inventario y pagos en una sola lista.
   Uso: SELECT TOP (10) ... FROM dbo.vw_ActividadReciente ORDER BY Fecha DESC
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_ActividadReciente
AS
SELECT h.FechaCambio AS Fecha,
       CAST('ORDEN' AS VARCHAR(15)) AS Tipo,
       CAST(CONCAT(o.NumeroOrden, ': ', ISNULL(ea.Codigo, '(nueva)'), ' -> ', en.Codigo) AS VARCHAR(300)) AS Detalle,
       u.NombreCompleto AS Usuario
FROM dbo.HistorialEstadoOrden h
JOIN dbo.OrdenServicio o     ON o.OrdenId        = h.OrdenId
LEFT JOIN dbo.EstadoOrden ea ON ea.EstadoOrdenId = h.EstadoAnteriorId
JOIN dbo.EstadoOrden en      ON en.EstadoOrdenId = h.EstadoNuevoId
JOIN dbo.Usuario u           ON u.UsuarioId      = h.UsuarioId

UNION ALL

SELECT m.FechaMovimiento,
       'INVENTARIO',
       CAST(CONCAT(m.TipoMovimiento, ' ', r.Codigo, ' x', m.Cantidad, ' en ', b.Nombre) AS VARCHAR(300)),
       u.NombreCompleto
FROM dbo.MovimientoInventario m
JOIN dbo.Repuesto r ON r.RepuestoId = m.RepuestoId
JOIN dbo.Bodega b   ON b.BodegaId   = m.BodegaId
JOIN dbo.Usuario u  ON u.UsuarioId  = m.UsuarioId

UNION ALL

SELECT p.FechaPago,
       'PAGO',
       CAST(CONCAT(f.NumeroFactura, ': Q', p.Monto, ' en ', mp.Nombre) AS VARCHAR(300)),
       u.NombreCompleto
FROM dbo.Pago p
JOIN dbo.Factura f     ON f.FacturaId     = p.FacturaId
JOIN dbo.MetodoPago mp ON mp.MetodoPagoId = p.MetodoPagoId
JOIN dbo.Usuario u     ON u.UsuarioId     = p.UsuarioId;
GO

/* ==========================================================
   VERIFICACIÓN: mínimos de la sección 4 del enunciado
   (contados directamente del catálogo de SQL Server)
   ========================================================== */
WITH Componentes AS (
    SELECT 1 AS Orden, 'Tablas' AS Componente, COUNT(*) AS Cantidad, 18 AS Minimo
    FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo')
    UNION ALL
    SELECT 2, 'Llaves primarias compuestas', COUNT(*), 2
    FROM (SELECT i.object_id
          FROM sys.indexes i
          JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
          WHERE i.is_primary_key = 1
          GROUP BY i.object_id
          HAVING COUNT(*) > 1) AS x
    UNION ALL
    SELECT 3, 'Llaves foráneas', COUNT(*), 1 FROM sys.foreign_keys
    UNION ALL
    SELECT 4, 'Restricciones UNIQUE', COUNT(*), 5
    FROM sys.indexes
    WHERE is_unique = 1 AND is_primary_key = 0
      AND object_id IN (SELECT object_id FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo'))
    UNION ALL
    SELECT 5, 'Valores DEFAULT', COUNT(*), 5 FROM sys.default_constraints
    UNION ALL
    SELECT 6, 'Restricciones CHECK', COUNT(*), 4 FROM sys.check_constraints
    UNION ALL
    SELECT 7, 'Vistas', COUNT(*), 4 FROM sys.views WHERE schema_id = SCHEMA_ID('dbo')
    UNION ALL
    SELECT 8, 'Procedimientos almacenados', COUNT(*), 6 FROM sys.procedures WHERE schema_id = SCHEMA_ID('dbo')
    UNION ALL
    SELECT 9, 'Funciones', COUNT(*), 2 FROM sys.objects WHERE type IN ('FN', 'IF', 'TF') AND schema_id = SCHEMA_ID('dbo')
    UNION ALL
    SELECT 10, 'Triggers', COUNT(*), 2 FROM sys.triggers WHERE parent_class = 1
    UNION ALL
    SELECT 11, 'Índices no agrupados (IX_)', COUNT(*), 6
    FROM sys.indexes WHERE type = 2 AND name LIKE 'IX[_]%'
)
SELECT Componente, Cantidad, Minimo,
       CASE WHEN Cantidad >= Minimo THEN 'Sí' ELSE 'NO' END AS Cumple
FROM Componentes
ORDER BY Orden;

-- Lista de lo creado en este script
SELECT o.type_desc AS Tipo, o.name AS Objeto
FROM sys.objects o
WHERE o.schema_id = SCHEMA_ID('dbo')
  AND (o.type = 'TR'
       OR o.name IN ('vw_HistorialCliente', 'vw_FacturasSaldoPendiente', 'vw_IngresosPeriodo',
                     'vw_TrazabilidadOrden', 'vw_Dashboard', 'vw_ActividadReciente',
                     'fn_ReporteIngresos', 'sp_TrazabilidadOrden'))
ORDER BY o.type_desc, o.name;
GO
