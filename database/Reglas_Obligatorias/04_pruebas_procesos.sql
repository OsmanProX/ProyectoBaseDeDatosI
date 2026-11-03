/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Pruebas de los procesos del script 04 (solo en Docker)
   Se corre UNA vez sobre una base recién creada:
   01 -> 02 -> 03 -> 04 -> este script
   (el 03_pruebas_procedimientos es opcional, no estorba)
   Las pruebas marcadas como ERROR ESPERADO tienen que fallar.
   ========================================================== */

-- USE TechCare;
-- GO

SET NOCOUNT ON;
GO

-- P0. OPENJSON (sp_RegistrarCompra) necesita nivel de compatibilidad 130 o más
SELECT name AS BaseDatos, compatibility_level AS NivelCompatibilidad
FROM sys.databases
WHERE name = DB_NAME();
GO

/* ==========================================================
   DIAGNÓSTICO Y REPARACIÓN
   ========================================================== */

-- P1. Orden nueva para la Dell de Comercial El Progreso (OK)
DECLARE @Cli INT = (SELECT ClienteId FROM dbo.Cliente WHERE NombreRazonSocial = 'Comercial El Progreso, S.A.');
DECLARE @Eq  INT = (SELECT EquipoId  FROM dbo.Equipo  WHERE NumeroSerie = 'DL-7HJK921');
DECLARE @Rec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion1');

EXEC dbo.sp_RegistrarOrden
     @ClienteId = @Cli, @EquipoId = @Eq, @UsuarioRecepcionId = @Rec,
     @ProblemaReportado = 'La computadora está lenta y se reinicia sola.',
     @Prioridad = 'ALTA';
GO

-- P2. Caja intenta diagnosticar -> ERROR ESPERADO 50303 (R03)
BEGIN TRY
    DECLARE @Ord  INT = (SELECT o.OrdenId FROM dbo.OrdenServicio o
                         JOIN dbo.Equipo e ON e.EquipoId = o.EquipoId
                         WHERE e.NumeroSerie = 'DL-7HJK921' AND o.EstadoOrdenId NOT IN (6, 7));
    DECLARE @Caja INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'caja1');
    EXEC dbo.sp_RegistrarDiagnostico @OrdenId = @Ord, @TecnicoId = @Caja,
         @Descripcion = 'Prueba sin permiso';
    SELECT 'P2 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P2 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- P3 (T03). Técnico registra el diagnóstico -> ESPERANDO_AUTORIZACION (OK)
DECLARE @Ord INT = (SELECT o.OrdenId FROM dbo.OrdenServicio o
                    JOIN dbo.Equipo e ON e.EquipoId = o.EquipoId
                    WHERE e.NumeroSerie = 'DL-7HJK921' AND o.EstadoOrdenId NOT IN (6, 7));
DECLARE @Tec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'tecnico1');

EXEC dbo.sp_RegistrarDiagnostico
     @OrdenId = @Ord, @TecnicoId = @Tec,
     @Descripcion = 'Memoria RAM con fallas y pasta térmica seca; el procesador se sobrecalienta.',
     @CostoManoObraEstimado = 200.00;
GO

-- P4 (R04). Orden de la Acer SIN diagnóstico e intento de reparar -> ERROR ESPERADO 50403
--     (la orden de la Acer se queda en RECIBIDO: escenario "orden sin diagnóstico")
DECLARE @Cli INT = (SELECT ClienteId FROM dbo.Cliente WHERE NombreRazonSocial = 'Colegio San Andrés');
DECLARE @Eq  INT = (SELECT EquipoId  FROM dbo.Equipo  WHERE NumeroSerie = 'ACR-NXHS7AA01');
DECLARE @Rec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion1');
DECLARE @Tec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'tecnico2');
DECLARE @Id  INT;

EXEC dbo.sp_RegistrarOrden
     @ClienteId = @Cli, @EquipoId = @Eq, @UsuarioRecepcionId = @Rec,
     @ProblemaReportado = 'La pantalla parpadea.', @OrdenId = @Id OUTPUT;

BEGIN TRY
    EXEC dbo.sp_IniciarReparacion @OrdenId = @Id, @TecnicoId = @Tec;
    SELECT 'P4 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P4 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- P5. El cliente autorizó: inicia la reparación de la Dell -> REPARACION (OK)
