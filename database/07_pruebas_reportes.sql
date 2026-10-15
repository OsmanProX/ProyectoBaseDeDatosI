/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Pruebas del script 07: triggers, índices y reportes
   Se corre sobre la base con datos de prueba:
   01 -> 02 -> 03 -> 04 -> 05 -> 06 -> 07 -> este script
   Las pruebas marcadas como ERROR ESPERADO tienen que fallar.
   ========================================================== */

-- USE TechCare;
-- GO

SET NOCOUNT ON;
GO

/* ==========================================================
   TRIGGERS
   ========================================================== */

-- G1 (T14). Cambio de precio: queda en AuditoriaPrecio y los precios
--     históricos de las reparaciones anteriores NO cambian
DECLARE @AudAntes INT = (SELECT COUNT(*) FROM dbo.AuditoriaPrecio);

UPDATE dbo.Repuesto SET PrecioVenta = 325.00 WHERE Codigo = 'REP-0003';   -- antes 300.00

SELECT 'G1 auditoría' AS Prueba, r.Codigo, a.PrecioVentaAnterior, a.PrecioVentaNuevo,
       a.FechaCambio, a.UsuarioBD
FROM dbo.AuditoriaPrecio a
JOIN dbo.Repuesto r ON r.RepuestoId = a.RepuestoId
WHERE a.AuditoriaId > @AudAntes
ORDER BY a.AuditoriaId;

SELECT 'G1 precio histórico' AS Prueba,
       COUNT(*)                     AS LineasConRAM8GB,
       MIN(VentaHistorica)          AS VentaHistoricaMin,     -- 300.00
       MAX(VentaHistorica)          AS VentaHistoricaMax,     -- 300.00
       MAX(PrecioVentaActual)       AS PrecioVentaActual      -- 325.00
FROM dbo.vw_RepuestosUtilizados
WHERE Codigo = 'REP-0003';

UPDATE dbo.Repuesto SET PrecioVenta = 300.00 WHERE Codigo = 'REP-0003';   -- se regresa (también se audita)

SELECT 'G1 total auditado' AS Prueba, COUNT(*) - @AudAntes AS RegistrosNuevos   -- 2
FROM dbo.AuditoriaPrecio;
GO

-- G2 (R14). Borrar un pago -> ERROR ESPERADO 50806 y el pago sigue ahí
DECLARE @Pago INT = (SELECT MIN(PagoId) FROM dbo.Pago);

BEGIN TRY
    DELETE FROM dbo.Pago WHERE PagoId = @Pago;
    SELECT 'G2 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'G2 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;

SELECT 'G2 el pago sigue' AS Prueba, COUNT(*) AS Existe FROM dbo.Pago WHERE PagoId = @Pago;   -- 1
GO

-- G3 (R14). Borrar un movimiento de inventario -> ERROR ESPERADO 50803
BEGIN TRY
    DELETE FROM dbo.MovimientoInventario
    WHERE MovimientoId = (SELECT MAX(MovimientoId) FROM dbo.MovimientoInventario);
    SELECT 'G3 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'G3 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- G4 (R14). Borrar el historial de una orden -> ERROR ESPERADO 50802
BEGIN TRY
    DELETE FROM dbo.HistorialEstadoOrden
    WHERE HistorialId = (SELECT MIN(HistorialId) FROM dbo.HistorialEstadoOrden);
    SELECT 'G4 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'G4 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- G5 (R14). Borrar una factura sin pagos -> ERROR ESPERADO 50805
--     (una factura con pagos ni siquiera llega al trigger: la FK la protege)
BEGIN TRY
    DELETE FROM dbo.Factura
    WHERE FacturaId = (SELECT MIN(f.FacturaId)
                       FROM dbo.Factura f
                       LEFT JOIN dbo.Pago p ON p.FacturaId = f.FacturaId
                       WHERE p.PagoId IS NULL);
    SELECT 'G5 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT 'G5 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

/* ==========================================================
   ÍNDICES
   ========================================================== */

-- G6. Índices no agrupados creados
SELECT 'G6 índices' AS Prueba, t.name AS Tabla, i.name AS Indice
FROM sys.indexes i
JOIN sys.tables t ON t.object_id = i.object_id
WHERE i.type = 2 AND i.name LIKE 'IX[_]%'
ORDER BY t.name, i.name;
GO

/* ==========================================================
   REPORTES
   ========================================================== */

-- R2. Historial de un cliente (Comercial El Progreso: varias órdenes)
SELECT Cliente, NumeroOrden, FechaIngreso, Estado, Equipo, NumeroSerie, NumeroFactura, TotalFacturado, SaldoPendiente
FROM dbo.vw_HistorialCliente
WHERE Cliente = 'Comercial El Progreso, S.A.'
ORDER BY FechaIngreso;

-- R2 con LEFT JOIN: el cliente sin órdenes también aparece (orden en NULL)
SELECT Cliente, TipoCliente, NumeroOrden, Estado
FROM dbo.vw_HistorialCliente
WHERE Cliente = 'Claudia Patricia Orellana';

