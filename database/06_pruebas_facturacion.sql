/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Pruebas del script 06: facturación, pagos y entrega
   Se corre sobre la base con datos de prueba:
   01 -> 02 -> 03 -> 04 -> 05 -> 06 -> 07 -> este script
   Usa órdenes del 05 (las busca por estado, no por número).
   Las pruebas marcadas como ERROR ESPERADO tienen que fallar.
   ========================================================== */

-- USE TechCare;
-- GO

SET NOCOUNT ON;
GO

-- Órdenes que se usan en las pruebas (se guardan para los siguientes bloques)
DROP TABLE IF EXISTS #Prueba;
CREATE TABLE #Prueba (Clave VARCHAR(20) PRIMARY KEY, Id INT);

-- Una orden LISTO todavía sin factura
INSERT INTO #Prueba (Clave, Id)
SELECT TOP (1) 'FACTURAR', o.OrdenId
FROM dbo.OrdenServicio o
LEFT JOIN dbo.Factura f ON f.OrdenId = o.OrdenId
WHERE o.EstadoOrdenId = 5 AND f.FacturaId IS NULL
ORDER BY o.OrdenId;

-- Una orden en REPARACION
INSERT INTO #Prueba (Clave, Id)
SELECT TOP (1) 'REPARACION', OrdenId
FROM dbo.OrdenServicio
WHERE EstadoOrdenId = 4
ORDER BY OrdenId;

SELECT p.Clave, o.NumeroOrden, eo.Codigo AS Estado
FROM #Prueba p
JOIN dbo.OrdenServicio o ON o.OrdenId = p.Id
JOIN dbo.EstadoOrden eo  ON eo.EstadoOrdenId = o.EstadoOrdenId;
GO

-- Si no están los datos del 05, se detiene aquí (no corre nada más)
IF (SELECT COUNT(*) FROM #Prueba) < 2
BEGIN
    RAISERROR('Faltan los datos de prueba: no hay una orden LISTO sin factura o una orden en REPARACION. Corra 01, 02, 03, 04, 05, 06 y 07, y después este script.', 16, 1);
    SET NOEXEC ON;
END;
GO

/* ==========================================================
   FACTURA
   ========================================================== */

-- F1 (T08). Caja factura la orden LISTO (OK)
DECLARE @Ord  INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURAR');
DECLARE @Caja INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'caja1');
DECLARE @Fac  INT;

EXEC dbo.sp_GenerarFactura @OrdenId = @Ord, @UsuarioId = @Caja, @FacturaId = @Fac OUTPUT;

INSERT INTO #Prueba (Clave, Id) VALUES ('FACTURA', @Fac);

-- Comprobar el cálculo: subtotal = mano de obra + repuestos (precio histórico), IVA 12 %
SELECT 'F1 cálculo' AS Prueba,
       f.TotalManoObra,
       rp.CostoManoObra                                   AS ManoObraReparacion,
       f.TotalRepuestos,
       (SELECT ISNULL(SUM(Cantidad * PrecioVentaUnitario), 0)
        FROM dbo.ReparacionRepuesto WHERE ReparacionId = rp.ReparacionId) AS RepuestosReparacion,
       f.Subtotal,
       dbo.fn_TotalOrden(f.OrdenId)                       AS fn_TotalOrden,
       f.Impuesto,
       ROUND(f.Subtotal * 0.12, 2)                        AS IVA12,
       f.Total,
       CASE WHEN f.Subtotal = dbo.fn_TotalOrden(f.OrdenId)
             AND f.Total = f.Subtotal + f.Impuesto THEN 'CORRECTO' ELSE 'REVISAR' END AS Resultado
FROM dbo.Factura f
JOIN dbo.Diagnostico d ON d.OrdenId = f.OrdenId
JOIN dbo.Reparacion rp ON rp.DiagnosticoId = d.DiagnosticoId
WHERE f.FacturaId = @Fac;
GO

-- F2 (R11). Facturar la misma orden otra vez -> ERROR ESPERADO 50704
BEGIN TRY
    DECLARE @Ord  INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURAR');
    DECLARE @Caja INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'caja1');
    EXEC dbo.sp_GenerarFactura @OrdenId = @Ord, @UsuarioId = @Caja;
    SELECT 'F2 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'F2 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- F3. Un técnico intenta facturar -> ERROR ESPERADO 50701
BEGIN TRY
    DECLARE @Ord INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURAR');
    DECLARE @Tec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'tecnico1');
    EXEC dbo.sp_GenerarFactura @OrdenId = @Ord, @UsuarioId = @Tec;
    SELECT 'F3 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'F3 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- F4. Facturar una orden que sigue en REPARACION -> ERROR ESPERADO 50703
BEGIN TRY
    DECLARE @Ord  INT = (SELECT Id FROM #Prueba WHERE Clave = 'REPARACION');
    DECLARE @Caja INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'caja1');
    EXEC dbo.sp_GenerarFactura @OrdenId = @Ord, @UsuarioId = @Caja;
    SELECT 'F4 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'F4 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

