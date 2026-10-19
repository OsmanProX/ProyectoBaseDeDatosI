/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 08: permisos por rol + vista
   Se ejecuta después del 01 y 02, y ANTES del 03
   (sp_LoginUsuario lee la tabla Permiso)
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

/* ==========================================================
   Tabla Permiso
   Cada fila dice qué puede hacer un rol en el sistema.
   ========================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Permiso')
BEGIN
    CREATE TABLE dbo.Permiso (
        PermisoId INT IDENTITY(1,1) NOT NULL,
        RolId     INT NOT NULL,
        permiso   VARCHAR(60) NOT NULL,
        activo    BIT NOT NULL DEFAULT 1,
        CONSTRAINT Permiso_PK PRIMARY KEY (PermisoId),
        CONSTRAINT Permiso_Rol_FK FOREIGN KEY (RolId)
            REFERENCES dbo.Rol(RolId) ON UPDATE CASCADE
    );
END;
GO

-- Limpieza para poder re-ejecutar el script sin duplicar
DELETE FROM dbo.Permiso;
GO

/* ==========================================================
   Permisos por rol
   ========================================================== */
-- ADMINISTRADOR: acceso total
INSERT INTO dbo.Permiso (RolId, permiso) VALUES
    (1, 'VER_ORDENES'),
    (1, 'CREAR_ORDENES'),
    (1, 'CAMBIAR_ESTADO_ORDEN'),
    (1, 'VER_USUARIOS');

-- RECEPCION: recibe equipos y registra/cambia órdenes
INSERT INTO dbo.Permiso (RolId, permiso) VALUES
    (2, 'VER_ORDENES'),
    (2, 'CREAR_ORDENES'),
    (2, 'CAMBIAR_ESTADO_ORDEN');

-- TECNICO: ve órdenes y avanza el estado (diagnóstico/reparación)
INSERT INTO dbo.Permiso (RolId, permiso) VALUES
    (3, 'VER_ORDENES'),
    (3, 'CAMBIAR_ESTADO_ORDEN');

-- BODEGA: solo consulta órdenes (necesita ver repuestos usados)
INSERT INTO dbo.Permiso (RolId, permiso) VALUES
    (4, 'VER_ORDENES');

-- CAJA: solo consulta órdenes (facturación y pagos)
INSERT INTO dbo.Permiso (RolId, permiso) VALUES
    (5, 'VER_ORDENES');
GO

/* ==========================================================
   vw_Permiso: permisos con el nombre del rol
   ========================================================== */
CREATE OR ALTER VIEW dbo.vw_Permiso
AS
    SELECT p.PermisoId,
           p.RolId,
           r.Nombre AS Rol,
           p.permiso,
           p.activo
    FROM dbo.Permiso p
    INNER JOIN dbo.Rol r ON r.RolId = p.RolId;
GO

/* ==========================================================
   vw_UsuarioPermiso: qué puede hacer cada usuario
   (usuario x rol x permiso activo)
   ========================================================== */
CREATE OR ALTER VIEW dbo.vw_UsuarioPermiso
AS
    SELECT u.UsuarioId,
           u.NombreUsuario,
           u.NombreCompleto,
           u.Correo,
           r.Nombre AS Rol,
           p.permiso
    FROM dbo.Usuario u
    INNER JOIN dbo.UsuarioRol ur ON ur.UsuarioId = u.UsuarioId
    INNER JOIN dbo.Rol r ON r.RolId = ur.RolId
    INNER JOIN dbo.Permiso p ON p.RolId = r.RolId AND p.activo = 1
    WHERE u.Activo = 1;
GO

-- Verificación
-- SELECT * FROM dbo.vw_Permiso ORDER BY RolId, PermisoId;
-- SELECT * FROM dbo.vw_UsuarioPermiso ORDER BY UsuarioId, Rol, permiso;
