/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Pruebas de los procedimientos del script 03
   Se corre una sola vez después de 01, 02 y 03.
   Las pruebas marcadas como ERROR ESPERADO tienen que fallar.
   ========================================================== */

-- USE TechCare;
-- GO

SET NOCOUNT ON;
GO

-- P1. Registrar una orden (debe crear OS-AAAA-0001)
DECLARE @Cli INT = (SELECT ClienteId FROM dbo.Cliente WHERE NombreRazonSocial = 'Juan Carlos Méndez');
DECLARE @Eq  INT = (SELECT EquipoId  FROM dbo.Equipo  WHERE NumeroSerie = 'HP5CD1234XYZ');
DECLARE @Rec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion1');
DECLARE @Id INT, @Num VARCHAR(15);

EXEC dbo.sp_RegistrarOrden
     @ClienteId = @Cli, @EquipoId = @Eq, @UsuarioRecepcionId = @Rec,
     @ProblemaReportado = 'La laptop no enciende, se apagó de golpe.',
     @Prioridad = 'ALTA',
     @OrdenId = @Id OUTPUT, @NumeroOrden = @Num OUTPUT;

SELECT 'P1 OK' AS Prueba, @Id AS OrdenId, @Num AS NumeroOrden;
GO

-- P2. Misma laptop otra vez -> ERROR ESPERADO 50108
BEGIN TRY
    DECLARE @Cli INT = (SELECT ClienteId FROM dbo.Cliente WHERE NombreRazonSocial = 'Juan Carlos Méndez');
    DECLARE @Eq  INT = (SELECT EquipoId  FROM dbo.Equipo  WHERE NumeroSerie = 'HP5CD1234XYZ');
    DECLARE @Rec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion1');
    EXEC dbo.sp_RegistrarOrden @ClienteId = @Cli, @EquipoId = @Eq, @UsuarioRecepcionId = @Rec,
         @ProblemaReportado = 'Prueba duplicada';
    SELECT 'P2 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P2 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- P3. Equipo de otro cliente -> ERROR ESPERADO 50106
BEGIN TRY
    DECLARE @Cli INT = (SELECT ClienteId FROM dbo.Cliente WHERE NombreRazonSocial = 'Juan Carlos Méndez');
    DECLARE @Eq  INT = (SELECT EquipoId  FROM dbo.Equipo  WHERE NumeroSerie = 'DL-7HJK921');   -- es de Comercial El Progreso
    DECLARE @Rec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion1');
    EXEC dbo.sp_RegistrarOrden @ClienteId = @Cli, @EquipoId = @Eq, @UsuarioRecepcionId = @Rec,
         @ProblemaReportado = 'Prueba equipo ajeno';
    SELECT 'P3 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P3 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- P4. Técnico pasa la orden a DIAGNOSTICO (OK)
DECLARE @Ord INT = (SELECT o.OrdenId FROM dbo.OrdenServicio o
                    JOIN dbo.Equipo e ON e.EquipoId = o.EquipoId
                    WHERE e.NumeroSerie = 'HP5CD1234XYZ' AND o.EstadoOrdenId NOT IN (6, 7));
DECLARE @Tec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'tecnico1');

EXEC dbo.sp_CambiarEstadoOrden @OrdenId = @Ord, @EstadoNuevoId = 2, @UsuarioId = @Tec,
     @Observacion = 'Inicia revisión del equipo';
GO

-- P5. Pasar a ESPERANDO_AUTORIZACION sin diagnóstico -> ERROR ESPERADO 50209
BEGIN TRY
    DECLARE @Ord INT = (SELECT o.OrdenId FROM dbo.OrdenServicio o
                        JOIN dbo.Equipo e ON e.EquipoId = o.EquipoId
                        WHERE e.NumeroSerie = 'HP5CD1234XYZ' AND o.EstadoOrdenId NOT IN (6, 7));
    DECLARE @Tec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'tecnico1');
    EXEC dbo.sp_CambiarEstadoOrden @OrdenId = @Ord, @EstadoNuevoId = 3, @UsuarioId = @Tec;
    SELECT 'P5 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P5 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- P6. Caja intenta cancelar -> ERROR ESPERADO 50204 (sin permiso)