DECLARE @Ord INT = (SELECT o.OrdenId FROM dbo.OrdenServicio o
                    JOIN dbo.Equipo e ON e.EquipoId = o.EquipoId
                    WHERE e.NumeroSerie = 'DL-7HJK921' AND o.EstadoOrdenId NOT IN (6, 7));
DECLARE @Tec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'tecnico1');

EXEC dbo.sp_IniciarReparacion @OrdenId = @Ord, @TecnicoId = @Tec;
GO

-- P6. Dos actividades de la reparación (OK)
DECLARE @Rep INT = (SELECT rp.ReparacionId FROM dbo.Reparacion rp
                    JOIN dbo.Diagnostico d   ON d.DiagnosticoId = rp.DiagnosticoId
                    JOIN dbo.OrdenServicio o ON o.OrdenId       = d.OrdenId
                    JOIN dbo.Equipo e        ON e.EquipoId      = o.EquipoId
                    WHERE e.NumeroSerie = 'DL-7HJK921' AND o.EstadoOrdenId NOT IN (6, 7));
DECLARE @Tec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'tecnico1');

EXEC dbo.sp_RegistrarActividadReparacion @ReparacionId = @Rep, @UsuarioId = @Tec,
     @Descripcion = 'Desarmado y limpieza interna', @HorasTrabajadas = 1.0;
EXEC dbo.sp_RegistrarActividadReparacion @ReparacionId = @Rep, @UsuarioId = @Tec,
     @Descripcion = 'Cambio de memoria RAM y pasta térmica', @HorasTrabajadas = 0.5;
GO

/* ==========================================================
   REPUESTOS EN LA REPARACIÓN
   ========================================================== */

-- P7 (T04). Batería en Zona 10: hay 1 y se piden 3 -> ERROR ESPERADO 50507
--     Después se comprueba que NO cambió nada
DECLARE @Rep INT = (SELECT rp.ReparacionId FROM dbo.Reparacion rp
                    JOIN dbo.Diagnostico d   ON d.DiagnosticoId = rp.DiagnosticoId
                    JOIN dbo.OrdenServicio o ON o.OrdenId       = d.OrdenId
                    JOIN dbo.Equipo e        ON e.EquipoId      = o.EquipoId
                    WHERE e.NumeroSerie = 'DL-7HJK921' AND o.EstadoOrdenId NOT IN (6, 7));
DECLARE @Tec INT = (SELECT UsuarioId  FROM dbo.Usuario  WHERE NombreUsuario = 'tecnico1');
DECLARE @Bat INT = (SELECT RepuestoId FROM dbo.Repuesto WHERE Codigo = 'REP-0008');
DECLARE @Z10 INT = (SELECT BodegaId   FROM dbo.Bodega   WHERE Nombre = 'Zona 10');
DECLARE @MovAntes INT = (SELECT COUNT(*) FROM dbo.MovimientoInventario);
DECLARE @DetAntes INT = (SELECT COUNT(*) FROM dbo.ReparacionRepuesto);

BEGIN TRY
    EXEC dbo.sp_AsignarRepuesto @ReparacionId = @Rep, @RepuestoId = @Bat, @BodegaId = @Z10,
         @Cantidad = 3, @UsuarioId = @Tec;
    SELECT 'P7 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P7 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;

SELECT 'P7 sin cambios parciales' AS Prueba,
       (SELECT Existencia FROM dbo.Inventario WHERE RepuestoId = @Bat AND BodegaId = @Z10) AS ExistenciaBateriaZona10,  -- sigue en 1
       (SELECT COUNT(*) FROM dbo.MovimientoInventario) - @MovAntes AS MovimientosNuevos,                              -- 0
       (SELECT COUNT(*) FROM dbo.ReparacionRepuesto)   - @DetAntes AS DetallesNuevos;                                 -- 0
GO

