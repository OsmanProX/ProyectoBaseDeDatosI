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
-- Permiso (script 08) apunta a Rol, por eso se borra primero
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