BEGIN TRY
    DECLARE @Ord INT = (SELECT o.OrdenId FROM dbo.OrdenServicio o
                        JOIN dbo.Equipo e ON e.EquipoId = o.EquipoId
                        WHERE e.NumeroSerie = 'HP5CD1234XYZ' AND o.EstadoOrdenId NOT IN (6, 7));
    DECLARE @Caja INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'caja1');
    EXEC dbo.sp_CambiarEstadoOrden @OrdenId = @Ord, @EstadoNuevoId = 7, @UsuarioId = @Caja,
         @Observacion = 'Prueba sin permiso';
    SELECT 'P6 FALLÓ: debía rechazarse' AS Prueba;
END TRY
BEGIN CATCH
    SELECT 'P6 ERROR ESPERADO' AS Prueba, ERROR_NUMBER() AS Codigo, ERROR_MESSAGE() AS Mensaje;
END CATCH;
GO

-- P7. Segunda orden (Lucía) y Recepción la cancela con motivo (OK)
DECLARE @Cli INT = (SELECT ClienteId FROM dbo.Cliente WHERE NombreRazonSocial = 'Lucía Hernández');
DECLARE @Eq  INT = (SELECT EquipoId  FROM dbo.Equipo  WHERE NumeroSerie = 'LNV-PF3ABC12');
DECLARE @Rec INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion1');
DECLARE @Id INT, @Num VARCHAR(15);

EXEC dbo.sp_RegistrarOrden @ClienteId = @Cli, @EquipoId = @Eq, @UsuarioRecepcionId = @Rec,
     @ProblemaReportado = 'Teclado no responde', @OrdenId = @Id OUTPUT, @NumeroOrden = @Num OUTPUT;

EXEC dbo.sp_CambiarEstadoOrden @OrdenId = @Id, @EstadoNuevoId = 7, @UsuarioId = @Rec,
     @Observacion = 'El cliente decidió no reparar';
GO

-- Consultas para ver las órdenes y su historial

-- C1. Órdenes con cliente, equipo, tipo, recepción y estado actual
SELECT o.NumeroOrden,
       c.NombreRazonSocial      AS Cliente,
       te.Nombre                AS TipoEquipo,
       e.Marca + ' ' + e.Modelo AS Equipo,
       e.NumeroSerie,
       u.NombreCompleto         AS RecibidoPor,
       o.FechaIngreso,
       o.Prioridad,
       eo.Codigo                AS EstadoActual
FROM dbo.OrdenServicio o
JOIN dbo.Cliente     c  ON c.ClienteId       = o.ClienteId
JOIN dbo.Equipo      e  ON e.EquipoId        = o.EquipoId
JOIN dbo.TipoEquipo  te ON te.TipoEquipoId   = e.TipoEquipoId
JOIN dbo.Usuario     u  ON u.UsuarioId       = o.UsuarioRecepcionId
JOIN dbo.EstadoOrden eo ON eo.EstadoOrdenId  = o.EstadoOrdenId
ORDER BY o.NumeroOrden;

-- C2. Historial de estados (LEFT JOIN porque el primer cambio no tiene estado anterior)
SELECT o.NumeroOrden,
       h.FechaCambio,
       ISNULL(ea.Codigo, '(inicio)') AS EstadoAnterior,
       en.Codigo                     AS EstadoNuevo,
       u.NombreUsuario               AS Usuario,
       h.Observacion
FROM dbo.HistorialEstadoOrden h
JOIN dbo.OrdenServicio    o  ON o.OrdenId        = h.OrdenId
LEFT JOIN dbo.EstadoOrden ea ON ea.EstadoOrdenId = h.EstadoAnteriorId
JOIN dbo.EstadoOrden      en ON en.EstadoOrdenId = h.EstadoNuevoId
JOIN dbo.Usuario          u  ON u.UsuarioId      = h.UsuarioId
ORDER BY o.NumeroOrden, h.HistorialId;
GO
-- Debe salir: P1 crea OS-AAAA-0001, P2/P3/P5/P6 dan error, P4 pasa a DIAGNOSTICO,
-- P7 crea OS-AAAA-0002 y la cancela. C1 muestra 2 órdenes y C2 4 cambios.