-- P8 (R06). Pantalla 15.6" desde Mixco (no está en esa bodega) -> ERROR ESPERADO 50506
BEGIN TRY
    DECLARE @Rep INT = (SELECT rp.ReparacionId FROM dbo.Reparacion rp
                        JOIN dbo.Diagnostico d   ON d.DiagnosticoId = rp.DiagnosticoId
                        JOIN dbo.OrdenServicio o ON o.OrdenId       = d.OrdenId
                        JOIN dbo.Equipo e        ON e.EquipoId      = o.EquipoId
                        WHERE e.NumeroSerie = 'DL-7HJK921' AND o.EstadoOrdenId NOT IN (6, 7));
    DECLARE @Tec INT = (SELECT UsuarioId  FROM dbo.Usuario  WHERE NombreUsuario = 'tecnico1');
    DECLARE @Pan INT = (SELECT RepuestoId FROM dbo.Repuesto WHERE Codigo = 'REP-0001');
    DECLARE @Mix INT = (SELECT BodegaId   FROM dbo.Bodega   WHERE Nombre = 'Mixco');
    EXEC dbo.sp_AsignarRepuesto @ReparacionId = @Rep, @RepuestoId = @Pan, @BodegaId = @Mix,
         @Cantidad = 1, @UsuarioId = @Tec;
    SELECT 'P8 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P8 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- P9 (T05). Usa 2 RAM 8GB y 1 pasta térmica de la Central (OK)
--     RAM: 15 -> 13, pasta: 30 -> 29, con su movimiento de SALIDA
DECLARE @Rep  INT = (SELECT rp.ReparacionId FROM dbo.Reparacion rp
                     JOIN dbo.Diagnostico d   ON d.DiagnosticoId = rp.DiagnosticoId
                     JOIN dbo.OrdenServicio o ON o.OrdenId       = d.OrdenId
                     JOIN dbo.Equipo e        ON e.EquipoId      = o.EquipoId
                     WHERE e.NumeroSerie = 'DL-7HJK921' AND o.EstadoOrdenId NOT IN (6, 7));
DECLARE @Tec  INT = (SELECT UsuarioId  FROM dbo.Usuario  WHERE NombreUsuario = 'tecnico1');
DECLARE @Ram  INT = (SELECT RepuestoId FROM dbo.Repuesto WHERE Codigo = 'REP-0003');
DECLARE @Pas  INT = (SELECT RepuestoId FROM dbo.Repuesto WHERE Codigo = 'REP-0010');
DECLARE @Cen  INT = (SELECT BodegaId   FROM dbo.Bodega   WHERE Nombre = 'Central');

EXEC dbo.sp_AsignarRepuesto @ReparacionId = @Rep, @RepuestoId = @Ram, @BodegaId = @Cen,
     @Cantidad = 2, @UsuarioId = @Tec;
EXEC dbo.sp_AsignarRepuesto @ReparacionId = @Rep, @RepuestoId = @Pas, @BodegaId = @Cen,
     @Cantidad = 1, @UsuarioId = @Tec;

-- Comprobar: detalle + inventario + movimiento
SELECT 'P9 detalle' AS Prueba, NumeroOrden, Codigo, Repuesto, Bodega, Cantidad, VentaHistorica, VentaTotal
FROM dbo.vw_RepuestosUtilizados
ORDER BY Codigo;

SELECT 'P9 movimientos' AS Prueba, TipoMovimiento, Codigo, Bodega, Cantidad, ExistenciaResultante, DocumentoOrigen
FROM dbo.vw_MovimientosInventario
WHERE TipoMovimiento = 'SALIDA'
ORDER BY MovimientoId;
GO

-- P10. Finaliza la reparación con mano de obra Q250 -> LISTO
--      Total sin IVA = 250 + 2 x 300 + 1 x 60 = 910.00
DECLARE @Rep INT = (SELECT rp.ReparacionId FROM dbo.Reparacion rp
                    JOIN dbo.Diagnostico d   ON d.DiagnosticoId = rp.DiagnosticoId
                    JOIN dbo.OrdenServicio o ON o.OrdenId       = d.OrdenId
                    JOIN dbo.Equipo e        ON e.EquipoId      = o.EquipoId
                    WHERE e.NumeroSerie = 'DL-7HJK921' AND o.EstadoOrdenId NOT IN (6, 7));
DECLARE @Tec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'tecnico1');

EXEC dbo.sp_FinalizarReparacion @ReparacionId = @Rep, @TecnicoId = @Tec,
     @CostoManoObra = 250.00,
     @DescripcionTrabajo = 'Se reemplazaron 2 módulos de RAM 8GB y se cambió la pasta térmica.';
GO

