/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 00: SCRIPT MAESTRO
   Crea toda la base desde cero en una sola ejecución, en este orden:
      1. 01_tablas.sql                      Tablas, llaves primarias y foráneas, UNIQUE, CHECK y DEFAULT
      2. 02_datos_iniciales.sql             Catálogos y datos iniciales
      3. 08_permisos.sql                    Permisos por rol (antes del 03: el login los lee)
      4. 03_procedimientos.sql              Órdenes y login
      5. 04_procesos.sql                    Diagnóstico, reparación, repuestos, compras y vistas de reportes
      6. 05_datos_prueba.sql                Datos de prueba (cantidades mínimas y escenarios del enunciado)
      7. 06_facturacion.sql                 Facturación, pagos y entrega
      8. 07_triggers_indices_reportes.sql   Triggers, índices no agrupados y reportes finales
      9. 09_clientes_equipos_ordenes.sql    Clientes, equipos y órdenes (vistas y SP)
     10. 10_sp_orden_usuario.sql            Listado de órdenes y usuarios
     11. 11_sp_cliente_equipo.sql           CRUD de clientes y equipos
     12. 12_mantenimientos.sql              Mantenimientos (repuestos, proveedores, bodegas, catálogos, usuarios)

   ÍNDICE POR TIPO DE OBJETO (cantidad y script donde está)
     Tablas           29  en los scripts: 01 (27), 08 (2)
     Restricciones   160  en los scripts: 01 (153), 08 (7)
     Índices          14  en los scripts: 01 (1), 07 (13)
     Vistas           20  en los scripts: 08 (2), 04 (8), 07 (6), 09 (3), 10 (1)
     Funciones         4  en los scripts: 04 (3), 07 (1)
     Procedimientos   39  en los scripts: 03 (3), 04 (8), 06 (4), 07 (1), 09 (2), 10 (1), 11 (6), 12 (15)
     Triggers         10  en los scripts: 07 (10)
   Cada sección de abajo empieza con la lista de sus objetos por tipo.

   ATENCIÓN: el script 01 BORRA todas las tablas si ya existen.
   Instancia local (Docker): descomentar las 4 líneas de abajo.
   SmarterASP: dejarlas comentadas (la base ya está seleccionada).
   Archivo generado juntando los scripts en ese orden; si se cambia
   uno de ellos, hay que volver a generar este archivo.
   ========================================================== */

-- IF DB_ID('TechCare') IS NULL CREATE DATABASE TechCare;
-- GO
-- USE TechCare;
-- GO


/* ##########################################################
    1/12  01_tablas.sql
   Tablas, llaves primarias y foráneas, UNIQUE, CHECK y DEFAULT
   Tablas (27): Rol, Usuario, UsuarioRol, Cliente, TipoEquipo, Equipo, EstadoOrden, OrdenServicio,
       HistorialEstadoOrden, Diagnostico, Reparacion, ActividadReparacion, Categoria, Repuesto,
       Bodega, Inventario, ReparacionRepuesto, AuditoriaPrecio, Proveedor, ProveedorRepuesto,
       Compra, DetalleCompra, MovimientoInventario, MetodoPago, Factura, Pago, Entrega
   Restricciones (153): DF 36, PK 27, UQ 18, FK 42, CK 30
   Índices (1): UX_Cliente_NIT
   ########################################################## */
PRINT '>> 1/12 01_tablas.sql';
GO

/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 01: creación de las 27 tablas
   ========================================================== */

-- Crear la base (solo en Docker; en SmarterASP no se ejecuta)
-- IF DB_ID('TechCare') IS NULL CREATE DATABASE TechCare;
-- GO
-- USE TechCare;
-- GO

-- Llaves foráneas: todas con ON DELETE NO ACTION ON UPDATE NO ACTION, a propósito.
--   R14: la información transaccional no se borra; se cancela o anula. Un CASCADE
--   borraría en cadena órdenes, pagos o movimientos; con NO ACTION la base rechaza
--   (error 547) borrar un padre que tiene hijos. Las llaves son IDENTITY y no cambian,
--   por eso tampoco se propaga el UPDATE.

-- Borrar las tablas si ya existen (al revés, por las llaves foráneas)
-- RolPermiso y Permiso (script 08) apuntan a Rol, por eso se borran primero
DROP TABLE IF EXISTS dbo.RolPermiso;
DROP TABLE IF EXISTS dbo.Permiso;
DROP TABLE IF EXISTS dbo.Entrega;
DROP TABLE IF EXISTS dbo.Pago;
DROP TABLE IF EXISTS dbo.Factura;
DROP TABLE IF EXISTS dbo.MetodoPago;
DROP TABLE IF EXISTS dbo.MovimientoInventario;
DROP TABLE IF EXISTS dbo.DetalleCompra;
DROP TABLE IF EXISTS dbo.Compra;
DROP TABLE IF EXISTS dbo.ProveedorRepuesto;
DROP TABLE IF EXISTS dbo.Proveedor;
DROP TABLE IF EXISTS dbo.AuditoriaPrecio;
DROP TABLE IF EXISTS dbo.ReparacionRepuesto;
DROP TABLE IF EXISTS dbo.Inventario;
DROP TABLE IF EXISTS dbo.Bodega;
DROP TABLE IF EXISTS dbo.Repuesto;
DROP TABLE IF EXISTS dbo.Categoria;
DROP TABLE IF EXISTS dbo.ActividadReparacion;
DROP TABLE IF EXISTS dbo.Reparacion;
DROP TABLE IF EXISTS dbo.Diagnostico;
DROP TABLE IF EXISTS dbo.HistorialEstadoOrden;
DROP TABLE IF EXISTS dbo.OrdenServicio;
DROP TABLE IF EXISTS dbo.EstadoOrden;
DROP TABLE IF EXISTS dbo.Equipo;
DROP TABLE IF EXISTS dbo.TipoEquipo;
DROP TABLE IF EXISTS dbo.Cliente;
DROP TABLE IF EXISTS dbo.UsuarioRol;
DROP TABLE IF EXISTS dbo.Usuario;
DROP TABLE IF EXISTS dbo.Rol;
GO

-- ========== Seguridad, clientes y equipos ==========

-- 1. Rol
CREATE TABLE dbo.Rol (
    RolId        INT IDENTITY(1,1) NOT NULL,
    Nombre       VARCHAR(30)  NOT NULL,
    Descripcion  VARCHAR(100) NULL,
    Activo       BIT          NOT NULL CONSTRAINT DF_Rol_Activo DEFAULT (1),
    CONSTRAINT PK_Rol PRIMARY KEY (RolId),
    CONSTRAINT UQ_Rol_Nombre UNIQUE (Nombre)
);
GO

-- 2. Usuario
CREATE TABLE dbo.Usuario (
    UsuarioId       INT IDENTITY(1,1) NOT NULL,
    NombreUsuario   VARCHAR(30)  NOT NULL,
    ContrasenaHash  VARCHAR(255) NOT NULL,   -- se guarda en hash
    NombreCompleto  VARCHAR(100) NOT NULL,
    Correo          VARCHAR(100) NOT NULL,
    Telefono        VARCHAR(15)  NULL,
    Activo          BIT          NOT NULL CONSTRAINT DF_Usuario_Activo DEFAULT (1),
    FechaCreacion   DATETIME     NOT NULL CONSTRAINT DF_Usuario_FechaCreacion DEFAULT (GETDATE()),
    CONSTRAINT PK_Usuario PRIMARY KEY (UsuarioId),
    CONSTRAINT UQ_Usuario_NombreUsuario UNIQUE (NombreUsuario),
    CONSTRAINT UQ_Usuario_Correo UNIQUE (Correo)
);
GO

