/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 08: permisos por rol + vistas
   Se ejecuta después del 01 y 02, y ANTES del 03
   (sp_LoginUsuario lee los permisos del usuario)

   Modelo (enunciado 2.1: "si se implementan permisos
   específicos, deberán modelarse relacionalmente"):
     Permiso     catálogo: cada permiso existe UNA sola vez
     RolPermiso  tabla asociativa N:M entre Rol y Permiso
                 (un rol tiene varios permisos y un permiso
                 lo pueden tener varios roles)
   Así el nombre del permiso no se repite por cada rol (2FN/3FN)
   y la llave compuesta (RolId, PermisoId) impide duplicados.
   El CHECK obliga a códigos en MAYÚSCULAS y guion bajo
   (COLLATE binario, porque la base no distingue mayúsculas).
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   Se borran y se vuelven a crear (son catálogos fijos,
   el script se puede volver a ejecutar sin duplicar).
   Primero las vistas y la tabla hija, después el catálogo.
   ========================================================== */
DROP VIEW IF EXISTS dbo.vw_UsuarioPermiso;
DROP VIEW IF EXISTS dbo.vw_Permiso;
DROP TABLE IF EXISTS dbo.RolPermiso;
DROP TABLE IF EXISTS dbo.Permiso;
GO

/* ==========================================================
   Tabla Permiso (catálogo)
   ========================================================== */
CREATE TABLE dbo.Permiso (
    PermisoId   INT IDENTITY(1,1) NOT NULL,
    Codigo      VARCHAR(60)  NOT NULL,
    Descripcion VARCHAR(150) NULL,
    Activo      BIT          NOT NULL CONSTRAINT DF_Permiso_Activo DEFAULT (1),
    CONSTRAINT PK_Permiso        PRIMARY KEY (PermisoId),
    CONSTRAINT UQ_Permiso_Codigo UNIQUE (Codigo),
    CONSTRAINT CK_Permiso_Codigo CHECK (LEN(Codigo) >= 3 AND Codigo NOT LIKE '%[^A-Z_]%' COLLATE Latin1_General_BIN)
);
GO

/* ==========================================================
   Tabla RolPermiso (asociativa Rol N:M Permiso)
   FK con NO ACTION, igual que todas las del modelo (R14).
   ========================================================== */
CREATE TABLE dbo.RolPermiso (
    RolId     INT NOT NULL,
    PermisoId INT NOT NULL,
    CONSTRAINT PK_RolPermiso         PRIMARY KEY (RolId, PermisoId),
    CONSTRAINT FK_RolPermiso_Rol     FOREIGN KEY (RolId)     REFERENCES dbo.Rol (RolId)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_RolPermiso_Permiso FOREIGN KEY (PermisoId) REFERENCES dbo.Permiso (PermisoId)
        ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

/* ==========================================================
   Catálogo de permisos
   ========================================================== */
INSERT INTO dbo.Permiso (Codigo, Descripcion) VALUES
    ('VER_ORDENES',          'Ver el listado y el detalle de las órdenes de servicio'),
    ('CREAR_ORDENES',        'Registrar una orden de servicio al recibir un equipo'),
    ('CAMBIAR_ESTADO_ORDEN', 'Cambiar el estado de una orden (guarda historial)'),
    ('VER_USUARIOS',         'Ver y administrar los usuarios del sistema');
GO

/* ==========================================================
   Permisos por rol (se buscan por nombre, no por número)
     ADMINISTRADOR  todos
     RECEPCION      ver, crear y cambiar estado (cancelar)
     TECNICO        ver y cambiar estado (diagnóstico/reparación)
     BODEGA         ver (necesita los repuestos usados)
     CAJA           ver (facturación y pagos)
   ========================================================== */
INSERT INTO dbo.RolPermiso (RolId, PermisoId)
SELECT r.RolId, p.PermisoId
FROM (VALUES
        ('ADMINISTRADOR', 'VER_ORDENES'),
        ('ADMINISTRADOR', 'CREAR_ORDENES'),
        ('ADMINISTRADOR', 'CAMBIAR_ESTADO_ORDEN'),
        ('ADMINISTRADOR', 'VER_USUARIOS'),
        ('RECEPCION',     'VER_ORDENES'),
        ('RECEPCION',     'CREAR_ORDENES'),
        ('RECEPCION',     'CAMBIAR_ESTADO_ORDEN'),
        ('TECNICO',       'VER_ORDENES'),
        ('TECNICO',       'CAMBIAR_ESTADO_ORDEN'),
        ('BODEGA',        'VER_ORDENES'),
        ('CAJA',          'VER_ORDENES')
     ) AS v (Rol, Codigo)
INNER JOIN dbo.Rol r     ON r.Nombre = v.Rol
INNER JOIN dbo.Permiso p ON p.Codigo = v.Codigo;
GO

/* ==========================================================
   vw_Permiso: permisos de cada rol con su nombre
   ========================================================== */
CREATE OR ALTER VIEW dbo.vw_Permiso
AS
    SELECT p.PermisoId,
           rp.RolId,
           r.Nombre      AS Rol,
           p.Codigo      AS Permiso,
           p.Descripcion,
           p.Activo
    FROM dbo.RolPermiso rp
    INNER JOIN dbo.Rol r     ON r.RolId     = rp.RolId
    INNER JOIN dbo.Permiso p ON p.PermisoId = rp.PermisoId;
GO

/* ==========================================================
   vw_UsuarioPermiso: qué puede hacer cada usuario activo
   (Usuario -> UsuarioRol -> Rol -> RolPermiso -> Permiso)
   ========================================================== */
CREATE OR ALTER VIEW dbo.vw_UsuarioPermiso
AS
    SELECT u.UsuarioId,
           u.NombreUsuario,
           u.NombreCompleto,
           u.Correo,
           r.Nombre AS Rol,
           p.Codigo AS Permiso
    FROM dbo.Usuario u
    INNER JOIN dbo.UsuarioRol ur ON ur.UsuarioId = u.UsuarioId
    INNER JOIN dbo.Rol r         ON r.RolId      = ur.RolId
    INNER JOIN dbo.RolPermiso rp ON rp.RolId     = r.RolId
    INNER JOIN dbo.Permiso p     ON p.PermisoId  = rp.PermisoId AND p.Activo = 1
    WHERE u.Activo = 1;
GO

-- Verificación
-- SELECT Rol, Permiso FROM dbo.vw_Permiso ORDER BY RolId, Permiso;
-- SELECT NombreUsuario, Rol, Permiso FROM dbo.vw_UsuarioPermiso ORDER BY UsuarioId, Permiso;