/* ==========================================================
   PAGOS
   ========================================================== */

-- F5 (T09). Dos pagos parciales: 40 % en efectivo y 30 % con tarjeta (OK)
DECLARE @Fac     INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURA');
DECLARE @Caja    INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'caja1');
DECLARE @Efect   INT = (SELECT MetodoPagoId FROM dbo.MetodoPago WHERE Nombre = 'EFECTIVO');
DECLARE @Tarjeta INT = (SELECT MetodoPagoId FROM dbo.MetodoPago WHERE Nombre = 'TARJETA');
DECLARE @Total   DECIMAL(10,2) = (SELECT Total FROM dbo.Factura WHERE FacturaId = @Fac);
DECLARE @Monto1  DECIMAL(10,2) = ROUND(@Total * 0.40, 2);
DECLARE @Monto2  DECIMAL(10,2) = ROUND(@Total * 0.30, 2);

EXEC dbo.sp_RegistrarPago @FacturaId = @Fac, @MetodoPagoId = @Efect,   @Monto = @Monto1, @UsuarioId = @Caja;
EXEC dbo.sp_RegistrarPago @FacturaId = @Fac, @MetodoPagoId = @Tarjeta, @Monto = @Monto2, @UsuarioId = @Caja,
     @Referencia = 'VOU-778812';

SELECT 'F5 saldo' AS Prueba, f.NumeroFactura, f.Total,
       (SELECT SUM(Monto) FROM dbo.Pago WHERE FacturaId = @Fac AND Estado = 'APLICADO') AS Pagado,
       dbo.fn_SaldoFactura(@Fac) AS SaldoPendiente,                 -- 30 % del total
       f.Estado                                                      -- sigue EMITIDA
FROM dbo.Factura f
WHERE f.FacturaId = @Fac;
GO

-- F6. Pago con tarjeta sin número de referencia -> ERROR ESPERADO 50718
BEGIN TRY
    DECLARE @Fac     INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURA');
    DECLARE @Caja    INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'caja1');
    DECLARE @Tarjeta INT = (SELECT MetodoPagoId FROM dbo.MetodoPago WHERE Nombre = 'TARJETA');
    EXEC dbo.sp_RegistrarPago @FacturaId = @Fac, @MetodoPagoId = @Tarjeta, @Monto = 10.00, @UsuarioId = @Caja;
    SELECT 'F6 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'F6 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- F7 (T10). Pago mayor que el saldo -> ERROR ESPERADO 50717 y no se guarda nada
DECLARE @Fac   INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURA');
DECLARE @Caja  INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'caja1');
DECLARE @Efect INT = (SELECT MetodoPagoId FROM dbo.MetodoPago WHERE Nombre = 'EFECTIVO');
DECLARE @Saldo DECIMAL(10,2) = dbo.fn_SaldoFactura(@Fac);
DECLARE @Excede DECIMAL(10,2) = @Saldo + 100.00;
DECLARE @PagosAntes INT = (SELECT COUNT(*) FROM dbo.Pago WHERE FacturaId = @Fac);

BEGIN TRY
    EXEC dbo.sp_RegistrarPago @FacturaId = @Fac, @MetodoPagoId = @Efect, @Monto = @Excede, @UsuarioId = @Caja;
    SELECT 'F7 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'F7 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;

SELECT 'F7 sin cambios' AS Prueba,
       (SELECT COUNT(*) FROM dbo.Pago WHERE FacturaId = @Fac) - @PagosAntes AS PagosNuevos,   -- 0
       dbo.fn_SaldoFactura(@Fac) AS SaldoPendiente;                                           -- igual que antes
GO

/* ==========================================================
   ENTREGA
   ========================================================== */

-- F8. Entregar con saldo pendiente -> ERROR ESPERADO 50726
BEGIN TRY
    DECLARE @Ord INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURAR');
    DECLARE @Rec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion1');
    EXEC dbo.sp_EntregarOrden @OrdenId = @Ord, @UsuarioId = @Rec, @NombreRecibe = 'Cliente de prueba';
    SELECT 'F8 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'F8 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- F9. Se paga el resto por transferencia -> la factura queda PAGADA (OK)
DECLARE @Fac    INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURA');
DECLARE @Caja   INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'caja2');
DECLARE @Transf INT = (SELECT MetodoPagoId FROM dbo.MetodoPago WHERE Nombre = 'TRANSFERENCIA');
DECLARE @Resto  DECIMAL(10,2) = dbo.fn_SaldoFactura(@Fac);

EXEC dbo.sp_RegistrarPago @FacturaId = @Fac, @MetodoPagoId = @Transf, @Monto = @Resto, @UsuarioId = @Caja,
     @Referencia = 'TRF-81234567';
GO