-- 3. UsuarioRol (un usuario puede tener varios roles)
CREATE TABLE dbo.UsuarioRol (
    UsuarioId        INT      NOT NULL,
    RolId            INT      NOT NULL,
    FechaAsignacion  DATETIME NOT NULL CONSTRAINT DF_UsuarioRol_Fecha DEFAULT (GETDATE()),
    CONSTRAINT PK_UsuarioRol PRIMARY KEY (UsuarioId, RolId),
    CONSTRAINT FK_UsuarioRol_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuario (UsuarioId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_UsuarioRol_Rol     FOREIGN KEY (RolId)     REFERENCES dbo.Rol (RolId) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- 4. Cliente
CREATE TABLE dbo.Cliente (
    ClienteId          INT IDENTITY(1,1) NOT NULL,
    TipoCliente        VARCHAR(15)  NOT NULL,
    NombreRazonSocial  VARCHAR(150) NOT NULL,
    NIT                VARCHAR(15)  NOT NULL,
    Telefono           VARCHAR(15)  NOT NULL,
    Correo             VARCHAR(100) NULL,
    Direccion          VARCHAR(200) NULL,
    Estado             VARCHAR(10)  NOT NULL CONSTRAINT DF_Cliente_Estado DEFAULT ('ACTIVO'),
    FechaRegistro      DATETIME     NOT NULL CONSTRAINT DF_Cliente_FechaRegistro DEFAULT (GETDATE()),
    CONSTRAINT PK_Cliente PRIMARY KEY (ClienteId),
    CONSTRAINT CK_Cliente_TipoCliente CHECK (TipoCliente IN ('INDIVIDUAL','EMPRESARIAL')),
    CONSTRAINT CK_Cliente_Estado      CHECK (Estado IN ('ACTIVO','INACTIVO'))
);
GO
-- El NIT no se repite, menos 'CF' (consumidor final)
CREATE UNIQUE NONCLUSTERED INDEX UX_Cliente_NIT ON dbo.Cliente (NIT) WHERE NIT <> 'CF';
GO

-- 5. TipoEquipo
CREATE TABLE dbo.TipoEquipo (
    TipoEquipoId  INT IDENTITY(1,1) NOT NULL,
    Nombre        VARCHAR(50) NOT NULL,
    CONSTRAINT PK_TipoEquipo PRIMARY KEY (TipoEquipoId),
    CONSTRAINT UQ_TipoEquipo_Nombre UNIQUE (Nombre)
);
GO

-- 6. Equipo
CREATE TABLE dbo.Equipo (
    EquipoId      INT IDENTITY(1,1) NOT NULL,
    ClienteId     INT          NOT NULL,
    TipoEquipoId  INT          NOT NULL,
    Marca         VARCHAR(50)  NOT NULL,
    Modelo        VARCHAR(50)  NOT NULL,
    NumeroSerie   VARCHAR(50)  NOT NULL,
    Descripcion   VARCHAR(200) NULL,
    Estado        VARCHAR(10)  NOT NULL CONSTRAINT DF_Equipo_Estado DEFAULT ('ACTIVO'),
    CONSTRAINT PK_Equipo PRIMARY KEY (EquipoId),
    CONSTRAINT UQ_Equipo_NumeroSerie UNIQUE (NumeroSerie),
    CONSTRAINT FK_Equipo_Cliente    FOREIGN KEY (ClienteId)    REFERENCES dbo.Cliente (ClienteId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Equipo_TipoEquipo FOREIGN KEY (TipoEquipoId) REFERENCES dbo.TipoEquipo (TipoEquipoId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Equipo_Estado CHECK (Estado IN ('ACTIVO','INACTIVO'))
);
GO

-- ========== Órdenes de servicio ==========

-- 7. EstadoOrden (los estados van con Id fijo del 1 al 7)
CREATE TABLE dbo.EstadoOrden (
    EstadoOrdenId  INT          NOT NULL,
    Codigo         VARCHAR(30)  NOT NULL,
    Descripcion    VARCHAR(100) NULL,
    CONSTRAINT PK_EstadoOrden PRIMARY KEY (EstadoOrdenId),
    CONSTRAINT UQ_EstadoOrden_Codigo UNIQUE (Codigo)
);
GO

-- 8. OrdenServicio
CREATE TABLE dbo.OrdenServicio (
    OrdenId             INT IDENTITY(1,1) NOT NULL,
    NumeroOrden         VARCHAR(15)  NOT NULL,
    ClienteId           INT          NOT NULL,   -- cliente que trajo el equipo
    EquipoId            INT          NOT NULL,
    UsuarioRecepcionId  INT          NOT NULL,
    FechaIngreso        DATETIME     NOT NULL CONSTRAINT DF_Orden_FechaIngreso DEFAULT (GETDATE()),
    ProblemaReportado   VARCHAR(500) NOT NULL,
    Prioridad           VARCHAR(10)  NOT NULL CONSTRAINT DF_Orden_Prioridad DEFAULT ('MEDIA'),
    EstadoOrdenId       INT          NOT NULL CONSTRAINT DF_Orden_Estado DEFAULT (1),   -- 1 = RECIBIDO
    FechaEstimada       DATE         NULL,
    Observaciones       VARCHAR(500) NULL,
    CONSTRAINT PK_OrdenServicio PRIMARY KEY (OrdenId),
    CONSTRAINT UQ_OrdenServicio_NumeroOrden UNIQUE (NumeroOrden),
    CONSTRAINT FK_Orden_Cliente     FOREIGN KEY (ClienteId)          REFERENCES dbo.Cliente (ClienteId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Orden_Equipo      FOREIGN KEY (EquipoId)           REFERENCES dbo.Equipo (EquipoId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Orden_Usuario     FOREIGN KEY (UsuarioRecepcionId) REFERENCES dbo.Usuario (UsuarioId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Orden_EstadoOrden FOREIGN KEY (EstadoOrdenId)      REFERENCES dbo.EstadoOrden (EstadoOrdenId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Orden_Prioridad CHECK (Prioridad IN ('BAJA','MEDIA','ALTA','URGENTE'))
);
GO

-- 9. HistorialEstadoOrden
CREATE TABLE dbo.HistorialEstadoOrden (
    HistorialId       INT IDENTITY(1,1) NOT NULL,
    OrdenId           INT          NOT NULL,
    EstadoAnteriorId  INT          NULL,      -- va NULL en el primer registro
    EstadoNuevoId     INT          NOT NULL,
    FechaCambio       DATETIME     NOT NULL CONSTRAINT DF_Historial_FechaCambio DEFAULT (GETDATE()),
    UsuarioId         INT          NOT NULL,
    Observacion       VARCHAR(300) NULL,
    CONSTRAINT PK_HistorialEstadoOrden PRIMARY KEY (HistorialId),
    CONSTRAINT FK_Historial_Orden          FOREIGN KEY (OrdenId)          REFERENCES dbo.OrdenServicio (OrdenId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Historial_EstadoAnterior FOREIGN KEY (EstadoAnteriorId) REFERENCES dbo.EstadoOrden (EstadoOrdenId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Historial_EstadoNuevo    FOREIGN KEY (EstadoNuevoId)    REFERENCES dbo.EstadoOrden (EstadoOrdenId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Historial_Usuario        FOREIGN KEY (UsuarioId)        REFERENCES dbo.Usuario (UsuarioId) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ========== Diagnóstico y reparación ==========

-- 10. Diagnostico (uno por orden)
CREATE TABLE dbo.Diagnostico (
    DiagnosticoId          INT IDENTITY(1,1) NOT NULL,
    OrdenId                INT           NOT NULL,
    TecnicoId              INT           NOT NULL,   -- usuario con rol técnico
    FechaDiagnostico       DATETIME      NOT NULL CONSTRAINT DF_Diagnostico_Fecha DEFAULT (GETDATE()),
    Descripcion            VARCHAR(500)  NOT NULL,
    CostoManoObraEstimado  DECIMAL(10,2) NOT NULL CONSTRAINT DF_Diagnostico_Costo DEFAULT (0),
    Observaciones          VARCHAR(300)  NULL,
    CONSTRAINT PK_Diagnostico PRIMARY KEY (DiagnosticoId),
    CONSTRAINT UQ_Diagnostico_Orden UNIQUE (OrdenId),
    CONSTRAINT FK_Diagnostico_Orden   FOREIGN KEY (OrdenId)   REFERENCES dbo.OrdenServicio (OrdenId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Diagnostico_Tecnico FOREIGN KEY (TecnicoId) REFERENCES dbo.Usuario (UsuarioId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Diagnostico_Costo CHECK (CostoManoObraEstimado >= 0)
);
GO

-- 11. Reparacion (una por diagnóstico)
CREATE TABLE dbo.Reparacion (
    ReparacionId        INT IDENTITY(1,1) NOT NULL,
    DiagnosticoId       INT           NOT NULL,
    TecnicoId           INT           NOT NULL,
    FechaInicio         DATETIME      NOT NULL CONSTRAINT DF_Reparacion_FechaInicio DEFAULT (GETDATE()),
    FechaFin            DATETIME      NULL,       -- NULL mientras no se termina
    DescripcionTrabajo  VARCHAR(500)  NULL,
    CostoManoObra       DECIMAL(10,2) NOT NULL CONSTRAINT DF_Reparacion_Costo DEFAULT (0),
    Estado              VARCHAR(12)   NOT NULL CONSTRAINT DF_Reparacion_Estado DEFAULT ('EN_PROCESO'),
    CONSTRAINT PK_Reparacion PRIMARY KEY (ReparacionId),
    CONSTRAINT UQ_Reparacion_Diagnostico UNIQUE (DiagnosticoId),
    CONSTRAINT FK_Reparacion_Diagnostico FOREIGN KEY (DiagnosticoId) REFERENCES dbo.Diagnostico (DiagnosticoId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Reparacion_Tecnico     FOREIGN KEY (TecnicoId)     REFERENCES dbo.Usuario (UsuarioId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Reparacion_Fechas CHECK (FechaFin IS NULL OR FechaFin >= FechaInicio),
    CONSTRAINT CK_Reparacion_Costo  CHECK (CostoManoObra >= 0),
    CONSTRAINT CK_Reparacion_Estado CHECK (Estado IN ('EN_PROCESO','FINALIZADA','CANCELADA'))
);
GO

-- 12. ActividadReparacion (actividades de cada reparación)
CREATE TABLE dbo.ActividadReparacion (
    ReparacionId     INT          NOT NULL,
    NumeroActividad  INT          NOT NULL,
    Descripcion      VARCHAR(300) NOT NULL,
    HorasTrabajadas  DECIMAL(5,2) NULL,
    FechaRegistro    DATETIME     NOT NULL CONSTRAINT DF_Actividad_Fecha DEFAULT (GETDATE()),
    CONSTRAINT PK_ActividadReparacion PRIMARY KEY (ReparacionId, NumeroActividad),
    CONSTRAINT FK_Actividad_Reparacion FOREIGN KEY (ReparacionId) REFERENCES dbo.Reparacion (ReparacionId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Actividad_Numero CHECK (NumeroActividad > 0),
    CONSTRAINT CK_Actividad_Horas  CHECK (HorasTrabajadas IS NULL OR HorasTrabajadas > 0)
);
GO

-- ========== Inventario ==========

-- 13. Categoria
CREATE TABLE dbo.Categoria (
    CategoriaId  INT IDENTITY(1,1) NOT NULL,
    Nombre       VARCHAR(50)  NOT NULL,
    Descripcion  VARCHAR(150) NULL,
    Activo       BIT          NOT NULL CONSTRAINT DF_Categoria_Activo DEFAULT (1),
    CONSTRAINT PK_Categoria PRIMARY KEY (CategoriaId),
    CONSTRAINT UQ_Categoria_Nombre UNIQUE (Nombre)
);
GO

-- 14. Repuesto
CREATE TABLE dbo.Repuesto (
    RepuestoId              INT IDENTITY(1,1) NOT NULL,
    CategoriaId             INT           NOT NULL,
    Codigo                  VARCHAR(20)   NOT NULL,
    Nombre                  VARCHAR(100)  NOT NULL,
    Descripcion             VARCHAR(200)  NULL,
    PrecioCompraReferencia  DECIMAL(10,2) NOT NULL,   -- precio actual
    PrecioVenta             DECIMAL(10,2) NOT NULL,   -- precio actual
    Estado                  VARCHAR(10)   NOT NULL CONSTRAINT DF_Repuesto_Estado DEFAULT ('ACTIVO'),
    CONSTRAINT PK_Repuesto PRIMARY KEY (RepuestoId),
    CONSTRAINT UQ_Repuesto_Codigo UNIQUE (Codigo),
    CONSTRAINT FK_Repuesto_Categoria FOREIGN KEY (CategoriaId) REFERENCES dbo.Categoria (CategoriaId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Repuesto_Precios CHECK (PrecioCompraReferencia >= 0 AND PrecioVenta >= 0),
    CONSTRAINT CK_Repuesto_Estado  CHECK (Estado IN ('ACTIVO','INACTIVO'))
);
GO

-- 15. Bodega
CREATE TABLE dbo.Bodega (
    BodegaId   INT IDENTITY(1,1) NOT NULL,
    Nombre     VARCHAR(50)  NOT NULL,
    Ubicacion  VARCHAR(150) NULL,
    Activo     BIT          NOT NULL CONSTRAINT DF_Bodega_Activo DEFAULT (1),
    CONSTRAINT PK_Bodega PRIMARY KEY (BodegaId),
    CONSTRAINT UQ_Bodega_Nombre UNIQUE (Nombre)
);
GO

-- 16. Inventario (existencia de cada repuesto por bodega)
CREATE TABLE dbo.Inventario (
    RepuestoId          INT      NOT NULL,
    BodegaId            INT      NOT NULL,
    Existencia          INT      NOT NULL CONSTRAINT DF_Inventario_Existencia DEFAULT (0),
    StockMinimo         INT      NOT NULL CONSTRAINT DF_Inventario_StockMinimo DEFAULT (0),
    FechaActualizacion  DATETIME NOT NULL CONSTRAINT DF_Inventario_Fecha DEFAULT (GETDATE()),
    CONSTRAINT PK_Inventario PRIMARY KEY (RepuestoId, BodegaId),
    CONSTRAINT FK_Inventario_Repuesto FOREIGN KEY (RepuestoId) REFERENCES dbo.Repuesto (RepuestoId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Inventario_Bodega   FOREIGN KEY (BodegaId)   REFERENCES dbo.Bodega (BodegaId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Inventario_Existencia  CHECK (Existencia >= 0),    -- nunca negativa
    CONSTRAINT CK_Inventario_StockMinimo CHECK (StockMinimo >= 0)
);
GO

-- 17. ReparacionRepuesto (repuestos usados en cada reparación)
CREATE TABLE dbo.ReparacionRepuesto (
    ReparacionId         INT           NOT NULL,
    RepuestoId           INT           NOT NULL,
    BodegaId             INT           NOT NULL,   -- bodega de donde sale
    Cantidad             INT           NOT NULL,
    CostoUnitario        DECIMAL(10,2) NOT NULL,   -- precio del momento
    PrecioVentaUnitario  DECIMAL(10,2) NOT NULL,   -- precio del momento
    FechaRegistro        DATETIME      NOT NULL CONSTRAINT DF_RepRep_Fecha DEFAULT (GETDATE()),
    UsuarioId            INT           NOT NULL,   -- quién asignó el repuesto
    CONSTRAINT PK_ReparacionRepuesto PRIMARY KEY (ReparacionId, RepuestoId, BodegaId),
    CONSTRAINT FK_RepRep_Reparacion FOREIGN KEY (ReparacionId)         REFERENCES dbo.Reparacion (ReparacionId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_RepRep_Inventario FOREIGN KEY (RepuestoId, BodegaId) REFERENCES dbo.Inventario (RepuestoId, BodegaId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_RepRep_Usuario    FOREIGN KEY (UsuarioId)            REFERENCES dbo.Usuario (UsuarioId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_RepRep_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_RepRep_Precios  CHECK (CostoUnitario >= 0 AND PrecioVentaUnitario >= 0)
);
GO

-- 18. AuditoriaPrecio (historial de cambios de precio)
CREATE TABLE dbo.AuditoriaPrecio (
    AuditoriaId           INT IDENTITY(1,1) NOT NULL,
    RepuestoId            INT           NOT NULL,
    PrecioCompraAnterior  DECIMAL(10,2) NULL,
    PrecioCompraNuevo     DECIMAL(10,2) NULL,
    PrecioVentaAnterior   DECIMAL(10,2) NULL,
    PrecioVentaNuevo      DECIMAL(10,2) NULL,
    FechaCambio           DATETIME      NOT NULL CONSTRAINT DF_Auditoria_Fecha DEFAULT (GETDATE()),
    UsuarioBD             VARCHAR(100)  NOT NULL CONSTRAINT DF_Auditoria_UsuarioBD DEFAULT (SUSER_SNAME()),
    CONSTRAINT PK_AuditoriaPrecio PRIMARY KEY (AuditoriaId),
    CONSTRAINT FK_Auditoria_Repuesto FOREIGN KEY (RepuestoId) REFERENCES dbo.Repuesto (RepuestoId) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- ========== Proveedores y compras ==========

-- 19. Proveedor
CREATE TABLE dbo.Proveedor (
    ProveedorId  INT IDENTITY(1,1) NOT NULL,
    NIT          VARCHAR(15)  NOT NULL,
    Nombre       VARCHAR(150) NOT NULL,
    Contacto     VARCHAR(100) NULL,
    Telefono     VARCHAR(15)  NOT NULL,
    Correo       VARCHAR(100) NULL,
    Direccion    VARCHAR(200) NULL,
    Estado       VARCHAR(10)  NOT NULL CONSTRAINT DF_Proveedor_Estado DEFAULT ('ACTIVO'),
    CONSTRAINT PK_Proveedor PRIMARY KEY (ProveedorId),
    CONSTRAINT UQ_Proveedor_NIT UNIQUE (NIT),
    CONSTRAINT CK_Proveedor_Estado CHECK (Estado IN ('ACTIVO','INACTIVO'))
);
GO

-- 20. ProveedorRepuesto (qué proveedor vende qué repuesto)
CREATE TABLE dbo.ProveedorRepuesto (
    ProveedorId       INT           NOT NULL,
    RepuestoId        INT           NOT NULL,
    CodigoProveedor   VARCHAR(30)   NULL,
    PrecioReferencia  DECIMAL(10,2) NULL,
    CONSTRAINT PK_ProveedorRepuesto PRIMARY KEY (ProveedorId, RepuestoId),
    CONSTRAINT FK_ProvRep_Proveedor FOREIGN KEY (ProveedorId) REFERENCES dbo.Proveedor (ProveedorId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_ProvRep_Repuesto  FOREIGN KEY (RepuestoId)  REFERENCES dbo.Repuesto (RepuestoId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_ProvRep_Precio CHECK (PrecioReferencia IS NULL OR PrecioReferencia >= 0)
);
GO

-- 21. Compra
CREATE TABLE dbo.Compra (
    CompraId        INT IDENTITY(1,1) NOT NULL,
    NumeroCompra    VARCHAR(20)  NOT NULL,
    ProveedorId     INT          NOT NULL,
    BodegaId        INT          NOT NULL,   -- bodega donde se recibe
    FechaCompra     DATETIME     NOT NULL CONSTRAINT DF_Compra_Fecha DEFAULT (GETDATE()),
    FechaRecepcion  DATETIME     NULL,       -- NULL mientras está PENDIENTE
    Estado          VARCHAR(10)  NOT NULL CONSTRAINT DF_Compra_Estado DEFAULT ('PENDIENTE'),
    UsuarioId       INT          NOT NULL,
    Observaciones   VARCHAR(300) NULL,
    CONSTRAINT PK_Compra PRIMARY KEY (CompraId),
    CONSTRAINT UQ_Compra_NumeroCompra UNIQUE (NumeroCompra),
    CONSTRAINT FK_Compra_Proveedor FOREIGN KEY (ProveedorId) REFERENCES dbo.Proveedor (ProveedorId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Compra_Bodega    FOREIGN KEY (BodegaId)    REFERENCES dbo.Bodega (BodegaId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Compra_Usuario   FOREIGN KEY (UsuarioId)   REFERENCES dbo.Usuario (UsuarioId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Compra_Estado CHECK (Estado IN ('PENDIENTE','RECIBIDA','ANULADA'))
);
GO

-- 22. DetalleCompra
CREATE TABLE dbo.DetalleCompra (
    CompraId       INT           NOT NULL,
    RepuestoId     INT           NOT NULL,
    Cantidad       INT           NOT NULL,
    CostoUnitario  DECIMAL(10,2) NOT NULL,   -- precio del momento
    CONSTRAINT PK_DetalleCompra PRIMARY KEY (CompraId, RepuestoId),
    CONSTRAINT FK_DetCompra_Compra   FOREIGN KEY (CompraId)   REFERENCES dbo.Compra (CompraId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_DetCompra_Repuesto FOREIGN KEY (RepuestoId) REFERENCES dbo.Repuesto (RepuestoId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_DetCompra_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_DetCompra_Costo    CHECK (CostoUnitario >= 0)
);
GO

-- 23. MovimientoInventario (entradas y salidas)
CREATE TABLE dbo.MovimientoInventario (
    MovimientoId          INT IDENTITY(1,1) NOT NULL,
    RepuestoId            INT          NOT NULL,
    BodegaId              INT          NOT NULL,
    TipoMovimiento        VARCHAR(10)  NOT NULL,
    Cantidad              INT          NOT NULL,
    ExistenciaResultante  INT          NOT NULL,
    CompraId              INT          NULL,   -- si es entrada por compra
    ReparacionId          INT          NULL,   -- si es salida por reparación
    FechaMovimiento       DATETIME     NOT NULL CONSTRAINT DF_Movimiento_Fecha DEFAULT (GETDATE()),
    UsuarioId             INT          NOT NULL,
    Observacion           VARCHAR(200) NULL,
    CONSTRAINT PK_MovimientoInventario PRIMARY KEY (MovimientoId),
    CONSTRAINT FK_Movimiento_Inventario  FOREIGN KEY (RepuestoId, BodegaId) REFERENCES dbo.Inventario (RepuestoId, BodegaId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Movimiento_Compra      FOREIGN KEY (CompraId)             REFERENCES dbo.Compra (CompraId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Movimiento_Reparacion  FOREIGN KEY (ReparacionId)         REFERENCES dbo.Reparacion (ReparacionId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Movimiento_Usuario     FOREIGN KEY (UsuarioId)            REFERENCES dbo.Usuario (UsuarioId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Movimiento_Tipo        CHECK (TipoMovimiento IN ('ENTRADA','SALIDA')),
    CONSTRAINT CK_Movimiento_Cantidad    CHECK (Cantidad > 0),
    CONSTRAINT CK_Movimiento_Existencia  CHECK (ExistenciaResultante >= 0),
    -- viene de una compra o de una reparación, no de las dos
    CONSTRAINT CK_Movimiento_Origen CHECK (
        (CompraId IS NOT NULL AND ReparacionId IS NULL) OR
        (CompraId IS NULL AND ReparacionId IS NOT NULL)
    )
);
GO

-- ========== Facturación, pagos y entrega ==========

-- 24. MetodoPago
CREATE TABLE dbo.MetodoPago (
    MetodoPagoId  INT IDENTITY(1,1) NOT NULL,
    Nombre        VARCHAR(30) NOT NULL,
    Activo        BIT         NOT NULL CONSTRAINT DF_MetodoPago_Activo DEFAULT (1),
    CONSTRAINT PK_MetodoPago PRIMARY KEY (MetodoPagoId),
    CONSTRAINT UQ_MetodoPago_Nombre UNIQUE (Nombre)
);
GO

-- 25. Factura (una por orden; el saldo se calcula, no se guarda)
CREATE TABLE dbo.Factura (
    FacturaId          INT IDENTITY(1,1) NOT NULL,
    NumeroFactura      VARCHAR(20)   NOT NULL,
    OrdenId            INT           NOT NULL,
    NITFacturacion     VARCHAR(15)   NOT NULL,
    NombreFacturacion  VARCHAR(150)  NOT NULL,
    FechaEmision       DATETIME      NOT NULL CONSTRAINT DF_Factura_Fecha DEFAULT (GETDATE()),
    TotalManoObra      DECIMAL(10,2) NOT NULL,   -- precio del momento
    TotalRepuestos     DECIMAL(10,2) NOT NULL,   -- precio del momento
    Subtotal           DECIMAL(10,2) NOT NULL,
    Impuesto           DECIMAL(10,2) NOT NULL,   -- IVA 12%
    Total              DECIMAL(10,2) NOT NULL,
    Estado             VARCHAR(10)   NOT NULL CONSTRAINT DF_Factura_Estado DEFAULT ('EMITIDA'),
    UsuarioId          INT           NOT NULL,   -- usuario de caja
    CONSTRAINT PK_Factura PRIMARY KEY (FacturaId),
    CONSTRAINT UQ_Factura_NumeroFactura UNIQUE (NumeroFactura),
    CONSTRAINT UQ_Factura_Orden UNIQUE (OrdenId),
    CONSTRAINT FK_Factura_Orden   FOREIGN KEY (OrdenId)   REFERENCES dbo.OrdenServicio (OrdenId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Factura_Usuario FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuario (UsuarioId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Factura_Montos CHECK (TotalManoObra >= 0 AND TotalRepuestos >= 0 AND Subtotal >= 0 AND Impuesto >= 0),
    CONSTRAINT CK_Factura_Total  CHECK (Total = Subtotal + Impuesto),
    CONSTRAINT CK_Factura_Estado CHECK (Estado IN ('EMITIDA','PAGADA','ANULADA'))
);
GO

-- 26. Pago (una factura puede tener varios pagos)
CREATE TABLE dbo.Pago (
    PagoId        INT IDENTITY(1,1) NOT NULL,
    FacturaId     INT           NOT NULL,
    MetodoPagoId  INT           NOT NULL,
    Monto         DECIMAL(10,2) NOT NULL,
    FechaPago     DATETIME      NOT NULL CONSTRAINT DF_Pago_Fecha DEFAULT (GETDATE()),
    Referencia    VARCHAR(50)   NULL,       -- no. de boleta o voucher
    Estado        VARCHAR(10)   NOT NULL CONSTRAINT DF_Pago_Estado DEFAULT ('APLICADO'),
    UsuarioId     INT           NOT NULL,   -- quién cobró
    CONSTRAINT PK_Pago PRIMARY KEY (PagoId),
    CONSTRAINT FK_Pago_Factura    FOREIGN KEY (FacturaId)    REFERENCES dbo.Factura (FacturaId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Pago_MetodoPago FOREIGN KEY (MetodoPagoId) REFERENCES dbo.MetodoPago (MetodoPagoId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Pago_Usuario    FOREIGN KEY (UsuarioId)    REFERENCES dbo.Usuario (UsuarioId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Pago_Monto  CHECK (Monto > 0),
    CONSTRAINT CK_Pago_Estado CHECK (Estado IN ('APLICADO','ANULADO'))
);
GO

-- 27. Entrega (una por orden)
CREATE TABLE dbo.Entrega (
    EntregaId         INT IDENTITY(1,1) NOT NULL,
    OrdenId           INT          NOT NULL,
    UsuarioEntregaId  INT          NOT NULL,   -- quién entrega
    NombreRecibe      VARCHAR(100) NOT NULL,   -- quién recibe
    FechaEntrega      DATETIME     NOT NULL CONSTRAINT DF_Entrega_Fecha DEFAULT (GETDATE()),
    Observaciones     VARCHAR(300) NULL,
    CONSTRAINT PK_Entrega PRIMARY KEY (EntregaId),
    CONSTRAINT UQ_Entrega_Orden UNIQUE (OrdenId),
    CONSTRAINT FK_Entrega_Orden   FOREIGN KEY (OrdenId)          REFERENCES dbo.OrdenServicio (OrdenId) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Entrega_Usuario FOREIGN KEY (UsuarioEntregaId) REFERENCES dbo.Usuario (UsuarioId) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- Verificar: deben salir 27 tablas
SELECT COUNT(*) AS TotalTablas
FROM sys.tables
WHERE schema_id = SCHEMA_ID('dbo');
GO
GO

/* ##########################################################
    2/12  02_datos_iniciales.sql
   Catálogos y datos iniciales
   (solo datos)
   ########################################################## */
PRINT '>> 2/12 02_datos_iniciales.sql';
GO

/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 02: datos iniciales y de prueba
   Se ejecuta después del 01. Contraseña de prueba: TechCare2026!
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;   -- lo pide el índice del NIT
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    -- Evita correrlo en master o dos veces
    IF DB_NAME() IN ('master', 'model', 'msdb', 'tempdb')
        THROW 50001, 'Está en una base del sistema. Seleccione TechCare (local) o db_acf53d_dbfinal2026 (nube).', 1;

    IF EXISTS (SELECT 1 FROM dbo.Rol)
        THROW 50002, 'Las tablas ya tienen datos. Ejecute primero 01_tablas.sql y luego este script.', 1;

    BEGIN TRANSACTION;

    -- ===== Seguridad =====

    -- 1. Roles
    INSERT INTO dbo.Rol (Nombre, Descripcion) VALUES
        ('ADMINISTRADOR', 'Acceso total: usuarios, catálogos y reportes'),
        ('RECEPCION',     'Registra clientes, equipos y órdenes; entrega equipos'),
        ('TECNICO',       'Registra diagnósticos, reparaciones y repuestos usados'),
        ('BODEGA',        'Administra repuestos, proveedores, compras e inventario'),
        ('CAJA',          'Emite facturas y registra pagos');

    -- 2. Usuarios
    DECLARE @Hash VARCHAR(255) = CONVERT(VARCHAR(255), HASHBYTES('SHA2_256', 'TechCare2026!'), 2);

    INSERT INTO dbo.Usuario (NombreUsuario, ContrasenaHash, NombreCompleto, Correo, Telefono) VALUES
        ('admin',      @Hash, 'Administrador del Sistema', 'admin@techcare.com.gt',      '22001000'),
        ('recepcion1', @Hash, 'Ana Lucía López',           'recepcion1@techcare.com.gt', '22001001'),
        ('tecnico1',   @Hash, 'Carlos Enrique Pérez',      'tecnico1@techcare.com.gt',   '22001002'),
        ('tecnico2',   @Hash, 'María José García',         'tecnico2@techcare.com.gt',   '22001003'),
        ('bodega1',    @Hash, 'Luis Fernando Ramírez',     'bodega1@techcare.com.gt',    '22001004'),
        ('caja1',      @Hash, 'Sofía Alejandra Morales',   'caja1@techcare.com.gt',      '22001005');

    -- 3. Rol de cada usuario
    INSERT INTO dbo.UsuarioRol (UsuarioId, RolId)
    SELECT u.UsuarioId, r.RolId
    FROM (VALUES
            ('admin',      'ADMINISTRADOR'),
            ('recepcion1', 'RECEPCION'),
            ('tecnico1',   'TECNICO'),
            ('tecnico2',   'TECNICO'),
            ('bodega1',    'BODEGA'),
            ('caja1',      'CAJA')
         ) AS v (NombreUsuario, NombreRol)
    JOIN dbo.Usuario u ON u.NombreUsuario = v.NombreUsuario
    JOIN dbo.Rol     r ON r.Nombre        = v.NombreRol;

    -- ===== Catálogos =====

    -- 4. Estados de la orden (Id fijos)
    INSERT INTO dbo.EstadoOrden (EstadoOrdenId, Codigo, Descripcion) VALUES
        (1, 'RECIBIDO',               'Equipo recibido en recepción'),
        (2, 'DIAGNOSTICO',            'Técnico revisando el equipo'),
        (3, 'ESPERANDO_AUTORIZACION', 'Diagnóstico listo, esperando respuesta del cliente'),
        (4, 'REPARACION',             'Reparación en proceso'),
        (5, 'LISTO',                  'Reparación terminada, listo para facturar y entregar'),
        (6, 'ENTREGADO',              'Equipo entregado al cliente'),
        (7, 'CANCELADO',              'Orden cancelada (cliente no autorizó u otro motivo)');

    -- 5. Tipos de equipo
    INSERT INTO dbo.TipoEquipo (Nombre) VALUES
        ('Laptop'), ('Desktop'), ('Impresora'), ('Monitor'), ('Tablet'), ('Equipo de red');

    -- 6. Métodos de pago
    INSERT INTO dbo.MetodoPago (Nombre) VALUES
        ('EFECTIVO'), ('TARJETA'), ('TRANSFERENCIA');

    -- 7. Categorías de repuestos
    INSERT INTO dbo.Categoria (Nombre, Descripcion) VALUES
        ('Pantallas',      'Pantallas LED/LCD para laptop y monitores'),
        ('Memorias RAM',   'Módulos de memoria DDR4/DDR5'),
        ('Almacenamiento', 'Discos SSD y HDD'),
        ('Teclados',       'Teclados de reemplazo para laptop'),
        ('Baterías',       'Baterías para laptop'),
        ('Cargadores',     'Cargadores y fuentes de poder'),
        ('Consumibles',    'Pasta térmica, tornillería y limpieza');

    -- 8. Bodegas
    INSERT INTO dbo.Bodega (Nombre, Ubicacion) VALUES
        ('Central', '6a. Avenida 10-25, Zona 1, Ciudad de Guatemala'),
        ('Zona 10', '12 Calle 2-40, Zona 10, Ciudad de Guatemala'),
        ('Mixco',   'Calzada Roosevelt 33-50, Zona 7 de Mixco');

    -- ===== Clientes y equipos =====

    -- 9. Clientes
    INSERT INTO dbo.Cliente (TipoCliente, NombreRazonSocial, NIT, Telefono, Correo, Direccion) VALUES
        ('INDIVIDUAL',  'Juan Carlos Méndez',          '4567890-1', '55551234', 'jcmendez@gmail.com',        'Zona 11, Ciudad de Guatemala'),
        ('INDIVIDUAL',  'Lucía Hernández',             'CF',        '44442211', NULL,                        'Villa Nueva'),
        ('EMPRESARIAL', 'Comercial El Progreso, S.A.', '7890123-4', '23305566', 'compras@elprogreso.com.gt', 'Zona 4, Ciudad de Guatemala'),
        ('EMPRESARIAL', 'Colegio San Andrés',          '8901234-5', '24407788', 'admin@colegiosa.edu.gt',    'Zona 15, Ciudad de Guatemala');

    -- 10. Equipos
    INSERT INTO dbo.Equipo (ClienteId, TipoEquipoId, Marca, Modelo, NumeroSerie, Descripcion)
    SELECT c.ClienteId, t.TipoEquipoId, v.Marca, v.Modelo, v.NumeroSerie, v.Descripcion
    FROM (VALUES
            ('Juan Carlos Méndez',          'Laptop',    'HP',     'Pavilion 15',    'HP5CD1234XYZ',  'Color plateado, con cargador'),
            ('Lucía Hernández',             'Laptop',    'Lenovo', 'IdeaPad 3',      'LNV-PF3ABC12',  'Sin cargador'),
            ('Comercial El Progreso, S.A.', 'Desktop',   'Dell',   'OptiPlex 3080',  'DL-7HJK921',    'Equipo de facturación'),
            ('Comercial El Progreso, S.A.', 'Impresora', 'Epson',  'L3250',          'EPS-X8QW5521',  'Multifuncional de tinta continua'),
            ('Colegio San Andrés',          'Laptop',    'Acer',   'Aspire 5',       'ACR-NXHS7AA01', 'Laptop del laboratorio de cómputo')
         ) AS v (Cliente, Tipo, Marca, Modelo, NumeroSerie, Descripcion)
    JOIN dbo.Cliente    c ON c.NombreRazonSocial = v.Cliente
    JOIN dbo.TipoEquipo t ON t.Nombre            = v.Tipo;

    -- ===== Repuestos y proveedores =====

    -- 11. Repuestos (precios en quetzales)
    INSERT INTO dbo.Repuesto (CategoriaId, Codigo, Nombre, Descripcion, PrecioCompraReferencia, PrecioVenta)
    SELECT cat.CategoriaId, v.Codigo, v.Nombre, v.Descripcion, v.PrecioCompra, v.PrecioVenta
    FROM (VALUES
            ('REP-0001', 'Pantallas',      'Pantalla LED 15.6" HD 30 pines',     'Compatible con HP, Lenovo y Acer', 350.00, 550.00),
            ('REP-0002', 'Pantallas',      'Pantalla LED 14" FHD 30 pines',      'Resolución 1920x1080',             420.00, 650.00),
            ('REP-0003', 'Memorias RAM',   'Memoria RAM DDR4 8GB SODIMM 3200',   'Para laptop',                      180.00, 300.00),
            ('REP-0004', 'Memorias RAM',   'Memoria RAM DDR4 16GB SODIMM 3200',  'Para laptop',                      330.00, 520.00),
            ('REP-0005', 'Almacenamiento', 'SSD SATA 2.5" 480GB',                'Estado sólido SATA III',           260.00, 425.00),
            ('REP-0006', 'Almacenamiento', 'SSD NVMe M.2 1TB',                   'PCIe 3.0',                         520.00, 800.00),
            ('REP-0007', 'Teclados',       'Teclado laptop español genérico',    'Distribución latinoamericana',     120.00, 225.00),
            ('REP-0008', 'Baterías',       'Batería laptop 6 celdas genérica',   '10.8 V, 4400 mAh',                 280.00, 450.00),
            ('REP-0009', 'Cargadores',     'Cargador laptop universal 65W',      'Incluye 8 puntas',                 150.00, 260.00),
            ('REP-0010', 'Consumibles',    'Pasta térmica 4g',                   'Alta conductividad',                25.00,  60.00)
         ) AS v (Codigo, Categoria, Nombre, Descripcion, PrecioCompra, PrecioVenta)
    JOIN dbo.Categoria cat ON cat.Nombre = v.Categoria;

    -- 12. Proveedores
    INSERT INTO dbo.Proveedor (NIT, Nombre, Contacto, Telefono, Correo, Direccion) VALUES
        ('1234567-8', 'Distribuidora Tecnológica de Guatemala, S.A.', 'Roberto Castillo', '23456789', 'ventas@distecgt.com',     'Zona 9, Ciudad de Guatemala'),
        ('2345678-9', 'Importadora de Repuestos Computación, S.A.',   'Andrea Ruiz',      '24561234', 'pedidos@irc.com.gt',      'Zona 12, Ciudad de Guatemala'),
        ('3456789-0', 'Energía y Baterías, S.A.',                      'Mario Gómez',      '22334455', 'info@energiabaterias.gt', 'Zona 13, Ciudad de Guatemala');

    -- 13. Qué proveedor vende cada repuesto
    INSERT INTO dbo.ProveedorRepuesto (ProveedorId, RepuestoId, CodigoProveedor, PrecioReferencia)
    SELECT p.ProveedorId, r.RepuestoId, v.CodigoProveedor, v.Precio
    FROM (VALUES
            ('1234567-8', 'REP-0001', 'DTG-LCD156', 350.00),
            ('1234567-8', 'REP-0002', 'DTG-LCD140', 420.00),
            ('1234567-8', 'REP-0003', 'DTG-RAM8',   180.00),
            ('1234567-8', 'REP-0004', 'DTG-RAM16',  330.00),
            ('1234567-8', 'REP-0005', 'DTG-SSD480', 260.00),
            ('1234567-8', 'REP-0006', 'DTG-NVME1T', 520.00),
            ('1234567-8', 'REP-0010', 'DTG-PASTA4',  25.00),
            ('2345678-9', 'REP-0001', 'IRC-0156',   345.00),
            ('2345678-9', 'REP-0003', 'IRC-0308',   175.00),
            ('2345678-9', 'REP-0005', 'IRC-0480',   255.00),
            ('2345678-9', 'REP-0007', 'IRC-KBES',   120.00),
            ('3456789-0', 'REP-0008', 'EB-BAT6C',   280.00),
            ('3456789-0', 'REP-0009', 'EB-CHG65',   150.00)
         ) AS v (NIT, Codigo, CodigoProveedor, Precio)
    JOIN dbo.Proveedor p ON p.NIT    = v.NIT
    JOIN dbo.Repuesto  r ON r.Codigo = v.Codigo;

    -- ===== Inventario inicial =====
    -- Se carga como compra recibida para que cuadre con los movimientos

    DECLARE @UsuarioBodega INT = (SELECT UsuarioId   FROM dbo.Usuario   WHERE NombreUsuario = 'bodega1');
    DECLARE @Proveedor     INT = (SELECT ProveedorId FROM dbo.Proveedor WHERE NIT = '1234567-8');

    -- Existencia inicial y stock mínimo por bodega
    DECLARE @Carga TABLE (Bodega VARCHAR(50), Codigo VARCHAR(20), Cantidad INT, StockMinimo INT);
    INSERT INTO @Carga (Bodega, Codigo, Cantidad, StockMinimo) VALUES
        ('Central', 'REP-0001',  8, 3), ('Central', 'REP-0002',  5, 2),
        ('Central', 'REP-0003', 15, 5), ('Central', 'REP-0004', 10, 3),
        ('Central', 'REP-0005', 12, 4), ('Central', 'REP-0006',  6, 2),
        ('Central', 'REP-0007',  7, 3), ('Central', 'REP-0008',  5, 2),
        ('Central', 'REP-0009', 10, 4), ('Central', 'REP-0010', 30, 10),
        ('Zona 10', 'REP-0001',  4, 2), ('Zona 10', 'REP-0003',  6, 3),
        ('Zona 10', 'REP-0005',  5, 2), ('Zona 10', 'REP-0008',  1, 2),   -- queda bajo el mínimo
        ('Zona 10', 'REP-0009',  4, 2), ('Zona 10', 'REP-0010', 10, 5);

    -- 14. Compras de la carga inicial
    INSERT INTO dbo.Compra (NumeroCompra, ProveedorId, BodegaId, FechaRecepcion, Estado, UsuarioId, Observaciones)
    SELECT v.NumeroCompra, @Proveedor, b.BodegaId, GETDATE(), 'RECIBIDA', @UsuarioBodega, 'Carga de inventario inicial'
    FROM (VALUES ('OC-2026-0001', 'Central'),
                 ('OC-2026-0002', 'Zona 10')) AS v (NumeroCompra, Bodega)
    JOIN dbo.Bodega b ON b.Nombre = v.Bodega;

    -- 15. Detalle de las compras
    INSERT INTO dbo.DetalleCompra (CompraId, RepuestoId, Cantidad, CostoUnitario)
    SELECT co.CompraId, r.RepuestoId, c.Cantidad, r.PrecioCompraReferencia
    FROM @Carga c
    JOIN dbo.Bodega   b  ON b.Nombre   = c.Bodega
    JOIN dbo.Compra   co ON co.BodegaId = b.BodegaId AND co.Observaciones = 'Carga de inventario inicial'
    JOIN dbo.Repuesto r  ON r.Codigo   = c.Codigo;

    -- 16. Inventario
    INSERT INTO dbo.Inventario (RepuestoId, BodegaId, Existencia, StockMinimo)
    SELECT r.RepuestoId, b.BodegaId, c.Cantidad, c.StockMinimo
    FROM @Carga c
    JOIN dbo.Bodega   b ON b.Nombre = c.Bodega
    JOIN dbo.Repuesto r ON r.Codigo = c.Codigo;

    -- En Mixco quedan en cero para probar el stock mínimo
    INSERT INTO dbo.Inventario (RepuestoId, BodegaId, Existencia, StockMinimo)
    SELECT r.RepuestoId, b.BodegaId, 0, 2
    FROM dbo.Repuesto r
    CROSS JOIN dbo.Bodega b
    WHERE b.Nombre = 'Mixco'
      AND r.Codigo IN ('REP-0003', 'REP-0005', 'REP-0009');

    -- 17. Movimientos de entrada de cada compra
    INSERT INTO dbo.MovimientoInventario
        (RepuestoId, BodegaId, TipoMovimiento, Cantidad, ExistenciaResultante, CompraId, ReparacionId, UsuarioId, Observacion)
    SELECT dc.RepuestoId, co.BodegaId, 'ENTRADA', dc.Cantidad, dc.Cantidad, co.CompraId, NULL, @UsuarioBodega,
           'Inventario inicial (' + co.NumeroCompra + ')'
    FROM dbo.DetalleCompra dc
    JOIN dbo.Compra co ON co.CompraId = dc.CompraId;

    COMMIT TRANSACTION;
    PRINT 'Datos iniciales cargados correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- Verificar cuántos registros quedaron por tabla
SELECT 'Rol'                  AS Tabla, COUNT(*) AS Registros FROM dbo.Rol                  UNION ALL
SELECT 'Usuario',                       COUNT(*)              FROM dbo.Usuario              UNION ALL
SELECT 'UsuarioRol',                    COUNT(*)              FROM dbo.UsuarioRol           UNION ALL
SELECT 'EstadoOrden',                   COUNT(*)              FROM dbo.EstadoOrden          UNION ALL
SELECT 'TipoEquipo',                    COUNT(*)              FROM dbo.TipoEquipo           UNION ALL
SELECT 'MetodoPago',                    COUNT(*)              FROM dbo.MetodoPago           UNION ALL
SELECT 'Categoria',                     COUNT(*)              FROM dbo.Categoria            UNION ALL
SELECT 'Bodega',                        COUNT(*)              FROM dbo.Bodega               UNION ALL
SELECT 'Cliente',                       COUNT(*)              FROM dbo.Cliente              UNION ALL
SELECT 'Equipo',                        COUNT(*)              FROM dbo.Equipo               UNION ALL
SELECT 'Repuesto',                      COUNT(*)              FROM dbo.Repuesto             UNION ALL
SELECT 'Proveedor',                     COUNT(*)              FROM dbo.Proveedor            UNION ALL
SELECT 'ProveedorRepuesto',             COUNT(*)              FROM dbo.ProveedorRepuesto    UNION ALL
SELECT 'Compra',                        COUNT(*)              FROM dbo.Compra               UNION ALL
SELECT 'DetalleCompra',                 COUNT(*)              FROM dbo.DetalleCompra        UNION ALL
SELECT 'Inventario',                    COUNT(*)              FROM dbo.Inventario           UNION ALL
SELECT 'MovimientoInventario',          COUNT(*)              FROM dbo.MovimientoInventario;
GO
-- Debe salir: Rol 5, Usuario 6, UsuarioRol 6, EstadoOrden 7, TipoEquipo 6, MetodoPago 3,
-- Categoria 7, Bodega 3, Cliente 4, Equipo 5, Repuesto 10, Proveedor 3, ProveedorRepuesto 13,
-- Compra 2, DetalleCompra 16, Inventario 19, MovimientoInventario 16
GO

/* ##########################################################
    3/12  08_permisos.sql
   Permisos por rol (antes del 03: el login los lee)
   Tablas (2): Permiso, RolPermiso
   Restricciones (7): DF 1, PK 2, UQ 1, CK 1, FK 2
   Vistas (2): vw_Permiso, vw_UsuarioPermiso
   ########################################################## */
PRINT '>> 3/12 08_permisos.sql';
GO

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
GO

/* ##########################################################
    4/12  03_procedimientos.sql
   Órdenes y login
   Procedimientos (3): sp_RegistrarOrden, sp_CambiarEstadoOrden, sp_LoginUsuario
   ########################################################## */
PRINT '>> 4/12 03_procedimientos.sql';
GO

/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 03: procedimientos para registrar órdenes y cambiar estado
   Se ejecuta después del 01 y 02
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   sp_RegistrarOrden
   Registra una orden nueva en estado RECIBIDO y guarda el
   primer registro del historial. Todo va en una transacción.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarOrden
    @ClienteId           INT,
    @EquipoId            INT,
    @UsuarioRecepcionId  INT,
    @ProblemaReportado   VARCHAR(500),
    @Prioridad           VARCHAR(10)  = 'MEDIA',
    @FechaEstimada       DATE         = NULL,
    @Observaciones       VARCHAR(500) = NULL,
    @OrdenId             INT          = NULL OUTPUT,
    @NumeroOrden         VARCHAR(15)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRecibido INT = 1;

    BEGIN TRY
        -- Validaciones
        IF @ProblemaReportado IS NULL OR LTRIM(RTRIM(@ProblemaReportado)) = ''
            THROW 50101, 'Debe describir el problema reportado por el cliente.', 1;

        IF @Prioridad NOT IN ('BAJA', 'MEDIA', 'ALTA', 'URGENTE')
            THROW 50102, 'Prioridad inválida. Use BAJA, MEDIA, ALTA o URGENTE.', 1;

        IF @FechaEstimada IS NOT NULL AND @FechaEstimada < CAST(GETDATE() AS DATE)
            THROW 50103, 'La fecha estimada no puede ser anterior a hoy.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente
                       WHERE ClienteId = @ClienteId AND Estado = 'ACTIVO')
            THROW 50104, 'El cliente no existe o está inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Equipo
                       WHERE EquipoId = @EquipoId AND Estado = 'ACTIVO')
            THROW 50105, 'El equipo no existe o está inactivo.', 1;

        -- el equipo tiene que ser del cliente
        IF NOT EXISTS (SELECT 1 FROM dbo.Equipo
                       WHERE EquipoId = @EquipoId AND ClienteId = @ClienteId)
            THROW 50106, 'El equipo no pertenece al cliente indicado.', 1;

        -- solo recepción o administrador pueden recibir equipos
        IF NOT EXISTS (SELECT 1
                       FROM dbo.Usuario u
                       JOIN dbo.UsuarioRol ur ON ur.UsuarioId = u.UsuarioId
                       JOIN dbo.Rol r         ON r.RolId      = ur.RolId
                       WHERE u.UsuarioId = @UsuarioRecepcionId
                         AND u.Activo = 1 AND r.Activo = 1
                         AND r.Nombre IN ('RECEPCION', 'ADMINISTRADOR'))
            THROW 50107, 'El usuario no está autorizado para recibir equipos (rol RECEPCION o ADMINISTRADOR).', 1;

        BEGIN TRANSACTION;

        -- no puede haber otra orden abierta del mismo equipo (6 y 7 ya están cerradas)
        IF EXISTS (SELECT 1 FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
                   WHERE EquipoId = @EquipoId AND EstadoOrdenId NOT IN (6, 7))
            THROW 50108, 'El equipo ya tiene una orden abierta. Cierre o cancele esa orden primero.', 1;

        -- Número de orden: OS-AAAA-0001
        DECLARE @Prefijo VARCHAR(8) = 'OS-' + CAST(YEAR(GETDATE()) AS CHAR(4)) + '-';
        DECLARE @Siguiente INT;

        SELECT @Siguiente = ISNULL(MAX(CAST(SUBSTRING(NumeroOrden, 9, 10) AS INT)), 0) + 1
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)   -- para que no se repita el número
        WHERE NumeroOrden LIKE @Prefijo + '%';

        SET @NumeroOrden = @Prefijo + RIGHT('0000' + CAST(@Siguiente AS VARCHAR(10)),
                                            CASE WHEN @Siguiente > 9999 THEN LEN(CAST(@Siguiente AS VARCHAR(10))) ELSE 4 END);

        -- Crear la orden
        INSERT INTO dbo.OrdenServicio
            (NumeroOrden, ClienteId, EquipoId, UsuarioRecepcionId, ProblemaReportado,
             Prioridad, EstadoOrdenId, FechaEstimada, Observaciones)
        VALUES
            (@NumeroOrden, @ClienteId, @EquipoId, @UsuarioRecepcionId, LTRIM(RTRIM(@ProblemaReportado)),
             @Prioridad, @EstadoRecibido, @FechaEstimada, @Observaciones);

        SET @OrdenId = SCOPE_IDENTITY();

        -- Primer registro del historial
        INSERT INTO dbo.HistorialEstadoOrden
            (OrdenId, EstadoAnteriorId, EstadoNuevoId, UsuarioId, Observacion)
        VALUES
            (@OrdenId, NULL, @EstadoRecibido, @UsuarioRecepcionId, 'Orden registrada en recepción');

        COMMIT TRANSACTION;

        -- Lo que devuelve
        SELECT @OrdenId AS OrdenId, @NumeroOrden AS NumeroOrden, 'RECIBIDO' AS Estado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_CambiarEstadoOrden
   Cambia el estado de una orden y guarda el historial.
   Orden: RECIBIDO -> DIAGNOSTICO -> ESPERANDO_AUTORIZACION
          -> REPARACION -> LISTO (se puede cancelar antes de LISTO).
   ENTREGADO no se pone aquí, va en el proceso de entrega
   porque primero hay que revisar los pagos.
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

        -- Se bloquea la orden mientras se hace el cambio
        SELECT @EstadoActualId = EstadoOrdenId
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
        WHERE OrdenId = @OrdenId;

        IF @EstadoActualId IS NULL
            THROW 50205, 'La orden no existe.', 1;

        IF @EstadoActualId IN (6, 7)
            THROW 50206, 'La orden ya está cerrada (ENTREGADO o CANCELADO) y no admite cambios.', 1;

        IF @EstadoActualId = @EstadoNuevoId
            THROW 50207, 'La orden ya se encuentra en ese estado.', 1;

        -- Cambios de estado permitidos
        IF NOT (   (@EstadoActualId = 1 AND @EstadoNuevoId IN (2, 7))
                OR (@EstadoActualId = 2 AND @EstadoNuevoId IN (3, 7))
                OR (@EstadoActualId = 3 AND @EstadoNuevoId IN (4, 7))
                OR (@EstadoActualId = 4 AND @EstadoNuevoId IN (5, 7)))
            THROW 50208, 'Cambio de estado no permitido para el estado actual de la orden.', 1;

        -- Validaciones según el nuevo estado
        IF @EstadoNuevoId IN (3, 4)
           AND NOT EXISTS (SELECT 1 FROM dbo.Diagnostico WHERE OrdenId = @OrdenId)
            THROW 50209, 'La orden todavía no tiene diagnóstico registrado.', 1;

        IF @EstadoNuevoId = 5
           AND NOT EXISTS (SELECT 1
                           FROM dbo.Reparacion rp
                           JOIN dbo.Diagnostico d ON d.DiagnosticoId = rp.DiagnosticoId
                           WHERE d.OrdenId = @OrdenId)
            THROW 50210, 'La orden todavía no tiene una reparación registrada.', 1;

        IF @EstadoNuevoId = 7 AND (@Observacion IS NULL OR LTRIM(RTRIM(@Observacion)) = '')
            THROW 50211, 'Indique el motivo de la cancelación en la observación.', 1;

        -- Cambiar el estado y guardar el historial
        UPDATE dbo.OrdenServicio
        SET EstadoOrdenId = @EstadoNuevoId
        WHERE OrdenId = @OrdenId;

        INSERT INTO dbo.HistorialEstadoOrden
            (OrdenId, EstadoAnteriorId, EstadoNuevoId, UsuarioId, Observacion)
        VALUES
            (@OrdenId, @EstadoActualId, @EstadoNuevoId, @UsuarioId, @Observacion);

        COMMIT TRANSACTION;

        -- Lo que devuelve
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
   sp_LoginUsuario
   Login por correo + contraseña (método normal).
   Compara el SHA256 de la contraseña con ContrasenaHash.
   Si es exitoso devuelve los datos del usuario, sus roles
   y sus permisos activos (regla: cada usuario solo ve y
   ejecuta las opciones de su rol); si falla devuelve 0 filas.
   Usa las tablas RolPermiso y Permiso: correr 08_permisos.sql antes.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_LoginUsuario
    @Correo     VARCHAR(100),
    @Contrasena VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Hash VARCHAR(64) =
        UPPER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @Contrasena), 2));

    SELECT u.UsuarioId,
           u.NombreUsuario,
           u.NombreCompleto,
           u.Correo,
           u.Telefono,
           (SELECT STRING_AGG(r.Nombre, ', ') WITHIN GROUP (ORDER BY r.RolId)
            FROM UsuarioRol ur
            INNER JOIN Rol r ON r.RolId = ur.RolId
            WHERE ur.UsuarioId = u.UsuarioId) AS Roles,
           -- Un permiso puede venir por dos roles (ej. RECEPCION y CAJA):
           -- GROUP BY lo deja una sola vez en la lista.
           (SELECT STRING_AGG(x.Codigo, ', ') WITHIN GROUP (ORDER BY x.Codigo)
            FROM (SELECT p.Codigo
                  FROM UsuarioRol ur
                  INNER JOIN RolPermiso rp ON rp.RolId    = ur.RolId
                  INNER JOIN Permiso p     ON p.PermisoId = rp.PermisoId
                  WHERE ur.UsuarioId = u.UsuarioId
                    AND p.Activo = 1
                  GROUP BY p.Codigo) x) AS Permisos
    FROM Usuario u
    WHERE u.Correo = @Correo
      AND u.Activo = 1
      AND u.ContrasenaHash = @Hash;
END;
GO

-- Verificar que se crearon los 3 procedimientos
SELECT name AS Procedimiento, create_date, modify_date
FROM sys.procedures
WHERE name IN ('sp_RegistrarOrden', 'sp_CambiarEstadoOrden', 'sp_LoginUsuario')
ORDER BY name;
GO
GO

/* ##########################################################
    5/12  04_procesos.sql
   Diagnóstico, reparación, repuestos, compras y vistas de reportes
   Vistas (8): vw_OrdenesActivas, vw_HistorialEquipo, vw_TrabajoTecnicos, vw_RepuestosUtilizados,
       vw_InventarioActual, vw_RepuestosBajoMinimo, vw_ComprasProveedor, vw_MovimientosInventario
   Funciones (3): fn_UsuarioTieneRol, fn_TotalOrden, fn_SaldoFactura
   Procedimientos (8): sp_RegistrarDiagnostico, sp_IniciarReparacion,
       sp_RegistrarActividadReparacion, sp_FinalizarReparacion, sp_AsignarRepuesto,
       sp_RegistrarCompra, sp_RecibirCompra, sp_AnularCompra
   ########################################################## */
PRINT '>> 5/12 04_procesos.sql';
GO

/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 04: procesos de la Semana 3
     - Funciones (roles, total de la orden, saldo de factura)
     - Diagnóstico y reparación
     - Repuestos usados en la reparación (salida de inventario)
     - Compras y recepción en bodega (entrada de inventario)
     - Primeros reportes (vistas)
   Se ejecuta después del 01, 02 y 03
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   ===================== FUNCIONES ==========================
   ========================================================== */

/* ----------------------------------------------------------
   fn_UsuarioTieneRol
   Devuelve 1 si el usuario está activo y tiene el rol indicado.
   El ADMINISTRADOR siempre cuenta como autorizado.
   Se usa en todos los procesos para validar permisos (R03).
   ---------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_UsuarioTieneRol (
    @UsuarioId  INT,
    @Rol        VARCHAR(30)
)
RETURNS BIT
AS
BEGIN
    DECLARE @Resultado BIT = 0;

    IF EXISTS (SELECT 1
               FROM dbo.Usuario u
               JOIN dbo.UsuarioRol ur ON ur.UsuarioId = u.UsuarioId
               JOIN dbo.Rol r         ON r.RolId      = ur.RolId
               WHERE u.UsuarioId = @UsuarioId
                 AND u.Activo = 1 AND r.Activo = 1
                 AND r.Nombre IN (@Rol, 'ADMINISTRADOR'))
        SET @Resultado = 1;

    RETURN @Resultado;
END;
GO

/* ----------------------------------------------------------
   fn_TotalOrden
   Total de la orden SIN IVA = mano de obra + repuestos usados.
   - Mano de obra: la de la reparación; si todavía no hay
     reparación, la estimada del diagnóstico; si no, 0.
   - Repuestos: cantidad x precio de venta HISTÓRICO (R09).
   Devuelve NULL si la orden no existe.
   La factura (Semana 4) le suma el IVA del 12 %.
   ---------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_TotalOrden (@OrdenId INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @ManoObra  DECIMAL(10,2) = NULL;
    DECLARE @Repuestos DECIMAL(10,2) = 0;

    SELECT @ManoObra = COALESCE(rp.CostoManoObra, d.CostoManoObraEstimado, 0)
    FROM dbo.OrdenServicio o
    LEFT JOIN dbo.Diagnostico d ON d.OrdenId        = o.OrdenId
    LEFT JOIN dbo.Reparacion rp ON rp.DiagnosticoId = d.DiagnosticoId
    WHERE o.OrdenId = @OrdenId;

    IF @ManoObra IS NULL
        RETURN NULL;   -- la orden no existe

    SELECT @Repuestos = ISNULL(SUM(rr.Cantidad * rr.PrecioVentaUnitario), 0)
    FROM dbo.Diagnostico d
    JOIN dbo.Reparacion rp         ON rp.DiagnosticoId = d.DiagnosticoId
    JOIN dbo.ReparacionRepuesto rr ON rr.ReparacionId  = rp.ReparacionId
    WHERE d.OrdenId = @OrdenId;

    RETURN @ManoObra + @Repuestos;
END;
GO

/* ----------------------------------------------------------
   fn_SaldoFactura
   Saldo pendiente = total de la factura - pagos APLICADOS (R13).
   Factura ANULADA devuelve 0. Si no existe devuelve NULL.
   ---------------------------------------------------------- */
CREATE OR ALTER FUNCTION dbo.fn_SaldoFactura (@FacturaId INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @Total  DECIMAL(10,2) = NULL;
    DECLARE @Estado VARCHAR(10);
    DECLARE @Pagado DECIMAL(10,2);

    SELECT @Total = Total, @Estado = Estado
    FROM dbo.Factura
    WHERE FacturaId = @FacturaId;

    IF @Total IS NULL
        RETURN NULL;

    IF @Estado = 'ANULADA'
        RETURN 0;

    SELECT @Pagado = ISNULL(SUM(Monto), 0)
    FROM dbo.Pago
    WHERE FacturaId = @FacturaId
      AND Estado = 'APLICADO';

    RETURN @Total - @Pagado;
END;
GO

/* ==========================================================
   =============== DIAGNÓSTICO Y REPARACIÓN =================
   ========================================================== */

/* ----------------------------------------------------------
   sp_RegistrarDiagnostico
   El técnico registra el diagnóstico de una orden y la orden
   pasa a ESPERANDO_AUTORIZACION (el cliente decide si repara).
   Si la orden estaba en RECIBIDO, se guarda también el paso
   por DIAGNOSTICO para que el historial quede completo (R05).
   Errores 50301 - 50306
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarDiagnostico
    @OrdenId                INT,
    @TecnicoId              INT,
    @Descripcion            VARCHAR(500),
    @CostoManoObraEstimado  DECIMAL(10,2) = 0,
    @Observaciones          VARCHAR(300)  = NULL,
    @DiagnosticoId          INT           = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoActualId INT;

    BEGIN TRY
        IF @Descripcion IS NULL OR LTRIM(RTRIM(@Descripcion)) = ''
            THROW 50301, 'Debe escribir la descripción del diagnóstico.', 1;

        IF @CostoManoObraEstimado IS NULL OR @CostoManoObraEstimado < 0
            THROW 50302, 'El costo estimado de mano de obra no puede ser negativo.', 1;

        IF dbo.fn_UsuarioTieneRol(@TecnicoId, 'TECNICO') = 0
            THROW 50303, 'El usuario no está autorizado para diagnosticar (rol TECNICO o ADMINISTRADOR).', 1;

        BEGIN TRANSACTION;

        SELECT @EstadoActualId = EstadoOrdenId
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
        WHERE OrdenId = @OrdenId;

        IF @EstadoActualId IS NULL
            THROW 50304, 'La orden no existe.', 1;

        IF @EstadoActualId NOT IN (1, 2)
            THROW 50305, 'Solo se puede diagnosticar una orden en estado RECIBIDO o DIAGNOSTICO.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Diagnostico WHERE OrdenId = @OrdenId)
            THROW 50306, 'La orden ya tiene un diagnóstico registrado.', 1;

        INSERT INTO dbo.Diagnostico (OrdenId, TecnicoId, Descripcion, CostoManoObraEstimado, Observaciones)
        VALUES (@OrdenId, @TecnicoId, LTRIM(RTRIM(@Descripcion)), @CostoManoObraEstimado, @Observaciones);

        SET @DiagnosticoId = SCOPE_IDENTITY();

        -- Si venía de RECIBIDO, se guarda el paso por DIAGNOSTICO
        IF @EstadoActualId = 1
            INSERT INTO dbo.HistorialEstadoOrden (OrdenId, EstadoAnteriorId, EstadoNuevoId, UsuarioId, Observacion)
            VALUES (@OrdenId, 1, 2, @TecnicoId, 'Inicia diagnóstico');

        UPDATE dbo.OrdenServicio
        SET EstadoOrdenId = 3
        WHERE OrdenId = @OrdenId;

        INSERT INTO dbo.HistorialEstadoOrden (OrdenId, EstadoAnteriorId, EstadoNuevoId, UsuarioId, Observacion)
        VALUES (@OrdenId, 2, 3, @TecnicoId, 'Diagnóstico registrado, esperando autorización del cliente');

        COMMIT TRANSACTION;

        SELECT o.OrdenId, o.NumeroOrden, @DiagnosticoId AS DiagnosticoId,
               'ESPERANDO_AUTORIZACION' AS Estado
        FROM dbo.OrdenServicio o
        WHERE o.OrdenId = @OrdenId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_IniciarReparacion
   El cliente autorizó: se crea la reparación y la orden pasa
   a REPARACION. No se permite sin diagnóstico previo (R04).
   La mano de obra inicia con el costo estimado del diagnóstico.
   Errores 50401 - 50405
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_IniciarReparacion
    @OrdenId             INT,
    @TecnicoId           INT,
    @DescripcionTrabajo  VARCHAR(500) = NULL,
    @ReparacionId        INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoActualId INT;
    DECLARE @DiagnosticoId  INT;
    DECLARE @CostoEstimado  DECIMAL(10,2);

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@TecnicoId, 'TECNICO') = 0
            THROW 50401, 'El usuario no está autorizado para reparar (rol TECNICO o ADMINISTRADOR).', 1;

        BEGIN TRANSACTION;

        SELECT @EstadoActualId = EstadoOrdenId
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
        WHERE OrdenId = @OrdenId;

        IF @EstadoActualId IS NULL
            THROW 50402, 'La orden no existe.', 1;

        SELECT @DiagnosticoId = DiagnosticoId,
               @CostoEstimado = CostoManoObraEstimado
        FROM dbo.Diagnostico
        WHERE OrdenId = @OrdenId;

        IF @DiagnosticoId IS NULL
            THROW 50403, 'No se puede iniciar una reparación sin un diagnóstico previo.', 1;

        -- 3 = ESPERANDO_AUTORIZACION (el cliente autorizó)
        -- 4 = REPARACION (por si ya la cambiaron con sp_CambiarEstadoOrden)
        IF @EstadoActualId NOT IN (3, 4)
            THROW 50404, 'La orden debe estar en ESPERANDO_AUTORIZACION para iniciar la reparación.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Reparacion WHERE DiagnosticoId = @DiagnosticoId)
            THROW 50405, 'La orden ya tiene una reparación registrada.', 1;

        INSERT INTO dbo.Reparacion (DiagnosticoId, TecnicoId, DescripcionTrabajo, CostoManoObra, Estado)
        VALUES (@DiagnosticoId, @TecnicoId, @DescripcionTrabajo, @CostoEstimado, 'EN_PROCESO');

        SET @ReparacionId = SCOPE_IDENTITY();

        IF @EstadoActualId = 3
        BEGIN
            UPDATE dbo.OrdenServicio
            SET EstadoOrdenId = 4
            WHERE OrdenId = @OrdenId;

            INSERT INTO dbo.HistorialEstadoOrden (OrdenId, EstadoAnteriorId, EstadoNuevoId, UsuarioId, Observacion)
            VALUES (@OrdenId, 3, 4, @TecnicoId, 'Cliente autorizó, inicia la reparación');
        END;

        COMMIT TRANSACTION;

        SELECT o.OrdenId, o.NumeroOrden, @ReparacionId AS ReparacionId,
               'REPARACION' AS Estado
        FROM dbo.OrdenServicio o
        WHERE o.OrdenId = @OrdenId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_RegistrarActividadReparacion
   Agrega una actividad a una reparación en proceso
   (una reparación puede tener varias actividades).
   Errores 50411 - 50415
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarActividadReparacion
    @ReparacionId     INT,
    @UsuarioId        INT,
    @Descripcion      VARCHAR(300),
    @HorasTrabajadas  DECIMAL(5,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRep VARCHAR(12);
    DECLARE @Numero    INT;

    BEGIN TRY
        IF @Descripcion IS NULL OR LTRIM(RTRIM(@Descripcion)) = ''
            THROW 50411, 'Debe describir la actividad realizada.', 1;

        IF @HorasTrabajadas IS NOT NULL AND @HorasTrabajadas <= 0
            THROW 50412, 'Las horas trabajadas deben ser mayores que cero.', 1;

        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'TECNICO') = 0
            THROW 50413, 'El usuario no está autorizado para registrar actividades (rol TECNICO o ADMINISTRADOR).', 1;

        BEGIN TRANSACTION;

        SELECT @EstadoRep = Estado
        FROM dbo.Reparacion WITH (UPDLOCK, HOLDLOCK)
        WHERE ReparacionId = @ReparacionId;

        IF @EstadoRep IS NULL
            THROW 50414, 'La reparación no existe.', 1;

        IF @EstadoRep <> 'EN_PROCESO'
            THROW 50415, 'Solo se agregan actividades a una reparación EN_PROCESO.', 1;

        SELECT @Numero = ISNULL(MAX(NumeroActividad), 0) + 1
        FROM dbo.ActividadReparacion WITH (UPDLOCK, HOLDLOCK)
        WHERE ReparacionId = @ReparacionId;

        INSERT INTO dbo.ActividadReparacion (ReparacionId, NumeroActividad, Descripcion, HorasTrabajadas)
        VALUES (@ReparacionId, @Numero, LTRIM(RTRIM(@Descripcion)), @HorasTrabajadas);

        COMMIT TRANSACTION;

        SELECT @ReparacionId AS ReparacionId, @Numero AS NumeroActividad;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_FinalizarReparacion
   Cierra la reparación (fecha fin, costo final, descripción)
   y la orden pasa a LISTO.
   Errores 50421 - 50426
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_FinalizarReparacion
    @ReparacionId        INT,
    @TecnicoId           INT,
    @CostoManoObra       DECIMAL(10,2) = NULL,   -- NULL = se queda el que tiene
    @DescripcionTrabajo  VARCHAR(500)  = NULL    -- NULL = se queda la que tiene
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRep      VARCHAR(12);
    DECLARE @DescActual     VARCHAR(500);
    DECLARE @OrdenId        INT;
    DECLARE @EstadoOrdenId  INT;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@TecnicoId, 'TECNICO') = 0
            THROW 50421, 'El usuario no está autorizado para finalizar reparaciones (rol TECNICO o ADMINISTRADOR).', 1;

        IF @CostoManoObra IS NOT NULL AND @CostoManoObra < 0
            THROW 50422, 'El costo de mano de obra no puede ser negativo.', 1;

        BEGIN TRANSACTION;

        SELECT @EstadoRep     = rp.Estado,
               @DescActual    = rp.DescripcionTrabajo,
               @OrdenId       = o.OrdenId,
               @EstadoOrdenId = o.EstadoOrdenId
        FROM dbo.Reparacion rp WITH (UPDLOCK, HOLDLOCK)
        JOIN dbo.Diagnostico d    ON d.DiagnosticoId = rp.DiagnosticoId
        JOIN dbo.OrdenServicio o  ON o.OrdenId       = d.OrdenId
        WHERE rp.ReparacionId = @ReparacionId;

        IF @EstadoRep IS NULL
            THROW 50423, 'La reparación no existe.', 1;

        IF @EstadoRep <> 'EN_PROCESO'
            THROW 50424, 'La reparación ya fue finalizada o cancelada.', 1;

        IF @EstadoOrdenId <> 4
            THROW 50425, 'La orden no está en estado REPARACION.', 1;

        IF COALESCE(NULLIF(LTRIM(RTRIM(@DescripcionTrabajo)), ''), @DescActual) IS NULL
            THROW 50426, 'Describa el trabajo realizado antes de finalizar.', 1;

        UPDATE dbo.Reparacion
        SET FechaFin           = GETDATE(),
            Estado             = 'FINALIZADA',
            CostoManoObra      = ISNULL(@CostoManoObra, CostoManoObra),
            DescripcionTrabajo = COALESCE(NULLIF(LTRIM(RTRIM(@DescripcionTrabajo)), ''), DescripcionTrabajo)
        WHERE ReparacionId = @ReparacionId;

        UPDATE dbo.OrdenServicio
        SET EstadoOrdenId = 5
        WHERE OrdenId = @OrdenId;

        INSERT INTO dbo.HistorialEstadoOrden (OrdenId, EstadoAnteriorId, EstadoNuevoId, UsuarioId, Observacion)
        VALUES (@OrdenId, 4, 5, @TecnicoId, 'Reparación finalizada');

        COMMIT TRANSACTION;

        SELECT o.OrdenId, o.NumeroOrden, @ReparacionId AS ReparacionId,
               'LISTO' AS Estado,
               dbo.fn_TotalOrden(o.OrdenId) AS TotalSinIVA
        FROM dbo.OrdenServicio o
        WHERE o.OrdenId = @OrdenId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   ============ REPUESTOS USADOS EN REPARACIÓN ==============
   ========================================================== */

/* ----------------------------------------------------------
   sp_AsignarRepuesto
   Usa un repuesto en una reparación, todo en una transacción:
     1. valida que exista en la bodega y tenga stock (R06, R10)
     2. descuenta el inventario
     3. guarda el detalle con el precio del momento (R09)
     4. registra el movimiento de SALIDA (R07)
   Si algo falla no queda nada aplicado (R15).
   Si el mismo repuesto de la misma bodega se agrega otra vez,
   se suma la cantidad y se mantiene el precio del primer registro.
   Errores 50501 - 50508
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_AsignarRepuesto
    @ReparacionId  INT,
    @RepuestoId    INT,
    @BodegaId      INT,
    @Cantidad      INT,
    @UsuarioId     INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @EstadoRep      VARCHAR(12);
    DECLARE @EstadoOrdenId  INT;
    DECLARE @NumeroOrden    VARCHAR(15);
    DECLARE @Existencia     INT;
    DECLARE @Resultante     INT;
    DECLARE @Costo          DECIMAL(10,2);
    DECLARE @Venta          DECIMAL(10,2);
    DECLARE @Msg            NVARCHAR(2048);

    BEGIN TRY
        IF @Cantidad IS NULL OR @Cantidad <= 0
            THROW 50501, 'La cantidad debe ser mayor que cero.', 1;

        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'TECNICO') = 0
            THROW 50502, 'El usuario no está autorizado para asignar repuestos (rol TECNICO o ADMINISTRADOR).', 1;

        SELECT @Costo = PrecioCompraReferencia,
               @Venta = PrecioVenta
        FROM dbo.Repuesto
        WHERE RepuestoId = @RepuestoId AND Estado = 'ACTIVO';

        IF @Venta IS NULL
            THROW 50503, 'El repuesto no existe o está inactivo.', 1;

        BEGIN TRANSACTION;

        -- Reparación y orden
        SELECT @EstadoRep     = rp.Estado,
               @EstadoOrdenId = o.EstadoOrdenId,
               @NumeroOrden   = o.NumeroOrden
        FROM dbo.Reparacion rp WITH (UPDLOCK, HOLDLOCK)
        JOIN dbo.Diagnostico d    ON d.DiagnosticoId = rp.DiagnosticoId
        JOIN dbo.OrdenServicio o  ON o.OrdenId       = d.OrdenId
        WHERE rp.ReparacionId = @ReparacionId;

        IF @EstadoRep IS NULL
            THROW 50504, 'La reparación no existe.', 1;

        IF @EstadoRep <> 'EN_PROCESO'
            THROW 50505, 'Solo se asignan repuestos a una reparación EN_PROCESO.', 1;

        IF @EstadoOrdenId <> 4
            THROW 50508, 'La orden no está en estado REPARACION.', 1;

        -- Se bloquea la fila del inventario para que nadie más la use al mismo tiempo
        SELECT @Existencia = i.Existencia
        FROM dbo.Inventario i WITH (UPDLOCK, HOLDLOCK)
        JOIN dbo.Bodega b ON b.BodegaId = i.BodegaId
        WHERE i.RepuestoId = @RepuestoId
          AND i.BodegaId   = @BodegaId
          AND b.Activo     = 1;

        IF @Existencia IS NULL
            THROW 50506, 'El repuesto no está registrado en el inventario de esa bodega.', 1;

        IF @Existencia < @Cantidad
        BEGIN
            SET @Msg = CONCAT('Stock insuficiente: hay ', @Existencia,
                              ' unidad(es) en la bodega y se pidieron ', @Cantidad, '.');
            THROW 50507, @Msg, 1;
        END;

        SET @Resultante = @Existencia - @Cantidad;

        -- 1. Descontar inventario
        UPDATE dbo.Inventario
        SET Existencia         = @Resultante,
            FechaActualizacion = GETDATE()
        WHERE RepuestoId = @RepuestoId AND BodegaId = @BodegaId;

        -- 2. Detalle de la reparación (precio del momento)
        IF EXISTS (SELECT 1 FROM dbo.ReparacionRepuesto
                   WHERE ReparacionId = @ReparacionId AND RepuestoId = @RepuestoId AND BodegaId = @BodegaId)
            UPDATE dbo.ReparacionRepuesto
            SET Cantidad = Cantidad + @Cantidad
            WHERE ReparacionId = @ReparacionId AND RepuestoId = @RepuestoId AND BodegaId = @BodegaId;
        ELSE
            INSERT INTO dbo.ReparacionRepuesto
                (ReparacionId, RepuestoId, BodegaId, Cantidad, CostoUnitario, PrecioVentaUnitario, UsuarioId)
            VALUES
                (@ReparacionId, @RepuestoId, @BodegaId, @Cantidad, @Costo, @Venta, @UsuarioId);

        -- 3. Movimiento de salida
        INSERT INTO dbo.MovimientoInventario
            (RepuestoId, BodegaId, TipoMovimiento, Cantidad, ExistenciaResultante,
             CompraId, ReparacionId, UsuarioId, Observacion)
        VALUES
            (@RepuestoId, @BodegaId, 'SALIDA', @Cantidad, @Resultante,
             NULL, @ReparacionId, @UsuarioId, 'Consumo en orden ' + @NumeroOrden);

        COMMIT TRANSACTION;

        SELECT @NumeroOrden AS NumeroOrden, r.Codigo, r.Nombre AS Repuesto, b.Nombre AS Bodega,
               @Cantidad AS Cantidad, @Existencia AS ExistenciaAnterior, @Resultante AS ExistenciaResultante
        FROM dbo.Repuesto r
        CROSS JOIN dbo.Bodega b
        WHERE r.RepuestoId = @RepuestoId AND b.BodegaId = @BodegaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   ================ COMPRAS E INVENTARIO ====================
   ========================================================== */

/* ----------------------------------------------------------
   sp_RegistrarCompra
   Crea la compra (encabezado + detalle) en estado PENDIENTE.
   Todavía NO mueve inventario; eso lo hace sp_RecibirCompra.
   El detalle llega en JSON, por ejemplo:
   [{"repuestoId":1,"cantidad":5,"costoUnitario":350.00},
    {"repuestoId":3,"cantidad":10,"costoUnitario":180.00}]
   Número de compra: OC-AAAA-0001
   Errores 50601 - 50607
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarCompra
    @ProveedorId    INT,
    @BodegaId       INT,
    @UsuarioId      INT,
    @Detalle        NVARCHAR(MAX),
    @Observaciones  VARCHAR(300) = NULL,
    @CompraId       INT          = NULL OUTPUT,
    @NumeroCompra   VARCHAR(20)  = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Lineas TABLE (
        RepuestoId     INT,
        Cantidad       INT,
        CostoUnitario  DECIMAL(10,2)
    );

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 50601, 'El usuario no está autorizado para registrar compras (rol BODEGA o ADMINISTRADOR).', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE ProveedorId = @ProveedorId AND Estado = 'ACTIVO')
            THROW 50602, 'El proveedor no existe o está inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Bodega WHERE BodegaId = @BodegaId AND Activo = 1)
            THROW 50603, 'La bodega no existe o está inactiva.', 1;

        IF @Detalle IS NULL OR ISJSON(@Detalle) = 0
            THROW 50604, 'El detalle de la compra no es válido.', 1;

        INSERT INTO @Lineas (RepuestoId, Cantidad, CostoUnitario)
        SELECT RepuestoId, Cantidad, CostoUnitario
        FROM OPENJSON(@Detalle)
        WITH (
            RepuestoId     INT           '$.repuestoId',
            Cantidad       INT           '$.cantidad',
            CostoUnitario  DECIMAL(10,2) '$.costoUnitario'
        );

        IF NOT EXISTS (SELECT 1 FROM @Lineas)
            THROW 50604, 'La compra debe tener al menos un repuesto.', 1;

        IF EXISTS (SELECT 1 FROM @Lineas
                   WHERE RepuestoId IS NULL
                      OR Cantidad IS NULL OR Cantidad <= 0
                      OR CostoUnitario IS NULL OR CostoUnitario < 0)
            THROW 50605, 'Cada línea necesita repuesto, cantidad mayor que cero y costo no negativo.', 1;

        -- LEFT JOIN: las líneas cuyo repuesto no existe quedan con r.RepuestoId en NULL
        IF EXISTS (SELECT 1
                   FROM @Lineas l
                   LEFT JOIN dbo.Repuesto r ON r.RepuestoId = l.RepuestoId AND r.Estado = 'ACTIVO'
                   WHERE r.RepuestoId IS NULL)
            THROW 50606, 'Uno de los repuestos no existe o está inactivo.', 1;

        IF EXISTS (SELECT RepuestoId FROM @Lineas GROUP BY RepuestoId HAVING COUNT(*) > 1)
            THROW 50607, 'Un repuesto aparece repetido en el detalle. Junte las cantidades en una sola línea.', 1;

        BEGIN TRANSACTION;

        -- Número de compra: OC-AAAA-0001
        DECLARE @Prefijo VARCHAR(8) = 'OC-' + CAST(YEAR(GETDATE()) AS CHAR(4)) + '-';
        DECLARE @Siguiente INT;

        SELECT @Siguiente = ISNULL(MAX(CAST(SUBSTRING(NumeroCompra, 9, 10) AS INT)), 0) + 1
        FROM dbo.Compra WITH (UPDLOCK, HOLDLOCK)
        WHERE NumeroCompra LIKE @Prefijo + '%';

        SET @NumeroCompra = @Prefijo + RIGHT('0000' + CAST(@Siguiente AS VARCHAR(10)),
                                             CASE WHEN @Siguiente > 9999 THEN LEN(CAST(@Siguiente AS VARCHAR(10))) ELSE 4 END);

        INSERT INTO dbo.Compra (NumeroCompra, ProveedorId, BodegaId, Estado, UsuarioId, Observaciones)
        VALUES (@NumeroCompra, @ProveedorId, @BodegaId, 'PENDIENTE', @UsuarioId, @Observaciones);

        SET @CompraId = SCOPE_IDENTITY();

        INSERT INTO dbo.DetalleCompra (CompraId, RepuestoId, Cantidad, CostoUnitario)
        SELECT @CompraId, RepuestoId, Cantidad, CostoUnitario
        FROM @Lineas;

        COMMIT TRANSACTION;

        SELECT @CompraId AS CompraId, @NumeroCompra AS NumeroCompra, 'PENDIENTE' AS Estado,
               COUNT(*) AS Lineas, SUM(Cantidad * CostoUnitario) AS TotalCompra
        FROM @Lineas;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_RecibirCompra
   Recibe una compra PENDIENTE en su bodega, todo en una
   transacción (R08):
     1. crea la fila de inventario si el repuesto no estaba
        en esa bodega
     2. suma las cantidades al inventario
     3. registra un movimiento de ENTRADA por cada repuesto
     4. marca la compra como RECIBIDA
   @SimularError = 1 provoca un error al final, solo para
   demostrar el ROLLBACK (prueba T07). Normalmente va en 0.
   Errores 50611 - 50615
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_RecibirCompra
    @CompraId      INT,
    @UsuarioId     INT,
    @SimularError  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Estado        VARCHAR(10);
    DECLARE @BodegaId      INT;
    DECLARE @NumeroCompra  VARCHAR(20);
    DECLARE @Msg           NVARCHAR(2048);

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 50611, 'El usuario no está autorizado para recibir compras (rol BODEGA o ADMINISTRADOR).', 1;

        BEGIN TRANSACTION;

        SELECT @Estado       = Estado,
               @BodegaId     = BodegaId,
               @NumeroCompra = NumeroCompra
        FROM dbo.Compra WITH (UPDLOCK, HOLDLOCK)
        WHERE CompraId = @CompraId;

        IF @Estado IS NULL
            THROW 50612, 'La compra no existe.', 1;

        IF @Estado <> 'PENDIENTE'
        BEGIN
            SET @Msg = CONCAT('La compra ', @NumeroCompra, ' está ', @Estado, '; solo se recibe una compra PENDIENTE.');
            THROW 50613, @Msg, 1;
        END;

        IF NOT EXISTS (SELECT 1 FROM dbo.DetalleCompra WHERE CompraId = @CompraId)
            THROW 50614, 'La compra no tiene detalle.', 1;

        -- 1. Crear la fila de inventario si el repuesto no estaba en esa bodega
        INSERT INTO dbo.Inventario (RepuestoId, BodegaId, Existencia, StockMinimo)
        SELECT dc.RepuestoId, @BodegaId, 0, 0
        FROM dbo.DetalleCompra dc
        WHERE dc.CompraId = @CompraId
          AND NOT EXISTS (SELECT 1 FROM dbo.Inventario i WITH (UPDLOCK, HOLDLOCK)
                          WHERE i.RepuestoId = dc.RepuestoId AND i.BodegaId = @BodegaId);

        -- 2. Sumar al inventario
        UPDATE i
        SET i.Existencia         = i.Existencia + dc.Cantidad,
            i.FechaActualizacion = GETDATE()
        FROM dbo.Inventario i
        JOIN dbo.DetalleCompra dc ON dc.RepuestoId = i.RepuestoId
        WHERE dc.CompraId = @CompraId
          AND i.BodegaId  = @BodegaId;

        -- 3. Movimiento de entrada (la existencia resultante ya es la nueva)
        INSERT INTO dbo.MovimientoInventario
            (RepuestoId, BodegaId, TipoMovimiento, Cantidad, ExistenciaResultante,
             CompraId, ReparacionId, UsuarioId, Observacion)
        SELECT dc.RepuestoId, @BodegaId, 'ENTRADA', dc.Cantidad, i.Existencia,
               @CompraId, NULL, @UsuarioId, 'Recepción de compra ' + @NumeroCompra
        FROM dbo.DetalleCompra dc
        JOIN dbo.Inventario i ON i.RepuestoId = dc.RepuestoId AND i.BodegaId = @BodegaId
        WHERE dc.CompraId = @CompraId;

        -- Solo para la prueba T07: el error ocurre con el inventario ya
        -- actualizado, y el ROLLBACK tiene que deshacer todo
        IF @SimularError = 1
            THROW 50615, 'Error simulado durante la recepción (prueba T07). Se revierte todo con ROLLBACK.', 1;

        -- 4. Compra recibida
        UPDATE dbo.Compra
        SET Estado         = 'RECIBIDA',
            FechaRecepcion = GETDATE()
        WHERE CompraId = @CompraId;

        COMMIT TRANSACTION;

        SELECT @CompraId AS CompraId, @NumeroCompra AS NumeroCompra, 'RECIBIDA' AS Estado,
               COUNT(*) AS Lineas, SUM(Cantidad) AS UnidadesRecibidas
        FROM dbo.DetalleCompra
        WHERE CompraId = @CompraId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_AnularCompra
   Anula una compra PENDIENTE. No se borra nada (R14).
   Una compra RECIBIDA ya movió inventario y no se anula.
   Errores 50621 - 50624
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_AnularCompra
    @CompraId   INT,
    @UsuarioId  INT,
    @Motivo     VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Estado VARCHAR(10);

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 50621, 'El usuario no está autorizado para anular compras (rol BODEGA o ADMINISTRADOR).', 1;

        IF @Motivo IS NULL OR LTRIM(RTRIM(@Motivo)) = ''
            THROW 50622, 'Indique el motivo de la anulación.', 1;

        BEGIN TRANSACTION;

        SELECT @Estado = Estado
        FROM dbo.Compra WITH (UPDLOCK, HOLDLOCK)
        WHERE CompraId = @CompraId;

        IF @Estado IS NULL
            THROW 50623, 'La compra no existe.', 1;

        IF @Estado <> 'PENDIENTE'
            THROW 50624, 'Solo se puede anular una compra PENDIENTE.', 1;

        UPDATE dbo.Compra
        SET Estado        = 'ANULADA',
            Observaciones = LEFT(CONCAT(Observaciones + ' | ', 'ANULADA: ', LTRIM(RTRIM(@Motivo))), 300)
        WHERE CompraId = @CompraId;

        COMMIT TRANSACTION;

        SELECT CompraId, NumeroCompra, Estado, Observaciones
        FROM dbo.Compra
        WHERE CompraId = @CompraId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   ============== VISTAS (PRIMEROS REPORTES) ================
   Los filtros (fechas, estado, bodega, etc.) se aplican con
   WHERE desde la API, con parámetros.
   ========================================================== */

/* ----------------------------------------------------------
   Reporte 1: órdenes activas por estado, prioridad y técnico
   LEFT JOIN: una orden recién recibida aún no tiene
   diagnóstico ni reparación y no debe desaparecer.
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_OrdenesActivas
AS
SELECT o.OrdenId,
       o.NumeroOrden,
       o.FechaIngreso,
       o.FechaEstimada,
       DATEDIFF(DAY, o.FechaIngreso, GETDATE())   AS DiasAbierta,
       eo.EstadoOrdenId,
       eo.Codigo                                  AS Estado,
       o.Prioridad,
       CASE o.Prioridad WHEN 'URGENTE' THEN 1
                        WHEN 'ALTA'    THEN 2
                        WHEN 'MEDIA'   THEN 3
                        ELSE 4 END                AS NivelPrioridad,
       c.ClienteId,
       c.NombreRazonSocial                        AS Cliente,
       te.Nombre                                  AS TipoEquipo,
       e.Marca + ' ' + e.Modelo                   AS Equipo,
       e.NumeroSerie,
       urec.NombreCompleto                        AS RecibidoPor,
       COALESCE(utr.NombreCompleto, utd.NombreCompleto, 'Sin asignar') AS TecnicoResponsable,
       o.ProblemaReportado,
       dbo.fn_TotalOrden(o.OrdenId)               AS TotalSinIVA
FROM dbo.OrdenServicio o
JOIN dbo.EstadoOrden eo      ON eo.EstadoOrdenId = o.EstadoOrdenId
JOIN dbo.Cliente c           ON c.ClienteId      = o.ClienteId
JOIN dbo.Equipo e            ON e.EquipoId       = o.EquipoId
JOIN dbo.TipoEquipo te       ON te.TipoEquipoId  = e.TipoEquipoId
JOIN dbo.Usuario urec        ON urec.UsuarioId   = o.UsuarioRecepcionId
LEFT JOIN dbo.Diagnostico d  ON d.OrdenId        = o.OrdenId
LEFT JOIN dbo.Usuario utd    ON utd.UsuarioId    = d.TecnicoId
LEFT JOIN dbo.Reparacion rp  ON rp.DiagnosticoId = d.DiagnosticoId
LEFT JOIN dbo.Usuario utr    ON utr.UsuarioId    = rp.TecnicoId
WHERE o.EstadoOrdenId NOT IN (6, 7);   -- 6 ENTREGADO, 7 CANCELADO
GO

/* ----------------------------------------------------------
   Reporte 3: historial técnico de un equipo (buscar por
   NumeroSerie). LEFT JOIN: el equipo aparece aunque no tenga
   órdenes, y cada orden aunque no tenga diagnóstico,
   reparación o factura.
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_HistorialEquipo
AS
SELECT e.EquipoId,
       e.NumeroSerie,
       te.Nombre                     AS TipoEquipo,
       e.Marca,
       e.Modelo,
       c.NombreRazonSocial           AS Propietario,
       o.OrdenId,
       o.NumeroOrden,
       o.FechaIngreso,
       eo.Codigo                     AS EstadoOrden,
       o.ProblemaReportado,
       d.FechaDiagnostico,
       utd.NombreCompleto            AS TecnicoDiagnostico,
       d.Descripcion                 AS Diagnostico,
       utr.NombreCompleto            AS TecnicoReparacion,
       rp.FechaInicio                AS InicioReparacion,
       rp.FechaFin                   AS FinReparacion,
       rp.Estado                     AS EstadoReparacion,
       rp.DescripcionTrabajo         AS TrabajoRealizado,
       f.NumeroFactura,
       f.Total                       AS TotalFacturado
FROM dbo.Equipo e
JOIN dbo.TipoEquipo te          ON te.TipoEquipoId  = e.TipoEquipoId
JOIN dbo.Cliente c              ON c.ClienteId      = e.ClienteId
LEFT JOIN dbo.OrdenServicio o   ON o.EquipoId       = e.EquipoId
LEFT JOIN dbo.EstadoOrden eo    ON eo.EstadoOrdenId = o.EstadoOrdenId
LEFT JOIN dbo.Diagnostico d     ON d.OrdenId        = o.OrdenId
LEFT JOIN dbo.Usuario utd       ON utd.UsuarioId    = d.TecnicoId
LEFT JOIN dbo.Reparacion rp     ON rp.DiagnosticoId = d.DiagnosticoId
LEFT JOIN dbo.Usuario utr       ON utr.UsuarioId    = rp.TecnicoId
LEFT JOIN dbo.Factura f         ON f.OrdenId        = o.OrdenId;
GO

/* ----------------------------------------------------------
   Reporte 4: diagnósticos y reparaciones por técnico
   (filtrar por TecnicoId y rango de Fecha desde la API)
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_TrabajoTecnicos
AS
SELECT 'DIAGNOSTICO'                         AS TipoTrabajo,
       u.UsuarioId                           AS TecnicoId,
       u.NombreCompleto                      AS Tecnico,
       d.FechaDiagnostico                    AS Fecha,
       CAST(NULL AS DATETIME)                AS FechaFin,
       o.NumeroOrden,
       c.NombreRazonSocial                   AS Cliente,
       e.NumeroSerie,
       d.Descripcion                         AS Detalle,
       d.CostoManoObraEstimado               AS ManoObra,
       CAST('REGISTRADO' AS VARCHAR(12))     AS Estado
FROM dbo.Diagnostico d
JOIN dbo.Usuario u        ON u.UsuarioId = d.TecnicoId
JOIN dbo.OrdenServicio o  ON o.OrdenId   = d.OrdenId
JOIN dbo.Cliente c        ON c.ClienteId = o.ClienteId
JOIN dbo.Equipo e         ON e.EquipoId  = o.EquipoId

UNION ALL

SELECT 'REPARACION',
       u.UsuarioId,
       u.NombreCompleto,
       rp.FechaInicio,
       rp.FechaFin,
       o.NumeroOrden,
       c.NombreRazonSocial,
       e.NumeroSerie,
       rp.DescripcionTrabajo,
       rp.CostoManoObra,
       rp.Estado
FROM dbo.Reparacion rp
JOIN dbo.Usuario u        ON u.UsuarioId     = rp.TecnicoId
JOIN dbo.Diagnostico d    ON d.DiagnosticoId = rp.DiagnosticoId
JOIN dbo.OrdenServicio o  ON o.OrdenId       = d.OrdenId
JOIN dbo.Cliente c        ON c.ClienteId     = o.ClienteId
JOIN dbo.Equipo e         ON e.EquipoId      = o.EquipoId;
GO

/* ----------------------------------------------------------
   Reporte 5: repuestos utilizados por orden, técnico y bodega
   con costo y venta HISTÓRICOS. Se muestra también el precio
   actual del catálogo para comparar (prueba T14).
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_RepuestosUtilizados
AS
SELECT o.OrdenId,
       o.NumeroOrden,
       c.NombreRazonSocial                              AS Cliente,
       ut.NombreCompleto                                AS Tecnico,
       b.BodegaId,
       b.Nombre                                         AS Bodega,
       cat.Nombre                                       AS Categoria,
       r.Codigo,
       r.Nombre                                         AS Repuesto,
       rr.Cantidad,
       rr.CostoUnitario                                 AS CostoHistorico,
       rr.PrecioVentaUnitario                           AS VentaHistorica,
       rr.Cantidad * rr.CostoUnitario                   AS CostoTotal,
       rr.Cantidad * rr.PrecioVentaUnitario             AS VentaTotal,
       r.PrecioVenta                                    AS PrecioVentaActual,
       rr.FechaRegistro
FROM dbo.ReparacionRepuesto rr
JOIN dbo.Reparacion rp    ON rp.ReparacionId  = rr.ReparacionId
JOIN dbo.Diagnostico d    ON d.DiagnosticoId  = rp.DiagnosticoId
JOIN dbo.OrdenServicio o  ON o.OrdenId        = d.OrdenId
JOIN dbo.Cliente c        ON c.ClienteId      = o.ClienteId
JOIN dbo.Usuario ut       ON ut.UsuarioId     = rp.TecnicoId
JOIN dbo.Repuesto r       ON r.RepuestoId     = rr.RepuestoId
JOIN dbo.Categoria cat    ON cat.CategoriaId  = r.CategoriaId
JOIN dbo.Bodega b         ON b.BodegaId       = rr.BodegaId;
GO

/* ----------------------------------------------------------
   Reporte 6: inventario actual por bodega, categoría y repuesto
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_InventarioActual
AS
SELECT b.BodegaId,
       b.Nombre                                      AS Bodega,
       cat.CategoriaId,
       cat.Nombre                                    AS Categoria,
       r.RepuestoId,
       r.Codigo,
       r.Nombre                                      AS Repuesto,
       i.Existencia,
       i.StockMinimo,
       r.PrecioCompraReferencia,
       r.PrecioVenta,
       i.Existencia * r.PrecioCompraReferencia       AS ValorInventario,
       CASE WHEN i.Existencia = 0              THEN 'SIN STOCK'
            WHEN i.Existencia <= i.StockMinimo THEN 'BAJO MINIMO'
            ELSE 'OK' END                            AS EstadoStock,
       i.FechaActualizacion
FROM dbo.Inventario i
JOIN dbo.Repuesto r    ON r.RepuestoId    = i.RepuestoId
JOIN dbo.Categoria cat ON cat.CategoriaId = r.CategoriaId
JOIN dbo.Bodega b      ON b.BodegaId      = i.BodegaId;
GO

/* ----------------------------------------------------------
   Reporte 7: repuestos con existencia igual o menor al mínimo
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_RepuestosBajoMinimo
AS
SELECT b.BodegaId,
       b.Nombre                          AS Bodega,
       cat.Nombre                        AS Categoria,
       r.Codigo,
       r.Nombre                          AS Repuesto,
       i.Existencia,
       i.StockMinimo,
       i.StockMinimo - i.Existencia      AS Faltante,
       CASE WHEN i.Existencia = 0 THEN 'SIN STOCK' ELSE 'BAJO MINIMO' END AS EstadoStock
FROM dbo.Inventario i
JOIN dbo.Repuesto r    ON r.RepuestoId    = i.RepuestoId
JOIN dbo.Categoria cat ON cat.CategoriaId = r.CategoriaId
JOIN dbo.Bodega b      ON b.BodegaId      = i.BodegaId
WHERE i.Existencia <= i.StockMinimo
  AND r.Estado = 'ACTIVO'
  AND b.Activo = 1;
GO

/* ----------------------------------------------------------
   Reporte 8: compras por proveedor con detalle y costo
   HISTÓRICO (se compara con el precio actual del catálogo)
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_ComprasProveedor
AS
SELECT p.ProveedorId,
       p.Nombre                              AS Proveedor,
       p.NIT                                 AS NITProveedor,
       co.CompraId,
       co.NumeroCompra,
       co.FechaCompra,
       co.FechaRecepcion,
       co.Estado,
       b.Nombre                              AS Bodega,
       u.NombreCompleto                      AS RegistradaPor,
       r.Codigo,
       r.Nombre                              AS Repuesto,
       dc.Cantidad,
       dc.CostoUnitario                      AS CostoHistorico,
       dc.Cantidad * dc.CostoUnitario        AS Subtotal,
       r.PrecioCompraReferencia              AS CostoActual
FROM dbo.Compra co
JOIN dbo.Proveedor p      ON p.ProveedorId = co.ProveedorId
JOIN dbo.Bodega b         ON b.BodegaId    = co.BodegaId
JOIN dbo.Usuario u        ON u.UsuarioId   = co.UsuarioId
JOIN dbo.DetalleCompra dc ON dc.CompraId   = co.CompraId
JOIN dbo.Repuesto r       ON r.RepuestoId  = dc.RepuestoId;
GO

/* ----------------------------------------------------------
   Reporte 9: movimientos de inventario con documento origen
   LEFT JOIN: una entrada viene de una compra y una salida de
   una reparación; nunca de las dos.
   ---------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_MovimientosInventario
AS
SELECT m.MovimientoId,
       m.FechaMovimiento,
       m.TipoMovimiento,
       b.BodegaId,
       b.Nombre                                      AS Bodega,
       r.Codigo,
       r.Nombre                                      AS Repuesto,
       m.Cantidad,
       m.ExistenciaResultante,
       CASE WHEN m.CompraId IS NOT NULL THEN 'COMPRA' ELSE 'ORDEN' END AS TipoDocumento,
       COALESCE(co.NumeroCompra, o.NumeroOrden)      AS DocumentoOrigen,
       p.Nombre                                      AS Proveedor,
       u.NombreCompleto                              AS Usuario,
       m.Observacion
FROM dbo.MovimientoInventario m
JOIN dbo.Repuesto r            ON r.RepuestoId     = m.RepuestoId
JOIN dbo.Bodega b              ON b.BodegaId       = m.BodegaId
JOIN dbo.Usuario u             ON u.UsuarioId      = m.UsuarioId
LEFT JOIN dbo.Compra co        ON co.CompraId      = m.CompraId
LEFT JOIN dbo.Proveedor p      ON p.ProveedorId    = co.ProveedorId
LEFT JOIN dbo.Reparacion rp    ON rp.ReparacionId  = m.ReparacionId
LEFT JOIN dbo.Diagnostico d    ON d.DiagnosticoId  = rp.DiagnosticoId
LEFT JOIN dbo.OrdenServicio o  ON o.OrdenId        = d.OrdenId;
GO

/* ==========================================================
   Verificar lo creado: 3 funciones, 8 procedimientos nuevos
   (10 en total con los del 03) y 8 vistas
   ========================================================== */
SELECT type_desc AS Tipo, name AS Objeto
FROM sys.objects
WHERE type IN ('FN', 'P', 'V')
  AND schema_id = SCHEMA_ID('dbo')
ORDER BY type_desc, name;
GO
GO

/* ##########################################################
    6/12  05_datos_prueba.sql
   Datos de prueba (cantidades mínimas y escenarios del enunciado)
   (solo datos)
   ########################################################## */
PRINT '>> 6/12 05_datos_prueba.sql';
GO

/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 05: datos de prueba (sección 7 del enunciado)
   Se ejecuta UNA vez sobre una base recién creada:
   01 -> 02 -> 03 -> 04 -> 05   (sin correr los scripts de pruebas)

   Cómo se generan:
   - Catálogos, clientes, equipos y repuestos: INSERT directo.
   - Órdenes, diagnósticos, reparaciones, repuestos usados y
     compras: se usan los procedimientos del 03 y 04, así cada
     dato pasa por las mismas validaciones del sistema
     (historial, inventario, movimientos, precios históricos).
   - Factura, pagos y entrega: INSERT directo con los totales
     calculados desde la base (los procedimientos de esta parte
     van en la Semana 4).
   - Todo se ejecuta en orden de fecha (julio a octubre 2026)
     y después se le pone a cada registro su fecha real, para que
     el inventario y el historial cuadren en el tiempo.
   Si algo falla, no queda nada aplicado (una sola transacción).
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    -- ===== Validaciones antes de empezar =====
    IF DB_NAME() IN ('master', 'model', 'msdb', 'tempdb')
        THROW 50001, 'Está en una base del sistema. Seleccione TechCare (local) o db_acf53d_dbfinal2026 (nube).', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.Rol)
        THROW 50004, 'Faltan los datos iniciales. Ejecute primero 02_datos_iniciales.sql.', 1;

    IF OBJECT_ID('dbo.sp_RegistrarOrden') IS NULL OR OBJECT_ID('dbo.sp_AsignarRepuesto') IS NULL
        THROW 50005, 'Faltan los procedimientos. Ejecute primero 03_procedimientos.sql y 04_procesos.sql.', 1;

    IF EXISTS (SELECT 1 FROM dbo.OrdenServicio) OR EXISTS (SELECT 1 FROM dbo.Usuario WHERE NombreUsuario = 'tecnico3')
        THROW 50003, 'La base ya tiene órdenes o datos de prueba. Vuelva a correr 01, 02, 03 y 04, y después este script.', 1;

    BEGIN TRANSACTION;

    /* ======================================================
       1. USUARIOS (6 + 5 = 11)
       recepcion2 tiene dos roles: RECEPCION y CAJA
       ====================================================== */
    DECLARE @Hash VARCHAR(255) = CONVERT(VARCHAR(255), HASHBYTES('SHA2_256', 'TechCare2026!'), 2);

    INSERT INTO dbo.Usuario (NombreUsuario, ContrasenaHash, NombreCompleto, Correo, Telefono) VALUES
        ('recepcion2', @Hash, 'Pedro Antonio Juárez',  'recepcion2@techcare.com.gt', '22001006'),
        ('tecnico3',   @Hash, 'Jorge Luis Castillo',   'tecnico3@techcare.com.gt',   '22001007'),
        ('tecnico4',   @Hash, 'Andrea Sofía Barrios',  'tecnico4@techcare.com.gt',   '22001008'),
        ('bodega2',    @Hash, 'Diana Marisol Cruz',    'bodega2@techcare.com.gt',    '22001009'),
        ('caja2',      @Hash, 'Héctor Raúl Ortiz',     'caja2@techcare.com.gt',      '22001010');

    INSERT INTO dbo.UsuarioRol (UsuarioId, RolId)
    SELECT u.UsuarioId, r.RolId
    FROM (VALUES ('recepcion2', 'RECEPCION'), ('recepcion2', 'CAJA'),
                 ('tecnico3',   'TECNICO'),   ('tecnico4',   'TECNICO'),
                 ('bodega2',    'BODEGA'),    ('caja2',      'CAJA')) AS v (NombreUsuario, NombreRol)
    JOIN dbo.Usuario u ON u.NombreUsuario = v.NombreUsuario
    JOIN dbo.Rol     r ON r.Nombre        = v.NombreRol;

    -- Los usuarios existen desde antes de la primera orden
    UPDATE dbo.Usuario    SET FechaCreacion   = '2026-06-01T08:00:00';
    UPDATE dbo.UsuarioRol SET FechaAsignacion = '2026-06-01T08:00:00';

    /* ======================================================
       2. CATEGORÍAS Y REPUESTOS (10 + 22 = 32)
       ====================================================== */
    INSERT INTO dbo.Categoria (Nombre, Descripcion) VALUES
        ('Impresión',   'Cabezales, almohadillas y rodillos de impresoras'),
        ('Redes',       'Fuentes y antenas para routers y access points'),
        ('Componentes', 'Ventiladores, bisagras y conectores');

    INSERT INTO dbo.Repuesto (CategoriaId, Codigo, Nombre, Descripcion, PrecioCompraReferencia, PrecioVenta)
    SELECT cat.CategoriaId, v.Codigo, v.Nombre, v.Descripcion, v.PrecioCompra, v.PrecioVenta
    FROM (VALUES
            ('REP-0011', 'Pantallas',      'Pantalla LED 13.3" FHD 30 pines',         'Para laptops de 13 pulgadas',       380.00, 600.00),
            ('REP-0012', 'Pantallas',      'Panel LED 21.5" para monitor',            'Panel de reemplazo para monitor',   520.00, 850.00),
            ('REP-0013', 'Memorias RAM',   'Memoria RAM DDR4 8GB DIMM 3200',          'Para computadora de escritorio',    170.00, 285.00),
            ('REP-0014', 'Memorias RAM',   'Memoria RAM DDR5 16GB SODIMM 4800',       'Para laptop',                       420.00, 650.00),
            ('REP-0015', 'Almacenamiento', 'SSD NVMe M.2 512GB',                      'PCIe 3.0',                          300.00, 480.00),
            ('REP-0016', 'Almacenamiento', 'Disco duro 1TB 2.5" SATA',                '5400 rpm',                          280.00, 420.00),
            ('REP-0017', 'Teclados',       'Teclado laptop HP 15 español',            'Compatible con HP 15 y Pavilion',   160.00, 295.00),
            ('REP-0018', 'Teclados',       'Teclado laptop Lenovo IdeaPad español',   'Compatible con IdeaPad 3 y 5',      170.00, 310.00),
            ('REP-0019', 'Baterías',       'Batería laptop HP HT03XL',                '11.4 V, 3 celdas',                  380.00, 590.00),
            ('REP-0020', 'Baterías',       'Batería laptop Lenovo L19 3 celdas',      '11.1 V, 3 celdas',                  390.00, 600.00),
            ('REP-0021', 'Cargadores',     'Cargador laptop HP 45W punta azul',       'Punta 4.5 mm',                      140.00, 240.00),
            ('REP-0022', 'Cargadores',     'Fuente de poder ATX 500W',                'Para computadora de escritorio',    320.00, 495.00),
            ('REP-0023', 'Consumibles',    'Kit de limpieza para equipos',            'Alcohol isopropílico y paños',       20.00,  50.00),
            ('REP-0024', 'Consumibles',    'Kit de tornillería para laptop',          'Tornillos M2 y M2.5',                15.00,  40.00),
            ('REP-0025', 'Impresión',      'Cabezal de impresión Epson L3250',        'Compatible con serie L3200',        450.00, 750.00),
            ('REP-0026', 'Impresión',      'Almohadillas de tinta Epson',             'Juego de almohadillas absorbentes',  60.00, 150.00),
            ('REP-0027', 'Impresión',      'Rodillo de arrastre de papel',            'Para impresoras HP y Epson',         90.00, 180.00),
            ('REP-0028', 'Redes',          'Fuente 12V 1A para router',               'Conector 5.5 mm',                    45.00,  95.00),
            ('REP-0029', 'Redes',          'Antena WiFi 5dBi',                        'Conector RP-SMA',                    35.00,  80.00),
            ('REP-0030', 'Componentes',    'Ventilador para laptop',                  'Compatible con HP, Acer y Dell',    110.00, 220.00),
            ('REP-0031', 'Componentes',    'Bisagras laptop 15.6" (par)',             'Izquierda y derecha',                95.00, 190.00),
            ('REP-0032', 'Componentes',    'Conector de carga DC jack',               'Puerto de carga para laptop',        40.00, 120.00)
         ) AS v (Codigo, Categoria, Nombre, Descripcion, PrecioCompra, PrecioVenta)
    JOIN dbo.Categoria cat ON cat.Nombre = v.Categoria;

    IF @@ROWCOUNT <> 22
        THROW 50010, 'No se insertaron los 22 repuestos (revise los nombres de categoría).', 1;

    /* ======================================================
       3. PROVEEDORES (3 + 6 = 9) Y QUÉ VENDE CADA UNO
       ====================================================== */
    INSERT INTO dbo.Proveedor (NIT, Nombre, Contacto, Telefono, Correo, Direccion) VALUES
        ('4567891-2', 'Suministros Informáticos Maya, S.A.',   'Karla Pineda',     '23661020', 'ventas@simaya.com.gt',       'Zona 4, Ciudad de Guatemala'),
        ('5678912-3', 'TecnoPartes Centroamérica, S.A.',       'Óscar Villatoro',  '23672030', 'pedidos@tecnopartes.gt',     'Zona 11, Ciudad de Guatemala'),
        ('6789123-4', 'Impresión y Tintas de Guatemala, S.A.', 'Silvia Recinos',   '23683040', 'info@impresionytintas.gt',   'Zona 1, Ciudad de Guatemala'),
        ('7891234-5', 'Redes y Conectividad GT, S.A.',         'Walter Coyoy',     '23694050', 'ventas@redesgt.com',         'Zona 10, Ciudad de Guatemala'),
        ('8912345-6', 'Componentes del Pacífico, S.A.',        'Marta Chávez',     '78305060', 'compras@comppacifico.gt',    'Escuintla'),
        ('9123456-7', 'Mayoreo Digital Quetzal, S.A.',         'Erick Sandoval',   '23716070', 'mayoreo@digitalquetzal.gt',  'Zona 12, Ciudad de Guatemala');

    INSERT INTO dbo.ProveedorRepuesto (ProveedorId, RepuestoId, CodigoProveedor, PrecioReferencia)
    SELECT p.ProveedorId, r.RepuestoId, v.CodigoProveedor, r.PrecioCompraReferencia
    FROM (VALUES
            ('3456789-0', 'REP-0019', 'EB-HT03'),   ('3456789-0', 'REP-0020', 'EB-L19'),
            ('3456789-0', 'REP-0021', 'EB-HP45'),   ('3456789-0', 'REP-0022', 'EB-ATX500'),
            ('4567891-2', 'REP-0011', 'SIM-133'),   ('4567891-2', 'REP-0013', 'SIM-D8'),
            ('4567891-2', 'REP-0014', 'SIM-D5-16'), ('4567891-2', 'REP-0015', 'SIM-NV512'),
            ('4567891-2', 'REP-0016', 'SIM-HD1T'),  ('4567891-2', 'REP-0023', 'SIM-LIMP'),
            ('4567891-2', 'REP-0024', 'SIM-TORN'),
            ('5678912-3', 'REP-0007', 'TP-KBGEN'),  ('5678912-3', 'REP-0017', 'TP-KBHP'),
            ('5678912-3', 'REP-0018', 'TP-KBLNV'),  ('5678912-3', 'REP-0019', 'TP-HT03'),
            ('5678912-3', 'REP-0020', 'TP-L19'),    ('5678912-3', 'REP-0030', 'TP-FAN'),
            ('5678912-3', 'REP-0031', 'TP-BIS156'), ('5678912-3', 'REP-0032', 'TP-DCJ'),
            ('6789123-4', 'REP-0023', 'IT-LIMP'),   ('6789123-4', 'REP-0025', 'IT-CAB3250'),
            ('6789123-4', 'REP-0026', 'IT-ALM'),    ('6789123-4', 'REP-0027', 'IT-ROD'),
            ('7891234-5', 'REP-0021', 'RC-HP45'),   ('7891234-5', 'REP-0028', 'RC-F12V'),
            ('7891234-5', 'REP-0029', 'RC-ANT5'),
            ('8912345-6', 'REP-0010', 'CP-PASTA'),  ('8912345-6', 'REP-0012', 'CP-P215'),
            ('8912345-6', 'REP-0022', 'CP-ATX'),    ('8912345-6', 'REP-0030', 'CP-FAN'),
            ('8912345-6', 'REP-0031', 'CP-BIS'),    ('8912345-6', 'REP-0032', 'CP-DCJ'),
            ('9123456-7', 'REP-0001', 'MDQ-156'),   ('9123456-7', 'REP-0002', 'MDQ-140'),
            ('9123456-7', 'REP-0003', 'MDQ-R8'),    ('9123456-7', 'REP-0004', 'MDQ-R16'),
            ('9123456-7', 'REP-0005', 'MDQ-S480'),  ('9123456-7', 'REP-0006', 'MDQ-NV1T'),
            ('9123456-7', 'REP-0009', 'MDQ-CH65'),  ('9123456-7', 'REP-0011', 'MDQ-133'),
            ('9123456-7', 'REP-0021', 'MDQ-HP45')
         ) AS v (NIT, Codigo, CodigoProveedor)
    JOIN dbo.Proveedor p ON p.NIT    = v.NIT
    JOIN dbo.Repuesto  r ON r.Codigo = v.Codigo;

    /* ======================================================
       4. INVENTARIO: filas nuevas por bodega (19 + 46 = 65)
       Empiezan en 0 con su stock mínimo; la existencia solo
       sube con las compras recibidas (sp_RecibirCompra).
       Mixco: REP-0016 y REP-0020 nunca se compran -> stock 0
       ====================================================== */
    INSERT INTO dbo.Inventario (RepuestoId, BodegaId, Existencia, StockMinimo, FechaActualizacion)
    SELECT r.RepuestoId, b.BodegaId, 0, v.StockMinimo, '2026-06-18T08:00:00'
    FROM (VALUES
            ('Central', 'REP-0011', 2), ('Central', 'REP-0012', 1), ('Central', 'REP-0013', 8),
            ('Central', 'REP-0014', 2), ('Central', 'REP-0015', 4), ('Central', 'REP-0016', 2),
            ('Central', 'REP-0017', 2), ('Central', 'REP-0018', 2), ('Central', 'REP-0019', 2),
            ('Central', 'REP-0020', 2), ('Central', 'REP-0021', 2), ('Central', 'REP-0022', 3),
            ('Central', 'REP-0023', 10),('Central', 'REP-0024', 10),('Central', 'REP-0025', 2),
            ('Central', 'REP-0026', 5), ('Central', 'REP-0027', 2), ('Central', 'REP-0028', 3),
            ('Central', 'REP-0029', 4), ('Central', 'REP-0030', 3), ('Central', 'REP-0031', 2),
            ('Central', 'REP-0032', 4),
            ('Zona 10', 'REP-0002', 1), ('Zona 10', 'REP-0004', 1), ('Zona 10', 'REP-0007', 2),
            ('Zona 10', 'REP-0013', 3), ('Zona 10', 'REP-0015', 2), ('Zona 10', 'REP-0017', 2),
            ('Zona 10', 'REP-0019', 1), ('Zona 10', 'REP-0021', 2), ('Zona 10', 'REP-0023', 5),
            ('Zona 10', 'REP-0024', 5), ('Zona 10', 'REP-0030', 2), ('Zona 10', 'REP-0032', 3),
            ('Mixco',   'REP-0001', 1), ('Mixco',   'REP-0008', 2), ('Mixco',   'REP-0010', 5),
            ('Mixco',   'REP-0016', 1), ('Mixco',   'REP-0018', 2), ('Mixco',   'REP-0020', 1),
            ('Mixco',   'REP-0022', 1), ('Mixco',   'REP-0025', 1), ('Mixco',   'REP-0026', 3),
            ('Mixco',   'REP-0027', 1), ('Mixco',   'REP-0028', 2), ('Mixco',   'REP-0029', 2)
         ) AS v (Bodega, Codigo, StockMinimo)
    JOIN dbo.Bodega   b ON b.Nombre = v.Bodega
    JOIN dbo.Repuesto r ON r.Codigo = v.Codigo;

    IF @@ROWCOUNT <> 46
        THROW 50011, 'No se insertaron las 46 filas de inventario.', 1;

    -- La carga inicial del 02 queda con fecha 15 de junio
    UPDATE dbo.Compra
    SET FechaCompra = '2026-06-15T09:00:00', FechaRecepcion = '2026-06-15T15:00:00'
    WHERE Observaciones = 'Carga de inventario inicial';

    UPDATE m
    SET m.FechaMovimiento = '2026-06-15T15:00:00'
    FROM dbo.MovimientoInventario m
    JOIN dbo.Compra co ON co.CompraId = m.CompraId
    WHERE co.Observaciones = 'Carga de inventario inicial';

    UPDATE dbo.Inventario
    SET FechaActualizacion = '2026-06-15T15:00:00'
    WHERE FechaActualizacion > '2026-06-18T08:00:00';

    /* ======================================================
       5. CLIENTES (4 + 27 = 31) Y EQUIPOS (5 + 43 = 48)
       Claudia Patricia Orellana: cliente sin equipos ni órdenes
       ====================================================== */
    INSERT INTO dbo.Cliente (TipoCliente, NombreRazonSocial, NIT, Telefono, Correo, Direccion) VALUES
        ('INDIVIDUAL',  'María Fernanda Ruiz',                     '3012456-1', '55012345', 'mfruiz@gmail.com',              'Zona 7, Ciudad de Guatemala'),
        ('INDIVIDUAL',  'José Antonio Pérez',                      'CF',        '55023456', NULL,                            'Mixco'),
        ('INDIVIDUAL',  'Ana Gabriela Castillo',                   '3123567-2', '55034567', 'agcastillo@hotmail.com',        'Zona 18, Ciudad de Guatemala'),
        ('INDIVIDUAL',  'Luis Alberto Morales',                    '3234678-3', '55045678', 'lamorales@gmail.com',           'Villa Nueva'),
        ('INDIVIDUAL',  'Carmen Lucía Estrada',                    'CF',        '55056789', NULL,                            'San Miguel Petapa'),
        ('INDIVIDUAL',  'Diego Alejandro Fuentes',                 '3345789-4', '55067890', 'dafuentes@gmail.com',           'Zona 12, Ciudad de Guatemala'),
        ('INDIVIDUAL',  'Sofía Valentina Rodas',                   '3456890-5', '55078901', 'svrodas@gmail.com',             'Zona 16, Ciudad de Guatemala'),
        ('INDIVIDUAL',  'Roberto Carlos Aguilar',                  '3567901-6', '55089012', 'rcaguilar@yahoo.com',           'Santa Catarina Pinula'),
        ('INDIVIDUAL',  'Gabriela Alejandra Soto',                 'CF',        '55090123', NULL,                            'Zona 6, Ciudad de Guatemala'),
        ('INDIVIDUAL',  'Fernando José Barrios',                   '3678012-7', '55101234', 'fjbarrios@gmail.com',           'Zona 14, Ciudad de Guatemala'),
        ('INDIVIDUAL',  'Paola Andrea Méndez',                     '3789123-8', '55112345', 'pamendez@gmail.com',            'Chinautla'),
        ('INDIVIDUAL',  'Ricardo Ernesto Lima',                    '3890234-9', '55123456', 'relima@outlook.com',            'Zona 5, Ciudad de Guatemala'),
        ('INDIVIDUAL',  'Andrea Isabel Cifuentes',                 'CF',        '55134567', NULL,                            'Amatitlán'),
        ('INDIVIDUAL',  'Javier Eduardo Monzón',                   '3901345-0', '55145678', 'jemonzon@gmail.com',            'Zona 1, Ciudad de Guatemala'),
        ('INDIVIDUAL',  'Claudia Patricia Orellana',               '4012456-1', '55156789', 'cporellana@gmail.com',          'Fraijanes'),
        ('EMPRESARIAL', 'Farmacia La Esperanza',                   '5123456-7', '23101010', 'compras@farmaesperanza.com.gt', 'Zona 11, Ciudad de Guatemala'),
        ('EMPRESARIAL', 'Despacho Contable Ramírez & Asociados',   '5234567-8', '23202020', 'info@ramirezasociados.gt',      'Zona 9, Ciudad de Guatemala'),
        ('EMPRESARIAL', 'Hotel Las Américas',                      '5345678-9', '23303030', 'sistemas@hotelamericas.com.gt', 'Zona 13, Ciudad de Guatemala'),
        ('EMPRESARIAL', 'Clínica Médica Santa Fe',                 '5456789-0', '23404040', 'admin@clinicasantafe.gt',       'Zona 10, Ciudad de Guatemala'),
        ('EMPRESARIAL', 'Librería El Estudiante',                  '5567890-1', '23505050', 'ventas@libreriaestudiante.gt',  'Zona 1, Ciudad de Guatemala'),
        ('EMPRESARIAL', 'Transportes Rápidos del Sur, S.A.',       '5678901-2', '23606060', 'ti@transrapidos.com.gt',        'Escuintla'),
        ('EMPRESARIAL', 'Restaurante El Fogón Chapín',             '5789012-3', '23707070', 'gerencia@elfogon.gt',           'Zona 10, Ciudad de Guatemala'),
        ('EMPRESARIAL', 'Academia de Inglés Global Talk',          '5890123-4', '23808080', 'admin@globaltalk.edu.gt',       'Zona 15, Ciudad de Guatemala'),
        ('EMPRESARIAL', 'Ferretería San José',                     '5901234-5', '23909090', 'ferresanjose@gmail.com',        'Villa Nueva'),
        ('EMPRESARIAL', 'Constructora Altiplano, S.A.',            '6012345-6', '24101010', 'compras@altiplano.com.gt',      'Zona 14, Ciudad de Guatemala'),
        ('EMPRESARIAL', 'Cooperativa Agrícola El Valle, R.L.',     '6123456-7', '24202020', 'info@coopelvalle.gt',           'Chimaltenango'),
        ('EMPRESARIAL', 'Agencia de Viajes Mundo Maya',            '6234567-8', '24303030', 'reservas@mundomaya.gt',         'Antigua Guatemala');

    INSERT INTO dbo.Equipo (ClienteId, TipoEquipoId, Marca, Modelo, NumeroSerie, Descripcion)
    SELECT c.ClienteId, t.TipoEquipoId, v.Marca, v.Modelo, v.NumeroSerie, v.Descripcion
    FROM (VALUES
            ('María Fernanda Ruiz',                   'Laptop',        'HP',       '14-dq2',                 'HP-5CG1100A01',     'Color azul'),
            ('María Fernanda Ruiz',                   'Tablet',        'Samsung',  'Galaxy Tab A8',          'SMT-R9WT1100A1',    'Con funda'),
            ('José Antonio Pérez',                    'Laptop',        'Dell',     'Inspiron 15 3511',       'DL-INS3511-0021',   'Color negro'),
            ('Ana Gabriela Castillo',                 'Laptop',        'Lenovo',   'IdeaPad 5',              'LNV-PF4XK2A1',      'Color gris'),
            ('Luis Alberto Morales',                  'Desktop',       'HP',       'ProDesk 400',            'HP-MXL2210B05',     'Torre con teclado y mouse'),
            ('Luis Alberto Morales',                  'Monitor',       'LG',       '22MK430H',               'LG-22MK-305NTAB1',  'Monitor de 22 pulgadas'),
            ('Carmen Lucía Estrada',                  'Laptop',        'Acer',     'Aspire 3',               'ACR-NXA6YAA02',     'Color plateado'),
            ('Diego Alejandro Fuentes',               'Laptop',        'Asus',     'VivoBook 15',            'ASUS-N3NRKD0101',   'Color negro'),
            ('Diego Alejandro Fuentes',               'Equipo de red', 'TP-Link',  'Archer C6',              'TPL-C6-2231A001',   'Router de la casa'),
            ('Sofía Valentina Rodas',                 'Laptop',        'HP',       'Pavilion x360',          'HP-5CD2201X22',     'Pantalla táctil'),
            ('Roberto Carlos Aguilar',                'Impresora',     'Epson',    'L3250',                  'EPS-X8QW6610',      'Tinta continua'),
            ('Roberto Carlos Aguilar',                'Laptop',        'Lenovo',   'ThinkPad E14',           'LNV-PF2TH9B3',      'Laptop de trabajo'),
            ('Gabriela Alejandra Soto',               'Laptop',        'Acer',     'Nitro 5',                'ACR-NHQ7JAA03',     'Laptop para juegos'),
            ('Fernando José Barrios',                 'Laptop',        'Dell',     'Latitude 5420',          'DL-LAT5420-0099',   'Color gris'),
            ('Paola Andrea Méndez',                   'Tablet',        'Lenovo',   'Tab M10',                'LNV-HA1KQ7C2',      'Sin cargador'),
            ('Ricardo Ernesto Lima',                  'Desktop',       'Dell',     'OptiPlex 7090',          'DL-7HJK1188',       'Equipo de oficina'),
            ('Andrea Isabel Cifuentes',               'Laptop',        'HP',       '15-ef',                  'HP-5CD1309Z11',     'Color blanco'),
            ('Javier Eduardo Monzón',                 'Laptop',        'Lenovo',   'IdeaPad 3',              'LNV-PF3XYZ77',      'Color azul'),
            ('Javier Eduardo Monzón',                 'Impresora',     'HP',       'LaserJet Pro M15w',      'HP-VNB3K12345',     'Impresora láser'),
            ('Farmacia La Esperanza',                 'Desktop',       'Lenovo',   'ThinkCentre M70',        'LNV-MJ0FA1B1',      'Caja principal'),
            ('Farmacia La Esperanza',                 'Impresora',     'Epson',    'L3250',                  'EPS-X8QW7701',      'Impresora de recetas'),
            ('Farmacia La Esperanza',                 'Equipo de red', 'TP-Link',  'TL-WR840N',              'TPL-840N-1180B2',   'Router de la farmacia'),
            ('Despacho Contable Ramírez & Asociados', 'Laptop',        'HP',       'ProBook 450 G8',         'HP-5CD1450G81',     'Contador 1'),
            ('Despacho Contable Ramírez & Asociados', 'Laptop',        'HP',       'ProBook 450 G8',         'HP-5CD1450G82',     'Contador 2'),
            ('Despacho Contable Ramírez & Asociados', 'Desktop',       'HP',       'ProDesk 600',            'HP-MXL2600C01',     'Recepción del despacho'),
            ('Hotel Las Américas',                    'Desktop',       'Dell',     'OptiPlex 3080',          'DL-7HJK3301',       'Recepción del hotel'),
            ('Hotel Las Américas',                    'Monitor',       'Samsung',  'S24R350',                'SMS-24R350-0K11',   'Monitor de 24 pulgadas'),
            ('Hotel Las Américas',                    'Equipo de red', 'Ubiquiti', 'UniFi AP AC Lite',       'UBQ-UAPACL-0042',   'Access point del lobby'),
            ('Clínica Médica Santa Fe',               'Laptop',        'Lenovo',   'ThinkPad E15',           'LNV-PF3TE15A',      'Consultorio 1'),
            ('Clínica Médica Santa Fe',               'Impresora',     'Epson',    'L4260',                  'EPS-X8QZ4260A',     'Impresora de recepción'),
            ('Clínica Médica Santa Fe',               'Monitor',       'Dell',     'P2219H',                 'DL-P2219H-CN0A1',   'Monitor de 22 pulgadas'),
            ('Librería El Estudiante',                'Desktop',       'HP',       '280 G4',                 'HP-MXL280G4A1',     'Punto de venta'),
            ('Transportes Rápidos del Sur, S.A.',     'Laptop',        'Dell',     'Vostro 3510',            'DL-VOS3510-0A12',   'Despacho de rutas'),
            ('Transportes Rápidos del Sur, S.A.',     'Laptop',        'Dell',     'Vostro 3510',            'DL-VOS3510-0A13',   'Gerencia'),
            ('Restaurante El Fogón Chapín',           'Tablet',        'Samsung',  'Galaxy Tab A7',          'SMT-R9WN7700B',     'Toma de pedidos'),
            ('Restaurante El Fogón Chapín',           'Impresora',     'Epson',    'TM-T20',                 'EPS-TMT20-X5501',   'Impresora térmica de comandas'),
            ('Academia de Inglés Global Talk',        'Laptop',        'Acer',     'Aspire 5',               'ACR-NXHS7AA22',     'Laboratorio 1'),
            ('Academia de Inglés Global Talk',        'Laptop',        'Acer',     'Aspire 5',               'ACR-NXHS7AA23',     'Laboratorio 2'),
            ('Academia de Inglés Global Talk',        'Equipo de red', 'TP-Link',  'Archer C6',              'TPL-C6-2231A077',   'Router de las aulas'),
            ('Ferretería San José',                   'Desktop',       'Lenovo',   'V50s',                   'LNV-V50S-MJ0A2',    'Caja de la ferretería'),
            ('Constructora Altiplano, S.A.',          'Laptop',        'HP',       'EliteBook 840',          'HP-5CG2840G7',      'Ingeniero residente'),
            ('Cooperativa Agrícola El Valle, R.L.',   'Desktop',       'HP',       'ProDesk 400',            'HP-MXL2210B77',     'Contabilidad'),
            ('Agencia de Viajes Mundo Maya',          'Laptop',        'Lenovo',   'IdeaPad 3',              'LNV-PF3XYZ90',      'Equipo sin órdenes de servicio')
         ) AS v (Cliente, Tipo, Marca, Modelo, NumeroSerie, Descripcion)
    JOIN dbo.Cliente    c ON c.NombreRazonSocial = v.Cliente
    JOIN dbo.TipoEquipo t ON t.Nombre            = v.Tipo;

    IF @@ROWCOUNT <> 43
        THROW 50012, 'No se insertaron los 43 equipos (revise nombres de cliente o tipo).', 1;

    /* ======================================================
       6. PLAN DE COMPRAS (23 compras nuevas)
       REC = se recibe, PEN = queda pendiente, ANU = se anula
       ====================================================== */
    DECLARE @PlanCompra TABLE (PlanId INT PRIMARY KEY, Dia DATE, NIT VARCHAR(15), Bodega VARCHAR(50), Final CHAR(3));
    INSERT INTO @PlanCompra (PlanId, Dia, NIT, Bodega, Final) VALUES
        ( 1, '2026-06-20', '1234567-8', 'Central', 'REC'),
        ( 2, '2026-06-22', '4567891-2', 'Central', 'REC'),
        ( 3, '2026-06-25', '5678912-3', 'Central', 'REC'),
        ( 4, '2026-06-28', '6789123-4', 'Central', 'REC'),
        ( 5, '2026-06-30', '7891234-5', 'Central', 'REC'),
        ( 6, '2026-07-02', '8912345-6', 'Central', 'REC'),
        ( 7, '2026-07-05', '2345678-9', 'Zona 10', 'REC'),
        ( 8, '2026-07-08', '4567891-2', 'Zona 10', 'REC'),
        ( 9, '2026-07-10', '5678912-3', 'Zona 10', 'REC'),
        (10, '2026-07-15', '9123456-7', 'Zona 10', 'REC'),
        (11, '2026-07-20', '5678912-3', 'Mixco',   'REC'),
        (12, '2026-07-22', '3456789-0', 'Mixco',   'REC'),
        (13, '2026-07-25', '6789123-4', 'Mixco',   'REC'),
        (14, '2026-07-28', '7891234-5', 'Mixco',   'REC'),
        (15, '2026-08-05', '1234567-8', 'Mixco',   'REC'),
        (16, '2026-08-18', '9123456-7', 'Central', 'REC'),
        (17, '2026-08-25', '7891234-5', 'Zona 10', 'ANU'),
        (18, '2026-09-02', '5678912-3', 'Central', 'REC'),
        (19, '2026-09-15', '4567891-2', 'Central', 'REC'),
        (20, '2026-09-28', '6789123-4', 'Central', 'REC'),
        (21, '2026-10-09', '8912345-6', 'Central', 'PEN'),
        (22, '2026-10-12', '3456789-0', 'Zona 10', 'PEN'),
        (23, '2026-10-13', '2345678-9', 'Mixco',   'PEN');

    DECLARE @PlanCompraLinea TABLE (PlanId INT, Codigo VARCHAR(20), Cantidad INT, Costo DECIMAL(10,2));
    INSERT INTO @PlanCompraLinea (PlanId, Codigo, Cantidad, Costo) VALUES
        ( 1, 'REP-0003', 10, 178.00), ( 1, 'REP-0004',  6, 330.00), ( 1, 'REP-0005',  8, 258.00), ( 1, 'REP-0006',  4, 515.00),
        ( 2, 'REP-0011',  5, 380.00), ( 2, 'REP-0013', 10, 170.00), ( 2, 'REP-0014',  4, 420.00), ( 2, 'REP-0015',  8, 300.00),
        ( 2, 'REP-0016',  4, 280.00), ( 2, 'REP-0023', 20,  20.00), ( 2, 'REP-0024', 20,  15.00),
        ( 3, 'REP-0017',  6, 160.00), ( 3, 'REP-0018',  6, 170.00), ( 3, 'REP-0019',  5, 380.00), ( 3, 'REP-0020',  4, 390.00),
        ( 3, 'REP-0030',  8, 110.00), ( 3, 'REP-0031',  6,  95.00), ( 3, 'REP-0032', 12,  40.00),
        ( 4, 'REP-0025',  4, 450.00), ( 4, 'REP-0026', 10,  60.00), ( 4, 'REP-0027',  6,  90.00),
        ( 5, 'REP-0028', 10,  45.00), ( 5, 'REP-0029', 12,  35.00), ( 5, 'REP-0021',  6, 140.00),
        ( 6, 'REP-0012',  3, 520.00), ( 6, 'REP-0022',  6, 320.00), ( 6, 'REP-0010', 20,  24.00),
        ( 7, 'REP-0001',  3, 345.00), ( 7, 'REP-0003',  6, 175.00), ( 7, 'REP-0007',  5, 120.00),
        ( 8, 'REP-0013',  6, 172.00), ( 8, 'REP-0015',  4, 298.00), ( 8, 'REP-0023', 10,  20.00), ( 8, 'REP-0024', 10,  15.00),
        ( 9, 'REP-0017',  4, 160.00), ( 9, 'REP-0019',  3, 382.00), ( 9, 'REP-0030',  4, 112.00), ( 9, 'REP-0032',  6,  40.00),
        (10, 'REP-0002',  3, 418.00), (10, 'REP-0004',  3, 332.00), (10, 'REP-0021',  4, 138.00),
        (11, 'REP-0018',  4, 170.00),
        (12, 'REP-0008',  4, 280.00), (12, 'REP-0022',  3, 318.00),
        (13, 'REP-0025',  2, 455.00), (13, 'REP-0026',  6,  60.00), (13, 'REP-0027',  3,  92.00),
        (14, 'REP-0028',  5,  45.00), (14, 'REP-0029',  6,  36.00),
        (15, 'REP-0001',  2, 350.00), (15, 'REP-0010', 10,  25.00),
        (16, 'REP-0001',  4, 352.00), (16, 'REP-0003',  8, 181.00), (16, 'REP-0005',  6, 262.00), (16, 'REP-0009',  5, 152.00),
        (17, 'REP-0028',  3,  46.00),
        (18, 'REP-0032',  8,  42.00), (18, 'REP-0030',  4, 114.00), (18, 'REP-0017',  3, 162.00), (18, 'REP-0019',  3, 385.00),
        (19, 'REP-0013',  6, 175.00), (19, 'REP-0015',  4, 305.00), (19, 'REP-0014',  2, 425.00),
        (20, 'REP-0025',  2, 460.00), (20, 'REP-0026',  6,  62.00),
        (21, 'REP-0012',  2, 525.00), (21, 'REP-0022',  3, 325.00),
        (22, 'REP-0008',  5, 285.00), (22, 'REP-0009',  4, 150.00),
        (23, 'REP-0003',  6, 176.00), (23, 'REP-0005',  4, 256.00);

    /* ======================================================
       7. CASOS DE SERVICIO (problema, diagnóstico, trabajo y
          repuestos que usa cada tipo de reparación)
       ====================================================== */
    DECLARE @Caso TABLE (CasoId INT PRIMARY KEY, Problema VARCHAR(500), Diagnostico VARCHAR(500),
                         ManoObra DECIMAL(10,2), Trabajo VARCHAR(500));
    INSERT INTO @Caso (CasoId, Problema, Diagnostico, ManoObra, Trabajo) VALUES
        ( 1, 'No enciende; el cargador no hace contacto.',            'Conector de carga (DC jack) dañado.',                              200.00, 'Se reemplazó el conector de carga y se probó el encendido.'),
        ( 2, 'Pantalla quebrada después de un golpe.',                 'Panel LED 15.6" quebrado; el resto del equipo funciona.',          150.00, 'Cambio de pantalla 15.6" y prueba de imagen.'),
        ( 3, 'El equipo está muy lento.',                              'Disco mecánico lento y memoria RAM insuficiente.',                 250.00, 'Se instaló SSD de 480GB, se agregó RAM de 8GB y se migró el sistema.'),
        ( 4, 'Se calienta y se apaga sola.',                           'Ventilador trabado y pasta térmica seca.',                         225.00, 'Cambio de ventilador, pasta térmica y limpieza interna.'),
        ( 5, 'Varias teclas no funcionan.',                            'Teclado dañado por derrame de líquido.',                           125.00, 'Reemplazo de teclado y limpieza de la placa.'),
        ( 6, 'La batería dura menos de 10 minutos.',                   'Batería degradada al 15 % de su capacidad.',                       100.00, 'Cambio de batería y calibración.'),
        ( 7, 'Ventanas emergentes y el sistema no arranca bien.',      'Sistema operativo dañado por virus; el hardware está bien.',       300.00, 'Respaldo de información, reinstalación del sistema y antivirus.'),
        ( 8, 'La tapa de la pantalla está floja.',                     'Bisagras quebradas y tornillos faltantes.',                        175.00, 'Cambio de bisagras y tornillería.'),
        ( 9, 'La computadora no enciende.',                            'Fuente de poder quemada.',                                         150.00, 'Cambio de fuente de poder ATX 500W.'),
        (10, 'La computadora está lenta para trabajar.',               'Poca memoria RAM y disco al 100 % de uso.',                        250.00, 'Se instaló SSD NVMe de 512GB y 2 módulos de RAM de 8GB.'),
        (11, 'Imprime con rayas y colores incompletos.',               'Cabezal obstruido y almohadillas saturadas.',                      275.00, 'Cambio de cabezal y almohadillas, reseteo del contador.'),
        (12, 'El papel se atasca al imprimir.',                        'Rodillo de arrastre gastado.',                                     150.00, 'Cambio de rodillo de arrastre y limpieza.'),
        (13, 'Muestra mensaje de mantenimiento requerido.',            'Contador de mantenimiento lleno; no hay piezas dañadas.',          175.00, 'Limpieza general, purga de tinta y reseteo del contador.'),
        (14, 'El monitor no muestra imagen.',                          'Panel LED dañado.',                                                200.00, 'Cambio de panel LED de 21.5".'),
        (15, 'El router no enciende.',                                 'Fuente de 12V quemada.',                                            80.00, 'Cambio de fuente y configuración de la red.'),
        (16, 'La señal WiFi es muy débil.',                            'Antenas dañadas.',                                                  90.00, 'Cambio de 2 antenas y ajuste del canal WiFi.'),
        (17, 'La tablet se congela y se reinicia.',                    'Sistema dañado por una actualización incompleta.',                 150.00, 'Respaldo, restablecimiento de fábrica y actualización.'),
        (18, 'Sale el mensaje de disco no encontrado.',                'Disco duro dañado.',                                               225.00, 'Cambio por SSD NVMe de 1TB y recuperación de archivos.'),
        (19, 'El cliente necesita más memoria para diseño.',           'Equipo funcional; se recomienda ampliar la RAM.',                   75.00, 'Instalación de memoria RAM de 16GB.'),
        (20, 'La pantalla tiene líneas de colores.',                   'Panel 14" FHD dañado.',                                            150.00, 'Cambio de pantalla 14" y prueba de imagen.'),
        (21, 'El cargador dejó de funcionar.',                         'Cargador dañado; la laptop está en buen estado.',                   50.00, 'Venta y prueba de cargador universal 65W.'),
        (22, 'El teclado tiene teclas sueltas.',                       'Teclado HP 15 dañado.',                                            125.00, 'Cambio de teclado HP 15.'),
        (23, 'La batería está inflada.',                               'Batería HT03XL hinchada; hay riesgo de daño.',                     100.00, 'Cambio de batería HP HT03XL.'),
        (24, 'Las teclas del Lenovo no responden.',                    'Teclado Lenovo IdeaPad dañado.',                                   125.00, 'Cambio de teclado Lenovo IdeaPad.'),
        (25, 'La pantalla parpadea y el equipo se traba.',             'Pantalla dañada y memoria RAM defectuosa.',                        275.00, 'Cambio de pantalla, 2 memorias RAM y pasta térmica.');

    DECLARE @CasoRepuesto TABLE (CasoId INT, Linea INT, Codigo VARCHAR(20), Cantidad INT);
    INSERT INTO @CasoRepuesto (CasoId, Linea, Codigo, Cantidad) VALUES
        ( 1, 1, 'REP-0032', 1),
        ( 2, 1, 'REP-0001', 1),
        ( 3, 1, 'REP-0005', 1), ( 3, 2, 'REP-0003', 1),
        ( 4, 1, 'REP-0030', 1), ( 4, 2, 'REP-0010', 1), ( 4, 3, 'REP-0023', 1),
        ( 5, 1, 'REP-0007', 1),
        ( 6, 1, 'REP-0008', 1),
        ( 8, 1, 'REP-0031', 1), ( 8, 2, 'REP-0024', 1),
        ( 9, 1, 'REP-0022', 1),
        (10, 1, 'REP-0015', 1), (10, 2, 'REP-0013', 2),
        (11, 1, 'REP-0025', 1), (11, 2, 'REP-0026', 1),
        (12, 1, 'REP-0027', 1),
        (14, 1, 'REP-0012', 1),
        (15, 1, 'REP-0028', 1),
        (16, 1, 'REP-0029', 2),
        (18, 1, 'REP-0006', 1),
        (19, 1, 'REP-0004', 1),
        (20, 1, 'REP-0002', 1),
        (21, 1, 'REP-0009', 1),
        (22, 1, 'REP-0017', 1),
        (23, 1, 'REP-0019', 1),
        (24, 1, 'REP-0018', 1),
        (25, 1, 'REP-0001', 1), (25, 2, 'REP-0003', 2), (25, 3, 'REP-0010', 1);
        -- Casos 7, 13 y 17: reparación sin repuestos

    /* ======================================================
       8. PLAN DE ÓRDENES (70 órdenes)
       Estado final:
         ENT   = entregada (factura pagada)
         LISFP = lista, facturada con pago parcial (saldo pendiente)
         LISF0 = lista, facturada sin pagos
         LIS   = lista, todavía sin factura
         REP   = en reparación
         ESP   = diagnosticada, esperando autorización
         DIA   = en diagnóstico (sin diagnóstico registrado)
         REC   = recibida (sin diagnóstico)
         CAND  = cancelada después del diagnóstico
         CANR  = cancelada en recepción
       Pagos = cuántos pagos recibe la factura
       ====================================================== */
    DECLARE @PlanOrden TABLE (PlanId INT PRIMARY KEY, Dia DATE, NumeroSerie VARCHAR(50), CasoId INT,
                              Final VARCHAR(5), Prioridad VARCHAR(10), Pagos INT);
    INSERT INTO @PlanOrden (PlanId, Dia, NumeroSerie, CasoId, Final, Prioridad, Pagos) VALUES
        ( 1, '2026-07-06', 'HP5CD1234XYZ',     4, 'ENT',   'ALTA',    1),
        ( 2, '2026-07-07', 'DL-7HJK921',      10, 'ENT',   'MEDIA',   2),
        ( 3, '2026-07-08', 'HP-5CG1100A01',    1, 'ENT',   'MEDIA',   1),
        ( 4, '2026-07-09', 'LNV-PF4XK2A1',    24, 'ENT',   'BAJA',    1),
        ( 5, '2026-07-10', 'DL-INS3511-0021',  7, 'CANR',  'MEDIA',   0),
        ( 6, '2026-07-13', 'HP-MXL2210B05',    9, 'ENT',   'URGENTE', 2),
        ( 7, '2026-07-14', 'EPS-X8QW5521',    11, 'ENT',   'ALTA',    3),
        ( 8, '2026-07-15', 'ACR-NXA6YAA02',    6, 'ENT',   'MEDIA',   1),
        ( 9, '2026-07-16', 'ASUS-N3NRKD0101',  3, 'ENT',   'MEDIA',   2),
        (10, '2026-07-17', 'EPS-X8QW6610',    13, 'CAND',  'BAJA',    0),
        (11, '2026-07-20', 'LNV-MJ0FA1B1',    10, 'ENT',   'ALTA',    2),
        (12, '2026-07-21', 'HP-5CD1450G81',   22, 'ENT',   'MEDIA',   1),
        (13, '2026-07-22', 'DL-7HJK3301',      9, 'ENT',   'URGENTE', 1),
        (14, '2026-07-23', 'LNV-PF3TE15A',     2, 'ENT',   'ALTA',    2),
        (15, '2026-07-27', 'TPL-840N-1180B2', 15, 'ENT',   'MEDIA',   1),
        (16, '2026-07-28', 'HP-5CD2201X22',    5, 'CAND',  'MEDIA',   0),
        (17, '2026-07-29', 'DL-VOS3510-0A12', 18, 'ENT',   'ALTA',    3),
        (18, '2026-07-30', 'SMT-R9WN7700B',   17, 'ENT',   'BAJA',    1),
        (19, '2026-08-03', 'ACR-NXHS7AA22',    8, 'ENT',   'MEDIA',   2),
        (20, '2026-08-04', 'EPS-X8QZ4260A',   11, 'ENT',   'ALTA',    1),
        (21, '2026-08-05', 'LNV-PF3ABC12',    24, 'ENT',   'MEDIA',   1),
        (22, '2026-08-06', 'HP-MXL280G4A1',    9, 'CAND',  'MEDIA',   0),
        (23, '2026-08-10', 'HP5CD1234XYZ',    23, 'ENT',   'MEDIA',   2),
        (24, '2026-08-11', 'DL-P2219H-CN0A1', 14, 'ENT',   'ALTA',    1),
        (25, '2026-08-12', 'LNV-HA1KQ7C2',    17, 'CANR',  'BAJA',    0),
        (26, '2026-08-13', 'HP-5CD1309Z11',   25, 'ENT',   'ALTA',    2),
        (27, '2026-08-17', 'UBQ-UAPACL-0042', 16, 'ENT',   'MEDIA',   1),
        (28, '2026-08-18', 'DL-7HJK1188',     10, 'ENT',   'MEDIA',   2),
        (29, '2026-08-19', 'LNV-PF3XYZ77',    19, 'ENT',   'BAJA',    1),
        (30, '2026-08-20', 'HP-VNB3K12345',   12, 'ENT',   'MEDIA',   1),
        (31, '2026-08-24', 'EPS-X8QW5521',    12, 'ENT',   'MEDIA',   1),
        (32, '2026-08-25', 'DL-LAT5420-0099', 20, 'ENT',   'ALTA',    2),
        (33, '2026-08-26', 'HP-5CG2840G7',     7, 'CAND',  'MEDIA',   0),
        (34, '2026-08-27', 'LNV-V50S-MJ0A2',   9, 'ENT',   'URGENTE', 1),
        (35, '2026-08-31', 'HP-MXL2210B77',   10, 'ENT',   'MEDIA',   2),
        (36, '2026-09-01', 'ACR-NHQ7JAA03',    4, 'ENT',   'ALTA',    1),
        (37, '2026-09-02', 'SMS-24R350-0K11', 14, 'CAND',  'BAJA',    0),
        (38, '2026-09-07', 'HP5CD1234XYZ',     3, 'CAND',  'MEDIA',   0),
        (39, '2026-09-08', 'HP-5CD1450G82',   21, 'ENT',   'BAJA',    1),
        (40, '2026-09-09', 'TPL-C6-2231A077', 16, 'ENT',   'MEDIA',   2),
        (41, '2026-09-14', 'DL-VOS3510-0A13',  1, 'ENT',   'ALTA',    1),
        (42, '2026-09-15', 'HP-MXL2600C01',    9, 'ENT',   'MEDIA',   1),
        (43, '2026-09-21', 'ACR-NXHS7AA23',    5, 'ENT',   'MEDIA',   2),
        (44, '2026-09-22', 'LNV-PF2TH9B3',     6, 'ENT',   'MEDIA',   1),
        (45, '2026-09-28', 'SMT-R9WT1100A1',  17, 'CANR',  'BAJA',    0),
        (46, '2026-09-28', 'ACR-NXHS7AA01',    2, 'ENT',   'ALTA',    2),
        (47, '2026-09-29', 'DL-7HJK921',       9, 'LISFP', 'ALTA',    1),
        (48, '2026-09-30', 'HP-5CG1100A01',   21, 'LISF0', 'BAJA',    0),
        (49, '2026-10-01', 'TPL-C6-2231A001', 15, 'LISFP', 'MEDIA',   2),
        (50, '2026-10-02', 'LNV-PF4XK2A1',    19, 'LIS',   'MEDIA',   0),
        (51, '2026-10-05', 'EPS-X8QZ4260A',   13, 'LISFP', 'MEDIA',   1),
        (52, '2026-10-06', 'EPS-X8QW5521',    11, 'LISF0', 'ALTA',    0),
        (53, '2026-10-07', 'HP-MXL2210B05',   10, 'LIS',   'URGENTE', 0),
        (54, '2026-10-08', 'DL-LAT5420-0099',  8, 'REP',   'MEDIA',   0),
        (55, '2026-10-08', 'LNV-MJ0FA1B1',     9, 'REP',   'ALTA',    0),
        (56, '2026-10-09', 'ASUS-N3NRKD0101',  7, 'REP',   'MEDIA',   0),
        (57, '2026-10-09', 'HP-5CD1450G81',    3, 'ESP',   'MEDIA',   0),
        (58, '2026-10-10', 'DL-7HJK3301',     10, 'REP',   'ALTA',    0),
        (59, '2026-10-11', 'UBQ-UAPACL-0042', 16, 'ESP',   'BAJA',    0),
        (60, '2026-10-11', 'LNV-PF3TE15A',     6, 'CAND',  'MEDIA',   0),
        (61, '2026-10-12', 'HP-5CD2201X22',    2, 'ESP',   'ALTA',    0),
        (62, '2026-10-12', 'DL-VOS3510-0A12',  5, 'DIA',   'MEDIA',   0),
        (63, '2026-10-13', 'ACR-NXHS7AA22',    4, 'DIA',   'ALTA',    0),
        (64, '2026-10-13', 'HP5CD1234XYZ',     1, 'REC',   'URGENTE', 0),
        (65, '2026-10-13', 'LG-22MK-305NTAB1',14, 'ESP',   'MEDIA',   0),
        (66, '2026-10-14', 'EPS-TMT20-X5501', 12, 'REC',   'MEDIA',   0),
        (67, '2026-10-14', 'HP-5CG2840G7',     5, 'REC',   'BAJA',    0),
        (68, '2026-10-14', 'DL-INS3511-0021',  7, 'DIA',   'MEDIA',   0),
        (69, '2026-10-14', 'ACR-NXHS7AA01',    5, 'REC',   'MEDIA',   0),
        (70, '2026-10-10', 'LNV-HA1KQ7C2',    17, 'REP',   'BAJA',    0);

    /* ======================================================
       9. USUARIOS QUE PARTICIPAN Y DATOS DE CADA ORDEN
       ====================================================== */
    DECLARE @Rec1 INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion1');
    DECLARE @Rec2 INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'recepcion2');
    DECLARE @Caja1 INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'caja1');
    DECLARE @Caja2 INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'caja2');
    DECLARE @Bod1 INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'bodega1');
    DECLARE @Bod2 INT = (SELECT UsuarioId FROM dbo.Usuario WHERE NombreUsuario = 'bodega2');
    DECLARE @Central INT = (SELECT BodegaId FROM dbo.Bodega WHERE Nombre = 'Central');
    DECLARE @Zona10  INT = (SELECT BodegaId FROM dbo.Bodega WHERE Nombre = 'Zona 10');
    DECLARE @Mixco   INT = (SELECT BodegaId FROM dbo.Bodega WHERE Nombre = 'Mixco');

    DECLARE @Tecnico TABLE (Idx INT PRIMARY KEY, UsuarioId INT);
    INSERT INTO @Tecnico (Idx, UsuarioId)
    SELECT v.Idx, u.UsuarioId
    FROM (VALUES (0, 'tecnico1'), (1, 'tecnico2'), (2, 'tecnico3'), (3, 'tecnico4')) AS v (Idx, NombreUsuario)
    JOIN dbo.Usuario u ON u.NombreUsuario = v.NombreUsuario;

    DECLARE @Ord TABLE (
        PlanId INT PRIMARY KEY, Fecha DATETIME, EquipoId INT, ClienteId INT, TipoEquipo VARCHAR(50),
        CasoId INT, Final VARCHAR(5), Prioridad VARCHAR(10), Pagos INT,
        RecepId INT, TecDiagId INT, TecRepId INT, CajaId INT, BodegaPref INT,
        OrdenId INT NULL, ReparacionId INT NULL, FacturaId INT NULL
    );

    INSERT INTO @Ord (PlanId, Fecha, EquipoId, ClienteId, TipoEquipo, CasoId, Final, Prioridad, Pagos,
                      RecepId, TecDiagId, TecRepId, CajaId, BodegaPref)
    SELECT p.PlanId,
           DATEADD(MINUTE, 480 + (p.PlanId % 9) * 50, CAST(p.Dia AS DATETIME)),   -- entre 08:00 y 14:40
           e.EquipoId, e.ClienteId, te.Nombre,
           p.CasoId, p.Final, p.Prioridad, p.Pagos,
           CASE p.PlanId % 2 WHEN 0 THEN @Rec1 ELSE @Rec2 END,
           t1.UsuarioId,
           CASE WHEN p.PlanId % 5 = 0 THEN t2.UsuarioId ELSE t1.UsuarioId END,   -- a veces repara otro técnico
           CASE p.PlanId % 3 WHEN 0 THEN @Caja1 WHEN 1 THEN @Caja2 ELSE @Rec2 END,
           CASE p.PlanId % 3 WHEN 0 THEN @Central WHEN 1 THEN @Zona10 ELSE @Mixco END
    FROM @PlanOrden p
    JOIN dbo.Equipo e      ON e.NumeroSerie   = p.NumeroSerie
    JOIN dbo.TipoEquipo te ON te.TipoEquipoId = e.TipoEquipoId
    JOIN @Tecnico t1       ON t1.Idx = p.PlanId % 4
    JOIN @Tecnico t2       ON t2.Idx = (p.PlanId + 1) % 4;

    IF (SELECT COUNT(*) FROM @Ord) <> (SELECT COUNT(*) FROM @PlanOrden)
        THROW 50013, 'Hay números de serie del plan de órdenes que no existen.', 1;

    DECLARE @Cmp TABLE (PlanId INT PRIMARY KEY, Fecha DATETIME, ProveedorId INT, BodegaId INT,
                        UsuarioId INT, Final CHAR(3), CompraId INT NULL);
    INSERT INTO @Cmp (PlanId, Fecha, ProveedorId, BodegaId, UsuarioId, Final)
    SELECT pc.PlanId, DATEADD(MINUTE, 600 + pc.PlanId, CAST(pc.Dia AS DATETIME)),   -- 10:00 aprox.
           pr.ProveedorId, b.BodegaId,
           CASE pc.PlanId % 2 WHEN 0 THEN @Bod1 ELSE @Bod2 END,
           pc.Final
    FROM @PlanCompra pc
    JOIN dbo.Proveedor pr ON pr.NIT    = pc.NIT
    JOIN dbo.Bodega b     ON b.Nombre  = pc.Bodega;

    IF (SELECT COUNT(*) FROM @Cmp) <> (SELECT COUNT(*) FROM @PlanCompra)
        THROW 50014, 'Hay proveedores o bodegas del plan de compras que no existen.', 1;

    /* ======================================================
       10. EVENTOS EN ORDEN DE FECHA
       ====================================================== */
    DECLARE @EvTmp TABLE (Fecha DATETIME, Tipo VARCHAR(10), PlanId INT, Paso INT);

    -- Compras
    INSERT INTO @EvTmp SELECT Fecha,                   'C_REG', PlanId, 0 FROM @Cmp;
    INSERT INTO @EvTmp SELECT DATEADD(HOUR, 53, Fecha), 'C_REC', PlanId, 0 FROM @Cmp WHERE Final = 'REC';
    INSERT INTO @EvTmp SELECT DATEADD(HOUR, 49, Fecha), 'C_ANU', PlanId, 0 FROM @Cmp WHERE Final = 'ANU';

    -- Órdenes
    INSERT INTO @EvTmp SELECT Fecha,                    'O_REG',  PlanId, 0 FROM @Ord;
    INSERT INTO @EvTmp SELECT DATEADD(HOUR, 4, Fecha),  'O_CAN',  PlanId, 0 FROM @Ord WHERE Final = 'CANR';
    INSERT INTO @EvTmp SELECT DATEADD(HOUR, 3, Fecha),  'O_EST2', PlanId, 0 FROM @Ord WHERE Final = 'DIA';
    INSERT INTO @EvTmp SELECT DATEADD(HOUR, 25, Fecha), 'O_DIAG', PlanId, 0 FROM @Ord
        WHERE Final IN ('ENT', 'LISFP', 'LISF0', 'LIS', 'REP', 'ESP', 'CAND');
    INSERT INTO @EvTmp SELECT DATEADD(HOUR, 74, Fecha), 'O_CAN',  PlanId, 0 FROM @Ord WHERE Final = 'CAND';
    INSERT INTO @EvTmp SELECT DATEADD(HOUR, 48, Fecha), 'O_INI',  PlanId, 0 FROM @Ord
        WHERE Final IN ('ENT', 'LISFP', 'LISF0', 'LIS', 'REP');
    INSERT INTO @EvTmp SELECT DATEADD(MINUTE, 48 * 60 + 40, Fecha), 'O_REPU', PlanId, 0 FROM @Ord
        WHERE Final IN ('ENT', 'LISFP', 'LISF0', 'LIS', 'REP');
    INSERT INTO @EvTmp SELECT DATEADD(MINUTE, 48 * 60 + 90, Fecha), 'O_ACT', PlanId, 1 FROM @Ord
        WHERE Final IN ('ENT', 'LISFP', 'LISF0', 'LIS', 'REP');
    INSERT INTO @EvTmp SELECT DATEADD(HOUR, 72, Fecha), 'O_ACT', PlanId, 2 FROM @Ord
        WHERE Final IN ('ENT', 'LISFP', 'LISF0', 'LIS', 'REP') AND PlanId % 2 = 0;
    INSERT INTO @EvTmp SELECT DATEADD(HOUR, 96, Fecha), 'O_FIN',  PlanId, 0 FROM @Ord
        WHERE Final IN ('ENT', 'LISFP', 'LISF0', 'LIS');
    INSERT INTO @EvTmp SELECT DATEADD(HOUR, 120, Fecha), 'O_FAC', PlanId, 0 FROM @Ord
        WHERE Final IN ('ENT', 'LISFP', 'LISF0');
    INSERT INTO @EvTmp
        SELECT DATEADD(MINUTE, 120 * 60 + 30 + (n.k - 1) * 24 * 60, o.Fecha), 'O_PAGO', o.PlanId, n.k
        FROM @Ord o
        JOIN (VALUES (1), (2), (3)) AS n (k) ON n.k <= o.Pagos
        WHERE o.Final IN ('ENT', 'LISFP');
    INSERT INTO @EvTmp SELECT DATEADD(MINUTE, 120 * 60 + 90 + (Pagos - 1) * 24 * 60, Fecha), 'O_ENT', PlanId, 0
        FROM @Ord WHERE Final = 'ENT';

    DECLARE @Ev TABLE (EventoId INT IDENTITY(1,1) PRIMARY KEY, Fecha DATETIME, Tipo VARCHAR(10), PlanId INT, Paso INT);
    INSERT INTO @Ev (Fecha, Tipo, PlanId, Paso)
    SELECT Fecha, Tipo, PlanId, Paso
    FROM @EvTmp
    ORDER BY Fecha, CASE WHEN Tipo LIKE 'C%' THEN 0 ELSE 1 END, PlanId, Paso;

    /* ======================================================
       11. EJECUTAR LOS EVENTOS
       ====================================================== */
    DECLARE @i INT = 1, @Total INT = (SELECT COUNT(*) FROM @Ev);
    DECLARE @Tipo VARCHAR(10), @F DATETIME, @Plan INT, @Paso INT;
    DECLARE @H INT, @M INT;
    DECLARE @OrdenId INT, @ReparacionId INT, @FacturaId INT, @NuevoId INT;
    DECLARE @EquipoId INT, @ClienteId INT, @TipoEquipo VARCHAR(50), @CasoId INT, @Final VARCHAR(5);
    DECLARE @Prioridad VARCHAR(10), @Pagos INT, @RecepId INT, @TecDiagId INT, @TecRepId INT, @CajaId INT, @BodegaPref INT;
    DECLARE @Problema VARCHAR(500), @Diagnostico VARCHAR(500), @Trabajo VARCHAR(500), @ManoObra DECIMAL(10,2);
    DECLARE @ObsOrden VARCHAR(500), @Linea INT, @RepuestoId INT, @Cant INT, @BodegaUso INT;
    DECLARE @CompraId INT, @ProveedorId INT, @BodegaCompra INT, @UsuarioCompra INT, @Json NVARCHAR(MAX);
    DECLARE @MO DECIMAL(10,2), @TotRep DECIMAL(10,2), @Sub DECIMAL(10,2), @Iva DECIMAL(10,2);
    DECLARE @TotalFactura DECIMAL(10,2), @Saldo DECIMAL(10,2), @Monto DECIMAL(10,2);
    DECLARE @NumFactura VARCHAR(20), @NumPago INT = 0, @MetodoId INT, @Referencia VARCHAR(50);
    DECLARE @Efectivo INT = (SELECT MetodoPagoId FROM dbo.MetodoPago WHERE Nombre = 'EFECTIVO');
    DECLARE @Tarjeta  INT = (SELECT MetodoPagoId FROM dbo.MetodoPago WHERE Nombre = 'TARJETA');
    DECLARE @Transf   INT = (SELECT MetodoPagoId FROM dbo.MetodoPago WHERE Nombre = 'TRANSFERENCIA');
    DECLARE @Msg NVARCHAR(2048);

    WHILE @i <= @Total
    BEGIN
        SELECT @Tipo = Tipo, @F = Fecha, @Plan = PlanId, @Paso = Paso FROM @Ev WHERE EventoId = @i;

        SELECT @H = ISNULL(MAX(HistorialId), 0)  FROM dbo.HistorialEstadoOrden;
        SELECT @M = ISNULL(MAX(MovimientoId), 0) FROM dbo.MovimientoInventario;

        /* ---------- Compras ---------- */
        IF @Tipo LIKE 'C[_]%'
        BEGIN
            SELECT @CompraId = CompraId, @ProveedorId = ProveedorId, @BodegaCompra = BodegaId, @UsuarioCompra = UsuarioId
            FROM @Cmp WHERE PlanId = @Plan;

            IF @Tipo = 'C_REG'
            BEGIN
                SET @Json = (SELECT r.RepuestoId AS repuestoId, l.Cantidad AS cantidad, l.Costo AS costoUnitario
                             FROM @PlanCompraLinea l
                             JOIN dbo.Repuesto r ON r.Codigo = l.Codigo
                             WHERE l.PlanId = @Plan
                             FOR JSON PATH);
                SET @NuevoId = NULL;

                EXEC dbo.sp_RegistrarCompra
                     @ProveedorId = @ProveedorId, @BodegaId = @BodegaCompra, @UsuarioId = @UsuarioCompra,
                     @Detalle = @Json, @Observaciones = 'Compra de reposición',
                     @CompraId = @NuevoId OUTPUT;

                UPDATE @Cmp SET CompraId = @NuevoId WHERE PlanId = @Plan;
                UPDATE dbo.Compra SET FechaCompra = @F WHERE CompraId = @NuevoId;
            END
            ELSE IF @Tipo = 'C_REC'
            BEGIN
                EXEC dbo.sp_RecibirCompra @CompraId = @CompraId, @UsuarioId = @UsuarioCompra;
                UPDATE dbo.Compra SET FechaRecepcion = @F WHERE CompraId = @CompraId;
            END
            ELSE IF @Tipo = 'C_ANU'
                EXEC dbo.sp_AnularCompra @CompraId = @CompraId, @UsuarioId = @UsuarioCompra,
                     @Motivo = 'El proveedor no tenía existencias';
        END
        /* ---------- Órdenes ---------- */
        ELSE
        BEGIN
            SELECT @OrdenId = OrdenId, @ReparacionId = ReparacionId, @FacturaId = FacturaId,
                   @EquipoId = EquipoId, @ClienteId = ClienteId, @TipoEquipo = TipoEquipo,
                   @CasoId = CasoId, @Final = Final, @Prioridad = Prioridad, @Pagos = Pagos,
                   @RecepId = RecepId, @TecDiagId = TecDiagId, @TecRepId = TecRepId,
                   @CajaId = CajaId, @BodegaPref = BodegaPref
            FROM @Ord WHERE PlanId = @Plan;

            SELECT @Problema = Problema, @Diagnostico = Diagnostico, @Trabajo = Trabajo, @ManoObra = ManoObra
            FROM @Caso WHERE CasoId = @CasoId;

            -- Recepción
            IF @Tipo = 'O_REG'
            BEGIN
                SET @ObsOrden = CASE WHEN @TipoEquipo = 'Laptop' AND @Plan % 2 = 0 THEN 'Se recibe con cargador.'
                                     WHEN @TipoEquipo = 'Laptop'                   THEN 'Se recibe sin cargador.'
                                     ELSE NULL END;
                SET @NuevoId = NULL;

                EXEC dbo.sp_RegistrarOrden
                     @ClienteId = @ClienteId, @EquipoId = @EquipoId, @UsuarioRecepcionId = @RecepId,
                     @ProblemaReportado = @Problema, @Prioridad = @Prioridad,
                     @Observaciones = @ObsOrden, @OrdenId = @NuevoId OUTPUT;

                UPDATE @Ord SET OrdenId = @NuevoId WHERE PlanId = @Plan;
                UPDATE dbo.OrdenServicio
                SET FechaIngreso  = @F,
                    FechaEstimada = CAST(DATEADD(DAY, 7, @F) AS DATE)
                WHERE OrdenId = @NuevoId;
            END
            -- Pasa a DIAGNOSTICO sin diagnóstico registrado todavía
            ELSE IF @Tipo = 'O_EST2'
                EXEC dbo.sp_CambiarEstadoOrden @OrdenId = @OrdenId, @EstadoNuevoId = 2, @UsuarioId = @TecDiagId,
                     @Observacion = 'Inicia revisión del equipo';
            -- Diagnóstico
            ELSE IF @Tipo = 'O_DIAG'
            BEGIN
                EXEC dbo.sp_RegistrarDiagnostico
                     @OrdenId = @OrdenId, @TecnicoId = @TecDiagId,
                     @Descripcion = @Diagnostico, @CostoManoObraEstimado = @ManoObra;
                UPDATE dbo.Diagnostico SET FechaDiagnostico = @F WHERE OrdenId = @OrdenId;
            END
            -- Cancelación
            ELSE IF @Tipo = 'O_CAN'
            BEGIN
                SET @ObsOrden = CASE @Final WHEN 'CANR' THEN 'El cliente retiró el equipo antes de la revisión.'
                                            ELSE 'El cliente no autorizó la reparación por el costo.' END;
                EXEC dbo.sp_CambiarEstadoOrden @OrdenId = @OrdenId, @EstadoNuevoId = 7, @UsuarioId = @RecepId,
                     @Observacion = @ObsOrden;
            END
            -- Inicio de la reparación
            ELSE IF @Tipo = 'O_INI'
            BEGIN
                SET @NuevoId = NULL;
                EXEC dbo.sp_IniciarReparacion @OrdenId = @OrdenId, @TecnicoId = @TecRepId,
                     @ReparacionId = @NuevoId OUTPUT;
                UPDATE @Ord SET ReparacionId = @NuevoId WHERE PlanId = @Plan;
                UPDATE dbo.Reparacion SET FechaInicio = @F WHERE ReparacionId = @NuevoId;
            END
            -- Repuestos usados: se toma la bodega preferida si tiene stock; si no, otra
            ELSE IF @Tipo = 'O_REPU'
            BEGIN
                SET @Linea = 1;
                WHILE EXISTS (SELECT 1 FROM @CasoRepuesto WHERE CasoId = @CasoId AND Linea = @Linea)
                BEGIN
                    SELECT @RepuestoId = r.RepuestoId, @Cant = cr.Cantidad
                    FROM @CasoRepuesto cr
                    JOIN dbo.Repuesto r ON r.Codigo = cr.Codigo
                    WHERE cr.CasoId = @CasoId AND cr.Linea = @Linea;

                    SET @BodegaUso = NULL;
                    SELECT TOP (1) @BodegaUso = i.BodegaId
                    FROM dbo.Inventario i
                    WHERE i.RepuestoId = @RepuestoId AND i.Existencia >= @Cant
                    ORDER BY CASE WHEN i.BodegaId = @BodegaPref THEN 0 ELSE 1 END, i.BodegaId;

                    IF @BodegaUso IS NULL
                    BEGIN
                        SET @Msg = CONCAT('No hay stock suficiente para el plan de la orden ', @Plan,
                                          ' (repuesto ', @RepuestoId, '). Revise el plan de compras.');
                        THROW 50015, @Msg, 1;
                    END;

                    EXEC dbo.sp_AsignarRepuesto @ReparacionId = @ReparacionId, @RepuestoId = @RepuestoId,
                         @BodegaId = @BodegaUso, @Cantidad = @Cant, @UsuarioId = @TecRepId;

                    SET @Linea += 1;
                END;

                UPDATE dbo.ReparacionRepuesto SET FechaRegistro = @F WHERE ReparacionId = @ReparacionId;
            END
            -- Actividades de la reparación
            ELSE IF @Tipo = 'O_ACT'
            BEGIN
                IF @Paso = 1
                    EXEC dbo.sp_RegistrarActividadReparacion @ReparacionId = @ReparacionId, @UsuarioId = @TecRepId,
                         @Descripcion = 'Desarmado, revisión y limpieza interna', @HorasTrabajadas = 0.50;
                ELSE
                    EXEC dbo.sp_RegistrarActividadReparacion @ReparacionId = @ReparacionId, @UsuarioId = @TecRepId,
                         @Descripcion = 'Pruebas de funcionamiento y control de calidad', @HorasTrabajadas = 1.00;

                UPDATE dbo.ActividadReparacion SET FechaRegistro = @F
                WHERE ReparacionId = @ReparacionId AND NumeroActividad = @Paso;
            END
            -- Fin de la reparación (a veces la mano de obra final sube Q25)
            ELSE IF @Tipo = 'O_FIN'
            BEGIN
                SET @MO = @ManoObra + CASE WHEN @Plan % 4 = 0 THEN 25.00 ELSE 0 END;
                EXEC dbo.sp_FinalizarReparacion @ReparacionId = @ReparacionId, @TecnicoId = @TecRepId,
                     @CostoManoObra = @MO, @DescripcionTrabajo = @Trabajo;
                UPDATE dbo.Reparacion SET FechaFin = @F WHERE ReparacionId = @ReparacionId;
            END
            -- Factura: mano de obra + repuestos con precio histórico, IVA 12 %
            ELSE IF @Tipo = 'O_FAC'
            BEGIN
                SELECT @MO = CostoManoObra FROM dbo.Reparacion WHERE ReparacionId = @ReparacionId;
                SELECT @TotRep = ISNULL(SUM(Cantidad * PrecioVentaUnitario), 0)
                FROM dbo.ReparacionRepuesto WHERE ReparacionId = @ReparacionId;

                SET @Sub = @MO + @TotRep;
                SET @Iva = ROUND(@Sub * 0.12, 2);
                SET @NumFactura = 'FAC-' + CAST(YEAR(@F) AS CHAR(4)) + '-'
                                + RIGHT('0000' + CAST((SELECT COUNT(*) FROM dbo.Factura) + 1 AS VARCHAR(10)), 4);

                INSERT INTO dbo.Factura
                    (NumeroFactura, OrdenId, NITFacturacion, NombreFacturacion, FechaEmision,
                     TotalManoObra, TotalRepuestos, Subtotal, Impuesto, Total, Estado, UsuarioId)
                SELECT @NumFactura, @OrdenId, c.NIT, c.NombreRazonSocial, @F,
                       @MO, @TotRep, @Sub, @Iva, @Sub + @Iva, 'EMITIDA', @CajaId
                FROM dbo.Cliente c
                WHERE c.ClienteId = @ClienteId;

                SET @NuevoId = SCOPE_IDENTITY();
                UPDATE @Ord SET FacturaId = @NuevoId WHERE PlanId = @Plan;
            END
            -- Pagos: 1 pago = total; 2 pagos = 50 % + resto; 3 pagos = 40 % + 30 % + resto
            -- Pago parcial (LISFP): 50 % o dos de 30 %
            ELSE IF @Tipo = 'O_PAGO'
            BEGIN
                SELECT @TotalFactura = Total FROM dbo.Factura WHERE FacturaId = @FacturaId;
                SET @Saldo = dbo.fn_SaldoFactura(@FacturaId);

                SET @Monto = CASE
                                 WHEN @Final = 'LISFP' AND @Pagos = 1 THEN ROUND(@TotalFactura * 0.50, 2)
                                 WHEN @Final = 'LISFP'                THEN ROUND(@TotalFactura * 0.30, 2)
                                 WHEN @Paso = @Pagos                  THEN @Saldo
                                 WHEN @Pagos = 2                      THEN ROUND(@TotalFactura * 0.50, 2)
                                 WHEN @Paso = 1                       THEN ROUND(@TotalFactura * 0.40, 2)
                                 ELSE                                      ROUND(@TotalFactura * 0.30, 2)
                             END;

                IF @Monto <= 0 OR @Monto > @Saldo
                    THROW 50016, 'Un pago del plan excede el saldo de la factura.', 1;

                SET @NumPago += 1;
                SET @MetodoId   = CASE @NumPago % 3 WHEN 1 THEN @Efectivo WHEN 2 THEN @Tarjeta ELSE @Transf END;
                SET @Referencia = CASE @NumPago % 3
                                      WHEN 1 THEN NULL
                                      WHEN 2 THEN 'VOU-' + RIGHT('000000' + CAST(400000 + @NumPago * 37 AS VARCHAR(10)), 6)
                                      ELSE        'TRF-' + RIGHT('00000000' + CAST(81000000 + @NumPago * 113 AS VARCHAR(10)), 8)
                                  END;

                INSERT INTO dbo.Pago (FacturaId, MetodoPagoId, Monto, FechaPago, Referencia, Estado, UsuarioId)
                VALUES (@FacturaId, @MetodoId, @Monto, @F, @Referencia, 'APLICADO', @CajaId);

                IF dbo.fn_SaldoFactura(@FacturaId) = 0
                    UPDATE dbo.Factura SET Estado = 'PAGADA' WHERE FacturaId = @FacturaId;
            END
            -- Entrega: solo con la factura pagada por completo
            ELSE IF @Tipo = 'O_ENT'
            BEGIN
                IF dbo.fn_SaldoFactura(@FacturaId) <> 0
                    THROW 50017, 'Se intentó entregar una orden con saldo pendiente.', 1;

                INSERT INTO dbo.Entrega (OrdenId, UsuarioEntregaId, NombreRecibe, FechaEntrega, Observaciones)
                SELECT @OrdenId, @RecepId,
                       CASE c.TipoCliente WHEN 'INDIVIDUAL' THEN c.NombreRazonSocial
                                          ELSE 'Encargado de ' + c.NombreRazonSocial END,
                       @F, 'Equipo probado frente al cliente.'
                FROM dbo.Cliente c
                WHERE c.ClienteId = @ClienteId;

                UPDATE dbo.OrdenServicio SET EstadoOrdenId = 6 WHERE OrdenId = @OrdenId;

                INSERT INTO dbo.HistorialEstadoOrden (OrdenId, EstadoAnteriorId, EstadoNuevoId, UsuarioId, Observacion)
                VALUES (@OrdenId, 5, 6, @RecepId, 'Equipo entregado al cliente');
            END;
        END;

        -- Fecha real del evento para el historial, los movimientos y el inventario
        UPDATE dbo.HistorialEstadoOrden SET FechaCambio = @F WHERE HistorialId > @H;
        UPDATE dbo.MovimientoInventario SET FechaMovimiento = @F WHERE MovimientoId > @M;
        UPDATE i
        SET i.FechaActualizacion = @F
        FROM dbo.Inventario i
        JOIN dbo.MovimientoInventario m ON m.RepuestoId = i.RepuestoId AND m.BodegaId = i.BodegaId
        WHERE m.MovimientoId > @M;

        SET @i += 1;
    END;

    -- Fecha de registro de cada cliente: unos días antes de su primera orden
    UPDATE c
    SET c.FechaRegistro = ISNULL(x.Primera, '2026-09-15T10:00:00')
    FROM dbo.Cliente c
    LEFT JOIN (SELECT ClienteId, DATEADD(DAY, -3, MIN(FechaIngreso)) AS Primera
               FROM dbo.OrdenServicio
               GROUP BY ClienteId) AS x ON x.ClienteId = c.ClienteId;

    COMMIT TRANSACTION;
    PRINT 'Datos de prueba cargados correctamente.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

/* ==========================================================
   VERIFICACIÓN 1: cantidades contra el mínimo del enunciado
   ========================================================== */
WITH Conteo AS (
    SELECT 1 AS Orden, 'Usuarios' AS Entidad, COUNT(*) AS Registros, 10 AS Minimo FROM dbo.Usuario
    UNION ALL SELECT 2,  'Clientes',               COUNT(*), 30  FROM dbo.Cliente
    UNION ALL SELECT 3,  'Equipos',                COUNT(*), 45  FROM dbo.Equipo
    UNION ALL SELECT 4,  'Órdenes de servicio',    COUNT(*), 60  FROM dbo.OrdenServicio
    UNION ALL SELECT 5,  'Diagnósticos',           COUNT(*), 45  FROM dbo.Diagnostico
    UNION ALL SELECT 6,  'Reparaciones',           COUNT(*), 35  FROM dbo.Reparacion
    UNION ALL SELECT 7,  'Repuestos',              COUNT(*), 30  FROM dbo.Repuesto
    UNION ALL SELECT 8,  'Bodegas',                COUNT(*), 3   FROM dbo.Bodega
    UNION ALL SELECT 9,  'Inventario',             COUNT(*), 60  FROM dbo.Inventario
    UNION ALL SELECT 10, 'Proveedores',            COUNT(*), 8   FROM dbo.Proveedor
    UNION ALL SELECT 11, 'Compras',                COUNT(*), 20  FROM dbo.Compra
    UNION ALL SELECT 12, 'Movimientos inventario', COUNT(*), 100 FROM dbo.MovimientoInventario
    UNION ALL SELECT 13, 'Facturas',               COUNT(*), 30  FROM dbo.Factura
    UNION ALL SELECT 14, 'Pagos',                  COUNT(*), 40  FROM dbo.Pago
)
SELECT Entidad, Registros, Minimo,
       CASE WHEN Registros >= Minimo THEN 'Sí' ELSE 'NO' END AS Cumple
FROM Conteo
ORDER BY Orden;

/* ==========================================================
   VERIFICACIÓN 2: escenarios obligatorios del enunciado
   ========================================================== */
WITH Escenarios AS (
    SELECT 1 AS Orden, 'Cliente sin órdenes' AS Escenario, COUNT(*) AS Cantidad
    FROM dbo.Cliente c
    LEFT JOIN dbo.OrdenServicio o ON o.ClienteId = c.ClienteId
    WHERE o.OrdenId IS NULL
    UNION ALL
    SELECT 2, 'Equipo con 3 o más órdenes', COUNT(*)
    FROM (SELECT EquipoId FROM dbo.OrdenServicio GROUP BY EquipoId HAVING COUNT(*) >= 3) AS x
    UNION ALL
    SELECT 3, 'Orden sin diagnóstico', COUNT(*)
    FROM dbo.OrdenServicio o
    LEFT JOIN dbo.Diagnostico d ON d.OrdenId = o.OrdenId
    WHERE d.DiagnosticoId IS NULL
    UNION ALL
    SELECT 4, 'Orden diagnosticada pero no reparada', COUNT(*)
    FROM dbo.Diagnostico d
    LEFT JOIN dbo.Reparacion rp ON rp.DiagnosticoId = d.DiagnosticoId
    WHERE rp.ReparacionId IS NULL
    UNION ALL
    SELECT 5, 'Reparación con varios repuestos', COUNT(*)
    FROM (SELECT ReparacionId FROM dbo.ReparacionRepuesto GROUP BY ReparacionId HAVING COUNT(*) >= 2) AS x
    UNION ALL
    SELECT 6, 'Reparación sin repuestos', COUNT(*)
    FROM dbo.Reparacion rp
    LEFT JOIN dbo.ReparacionRepuesto rr ON rr.ReparacionId = rp.ReparacionId
    WHERE rr.ReparacionId IS NULL
    UNION ALL
    SELECT 7, 'Repuesto disponible en varias bodegas', COUNT(*)
    FROM (SELECT RepuestoId FROM dbo.Inventario WHERE Existencia > 0 GROUP BY RepuestoId HAVING COUNT(*) >= 2) AS x
    UNION ALL
    SELECT 8, 'Stock en cero', COUNT(*)
    FROM dbo.Inventario WHERE Existencia = 0
    UNION ALL
    SELECT 9, 'Repuesto bajo el mínimo (con existencia)', COUNT(*)
    FROM dbo.Inventario WHERE Existencia > 0 AND Existencia <= StockMinimo
    UNION ALL
    SELECT 10, 'Factura con varios pagos', COUNT(*)
    FROM (SELECT FacturaId FROM dbo.Pago GROUP BY FacturaId HAVING COUNT(*) >= 2) AS x
    UNION ALL
    SELECT 11, 'Factura con saldo pendiente', COUNT(*)
    FROM dbo.Factura WHERE dbo.fn_SaldoFactura(FacturaId) > 0
    UNION ALL
    SELECT 12, 'Compra pendiente de recibir', COUNT(*)
    FROM dbo.Compra WHERE Estado = 'PENDIENTE'
    UNION ALL
    SELECT 13, 'Movimientos de entrada', COUNT(*)
    FROM dbo.MovimientoInventario WHERE TipoMovimiento = 'ENTRADA'
    UNION ALL
    SELECT 14, 'Movimientos de salida', COUNT(*)
    FROM dbo.MovimientoInventario WHERE TipoMovimiento = 'SALIDA'
)
SELECT Escenario, Cantidad,
       CASE WHEN Cantidad >= 1 THEN 'Sí' ELSE 'NO' END AS Cumple
FROM Escenarios
ORDER BY Orden;

/* ==========================================================
   VERIFICACIÓN 3: órdenes por estado
   ========================================================== */
SELECT eo.Codigo AS Estado, COUNT(o.OrdenId) AS Ordenes
FROM dbo.EstadoOrden eo
LEFT JOIN dbo.OrdenServicio o ON o.EstadoOrdenId = eo.EstadoOrdenId
GROUP BY eo.EstadoOrdenId, eo.Codigo
ORDER BY eo.EstadoOrdenId;

-- Control: nunca existencias negativas ni facturas pagadas de más
SELECT (SELECT COUNT(*) FROM dbo.Inventario WHERE Existencia < 0)                AS ExistenciasNegativas,
       (SELECT COUNT(*) FROM dbo.Factura WHERE dbo.fn_SaldoFactura(FacturaId) < 0) AS FacturasSobrepagadas;
GO
/* Debe salir:
   Verificación 1: las 14 entidades con Cumple = Sí
     (11 usuarios, 31 clientes, 48 equipos, 70 órdenes, 60 diagnósticos,
      49 reparaciones, 32 repuestos, 3 bodegas, 65 inventario, 9 proveedores,
      25 compras, 143 movimientos, 42 facturas, 59 pagos)
   Verificación 2: los 14 escenarios con Cumple = Sí
   Verificación 3: RECIBIDO 4, DIAGNOSTICO 3, ESPERANDO_AUTORIZACION 4,
     REPARACION 5, LISTO 7, ENTREGADO 37, CANCELADO 10
   ExistenciasNegativas = 0 y FacturasSobrepagadas = 0 */
GO

/* ##########################################################
    7/12  06_facturacion.sql
   Facturación, pagos y entrega
   Procedimientos (4): sp_CambiarEstadoOrden, sp_GenerarFactura, sp_RegistrarPago, sp_EntregarOrden
   ########################################################## */
PRINT '>> 7/12 06_facturacion.sql';
GO

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

        -- Referencia: de 4 a 50 caracteres, solo letras, números y guiones; se guarda en mayúsculas
        SET @Referencia = NULLIF(UPPER(LTRIM(RTRIM(@Referencia))), '');
        IF @Referencia IS NOT NULL AND (LEN(@Referencia) < 4 OR @Referencia LIKE '%[^A-Z0-9-]%')
            THROW 50719, 'Referencia inválida: use de 4 a 50 caracteres, solo letras, números y guiones (ej. AUT-482915).', 1;

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

        -- El mismo voucher o boleta no se puede aplicar dos veces con el mismo método
        IF @Referencia IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.Pago WITH (UPDLOCK, HOLDLOCK)
                                               WHERE MetodoPagoId = @MetodoPagoId
                                                 AND Referencia = @Referencia
                                                 AND Estado = 'APLICADO')
        BEGIN
            SET @Msg = CONCAT('La referencia ', @Referencia, ' ya fue usada en otro pago con ', @Metodo, '. Revise el voucher o la boleta.');
            THROW 50720, @Msg, 1;
        END;

        INSERT INTO dbo.Pago (FacturaId, MetodoPagoId, Monto, Referencia, Estado, UsuarioId)
        VALUES (@FacturaId, @MetodoPagoId, @Monto, @Referencia, 'APLICADO', @UsuarioId);

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
GO

/* ##########################################################
    8/12  07_triggers_indices_reportes.sql
   Triggers, índices no agrupados y reportes finales
   Índices (13): IX_OrdenServicio_Estado_Prioridad, IX_OrdenServicio_Equipo_Fecha,
       IX_OrdenServicio_Cliente_Fecha, IX_HistorialEstadoOrden_Orden_Fecha,
       IX_Diagnostico_Tecnico_Fecha, IX_Reparacion_Tecnico_Fecha, IX_MovimientoInventario_Fecha,
       IX_MovimientoInventario_Repuesto_Bodega, IX_Compra_Proveedor_Fecha, IX_Factura_FechaEmision,
       IX_Pago_Factura, IX_Equipo_Cliente, IX_Cliente_Nombre
   Vistas (6): vw_HistorialCliente, vw_FacturasSaldoPendiente, vw_IngresosPeriodo,
       vw_TrazabilidadOrden, vw_Dashboard, vw_ActividadReciente
   Funciones (1): fn_ReporteIngresos
   Procedimientos (1): sp_TrazabilidadOrden
   Triggers (10): trg_Repuesto_AuditoriaPrecio, trg_OrdenServicio_NoEliminar,
       trg_HistorialEstadoOrden_NoEliminar, trg_MovimientoInventario_NoEliminar,
       trg_Compra_NoEliminar, trg_Factura_NoEliminar, trg_Pago_NoEliminar, trg_Pago_NoExcederTotal,
       trg_Entrega_SinSaldo, trg_OrdenServicio_EntregadoConEntrega
   ########################################################## */
PRINT '>> 8/12 07_triggers_indices_reportes.sql';
GO

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

/* ----------------------------------------------------------
   Triggers de protección financiera (R12, R16 y 2.7)
   Los procedimientos ya validan estas reglas; los triggers son
   la última barrera si alguien inserta o actualiza directo desde
   SQL Server. Trabajan por conjuntos (varias filas a la vez).
   ---------------------------------------------------------- */

-- R12: la suma de pagos nunca puede pasar del total de la factura
CREATE OR ALTER TRIGGER dbo.trg_Pago_NoExcederTotal
ON dbo.Pago
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1
               FROM (SELECT FacturaId FROM inserted GROUP BY FacturaId) AS i
               WHERE dbo.fn_SaldoFactura(i.FacturaId) < 0)
        THROW 50807, 'La suma de los pagos no puede exceder el total de la factura.', 1;
END;
GO

-- 2.7: no se entrega un equipo sin factura o con saldo pendiente
CREATE OR ALTER TRIGGER dbo.trg_Entrega_SinSaldo
ON dbo.Entrega
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1
               FROM inserted e
               LEFT JOIN dbo.Factura f ON f.OrdenId = e.OrdenId AND f.Estado <> 'ANULADA'
               WHERE f.FacturaId IS NULL
                  OR dbo.fn_SaldoFactura(f.FacturaId) > 0)
        THROW 50808, 'No se puede registrar la entrega: la orden no tiene factura o tiene saldo pendiente.', 1;
END;
GO

-- 2.8: una orden solo pasa a ENTREGADO si existe su entrega
-- (sp_EntregarOrden inserta la entrega antes de cambiar el estado)
CREATE OR ALTER TRIGGER dbo.trg_OrdenServicio_EntregadoConEntrega
ON dbo.OrdenServicio
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(EstadoOrdenId)
        RETURN;

    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN deleted d       ON d.OrdenId = i.OrdenId
               LEFT JOIN dbo.Entrega en ON en.OrdenId = i.OrdenId
               WHERE i.EstadoOrdenId = 6
                 AND d.EstadoOrdenId <> 6
                 AND en.EntregaId IS NULL)
        THROW 50809, 'Una orden solo pasa a ENTREGADO registrando la entrega (sp_EntregarOrden).', 1;
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
GO

/* ##########################################################
    9/12  09_clientes_equipos_ordenes.sql
   Clientes, equipos y órdenes (vistas y SP)
   Vistas (3): vw_Cliente, vw_Equipo, vw_Orden
   Procedimientos (2): sp_Cliente_Crear, sp_Equipo_Crear
   ########################################################## */
PRINT '>> 9/12 09_clientes_equipos_ordenes.sql';
GO

/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 09: SPs básicos y vistas de clientes, equipos y órdenes
   Se ejecuta después del 01, 02 y 03
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   VISTAS
   ========================================================== */

-- vw_Cliente: clientes con su estado
CREATE OR ALTER VIEW dbo.vw_Cliente
AS
    SELECT ClienteId,
           TipoCliente,
           NombreRazonSocial,
           NIT,
           Telefono,
           Correo,
           Direccion,
           Estado,
           FechaRegistro
    FROM dbo.Cliente;
GO

-- vw_Equipo: equipos con el nombre del cliente y del tipo
CREATE OR ALTER VIEW dbo.vw_Equipo
AS
    SELECT e.EquipoId,
           e.ClienteId,
           c.NombreRazonSocial AS NombreCliente,
           e.TipoEquipoId,
           t.Nombre AS TipoEquipo,
           e.Marca,
           e.Modelo,
           e.NumeroSerie,
           e.Descripcion,
           e.Estado
    FROM dbo.Equipo e
    INNER JOIN dbo.Cliente c ON c.ClienteId = e.ClienteId
    INNER JOIN dbo.TipoEquipo t ON t.TipoEquipoId = e.TipoEquipoId;
GO

-- vw_Orden: órdenes con cliente, equipo, estado y recepcionista
-- (las reglas usan LEFT JOIN cuando lo opcional; aquí todo es NOT NULL)
CREATE OR ALTER VIEW dbo.vw_Orden
AS
    SELECT o.OrdenId,
           o.NumeroOrden,
           o.ClienteId,
           c.NombreRazonSocial AS NombreCliente,
           o.EquipoId,
           e.NumeroSerie,
           t.Nombre + ' ' + e.Marca + ' ' + e.Modelo AS Equipo,
           o.UsuarioRecepcionId,
           u.NombreCompleto AS Recepcionista,
           o.FechaIngreso,
           o.ProblemaReportado,
           o.Prioridad,
           o.EstadoOrdenId,
           eo.Codigo AS Estado,
           o.FechaEstimada,
           o.Observaciones
    FROM dbo.OrdenServicio o
    INNER JOIN dbo.Cliente c ON c.ClienteId = o.ClienteId
    INNER JOIN dbo.Equipo e ON e.EquipoId = o.EquipoId
    INNER JOIN dbo.TipoEquipo t ON t.TipoEquipoId = e.TipoEquipoId
    INNER JOIN dbo.EstadoOrden eo ON eo.EstadoOrdenId = o.EstadoOrdenId
    INNER JOIN dbo.Usuario u ON u.UsuarioId = o.UsuarioRecepcionId;
GO

/* ==========================================================
   sp_Cliente_Crear
   Registra un cliente (individual o empresarial).
   Valida el tipo de cliente y que el NIT no esté duplicado.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_Crear
    @TipoCliente       VARCHAR(15),
    @NombreRazonSocial VARCHAR(150),
    @NIT               VARCHAR(15),
    @Telefono          VARCHAR(15),
    @Correo            VARCHAR(100) = NULL,
    @Direccion         VARCHAR(200) = NULL,
    @ClienteId         INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @TipoCliente NOT IN ('INDIVIDUAL', 'EMPRESARIAL')
            THROW 50301, 'Tipo de cliente inválido. Use INDIVIDUAL o EMPRESARIAL.', 1;

        IF @NombreRazonSocial IS NULL OR LTRIM(RTRIM(@NombreRazonSocial)) = ''
            THROW 50302, 'El nombre o razón social es obligatorio.', 1;

        IF @NIT IS NULL OR LTRIM(RTRIM(@NIT)) = ''
            THROW 50303, 'El NIT es obligatorio.', 1;

        -- CF (consumidor final) se puede repetir: el índice UX_Cliente_NIT lo excluye
        IF @NIT <> 'CF' AND EXISTS (SELECT 1 FROM dbo.Cliente WHERE NIT = @NIT)
            THROW 50304, 'Ya existe un cliente con ese NIT.', 1;

        INSERT INTO dbo.Cliente (TipoCliente, NombreRazonSocial, NIT, Telefono, Correo, Direccion)
        VALUES (@TipoCliente, LTRIM(RTRIM(@NombreRazonSocial)), LTRIM(RTRIM(@NIT)),
                @Telefono, @Correo, @Direccion);

        SET @ClienteId = SCOPE_IDENTITY();

        SELECT @ClienteId AS ClienteId, @NIT AS NIT, 'CLIENTE REGISTRADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_Equipo_Crear
   Registra un equipo de un cliente.
   Valida que el cliente esté activo, que el tipo exista
   y que el número de serie sea único (R01).
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Equipo_Crear
    @ClienteId    INT,
    @TipoEquipoId INT,
    @Marca        VARCHAR(50),
    @Modelo       VARCHAR(50),
    @NumeroSerie  VARCHAR(50),
    @Descripcion  VARCHAR(200) = NULL,
    @EquipoId     INT          = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente
                       WHERE ClienteId = @ClienteId AND Estado = 'ACTIVO')
            THROW 50311, 'El cliente no existe o está inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.TipoEquipo WHERE TipoEquipoId = @TipoEquipoId)
            THROW 50312, 'El tipo de equipo no existe.', 1;

        IF @NumeroSerie IS NULL OR LTRIM(RTRIM(@NumeroSerie)) = ''
            THROW 50313, 'El número de serie es obligatorio.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Equipo WHERE NumeroSerie = @NumeroSerie)
            THROW 50314, 'Ya existe un equipo con ese número de serie.', 1;

        INSERT INTO dbo.Equipo (ClienteId, TipoEquipoId, Marca, Modelo, NumeroSerie, Descripcion)
        VALUES (@ClienteId, @TipoEquipoId, @Marca, @Modelo,
                LTRIM(RTRIM(@NumeroSerie)), @Descripcion);

        SET @EquipoId = SCOPE_IDENTITY();

        SELECT @EquipoId AS EquipoId, @NumeroSerie AS NumeroSerie, 'EQUIPO REGISTRADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- Verificación
-- SELECT name FROM sys.views WHERE name IN ('vw_Cliente', 'vw_Equipo', 'vw_Orden');
-- SELECT name FROM sys.procedures WHERE name IN ('sp_Cliente_Crear', 'sp_Equipo_Crear');
GO

/* ##########################################################
   10/12  10_sp_orden_usuario.sql
   Listado de órdenes y usuarios
   Vistas (1): vw_UsuarioLista
   Procedimientos (1): sp_ListarOrdenes
   ########################################################## */
PRINT '>> 10/12 10_sp_orden_usuario.sql';
GO

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
GO

/* ##########################################################
   11/12  11_sp_cliente_equipo.sql
   CRUD de clientes y equipos
   Procedimientos (6): sp_Cliente_Listar, sp_Cliente_Actualizar, sp_Cliente_Eliminar,
       sp_Equipo_Listar, sp_Equipo_Actualizar, sp_Equipo_Eliminar
   ########################################################## */
PRINT '>> 11/12 11_sp_cliente_equipo.sql';
GO

/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 11: SPs de clientes y equipos (listar, actualizar, eliminar)
   Siguiente de 01..10:
     - Crear cliente  -> ya existe dbo.sp_Cliente_Crear (09)
     - Crear equipo   -> ya existe dbo.sp_Equipo_Crear  (09)
     - Listados base  -> vistas dbo.vw_Cliente / dbo.vw_Equipo (09)
   Este script agrega lo que falta para el CRUD completo:
     - sp_Cliente_Listar      (por texto y estado)
     - sp_Cliente_Actualizar  (valida tipo y NIT unico)
     - sp_Cliente_Eliminar    (logico; no si tiene ordenes abiertas)
     - sp_Equipo_Listar       (por cliente, texto y solo activos)
     - sp_Equipo_Actualizar   (valida cliente activo, tipo y serie unica)
     - sp_Equipo_Eliminar     (logico; no si tiene ordenes abiertas)
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   sp_Cliente_Listar
   Lista los clientes desde vw_Cliente.
   @Buscar: filtra por nombre/razon social o NIT.
   @Estado: 'ACTIVO' o 'INACTIVO'. NULL = todos.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_Listar
    @Buscar VARCHAR(100) = NULL,
    @Estado VARCHAR(12)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ClienteId, TipoCliente, NombreRazonSocial, NIT, Telefono,
           Correo, Direccion, Estado, FechaRegistro
    FROM dbo.vw_Cliente
    WHERE (@Estado IS NULL OR Estado = @Estado)
      AND (@Buscar IS NULL OR @Buscar = ''
           OR NombreRazonSocial LIKE '%' + @Buscar + '%'
           OR NIT LIKE '%' + @Buscar + '%')
    ORDER BY ClienteId;
END;
GO

/* ==========================================================
   sp_Cliente_Actualizar
   Actualiza los datos del cliente.
   Valida que exista, el tipo y que el NIT no lo use otro cliente.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_Actualizar
    @ClienteId         INT,
    @TipoCliente       VARCHAR(15),
    @NombreRazonSocial VARCHAR(150),
    @NIT               VARCHAR(15),
    @Telefono          VARCHAR(15),
    @Correo            VARCHAR(100) = NULL,
    @Direccion         VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteId = @ClienteId)
            THROW 51101, 'El cliente no existe.', 1;

        IF @TipoCliente NOT IN ('INDIVIDUAL', 'EMPRESARIAL')
            THROW 51102, 'Tipo de cliente inválido. Use INDIVIDUAL o EMPRESARIAL.', 1;

        IF @NombreRazonSocial IS NULL OR LTRIM(RTRIM(@NombreRazonSocial)) = ''
            THROW 51103, 'El nombre o razón social es obligatorio.', 1;

        IF @NIT IS NULL OR LTRIM(RTRIM(@NIT)) = ''
            THROW 51104, 'El NIT es obligatorio.', 1;

        -- CF (consumidor final) se puede repetir: el índice UX_Cliente_NIT lo excluye
        IF @NIT <> 'CF' AND EXISTS (SELECT 1 FROM dbo.Cliente WHERE NIT = @NIT AND ClienteId <> @ClienteId)
            THROW 51105, 'Ya existe otro cliente con ese NIT.', 1;

        UPDATE dbo.Cliente
        SET TipoCliente       = @TipoCliente,
            NombreRazonSocial = LTRIM(RTRIM(@NombreRazonSocial)),
            NIT               = LTRIM(RTRIM(@NIT)),
            Telefono          = @Telefono,
            Correo            = @Correo,
            Direccion         = @Direccion
        WHERE ClienteId = @ClienteId;

        SELECT @ClienteId AS ClienteId, 'CLIENTE ACTUALIZADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_Cliente_Eliminar
   Borrado logico (Estado = 'INACTIVO') para no romper ordenes e historial.
   No permite inactivar un cliente con ordenes abiertas.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_Eliminar
    @ClienteId INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteId = @ClienteId)
            THROW 51111, 'El cliente no existe.', 1;

        IF EXISTS (SELECT 1 FROM dbo.OrdenServicio
                   WHERE ClienteId = @ClienteId AND EstadoOrdenId NOT IN (6, 7))
            THROW 51112, 'El cliente tiene órdenes abiertas. Cierre o cancele esas órdenes primero.', 1;

        UPDATE dbo.Cliente SET Estado = 'INACTIVO' WHERE ClienteId = @ClienteId;

        SELECT @ClienteId AS ClienteId, 'CLIENTE INACTIVADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_Equipo_Listar
   Lista los equipos desde vw_Equipo.
   @ClienteId: filtra por cliente. NULL = todos.
   @Buscar: por marca, modelo o numero de serie.
   @SoloActivos: 1 = solo equipos ACTIVO (para el formulario de nueva orden).
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Equipo_Listar
    @ClienteId   INT          = NULL,
    @Buscar      VARCHAR(100) = NULL,
    @SoloActivos BIT          = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT EquipoId, ClienteId, NombreCliente, TipoEquipoId,
           TipoEquipo AS NombreTipoEquipo,
           Marca, Modelo, NumeroSerie, Descripcion, Estado
    FROM dbo.vw_Equipo
    WHERE (@ClienteId IS NULL OR ClienteId = @ClienteId)
      AND (@SoloActivos = 0 OR Estado = 'ACTIVO')
      AND (@Buscar IS NULL OR @Buscar = ''
           OR Marca LIKE '%' + @Buscar + '%'
           OR Modelo LIKE '%' + @Buscar + '%'
           OR NumeroSerie LIKE '%' + @Buscar + '%')
    ORDER BY EquipoId;
END;
GO

/* ==========================================================
   sp_Equipo_Actualizar
   Actualiza los datos del equipo.
   Valida que exista, que el cliente este activo, que el tipo
   exista y que el numero de serie sea unico (R01).
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Equipo_Actualizar
    @EquipoId     INT,
    @ClienteId    INT,
    @TipoEquipoId INT,
    @Marca        VARCHAR(50),
    @Modelo       VARCHAR(50),
    @NumeroSerie  VARCHAR(50),
    @Descripcion  VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Equipo WHERE EquipoId = @EquipoId)
            THROW 51121, 'El equipo no existe.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente
                       WHERE ClienteId = @ClienteId AND Estado = 'ACTIVO')
            THROW 51122, 'El cliente no existe o está inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.TipoEquipo WHERE TipoEquipoId = @TipoEquipoId)
            THROW 51123, 'El tipo de equipo no existe.', 1;

        IF @NumeroSerie IS NULL OR LTRIM(RTRIM(@NumeroSerie)) = ''
            THROW 51124, 'El número de serie es obligatorio.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Equipo
                   WHERE NumeroSerie = @NumeroSerie AND EquipoId <> @EquipoId)
            THROW 51125, 'Ya existe otro equipo con ese número de serie.', 1;

        UPDATE dbo.Equipo
        SET ClienteId    = @ClienteId,
            TipoEquipoId = @TipoEquipoId,
            Marca        = LTRIM(RTRIM(@Marca)),
            Modelo       = LTRIM(RTRIM(@Modelo)),
            NumeroSerie  = LTRIM(RTRIM(@NumeroSerie)),
            Descripcion  = @Descripcion
        WHERE EquipoId = @EquipoId;

        SELECT @EquipoId AS EquipoId, 'EQUIPO ACTUALIZADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   sp_Equipo_Eliminar
   Borrado logico (Estado = 'INACTIVO').
   No permite inactivar un equipo con ordenes abiertas.
   ========================================================== */
CREATE OR ALTER PROCEDURE dbo.sp_Equipo_Eliminar
    @EquipoId INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Equipo WHERE EquipoId = @EquipoId)
            THROW 51131, 'El equipo no existe.', 1;

        IF EXISTS (SELECT 1 FROM dbo.OrdenServicio
                   WHERE EquipoId = @EquipoId AND EstadoOrdenId NOT IN (6, 7))
            THROW 51132, 'El equipo tiene órdenes abiertas. Cierre o cancele esas órdenes primero.', 1;

        UPDATE dbo.Equipo SET Estado = 'INACTIVO' WHERE EquipoId = @EquipoId;

        SELECT @EquipoId AS EquipoId, 'EQUIPO INACTIVADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- Verificación (en la base ejecutar descomentado):
-- SELECT name, type_desc FROM sys.objects
-- WHERE name IN ('sp_Cliente_Listar','sp_Cliente_Actualizar','sp_Cliente_Eliminar',
--                'sp_Equipo_Listar','sp_Equipo_Actualizar','sp_Equipo_Eliminar');
-- EXEC dbo.sp_Cliente_Listar;
-- EXEC dbo.sp_Cliente_Listar @Buscar = 'comercial', @Estado = 'ACTIVO';
-- EXEC dbo.sp_Equipo_Listar @ClienteId = 1, @SoloActivos = 1;
GO

/* ##########################################################
   12/12  12_mantenimientos.sql
   Mantenimientos (repuestos, proveedores, bodegas, catálogos, usuarios)
   Procedimientos (15): sp_Categoria_Guardar, sp_Categoria_CambiarEstado, sp_TipoEquipo_Guardar,
       sp_Repuesto_Guardar, sp_Repuesto_CambiarEstado, sp_Inventario_GuardarMinimo,
       sp_Bodega_Guardar, sp_Bodega_CambiarEstado, sp_Proveedor_Guardar, sp_Proveedor_CambiarEstado,
       sp_Usuario_Guardar, sp_Usuario_CambiarEstado, sp_Usuario_RestablecerContrasena,
       sp_Cliente_Activar, sp_Equipo_Activar
   ########################################################## */
PRINT '>> 12/12 12_mantenimientos.sql';
GO

/* ==========================================================
   Proyecto Final - Base de Datos I (UMG)
   TechCare Solutions
   Script 12: Mantenimientos (enunciado 6.1)
   Se ejecuta después del 01..11.
   Procedimientos para crear, editar y activar/inactivar:
     - Categorías de repuesto     sp_Categoria_Guardar, sp_Categoria_CambiarEstado
     - Tipos de equipo            sp_TipoEquipo_Guardar
     - Repuestos                  sp_Repuesto_Guardar, sp_Repuesto_CambiarEstado
     - Stock mínimo por bodega    sp_Inventario_GuardarMinimo
     - Bodegas                    sp_Bodega_Guardar, sp_Bodega_CambiarEstado
     - Proveedores                sp_Proveedor_Guardar, sp_Proveedor_CambiarEstado
     - Usuarios/empleados         sp_Usuario_Guardar, sp_Usuario_CambiarEstado,
                                  sp_Usuario_RestablecerContrasena
     - Clientes y equipos         sp_Cliente_Activar, sp_Equipo_Activar
                                  (reactivan lo que inactivan los SP del 11)
   Reglas:
     - Nada se borra: se inactiva (los históricos siguen apuntando al registro).
     - @UsuarioId es quien hace el cambio; se valida con fn_UsuarioTieneRol.
       Repuestos, mínimos y proveedores: BODEGA o ADMINISTRADOR.
       Bodegas, categorías, tipos de equipo y usuarios: solo ADMINISTRADOR.
     - El precio se cambia con UPDATE normal: trg_Repuesto_AuditoriaPrecio (07)
       guarda el historial en AuditoriaPrecio.
     - Contraseñas: se guarda el SHA2_256, igual que en 02 y sp_LoginUsuario.
   Errores: 51201..51799
   ========================================================== */

-- Solo en Docker (en SmarterASP se deja comentado)
-- USE TechCare;
-- GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ==========================================================
   CATÁLOGOS
   ========================================================== */

/* ----------------------------------------------------------
   sp_Categoria_Guardar
   @CategoriaId NULL = crear; con valor = editar.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Categoria_Guardar
    @UsuarioId    INT,
    @CategoriaId  INT          = NULL,
    @Nombre       VARCHAR(50),
    @Descripcion  VARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51201, 'Solo el ADMINISTRADOR puede modificar las categorías.', 1;

        SET @Nombre = LTRIM(RTRIM(@Nombre));
        IF @Nombre IS NULL OR @Nombre = ''
            THROW 51202, 'El nombre de la categoría es obligatorio.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Categoria WITH (UPDLOCK, HOLDLOCK)
                   WHERE Nombre = @Nombre AND (@CategoriaId IS NULL OR CategoriaId <> @CategoriaId))
            THROW 51203, 'Ya existe una categoría con ese nombre.', 1;

        IF @CategoriaId IS NULL
        BEGIN
            INSERT INTO dbo.Categoria (Nombre, Descripcion)
            VALUES (@Nombre, NULLIF(LTRIM(RTRIM(@Descripcion)), ''));
            SET @CategoriaId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Categoria WHERE CategoriaId = @CategoriaId)
                THROW 51204, 'La categoría no existe.', 1;

            UPDATE dbo.Categoria
            SET Nombre = @Nombre, Descripcion = NULLIF(LTRIM(RTRIM(@Descripcion)), '')
            WHERE CategoriaId = @CategoriaId;
        END

        COMMIT TRANSACTION;

        SELECT CategoriaId, Nombre, Descripcion, Activo
        FROM dbo.Categoria WHERE CategoriaId = @CategoriaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Categoria_CambiarEstado
   No se inactiva si tiene repuestos activos.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Categoria_CambiarEstado
    @UsuarioId    INT,
    @CategoriaId  INT,
    @Activo       BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51211, 'Solo el ADMINISTRADOR puede modificar las categorías.', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Categoria WITH (UPDLOCK, HOLDLOCK) WHERE CategoriaId = @CategoriaId)
            THROW 51212, 'La categoría no existe.', 1;

        IF @Activo = 0 AND EXISTS (SELECT 1 FROM dbo.Repuesto
                                   WHERE CategoriaId = @CategoriaId AND Estado = 'ACTIVO')
            THROW 51213, 'La categoría tiene repuestos activos. Inactive o cambie esos repuestos primero.', 1;

        UPDATE dbo.Categoria SET Activo = @Activo WHERE CategoriaId = @CategoriaId;

        COMMIT TRANSACTION;

        SELECT CategoriaId, Nombre, Descripcion, Activo
        FROM dbo.Categoria WHERE CategoriaId = @CategoriaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_TipoEquipo_Guardar
   @TipoEquipoId NULL = crear; con valor = renombrar.
   (La tabla no tiene estado; los tipos usados por equipos no se borran.)
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_TipoEquipo_Guardar
    @UsuarioId     INT,
    @TipoEquipoId  INT = NULL,
    @Nombre        VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51221, 'Solo el ADMINISTRADOR puede modificar los tipos de equipo.', 1;

        SET @Nombre = LTRIM(RTRIM(@Nombre));
        IF @Nombre IS NULL OR @Nombre = ''
            THROW 51222, 'El nombre del tipo de equipo es obligatorio.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.TipoEquipo WITH (UPDLOCK, HOLDLOCK)
                   WHERE Nombre = @Nombre AND (@TipoEquipoId IS NULL OR TipoEquipoId <> @TipoEquipoId))
            THROW 51223, 'Ya existe un tipo de equipo con ese nombre.', 1;

        IF @TipoEquipoId IS NULL
        BEGIN
            INSERT INTO dbo.TipoEquipo (Nombre) VALUES (@Nombre);
            SET @TipoEquipoId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.TipoEquipo WHERE TipoEquipoId = @TipoEquipoId)
                THROW 51224, 'El tipo de equipo no existe.', 1;

            UPDATE dbo.TipoEquipo SET Nombre = @Nombre WHERE TipoEquipoId = @TipoEquipoId;
        END

        COMMIT TRANSACTION;

        SELECT TipoEquipoId, Nombre FROM dbo.TipoEquipo WHERE TipoEquipoId = @TipoEquipoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   REPUESTOS
   ========================================================== */

/* ----------------------------------------------------------
   sp_Repuesto_Guardar
   @RepuestoId NULL = crear; con valor = editar.
   Al crear, si se indica @BodegaId, se crea su fila de inventario
   en esa bodega con existencia 0 y el @StockMinimo indicado
   (la existencia solo sube con una compra recibida).
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Repuesto_Guardar
    @UsuarioId               INT,
    @RepuestoId              INT           = NULL,
    @CategoriaId             INT,
    @Codigo                  VARCHAR(20),
    @Nombre                  VARCHAR(100),
    @Descripcion             VARCHAR(200)  = NULL,
    @PrecioCompraReferencia  DECIMAL(10,2),
    @PrecioVenta             DECIMAL(10,2),
    @BodegaId                INT           = NULL,
    @StockMinimo             INT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 51301, 'El usuario no está autorizado para modificar repuestos (rol BODEGA o ADMINISTRADOR).', 1;

        SET @Codigo = UPPER(LTRIM(RTRIM(@Codigo)));
        SET @Nombre = LTRIM(RTRIM(@Nombre));

        IF @Codigo IS NULL OR @Codigo = ''
            THROW 51302, 'El código del repuesto es obligatorio.', 1;

        IF @Nombre IS NULL OR @Nombre = ''
            THROW 51303, 'El nombre del repuesto es obligatorio.', 1;

        IF @PrecioCompraReferencia IS NULL OR @PrecioCompraReferencia < 0
           OR @PrecioVenta IS NULL OR @PrecioVenta < 0
            THROW 51304, 'Los precios no pueden ser negativos.', 1;

        IF @PrecioVenta < @PrecioCompraReferencia
            THROW 51305, 'El precio de venta no puede ser menor al precio de compra.', 1;

        IF ISNULL(@StockMinimo, 0) < 0
            THROW 51306, 'El stock mínimo no puede ser negativo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Categoria WHERE CategoriaId = @CategoriaId AND Activo = 1)
            THROW 51307, 'La categoría no existe o está inactiva.', 1;

        IF @RepuestoId IS NULL AND @BodegaId IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.Bodega WHERE BodegaId = @BodegaId AND Activo = 1)
            THROW 51308, 'La bodega no existe o está inactiva.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Repuesto WITH (UPDLOCK, HOLDLOCK)
                   WHERE Codigo = @Codigo AND (@RepuestoId IS NULL OR RepuestoId <> @RepuestoId))
            THROW 51309, 'Ya existe otro repuesto con ese código.', 1;

        IF @RepuestoId IS NULL
        BEGIN
            INSERT INTO dbo.Repuesto (CategoriaId, Codigo, Nombre, Descripcion, PrecioCompraReferencia, PrecioVenta)
            VALUES (@CategoriaId, @Codigo, @Nombre, NULLIF(LTRIM(RTRIM(@Descripcion)), ''),
                    @PrecioCompraReferencia, @PrecioVenta);
            SET @RepuestoId = SCOPE_IDENTITY();

            IF @BodegaId IS NOT NULL
                INSERT INTO dbo.Inventario (RepuestoId, BodegaId, Existencia, StockMinimo)
                VALUES (@RepuestoId, @BodegaId, 0, ISNULL(@StockMinimo, 0));
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Repuesto WHERE RepuestoId = @RepuestoId)
                THROW 51310, 'El repuesto no existe.', 1;

            -- Si cambia el precio, trg_Repuesto_AuditoriaPrecio lo registra
            UPDATE dbo.Repuesto
            SET CategoriaId            = @CategoriaId,
                Codigo                 = @Codigo,
                Nombre                 = @Nombre,
                Descripcion            = NULLIF(LTRIM(RTRIM(@Descripcion)), ''),
                PrecioCompraReferencia = @PrecioCompraReferencia,
                PrecioVenta            = @PrecioVenta
            WHERE RepuestoId = @RepuestoId;
        END

        COMMIT TRANSACTION;

        SELECT RepuestoId, Codigo, Nombre, PrecioCompraReferencia, PrecioVenta, Estado
        FROM dbo.Repuesto WHERE RepuestoId = @RepuestoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Repuesto_CambiarEstado
   @Estado: 'ACTIVO' o 'INACTIVO'.
   No se inactiva si está en una compra PENDIENTE.
   Para activarlo su categoría debe estar activa.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Repuesto_CambiarEstado
    @UsuarioId   INT,
    @RepuestoId  INT,
    @Estado      VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 51321, 'El usuario no está autorizado para modificar repuestos (rol BODEGA o ADMINISTRADOR).', 1;

        SET @Estado = UPPER(LTRIM(RTRIM(@Estado)));
        IF @Estado NOT IN ('ACTIVO', 'INACTIVO')
            THROW 51322, 'Estado inválido. Use ACTIVO o INACTIVO.', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Repuesto WITH (UPDLOCK, HOLDLOCK) WHERE RepuestoId = @RepuestoId)
            THROW 51323, 'El repuesto no existe.', 1;

        IF @Estado = 'INACTIVO' AND EXISTS (
               SELECT 1 FROM dbo.DetalleCompra dc
               JOIN dbo.Compra c ON c.CompraId = dc.CompraId
               WHERE dc.RepuestoId = @RepuestoId AND c.Estado = 'PENDIENTE')
            THROW 51324, 'El repuesto está en una compra pendiente. Reciba o anule la compra primero.', 1;

        IF @Estado = 'ACTIVO' AND EXISTS (
               SELECT 1 FROM dbo.Repuesto r
               JOIN dbo.Categoria c ON c.CategoriaId = r.CategoriaId
               WHERE r.RepuestoId = @RepuestoId AND c.Activo = 0)
            THROW 51325, 'La categoría del repuesto está inactiva. Actívela primero.', 1;

        UPDATE dbo.Repuesto SET Estado = @Estado WHERE RepuestoId = @RepuestoId;

        COMMIT TRANSACTION;

        SELECT RepuestoId, Codigo, Nombre, Estado FROM dbo.Repuesto WHERE RepuestoId = @RepuestoId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Inventario_GuardarMinimo
   Cambia el stock mínimo de un repuesto en una bodega.
   Si el repuesto aún no tiene fila en esa bodega, la crea con existencia 0.
   La existencia NO se toca aquí (solo compras y reparaciones la mueven).
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Inventario_GuardarMinimo
    @UsuarioId    INT,
    @RepuestoId   INT,
    @BodegaId     INT,
    @StockMinimo  INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 51401, 'El usuario no está autorizado para modificar el inventario (rol BODEGA o ADMINISTRADOR).', 1;

        IF @StockMinimo IS NULL OR @StockMinimo < 0
            THROW 51402, 'El stock mínimo no puede ser negativo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Repuesto WHERE RepuestoId = @RepuestoId AND Estado = 'ACTIVO')
            THROW 51403, 'El repuesto no existe o está inactivo.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Bodega WHERE BodegaId = @BodegaId AND Activo = 1)
            THROW 51404, 'La bodega no existe o está inactiva.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Inventario WITH (UPDLOCK, HOLDLOCK)
                   WHERE RepuestoId = @RepuestoId AND BodegaId = @BodegaId)
            UPDATE dbo.Inventario
            SET StockMinimo = @StockMinimo, FechaActualizacion = GETDATE()
            WHERE RepuestoId = @RepuestoId AND BodegaId = @BodegaId;
        ELSE
            INSERT INTO dbo.Inventario (RepuestoId, BodegaId, Existencia, StockMinimo)
            VALUES (@RepuestoId, @BodegaId, 0, @StockMinimo);

        COMMIT TRANSACTION;

        SELECT RepuestoId, BodegaId, Existencia, StockMinimo
        FROM dbo.Inventario
        WHERE RepuestoId = @RepuestoId AND BodegaId = @BodegaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   BODEGAS
   ========================================================== */

/* ----------------------------------------------------------
   sp_Bodega_Guardar
   @BodegaId NULL = crear; con valor = editar.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Bodega_Guardar
    @UsuarioId  INT,
    @BodegaId   INT          = NULL,
    @Nombre     VARCHAR(50),
    @Ubicacion  VARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51501, 'Solo el ADMINISTRADOR puede modificar las bodegas.', 1;

        SET @Nombre = LTRIM(RTRIM(@Nombre));
        IF @Nombre IS NULL OR @Nombre = ''
            THROW 51502, 'El nombre de la bodega es obligatorio.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Bodega WITH (UPDLOCK, HOLDLOCK)
                   WHERE Nombre = @Nombre AND (@BodegaId IS NULL OR BodegaId <> @BodegaId))
            THROW 51503, 'Ya existe una bodega con ese nombre.', 1;

        IF @BodegaId IS NULL
        BEGIN
            INSERT INTO dbo.Bodega (Nombre, Ubicacion)
            VALUES (@Nombre, NULLIF(LTRIM(RTRIM(@Ubicacion)), ''));
            SET @BodegaId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Bodega WHERE BodegaId = @BodegaId)
                THROW 51504, 'La bodega no existe.', 1;

            UPDATE dbo.Bodega
            SET Nombre = @Nombre, Ubicacion = NULLIF(LTRIM(RTRIM(@Ubicacion)), '')
            WHERE BodegaId = @BodegaId;
        END

        COMMIT TRANSACTION;

        SELECT BodegaId, Nombre, Ubicacion, Activo FROM dbo.Bodega WHERE BodegaId = @BodegaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Bodega_CambiarEstado
   No se inactiva si tiene existencias, compras pendientes
   o si es la última bodega activa.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Bodega_CambiarEstado
    @UsuarioId  INT,
    @BodegaId   INT,
    @Activo     BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51511, 'Solo el ADMINISTRADOR puede modificar las bodegas.', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Bodega WITH (UPDLOCK, HOLDLOCK) WHERE BodegaId = @BodegaId)
            THROW 51512, 'La bodega no existe.', 1;

        IF @Activo = 0
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Inventario WHERE BodegaId = @BodegaId AND Existencia > 0)
                THROW 51513, 'La bodega todavía tiene existencias. No se puede inactivar.', 1;

            IF EXISTS (SELECT 1 FROM dbo.Compra WHERE BodegaId = @BodegaId AND Estado = 'PENDIENTE')
                THROW 51514, 'La bodega tiene compras pendientes de recibir.', 1;

            IF NOT EXISTS (SELECT 1 FROM dbo.Bodega WHERE Activo = 1 AND BodegaId <> @BodegaId)
                THROW 51515, 'Debe quedar al menos una bodega activa.', 1;
        END

        UPDATE dbo.Bodega SET Activo = @Activo WHERE BodegaId = @BodegaId;

        COMMIT TRANSACTION;

        SELECT BodegaId, Nombre, Ubicacion, Activo FROM dbo.Bodega WHERE BodegaId = @BodegaId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   PROVEEDORES
   ========================================================== */

/* ----------------------------------------------------------
   sp_Proveedor_Guardar
   @ProveedorId NULL = crear; con valor = editar.
   NIT: dígitos con guion opcional y dígito verificador (0-9 o K).
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Proveedor_Guardar
    @UsuarioId    INT,
    @ProveedorId  INT          = NULL,
    @NIT          VARCHAR(15),
    @Nombre       VARCHAR(150),
    @Contacto     VARCHAR(100) = NULL,
    @Telefono     VARCHAR(15),
    @Correo       VARCHAR(100) = NULL,
    @Direccion    VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 51601, 'El usuario no está autorizado para modificar proveedores (rol BODEGA o ADMINISTRADOR).', 1;

        SET @NIT      = UPPER(REPLACE(LTRIM(RTRIM(@NIT)), ' ', ''));
        SET @Nombre   = LTRIM(RTRIM(@Nombre));
        SET @Telefono = LTRIM(RTRIM(@Telefono));
        SET @Correo   = NULLIF(LTRIM(RTRIM(@Correo)), '');

        IF @NIT IS NULL OR @NIT = '' OR @NIT LIKE '%[^0-9K-]%' OR @NIT NOT LIKE '%[0-9K]'
            THROW 51602, 'NIT inválido. Use solo números, guion y dígito verificador (ej. 1234567-8).', 1;

        IF @Nombre IS NULL OR @Nombre = ''
            THROW 51603, 'El nombre del proveedor es obligatorio.', 1;

        IF @Telefono IS NULL OR @Telefono = '' OR @Telefono LIKE '%[^0-9 +-]%'
            THROW 51604, 'Teléfono inválido.', 1;

        IF @Correo IS NOT NULL AND @Correo NOT LIKE '%_@_%._%'
            THROW 51605, 'Correo inválido.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Proveedor WITH (UPDLOCK, HOLDLOCK)
                   WHERE NIT = @NIT AND (@ProveedorId IS NULL OR ProveedorId <> @ProveedorId))
            THROW 51606, 'Ya existe otro proveedor con ese NIT.', 1;

        IF @ProveedorId IS NULL
        BEGIN
            INSERT INTO dbo.Proveedor (NIT, Nombre, Contacto, Telefono, Correo, Direccion)
            VALUES (@NIT, @Nombre, NULLIF(LTRIM(RTRIM(@Contacto)), ''), @Telefono, @Correo,
                    NULLIF(LTRIM(RTRIM(@Direccion)), ''));
            SET @ProveedorId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Proveedor WHERE ProveedorId = @ProveedorId)
                THROW 51607, 'El proveedor no existe.', 1;

            UPDATE dbo.Proveedor
            SET NIT       = @NIT,
                Nombre    = @Nombre,
                Contacto  = NULLIF(LTRIM(RTRIM(@Contacto)), ''),
                Telefono  = @Telefono,
                Correo    = @Correo,
                Direccion = NULLIF(LTRIM(RTRIM(@Direccion)), '')
            WHERE ProveedorId = @ProveedorId;
        END

        COMMIT TRANSACTION;

        SELECT ProveedorId, NIT, Nombre, Estado FROM dbo.Proveedor WHERE ProveedorId = @ProveedorId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Proveedor_CambiarEstado
   No se inactiva si tiene compras PENDIENTES.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Proveedor_CambiarEstado
    @UsuarioId    INT,
    @ProveedorId  INT,
    @Estado       VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'BODEGA') = 0
            THROW 51611, 'El usuario no está autorizado para modificar proveedores (rol BODEGA o ADMINISTRADOR).', 1;

        SET @Estado = UPPER(LTRIM(RTRIM(@Estado)));
        IF @Estado NOT IN ('ACTIVO', 'INACTIVO')
            THROW 51612, 'Estado inválido. Use ACTIVO o INACTIVO.', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Proveedor WITH (UPDLOCK, HOLDLOCK) WHERE ProveedorId = @ProveedorId)
            THROW 51613, 'El proveedor no existe.', 1;

        IF @Estado = 'INACTIVO' AND EXISTS (SELECT 1 FROM dbo.Compra
                                           WHERE ProveedorId = @ProveedorId AND Estado = 'PENDIENTE')
            THROW 51614, 'El proveedor tiene compras pendientes. Reciba o anule esas compras primero.', 1;

        UPDATE dbo.Proveedor SET Estado = @Estado WHERE ProveedorId = @ProveedorId;

        COMMIT TRANSACTION;

        SELECT ProveedorId, NIT, Nombre, Estado FROM dbo.Proveedor WHERE ProveedorId = @ProveedorId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   USUARIOS / EMPLEADOS
   ========================================================== */

/* ----------------------------------------------------------
   sp_Usuario_Guardar
   @UsuarioEditarId NULL = crear (la contraseña es obligatoria);
   con valor = editar datos y roles (la contraseña se ignora;
   para cambiarla se usa sp_Usuario_RestablecerContrasena).
   @Roles: Ids de rol separados por coma, ej. '2,5'.
   Regla: siempre debe quedar al menos un ADMINISTRADOR activo.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Usuario_Guardar
    @UsuarioId        INT,
    @UsuarioEditarId  INT          = NULL,
    @NombreUsuario    VARCHAR(30),
    @NombreCompleto   VARCHAR(100),
    @Correo           VARCHAR(100),
    @Telefono         VARCHAR(15)  = NULL,
    @Contrasena       VARCHAR(255) = NULL,
    @Roles            VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RolesNuevos TABLE (RolId INT PRIMARY KEY);

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51701, 'Solo el ADMINISTRADOR puede administrar usuarios.', 1;

        SET @NombreUsuario  = LOWER(LTRIM(RTRIM(@NombreUsuario)));
        SET @NombreCompleto = LTRIM(RTRIM(@NombreCompleto));
        SET @Correo         = LOWER(LTRIM(RTRIM(@Correo)));
        SET @Telefono       = NULLIF(LTRIM(RTRIM(@Telefono)), '');

        IF @NombreUsuario IS NULL OR LEN(@NombreUsuario) < 3 OR @NombreUsuario LIKE '%[^a-z0-9._]%'
            THROW 51702, 'Nombre de usuario inválido: mínimo 3 caracteres, solo letras, números, punto o guion bajo.', 1;

        IF @NombreCompleto IS NULL OR @NombreCompleto = ''
            THROW 51703, 'El nombre completo es obligatorio.', 1;

        IF @Correo IS NULL OR @Correo NOT LIKE '%_@_%._%'
            THROW 51704, 'Correo inválido.', 1;

        IF @Telefono IS NOT NULL AND @Telefono LIKE '%[^0-9 +-]%'
            THROW 51705, 'Teléfono inválido.', 1;

        IF @UsuarioEditarId IS NULL AND (@Contrasena IS NULL OR LEN(@Contrasena) < 8)
            THROW 51706, 'La contraseña debe tener al menos 8 caracteres.', 1;

        -- Roles enviados (solo Ids numéricos y roles activos)
        INSERT INTO @RolesNuevos (RolId)
        SELECT DISTINCT TRY_CAST(LTRIM(RTRIM(s.value)) AS INT)
        FROM STRING_SPLIT(ISNULL(@Roles, ''), ',') s
        WHERE TRY_CAST(LTRIM(RTRIM(s.value)) AS INT) IS NOT NULL;

        IF NOT EXISTS (SELECT 1 FROM @RolesNuevos)
            THROW 51707, 'Asigne al menos un rol.', 1;

        IF EXISTS (SELECT 1 FROM @RolesNuevos n
                   LEFT JOIN dbo.Rol r ON r.RolId = n.RolId AND r.Activo = 1
                   WHERE r.RolId IS NULL)
            THROW 51708, 'Uno de los roles no existe o está inactivo.', 1;

        BEGIN TRANSACTION;

        IF EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK)
                   WHERE NombreUsuario = @NombreUsuario
                     AND (@UsuarioEditarId IS NULL OR UsuarioId <> @UsuarioEditarId))
            THROW 51709, 'Ese nombre de usuario ya está en uso.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK)
                   WHERE Correo = @Correo
                     AND (@UsuarioEditarId IS NULL OR UsuarioId <> @UsuarioEditarId))
            THROW 51710, 'Ese correo ya está registrado en otro usuario.', 1;

        IF @UsuarioEditarId IS NULL
        BEGIN
            INSERT INTO dbo.Usuario (NombreUsuario, ContrasenaHash, NombreCompleto, Correo, Telefono)
            VALUES (@NombreUsuario,
                    UPPER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @Contrasena), 2)),
                    @NombreCompleto, @Correo, @Telefono);
            SET @UsuarioEditarId = SCOPE_IDENTITY();
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE UsuarioId = @UsuarioEditarId)
                THROW 51711, 'El usuario no existe.', 1;

            UPDATE dbo.Usuario
            SET NombreUsuario  = @NombreUsuario,
                NombreCompleto = @NombreCompleto,
                Correo         = @Correo,
                Telefono       = @Telefono
            WHERE UsuarioId = @UsuarioEditarId;

            -- Quita los roles que ya no tiene
            DELETE ur
            FROM dbo.UsuarioRol ur
            WHERE ur.UsuarioId = @UsuarioEditarId
              AND NOT EXISTS (SELECT 1 FROM @RolesNuevos n WHERE n.RolId = ur.RolId);
        END

        -- Agrega los roles nuevos (los que ya tenía conservan su fecha)
        INSERT INTO dbo.UsuarioRol (UsuarioId, RolId)
        SELECT @UsuarioEditarId, n.RolId
        FROM @RolesNuevos n
        WHERE NOT EXISTS (SELECT 1 FROM dbo.UsuarioRol ur
                          WHERE ur.UsuarioId = @UsuarioEditarId AND ur.RolId = n.RolId);

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario u
                       JOIN dbo.UsuarioRol ur ON ur.UsuarioId = u.UsuarioId
                       JOIN dbo.Rol r ON r.RolId = ur.RolId
                       WHERE u.Activo = 1 AND r.Nombre = 'ADMINISTRADOR')
            THROW 51712, 'Debe quedar al menos un ADMINISTRADOR activo.', 1;

        COMMIT TRANSACTION;

        SELECT UsuarioId, NombreUsuario, NombreCompleto, Correo, Telefono, Activo, Roles
        FROM dbo.vw_UsuarioLista WHERE UsuarioId = @UsuarioEditarId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Usuario_CambiarEstado
   Activa o inactiva un usuario (un usuario inactivo no puede
   iniciar sesión). Nadie se puede inactivar a sí mismo.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Usuario_CambiarEstado
    @UsuarioId        INT,
    @UsuarioEditarId  INT,
    @Activo           BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51721, 'Solo el ADMINISTRADOR puede administrar usuarios.', 1;

        IF @Activo = 0 AND @UsuarioEditarId = @UsuarioId
            THROW 51722, 'No puede inactivar su propio usuario.', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK) WHERE UsuarioId = @UsuarioEditarId)
            THROW 51723, 'El usuario no existe.', 1;

        UPDATE dbo.Usuario SET Activo = @Activo WHERE UsuarioId = @UsuarioEditarId;

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario u
                       JOIN dbo.UsuarioRol ur ON ur.UsuarioId = u.UsuarioId
                       JOIN dbo.Rol r ON r.RolId = ur.RolId
                       WHERE u.Activo = 1 AND r.Nombre = 'ADMINISTRADOR')
            THROW 51724, 'Debe quedar al menos un ADMINISTRADOR activo.', 1;

        COMMIT TRANSACTION;

        SELECT UsuarioId, NombreUsuario, NombreCompleto, Correo, Telefono, Activo, Roles
        FROM dbo.vw_UsuarioLista WHERE UsuarioId = @UsuarioEditarId;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Usuario_RestablecerContrasena
   El ADMINISTRADOR asigna una contraseña nueva (mínimo 8 caracteres).
   Se guarda solo el hash SHA2_256.
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Usuario_RestablecerContrasena
    @UsuarioId        INT,
    @UsuarioEditarId  INT,
    @Contrasena       VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF dbo.fn_UsuarioTieneRol(@UsuarioId, 'ADMINISTRADOR') = 0
            THROW 51731, 'Solo el ADMINISTRADOR puede administrar usuarios.', 1;

        IF @Contrasena IS NULL OR LEN(@Contrasena) < 8
            THROW 51732, 'La contraseña debe tener al menos 8 caracteres.', 1;

        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WITH (UPDLOCK, HOLDLOCK) WHERE UsuarioId = @UsuarioEditarId)
            THROW 51733, 'El usuario no existe.', 1;

        UPDATE dbo.Usuario
        SET ContrasenaHash = UPPER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', @Contrasena), 2))
        WHERE UsuarioId = @UsuarioEditarId;

        COMMIT TRANSACTION;

        SELECT @UsuarioEditarId AS UsuarioId, 'CONTRASEÑA ACTUALIZADA' AS Resultado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

/* ==========================================================
   CLIENTES Y EQUIPOS: volver a activar
   sp_Cliente_Eliminar y sp_Equipo_Eliminar (script 11) inactivan;
   estos dos procedimientos deshacen ese paso.
   ========================================================== */

/* ----------------------------------------------------------
   sp_Cliente_Activar
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Cliente_Activar
    @ClienteId INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Cliente WHERE ClienteId = @ClienteId)
            THROW 51801, 'El cliente no existe.', 1;

        UPDATE dbo.Cliente SET Estado = 'ACTIVO' WHERE ClienteId = @ClienteId;

        SELECT @ClienteId AS ClienteId, 'CLIENTE ACTIVADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

/* ----------------------------------------------------------
   sp_Equipo_Activar
   El dueño debe estar activo (un equipo activo de un cliente
   inactivo no podría recibir órdenes).
   ---------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Equipo_Activar
    @EquipoId INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM dbo.Equipo WHERE EquipoId = @EquipoId)
            THROW 51811, 'El equipo no existe.', 1;

        IF EXISTS (SELECT 1 FROM dbo.Equipo e
                   JOIN dbo.Cliente c ON c.ClienteId = e.ClienteId
                   WHERE e.EquipoId = @EquipoId AND c.Estado <> 'ACTIVO')
            THROW 51812, 'El cliente de este equipo está inactivo. Active primero al cliente.', 1;

        UPDATE dbo.Equipo SET Estado = 'ACTIVO' WHERE EquipoId = @EquipoId;

        SELECT @EquipoId AS EquipoId, 'EQUIPO ACTIVADO' AS Resultado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

-- Verificar que se crearon los procedimientos
SELECT name AS Procedimiento, create_date, modify_date
FROM sys.procedures
WHERE name IN ('sp_Categoria_Guardar', 'sp_Categoria_CambiarEstado', 'sp_TipoEquipo_Guardar',
               'sp_Repuesto_Guardar', 'sp_Repuesto_CambiarEstado', 'sp_Inventario_GuardarMinimo',
               'sp_Bodega_Guardar', 'sp_Bodega_CambiarEstado',
               'sp_Proveedor_Guardar', 'sp_Proveedor_CambiarEstado',
               'sp_Usuario_Guardar', 'sp_Usuario_CambiarEstado', 'sp_Usuario_RestablecerContrasena',
               'sp_Cliente_Activar', 'sp_Equipo_Activar')
ORDER BY name;
GO
GO

PRINT '>> Base TechCare creada completa.';
GO
