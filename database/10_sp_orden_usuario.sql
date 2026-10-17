/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 10: SP y vista para el listado de órdenes y usuarios
   Siguiente de 01..09:
     - Crear orden    -> ya existe dbo.sp_RegistrarOrden   (03)
     - Actualizar orden (estado + historial) -> dbo.sp_CambiarEstadoOrden (03/06)
   Este script agrega lo que falta:
     - sp_ListarOrdenes: listado con cliente, equipo, estado y recepcionista
     - vw_UsuarioLista: usuarios con sus roles (para la vista de usuarios)
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   sp_ListarOrdenes
   Lista las órdenes con datos de cliente, equipo, recibidor y estado.
   @Buscar: filtra por número de orden, cliente o número de serie.
   @Estado: código de estado (RECIBIDO, DIAGNOSTICO, ...) o 'ABIERTAS'
            (= todas menos ENTREGADO y CANCELADO). NULL = todas.
   Los nombres de columnas coinciden con lo que usa el frontend.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_ListarOrdenes
    @Buscar VARCHAR(100) = NULL,
    @Estado VARCHAR(30)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EstadoOrdenId INT = NULL;

    -- @Estado puede venir como código exacto o como 'ABIERTAS'
    IF @Estado IS NOT NULL AND @Estado <> 'ABIERTAS'
        SELECT @EstadoOrdenId = EstadoOrdenId
        FROM dbo.EstadoOrden WHERE Codigo = @Estado;

    IF @Estado IS NOT NULL AND @Estado <> 'ABIERTAS' AND @EstadoOrdenId IS NULL
        THROW 50321, 'El estado indicado no existe. Use un código de EstadoOrden o ABIERTAS.', 1;

    SELECT o.OrdenId,
           o.NumeroOrden,
           o.ClienteId,
           c.NombreRazonSocial            AS Cliente,
           o.EquipoId,
           t.Nombre                       AS TipoEquipo,
           e.Marca + ' ' + e.Modelo       AS Equipo,
           e.NumeroSerie,
           u.NombreCompleto               AS RecibidoPor,
           o.FechaIngreso,
           o.FechaEstimada,
           o.Prioridad,
           o.EstadoOrdenId                AS EstadoId,
           eo.Codigo                      AS Estado,
           o.ProblemaReportado,
           o.Observaciones
    FROM dbo.OrdenServicio o
    INNER JOIN dbo.Cliente c      ON c.ClienteId      = o.ClienteId
    INNER JOIN dbo.Equipo e       ON e.EquipoId       = o.EquipoId
    INNER JOIN dbo.TipoEquipo t   ON t.TipoEquipoId   = e.TipoEquipoId
    INNER JOIN dbo.EstadoOrden eo ON eo.EstadoOrdenId = o.EstadoOrdenId
    INNER JOIN dbo.Usuario u      ON u.UsuarioId      = o.UsuarioRecepcionId
    WHERE ( @Estado IS NULL OR ( @Estado = 'ABIERTAS' AND o.EstadoOrdenId NOT IN (6, 7) )
            OR ( @Estado <> 'ABIERTAS' AND o.EstadoOrdenId = @EstadoOrdenId ) )
      AND ( @Buscar IS NULL OR @Buscar = ''
            OR o.NumeroOrden LIKE '%' + @Buscar + '%'
            OR c.NombreRazonSocial LIKE '%' + @Buscar + '%'
            OR e.NumeroSerie LIKE '%' + @Buscar + '%' )
    ORDER BY o.OrdenId DESC;
END;
GO

/* ==========================================================
   vw_UsuarioLista
   Usuarios del sistema con sus roles concatenados.
   Alimenta GET api/usuario (vista "Usuarios" del frontend).
   ========================================================== */
CREATE OR ALTER VIEW dbo.vw_UsuarioLista
AS
    SELECT u.UsuarioId,
           u.NombreUsuario,
           u.NombreCompleto,
           u.Correo,
           u.Telefono,
           u.Activo,
           (SELECT STRING_AGG(r.Nombre, ', ') WITHIN GROUP (ORDER BY r.RolId)
            FROM dbo.UsuarioRol ur
            INNER JOIN dbo.Rol r ON r.RolId = ur.RolId
            WHERE ur.UsuarioId = u.UsuarioId) AS Roles
    FROM dbo.Usuario u;
GO

-- Verificación (en la base ejecutar descomentado):
-- EXEC dbo.sp_ListarOrdenes;                             -- todas
-- EXEC dbo.sp_ListarOrdenes @Estado = 'ABIERTAS';        -- abiertas (sin ENTREGADO/CANCELADO)
-- EXEC dbo.sp_ListarOrdenes @Estado = 'RECIBIDO';        -- por código de estado
-- EXEC dbo.sp_ListarOrdenes @Buscar = 'HP5CD';           -- por cliente/número/serie
-- SELECT UsuarioId, NombreUsuario, NombreCompleto, Roles, Activo FROM dbo.vw_UsuarioLista;
-- SELECT name FROM sys.objects WHERE name IN ('sp_ListarOrdenes', 'vw_UsuarioLista');