-- P11. Agregar repuesto a una reparación ya finalizada -> ERROR ESPERADO 50505
BEGIN TRY
    DECLARE @Rep INT = (SELECT rp.ReparacionId FROM dbo.Reparacion rp
                        JOIN dbo.Diagnostico d   ON d.DiagnosticoId = rp.DiagnosticoId
                        JOIN dbo.OrdenServicio o ON o.OrdenId       = d.OrdenId
                        JOIN dbo.Equipo e        ON e.EquipoId      = o.EquipoId
                        WHERE e.NumeroSerie = 'DL-7HJK921' AND o.EstadoOrdenId NOT IN (6, 7));
    DECLARE @Tec INT = (SELECT UsuarioId  FROM dbo.Usuario  WHERE NombreUsuario = 'tecnico1');
    DECLARE @Pas INT = (SELECT RepuestoId FROM dbo.Repuesto WHERE Codigo = 'REP-0010');
    DECLARE @Cen INT = (SELECT BodegaId   FROM dbo.Bodega   WHERE Nombre = 'Central');
    EXEC dbo.sp_AsignarRepuesto @ReparacionId = @Rep, @RepuestoId = @Pas, @BodegaId = @Cen,
         @Cantidad = 1, @UsuarioId = @Tec;
    SELECT 'P11 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P11 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

/* ==========================================================
   COMPRAS E INVENTARIO
   ========================================================== */

-- P12 (T06). Compra con 3 repuestos para Mixco (queda PENDIENTE)
--      La pantalla REP-0001 no existía en Mixco: se crea al recibir
DECLARE @Prov INT = (SELECT ProveedorId FROM dbo.Proveedor WHERE NIT = '2345678-9');
DECLARE @Mix  INT = (SELECT BodegaId    FROM dbo.Bodega    WHERE Nombre = 'Mixco');
DECLARE @Bod  INT = (SELECT UsuarioId   FROM dbo.Usuario   WHERE NombreUsuario = 'bodega1');
DECLARE @Json NVARCHAR(MAX) = (
    SELECT r.RepuestoId AS repuestoId, v.Cantidad AS cantidad, v.Costo AS costoUnitario
    FROM (VALUES ('REP-0001',  4, 345.00),
                 ('REP-0003', 10, 175.00),
                 ('REP-0005',  6, 255.00)) AS v (Codigo, Cantidad, Costo)
    JOIN dbo.Repuesto r ON r.Codigo = v.Codigo
    FOR JSON PATH);

SELECT 'P12 JSON enviado' AS Prueba, @Json AS Detalle;

EXEC dbo.sp_RegistrarCompra @ProveedorId = @Prov, @BodegaId = @Mix, @UsuarioId = @Bod,
     @Detalle = @Json, @Observaciones = 'Prueba T06';
GO

-- P13 (T06). Recibir la compra: suma inventario y crea movimientos de ENTRADA
DECLARE @Comp INT = (SELECT CompraId  FROM dbo.Compra  WHERE Observaciones = 'Prueba T06');
DECLARE @Bod  INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'bodega1');

SELECT 'P13 Mixco ANTES' AS Prueba, Codigo, Existencia, StockMinimo, EstadoStock
FROM dbo.vw_InventarioActual
WHERE Bodega = 'Mixco'
ORDER BY Codigo;

EXEC dbo.sp_RecibirCompra @CompraId = @Comp, @UsuarioId = @Bod;

SELECT 'P13 Mixco DESPUÉS' AS Prueba, Codigo, Existencia, StockMinimo, EstadoStock
FROM dbo.vw_InventarioActual
WHERE Bodega = 'Mixco'
ORDER BY Codigo;
-- REP-0001: 0 -> 4 (fila nueva), REP-0003: 0 -> 10, REP-0005: 0 -> 6, REP-0009 sigue en 0

SELECT 'P13 movimientos' AS Prueba, TipoMovimiento, Codigo, Cantidad, ExistenciaResultante, DocumentoOrigen, Proveedor
FROM dbo.vw_MovimientosInventario
WHERE Observacion LIKE 'Recepción de compra%'
ORDER BY MovimientoId;
GO

-- P14. Recibir la misma compra otra vez -> ERROR ESPERADO 50613
BEGIN TRY
    DECLARE @Comp INT = (SELECT CompraId  FROM dbo.Compra  WHERE Observaciones = 'Prueba T06');
    DECLARE @Bod  INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'bodega1');
    EXEC dbo.sp_RecibirCompra @CompraId = @Comp, @UsuarioId = @Bod;
    SELECT 'P14 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P14 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- P15 (T07). ROLLBACK: compra de 3 pantallas 14" para la Central y se recibe