-- R10. Facturas con saldo pendiente y sus pagos (las que no tienen pagos también salen)
SELECT NumeroFactura, NumeroOrden, Cliente, Total, TotalPagado, SaldoPendiente, FechaPago, MetodoPago, MontoPago
FROM dbo.vw_FacturasSaldoPendiente
ORDER BY NumeroFactura, FechaPago;

-- R11. Ingresos por mes, separando mano de obra y repuestos
SELECT Anio, Mes, Facturas, ManoObra, Repuestos, Subtotal, IVA, TotalFacturado, Cobrado, PorCobrar
FROM dbo.vw_IngresosPeriodo
ORDER BY Anio, Mes;

-- R11 por rango de fechas (agosto y septiembre)
SELECT Anio, Mes, Facturas, ManoObra, Repuestos, TotalFacturado, Cobrado
FROM dbo.fn_ReporteIngresos('2026-08-01', '2026-09-30')
ORDER BY Anio, Mes;
GO

-- T11. Historial de un equipo con varias órdenes (la HP de Juan Carlos tiene 4)
SELECT NumeroSerie, Propietario, NumeroOrden, FechaIngreso, EstadoOrden, Diagnostico, EstadoReparacion, NumeroFactura
FROM dbo.vw_HistorialEquipo
WHERE NumeroSerie = 'HP5CD1234XYZ'
ORDER BY FechaIngreso;
GO

-- T12. Trazabilidad completa de una orden ENTREGADA con varios repuestos y varios pagos
DECLARE @Num VARCHAR(15) = (SELECT TOP (1) NumeroOrden
                            FROM dbo.vw_TrazabilidadOrden
                            WHERE EstadoActual = 'ENTREGADO' AND RepuestosUsados >= 2 AND Pagos >= 2
                            ORDER BY OrdenId);
SELECT 'T12 orden' AS Prueba, @Num AS NumeroOrden;
EXEC dbo.sp_TrazabilidadOrden @NumeroOrden = @Num;
GO

-- T12 con LEFT JOIN: una orden recién RECIBIDA también sale (sin diagnóstico ni factura)
SELECT NumeroOrden, EstadoActual, Cliente, Equipo, TecnicoDiagnostico, NumeroFactura, Pagos, SaldoPendiente
FROM dbo.vw_TrazabilidadOrden
WHERE EstadoActual = 'RECIBIDO'
ORDER BY NumeroOrden;
GO

-- T13. Repuestos en o bajo el mínimo en diferentes bodegas
SELECT Bodega, Codigo, Repuesto, Existencia, StockMinimo, Faltante, EstadoStock
FROM dbo.vw_RepuestosBajoMinimo
ORDER BY Bodega, Codigo;
GO

-- Dashboard (pantalla principal) y actividad reciente
SELECT OrdenesAbiertas, Recibidas, EnDiagnostico, EsperandoAutorizacion, EnReparacion,
       ListasParaEntregar, FacturasConSaldo, SaldoPorCobrar, RepuestosBajoMinimo
FROM dbo.vw_Dashboard;

SELECT TOP (10) Fecha, Tipo, Detalle, Usuario
FROM dbo.vw_ActividadReciente
ORDER BY Fecha DESC;
GO

/* ==========================================================
   CONSISTENCIA DE TOTALES (sección 5.1)
   Cada factura debe coincidir con su reparación y repuestos,
   y los pagos nunca pasan del total.
   ========================================================== */
SELECT 'Consistencia' AS Prueba,
       SUM(CASE WHEN f.TotalManoObra <> rp.CostoManoObra THEN 1 ELSE 0 END)           AS ManoObraDiferente,
       SUM(CASE WHEN f.TotalRepuestos <> ISNULL(rr.Venta, 0) THEN 1 ELSE 0 END)        AS RepuestosDiferentes,
       SUM(CASE WHEN f.Total <> f.Subtotal + f.Impuesto THEN 1 ELSE 0 END)             AS TotalDiferente,
       SUM(CASE WHEN dbo.fn_SaldoFactura(f.FacturaId) < 0 THEN 1 ELSE 0 END)           AS Sobrepagadas,
       (SELECT COUNT(*) FROM dbo.Inventario WHERE Existencia < 0)                      AS ExistenciasNegativas
FROM dbo.Factura f
JOIN dbo.Diagnostico d ON d.OrdenId        = f.OrdenId
JOIN dbo.Reparacion rp ON rp.DiagnosticoId = d.DiagnosticoId
LEFT JOIN (SELECT ReparacionId, SUM(Cantidad * PrecioVentaUnitario) AS Venta
           FROM dbo.ReparacionRepuesto
           GROUP BY ReparacionId) AS rr ON rr.ReparacionId = rp.ReparacionId;
GO
/* Debe salir:
   G1: 2 registros de auditoría (300 -> 325 y 325 -> 300); la venta histórica
       sigue en 300.00 mientras el precio actual era 325.00.
   G2, G3, G4 y G5 dan ERROR ESPERADO; G2 muestra Existe = 1.
   G6: 13 índices IX_.
   R2: Claudia Patricia Orellana sale con NumeroOrden en NULL.
   T11: 4 órdenes de la HP5CD1234XYZ.
   T12: el resumen de la orden y su línea de tiempo completa.
   Consistencia: todo en 0. */