-- F10. Otro pago a la factura ya pagada -> ERROR ESPERADO 50716
BEGIN TRY
    DECLARE @Fac   INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURA');
    DECLARE @Caja  INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'caja1');
    DECLARE @Efect INT = (SELECT MetodoPagoId FROM dbo.MetodoPago WHERE Nombre = 'EFECTIVO');
    EXEC dbo.sp_RegistrarPago @FacturaId = @Fac, @MetodoPagoId = @Efect, @Monto = 1.00, @UsuarioId = @Caja;
    SELECT 'F10 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'F10 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- F11. Entregar sin indicar quién recibe -> ERROR ESPERADO 50721
BEGIN TRY
    DECLARE @Ord INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURAR');
    DECLARE @Rec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion1');
    EXEC dbo.sp_EntregarOrden @OrdenId = @Ord, @UsuarioId = @Rec, @NombreRecibe = '';
    SELECT 'F11 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'F11 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- F12. Entrega correcta: factura pagada -> ENTREGADO (OK)
DECLARE @Ord INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURAR');
DECLARE @Rec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion1');

EXEC dbo.sp_EntregarOrden @OrdenId = @Ord, @UsuarioId = @Rec,
     @NombreRecibe = 'Titular de la orden', @Observaciones = 'Se probó el equipo frente al cliente.';

SELECT TOP (2) 'F12 historial' AS Prueba, h.FechaCambio, ea.Codigo AS EstadoAnterior, en.Codigo AS EstadoNuevo,
       u.NombreUsuario, h.Observacion
FROM dbo.HistorialEstadoOrden h
LEFT JOIN dbo.EstadoOrden ea ON ea.EstadoOrdenId = h.EstadoAnteriorId
JOIN dbo.EstadoOrden en      ON en.EstadoOrdenId = h.EstadoNuevoId
JOIN dbo.Usuario u           ON u.UsuarioId      = h.UsuarioId
WHERE h.OrdenId = @Ord
ORDER BY h.HistorialId DESC;
GO

-- F13. Entregar la misma orden otra vez -> ERROR ESPERADO 50724
BEGIN TRY
    DECLARE @Ord INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURAR');
    DECLARE @Rec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion1');
    EXEC dbo.sp_EntregarOrden @OrdenId = @Ord, @UsuarioId = @Rec, @NombreRecibe = 'Otra persona';
    SELECT 'F13 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'F13 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

/* ==========================================================
   CAMBIOS AL sp_CambiarEstadoOrden
   ========================================================== */

-- F14. Pasar a LISTO "a mano" con la reparación todavía EN_PROCESO -> ERROR ESPERADO 50210
BEGIN TRY
    DECLARE @Ord INT = (SELECT Id FROM #Prueba WHERE Clave = 'REPARACION');
    DECLARE @Adm INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'admin');
    EXEC dbo.sp_CambiarEstadoOrden @OrdenId = @Ord, @EstadoNuevoId = 5, @UsuarioId = @Adm;
    SELECT 'F14 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'F14 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- F15. Cancelar una orden en REPARACION: la reparación queda CANCELADA (OK)
DECLARE @Ord INT = (SELECT Id FROM #Prueba WHERE Clave = 'REPARACION');
DECLARE @Rec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion1');

EXEC dbo.sp_CambiarEstadoOrden @OrdenId = @Ord, @EstadoNuevoId = 7, @UsuarioId = @Rec,
     @Observacion = 'El cliente retiró el equipo a media reparación.';

SELECT 'F15 reparación' AS Prueba, o.NumeroOrden, eo.Codigo AS EstadoOrden,
       rp.Estado AS EstadoReparacion, rp.FechaInicio, rp.FechaFin
FROM dbo.OrdenServicio o
JOIN dbo.EstadoOrden eo ON eo.EstadoOrdenId = o.EstadoOrdenId
JOIN dbo.Diagnostico d  ON d.OrdenId        = o.OrdenId
JOIN dbo.Reparacion rp  ON rp.DiagnosticoId = d.DiagnosticoId
WHERE o.OrdenId = @Ord;
GO

-- Resumen de la orden facturada en estas pruebas
DECLARE @Ord INT = (SELECT Id FROM #Prueba WHERE Clave = 'FACTURAR');
SELECT 'Resumen' AS Prueba, NumeroOrden, EstadoActual, NumeroFactura, TotalFactura, Pagos, TotalPagado,
       SaldoPendiente, FechaEntrega, NombreRecibe
FROM dbo.vw_TrazabilidadOrden
WHERE OrdenId = @Ord;

DROP TABLE IF EXISTS #Prueba;
GO
/* Debe salir:
   F1 factura la orden con Resultado = CORRECTO.
   F5 deja un saldo del 30 % y la factura sigue EMITIDA.
   F7 muestra PagosNuevos = 0.
   F9 deja la factura PAGADA con SaldoPendiente = 0.
   F12 cambia la orden a ENTREGADO (LISTO -> ENTREGADO en el historial).
   F15 deja la orden CANCELADO y su reparación CANCELADA con fecha de fin.
   F2, F3, F4, F6, F7, F8, F10, F11, F13 y F14 dan ERROR ESPERADO.
   Resumen: 3 pagos, saldo 0.00 y la entrega registrada. */

SET NOEXEC OFF;
GO