--      con un error provocado -> ERROR ESPERADO 50615 y no cambia nada
DECLARE @Prov INT = (SELECT ProveedorId FROM dbo.Proveedor WHERE NIT = '1234567-8');
DECLARE @Cen  INT = (SELECT BodegaId    FROM dbo.Bodega    WHERE Nombre = 'Central');
DECLARE @Bod  INT = (SELECT UsuarioId   FROM dbo.Usuario   WHERE NombreUsuario = 'bodega1');
DECLARE @Pan  INT = (SELECT RepuestoId  FROM dbo.Repuesto  WHERE Codigo = 'REP-0002');
DECLARE @Json NVARCHAR(MAX) = CONCAT('[{"repuestoId":', @Pan, ',"cantidad":3,"costoUnitario":420.00}]');
DECLARE @Comp INT;

EXEC dbo.sp_RegistrarCompra @ProveedorId = @Prov, @BodegaId = @Cen, @UsuarioId = @Bod,
     @Detalle = @Json, @Observaciones = 'Prueba T07', @CompraId = @Comp OUTPUT;

DECLARE @ExistAntes INT = (SELECT Existencia FROM dbo.Inventario WHERE RepuestoId = @Pan AND BodegaId = @Cen);
DECLARE @MovAntes   INT = (SELECT COUNT(*) FROM dbo.MovimientoInventario);

BEGIN TRY
    EXEC dbo.sp_RecibirCompra @CompraId = @Comp, @UsuarioId = @Bod, @SimularError = 1;
    SELECT 'P15 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P15 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;

SELECT 'P15 después del ROLLBACK' AS Prueba,
       (SELECT Estado FROM dbo.Compra WHERE CompraId = @Comp)                                AS EstadoCompra,       -- PENDIENTE
       @ExistAntes                                                                           AS ExistenciaAntes,    -- 5
       (SELECT Existencia FROM dbo.Inventario WHERE RepuestoId = @Pan AND BodegaId = @Cen)   AS ExistenciaDespues,  -- 5
       (SELECT COUNT(*) FROM dbo.MovimientoInventario) - @MovAntes                           AS MovimientosNuevos;  -- 0
GO

-- P16 (R14). Anular la compra de la prueba T07 (no se borra, cambia a ANULADA)
DECLARE @Comp INT = (SELECT CompraId  FROM dbo.Compra  WHERE Observaciones = 'Prueba T07');
DECLARE @Bod  INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'bodega1');

EXEC dbo.sp_AnularCompra @CompraId = @Comp, @UsuarioId = @Bod,
     @Motivo = 'El proveedor no tenía existencias';
GO

-- P17. Un técnico intenta registrar una compra -> ERROR ESPERADO 50601
BEGIN TRY
    DECLARE @Prov INT = (SELECT ProveedorId FROM dbo.Proveedor WHERE NIT = '1234567-8');
    DECLARE @Cen  INT = (SELECT BodegaId    FROM dbo.Bodega    WHERE Nombre = 'Central');
    DECLARE @Tec  INT = (SELECT UsuarioId   FROM dbo.Usuario   WHERE NombreUsuario = 'tecnico1');
    EXEC dbo.sp_RegistrarCompra @ProveedorId = @Prov, @BodegaId = @Cen, @UsuarioId = @Tec,
         @Detalle = N'[{"repuestoId":1,"cantidad":1,"costoUnitario":350.00}]';
    SELECT 'P17 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P17 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- P18. Compra con cantidad 0 -> ERROR ESPERADO 50605
BEGIN TRY
    DECLARE @Prov INT = (SELECT ProveedorId FROM dbo.Proveedor WHERE NIT = '1234567-8');
    DECLARE @Cen  INT = (SELECT BodegaId    FROM dbo.Bodega    WHERE Nombre = 'Central');
    DECLARE @Bod  INT = (SELECT UsuarioId   FROM dbo.Usuario   WHERE NombreUsuario = 'bodega1');
    EXEC dbo.sp_RegistrarCompra @ProveedorId = @Prov, @BodegaId = @Cen, @UsuarioId = @Bod,
         @Detalle = N'[{"repuestoId":1,"cantidad":0,"costoUnitario":350.00}]';
    SELECT 'P18 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P18 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

/* ==========================================================
   PRECIOS HISTÓRICOS (T14)
   ========================================================== */

-- P19. Sube el precio de la RAM 8GB de Q300 a Q350: el detalle de la
--      reparación se queda en Q300 y el total de la orden no cambia
UPDATE dbo.Repuesto SET PrecioVenta = 350.00 WHERE Codigo = 'REP-0003';

SELECT 'P19 precio histórico' AS Prueba, NumeroOrden, Codigo, VentaHistorica, PrecioVentaActual,
       dbo.fn_TotalOrden(OrdenId) AS TotalOrdenSinIVA   -- sigue en 910.00
FROM dbo.vw_RepuestosUtilizados
WHERE Codigo = 'REP-0003';

UPDATE dbo.Repuesto SET PrecioVenta = 300.00 WHERE Codigo = 'REP-0003';   -- se regresa
GO

/* ==========================================================
   REPORTES (vistas)
   ========================================================== */

-- R1. Órdenes activas por estado, prioridad y técnico
SELECT NumeroOrden, Estado, Prioridad, Cliente, Equipo, NumeroSerie, TecnicoResponsable, DiasAbierta, TotalSinIVA
FROM dbo.vw_OrdenesActivas
ORDER BY EstadoOrdenId, NivelPrioridad, FechaIngreso;

-- R3. Historial técnico de un equipo por número de serie
SELECT NumeroSerie, Propietario, NumeroOrden, FechaIngreso, EstadoOrden,
       TecnicoDiagnostico, Diagnostico, TecnicoReparacion, EstadoReparacion, TrabajoRealizado
FROM dbo.vw_HistorialEquipo
WHERE NumeroSerie = 'DL-7HJK921'
ORDER BY FechaIngreso;

-- R4. Trabajo por técnico en un rango de fechas (hoy)
SELECT Tecnico, TipoTrabajo, Fecha, NumeroOrden, Cliente, ManoObra, Estado
FROM dbo.vw_TrabajoTecnicos
WHERE Fecha >= CAST(GETDATE() AS DATE)
  AND Fecha <  DATEADD(DAY, 1, CAST(GETDATE() AS DATE))
ORDER BY Tecnico, Fecha;

-- R5. Repuestos utilizados con precio histórico
SELECT NumeroOrden, Tecnico, Bodega, Codigo, Repuesto, Cantidad, CostoHistorico, VentaHistorica, VentaTotal
FROM dbo.vw_RepuestosUtilizados
ORDER BY NumeroOrden, Codigo;

-- R6. Inventario actual por bodega y categoría
SELECT Bodega, Categoria, Codigo, Repuesto, Existencia, StockMinimo, ValorInventario, EstadoStock
FROM dbo.vw_InventarioActual
ORDER BY Bodega, Categoria, Codigo;

-- R7. Repuestos en o bajo el stock mínimo
SELECT Bodega, Codigo, Repuesto, Existencia, StockMinimo, Faltante, EstadoStock
FROM dbo.vw_RepuestosBajoMinimo
ORDER BY Bodega, Codigo;

-- R8. Compras por proveedor con costo histórico
SELECT Proveedor, NumeroCompra, Estado, Bodega, Codigo, Cantidad, CostoHistorico, Subtotal
FROM dbo.vw_ComprasProveedor
ORDER BY Proveedor, NumeroCompra, Codigo;

-- R9. Movimientos con documento origen y usuario
SELECT FechaMovimiento, TipoMovimiento, Bodega, Codigo, Cantidad, ExistenciaResultante,
       TipoDocumento, DocumentoOrigen, Usuario
FROM dbo.vw_MovimientosInventario
ORDER BY MovimientoId;

-- Control final: nunca debe haber existencias negativas (R10)
SELECT COUNT(*) AS ExistenciasNegativas FROM dbo.Inventario WHERE Existencia < 0;
GO
/* Debe salir:
   P1 crea la orden de la Dell, P3 la pasa a ESPERANDO_AUTORIZACION,
   P5 a REPARACION, P10 a LISTO con TotalSinIVA = 910.00.
   P4 deja la orden de la Acer en RECIBIDO (sin diagnóstico).
   P2, P4, P7, P8, P11, P14, P15, P17 y P18 dan ERROR ESPERADO.
   P7 y P15 muestran 0 movimientos nuevos (no quedó nada a medias).
   P13: Mixco queda con REP-0001 = 4, REP-0003 = 10, REP-0005 = 6.
   P16 deja la compra de la prueba T07 en ANULADA.
   P19: VentaHistorica 300.00 y PrecioVentaActual 350.00.
   ExistenciasNegativas = 0 */
