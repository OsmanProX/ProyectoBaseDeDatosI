USE db_acf53d_dbfinal2026;
GO

/* =====================================================================
   SISTEMA DE GESTION DE TALLER - SCRIPT DE CREACION DE TABLAS
   Diseño completo (28 tablas) segun "Hoja de Tablas y Entidades".
   NOTA: Las tablas Rol, Usuario, UsuarioRol, Cliente, TipoEquipo y
   Equipo ya existen en la BD; si el script se ejecuta completo,
   comentar o eliminar esas 6 tablas primero.
   Orden de creación respetando las dependencias (FK).
   ===================================================================== */

/* ---------------------------------------------------------------------
   1. SEGURIDAD: Roles y Usuarios
   --------------------------------------------------------------------- */

-- TABLA Rol
CREATE TABLE Rol (
    RolId       INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    Nombre      VARCHAR (30) NOT NULL UNIQUE,
    Descripcion VARCHAR (100) NULL,
    Activo      BIT NOT NULL DEFAULT 1,
    CHECK (Nombre IN ('ADMINISTRADOR','RECEPCION','TECNICO','BODEGA','CAJA'))
);

-- Tabla Usuario
CREATE TABLE Usuario (
    UsuarioId       INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    NombreUsuario   VARCHAR (30) NOT NULL UNIQUE,
    ContrasenaHash  VARCHAR (255) NOT NULL,               -- Hash, nunca texto plano
    NombreCompleto  VARCHAR (100) NOT NULL,
    Correo          VARCHAR (100) NOT NULL UNIQUE,
    Telefono        VARCHAR (15) NULL,
    Activo          BIT NOT NULL DEFAULT 1,
    FechaCreacion   DATETIME NOT NULL DEFAULT GETDATE()
);

-- Tabla UsuarioRol (N:M Usuario-Rol)
CREATE TABLE UsuarioRol (
    UsuarioId       INT NOT NULL,
    RolId           INT NOT NULL,
    FechaAsignacion DATETIME NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY (UsuarioId, RolId),
    FOREIGN KEY (UsuarioId) REFERENCES Usuario(UsuarioId),
    FOREIGN KEY (RolId)     REFERENCES Rol(RolId)
);

-- Roles iniciales (necesarios para el DEFAULT de OrdenServicio y reglas)
INSERT INTO Rol (Nombre, Descripcion) VALUES
    ('ADMINISTRADOR', 'Acceso total al sistema'),
    ('RECEPCION',     'Ingreso de equipos y órdenes de servicio'),
    ('TECNICO',       'Diagnóstico y reparación de equipos'),
    ('BODEGA',        'Gestión de inventario y compras'),
    ('CAJA',          'Facturación y cobros');

/* ---------------------------------------------------------------------
   2. CLIENTES Y EQUIPOS
   --------------------------------------------------------------------- */

-- Tabla Cliente
CREATE TABLE Cliente (
    ClienteId         INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    TipoCliente       VARCHAR (15) NOT NULL,
    NombreRazonSocial VARCHAR (150) NOT NULL,
    NIT               VARCHAR (15) NOT NULL,
    Telefono          VARCHAR (15) NOT NULL,
    Correo            VARCHAR (100) NULL,
    Direccion         VARCHAR (200) NULL,
    Estado            VARCHAR (10) NOT NULL DEFAULT 'ACTIVO',
    FechaRegistro     DATETIME NOT NULL DEFAULT GETDATE(),
    CHECK (TipoCliente IN ('INDIVIDUAL','EMPRESARIAL')),
    CHECK (Estado IN ('ACTIVO','INACTIVO'))
);

-- NIT único filtrado: permite varios 'CF' pero los demás deben ser únicos
CREATE UNIQUE INDEX UX_Cliente_NIT
    ON Cliente (NIT)
    WHERE NIT <> 'CF';

-- Tabla TipoEquipo
CREATE TABLE TipoEquipo (
    TipoEquipoId INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    Nombre       VARCHAR (50) NOT NULL UNIQUE,
    CHECK (Nombre IN ('Laptop','Desktop','Impresora','Red'))
);

INSERT INTO TipoEquipo (Nombre) VALUES
    ('Laptop'), ('Desktop'), ('Impresora'), ('Red');

-- Tabla Equipo
CREATE TABLE Equipo (
    EquipoId     INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    ClienteId    INT NOT NULL,
    TipoEquipoId INT NOT NULL,
    Marca        VARCHAR (50) NOT NULL,
    Modelo       VARCHAR (50) NOT NULL,
    NumeroSerie  VARCHAR (50) NOT NULL UNIQUE,             -- Búsqueda del historial
    Descripcion  VARCHAR (200) NULL,
    Estado       VARCHAR (10) NOT NULL DEFAULT 'ACTIVO',
    FOREIGN KEY (ClienteId)    REFERENCES Cliente(ClienteId),
    FOREIGN KEY (TipoEquipoId) REFERENCES TipoEquipo(TipoEquipoId),
    CHECK (Estado IN ('ACTIVO','INACTIVO'))
);

/* ---------------------------------------------------------------------
   3. ÓRDENES DE SERVICIO
   --------------------------------------------------------------------- */

-- Tabla EstadoOrden (catálogo, sin IDENTITY: IDs fijos)
CREATE TABLE EstadoOrden (
    EstadoOrdenId INT PRIMARY KEY NOT NULL,
    Codigo        VARCHAR (30) NOT NULL UNIQUE,
    Descripcion   VARCHAR (100) NULL,
    CHECK (Codigo IN ('RECIBIDO','DIAGNOSTICO','ESPERANDO_AUTORIZACION',
                      'REPARACION','LISTO','ENTREGADO','CANCELADO'))
);

INSERT INTO EstadoOrden (EstadoOrdenId, Codigo, Descripcion) VALUES
    (1, 'RECIBIDO',               'Equipo ingresado al taller'),
    (2, 'DIAGNOSTICO',            'En revisión técnica'),
    (3, 'ESPERANDO_AUTORIZACION', 'Pendiente de aprobación del cliente'),
    (4, 'REPARACION',             'En reparación'),
    (5, 'LISTO',                  'Reparado, listo para entrega'),
    (6, 'ENTREGADO',              'Entregado al cliente'),
    (7, 'CANCELADO',              'Orden cancelada');

-- Tabla OrdenServicio
CREATE TABLE OrdenServicio (
    OrdenId             INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    NumeroOrden         VARCHAR (15) NOT NULL UNIQUE,      -- Ej: OS-2026-0001
    ClienteId           INT NOT NULL,                      -- Snapshot del cliente al ingresar
    EquipoId            INT NOT NULL,
    UsuarioRecepcionId  INT NOT NULL,
    FechaIngreso        DATETIME NOT NULL DEFAULT GETDATE(),
    ProblemaReportado   VARCHAR (500) NOT NULL,
    Prioridad           VARCHAR (10) NOT NULL DEFAULT 'MEDIA',
    EstadoOrdenId       INT NOT NULL DEFAULT 1,            -- 1 = RECIBIDO
    FechaEstimada       DATE NULL,
    Observaciones       VARCHAR (500) NULL,
    FOREIGN KEY (ClienteId)          REFERENCES Cliente(ClienteId),
    FOREIGN KEY (EquipoId)           REFERENCES Equipo(EquipoId),
    FOREIGN KEY (UsuarioRecepcionId) REFERENCES Usuario(UsuarioId),
    FOREIGN KEY (EstadoOrdenId)      REFERENCES EstadoOrden(EstadoOrdenId),
    CHECK (Prioridad IN ('BAJA','MEDIA','ALTA','URGENTE'))
);

-- Tabla HistorialEstadoOrden (R05: cada cambio de estado queda registrado)
CREATE TABLE HistorialEstadoOrden (
    HistorialId       INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    OrdenId           INT NOT NULL,
    EstadoAnteriorId  INT NULL,                            -- NULL en el primer registro
    EstadoNuevoId     INT NOT NULL,
    FechaCambio       DATETIME NOT NULL DEFAULT GETDATE(),
    UsuarioId         INT NOT NULL,
    Observacion       VARCHAR (300) NULL,
    FOREIGN KEY (OrdenId)          REFERENCES OrdenServicio(OrdenId),
    FOREIGN KEY (EstadoAnteriorId) REFERENCES EstadoOrden(EstadoOrdenId),
    FOREIGN KEY (EstadoNuevoId)    REFERENCES EstadoOrden(EstadoOrdenId),
    FOREIGN KEY (UsuarioId)        REFERENCES Usuario(UsuarioId)
);

-- Tabla Entrega (una entrega por orden)
CREATE TABLE Entrega (
    EntregaId         INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    OrdenId           INT NOT NULL UNIQUE,
    UsuarioEntregaId  INT NOT NULL,
    NombreRecibe      VARCHAR (100) NOT NULL,
    FechaEntrega      DATETIME NOT NULL DEFAULT GETDATE(),
    Observaciones     VARCHAR (300) NULL,
    FOREIGN KEY (OrdenId)          REFERENCES OrdenServicio(OrdenId),
    FOREIGN KEY (UsuarioEntregaId) REFERENCES Usuario(UsuarioId)
);

/* ---------------------------------------------------------------------
   4. DIAGNÓSTICO Y REPARACIÓN
   --------------------------------------------------------------------- */

-- Tabla Diagnostico (R01: un diagnóstico por orden)
CREATE TABLE Diagnostico (
    DiagnosticoId           INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    OrdenId                 INT NOT NULL UNIQUE,
    TecnicoId               INT NOT NULL,                  -- R03: usuario con rol TECNICO
    FechaDiagnostico        DATETIME NOT NULL DEFAULT GETDATE(),
    Descripcion             VARCHAR (500) NOT NULL,
    CostoManoObraEstimado   DECIMAL (10,2) NOT NULL DEFAULT 0.0,
    Observaciones           VARCHAR (300) NULL,
    FOREIGN KEY (OrdenId)   REFERENCES OrdenServicio(OrdenId),
    FOREIGN KEY (TecnicoId) REFERENCES Usuario(UsuarioId),
    CHECK (CostoManoObraEstimado >= 0)
);

-- Tabla Reparacion (R04: no hay reparación sin diagnóstico previo)
CREATE TABLE Reparacion (
    ReparacionId        INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    DiagnosticoId       INT NOT NULL UNIQUE,
    TecnicoId           INT NOT NULL,
    FechaInicio         DATETIME NOT NULL DEFAULT GETDATE(),
    FechaFin            DATETIME NULL,                     -- NULL mientras está en proceso
    DescripcionTrabajo  VARCHAR (500) NULL,
    CostoManoObra       DECIMAL (10,2) NOT NULL DEFAULT 0.0,
    Estado              VARCHAR (12) NOT NULL DEFAULT 'EN_PROCESO',
    FOREIGN KEY (DiagnosticoId) REFERENCES Diagnostico(DiagnosticoId),
    FOREIGN KEY (TecnicoId)     REFERENCES Usuario(UsuarioId),
    CHECK (FechaFin IS NULL OR FechaFin >= FechaInicio),
    CHECK (CostoManoObra >= 0),
    CHECK (Estado IN ('EN_PROCESO','FINALIZADA','CANCELADA'))
);

-- Tabla ActividadReparacion (pasos dentro de cada reparación)
CREATE TABLE ActividadReparacion (
    ReparacionId     INT NOT NULL,
    NumeroActividad  INT NOT NULL,                         -- 1, 2, 3... dentro de cada reparación
    Descripcion      VARCHAR (300) NOT NULL,
    HorasTrabajadas  DECIMAL (5,2) NULL,
    FechaRegistro    DATETIME NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY (ReparacionId, NumeroActividad),
    FOREIGN KEY (ReparacionId) REFERENCES Reparacion(ReparacionId),
    CHECK (NumeroActividad > 0),
    CHECK (HorasTrabajadas IS NULL OR HorasTrabajadas > 0)
);

/* ---------------------------------------------------------------------
   5. CATÁLOGOS DE INVENTARIO
   --------------------------------------------------------------------- */

-- Tabla Categoria
CREATE TABLE Categoria (
    CategoriaId  INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    Nombre       VARCHAR (50) NOT NULL UNIQUE,
    Descripcion  VARCHAR (150) NULL,
    Activo       BIT NOT NULL DEFAULT 1
);

-- Tabla Repuesto
CREATE TABLE Repuesto (
    RepuestoId              INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    CategoriaId             INT NOT NULL,
    Codigo                  VARCHAR (20) NOT NULL UNIQUE,
    Nombre                  VARCHAR (100) NOT NULL,
    Descripcion             VARCHAR (200) NULL,
    PrecioCompraReferencia  DECIMAL (10,2) NOT NULL DEFAULT 0.0,
    PrecioVenta             DECIMAL (10,2) NOT NULL DEFAULT 0.0,
    Estado                  VARCHAR (10) NOT NULL DEFAULT 'ACTIVO',
    FOREIGN KEY (CategoriaId) REFERENCES Categoria(CategoriaId),
    CHECK (PrecioCompraReferencia >= 0),
    CHECK (PrecioVenta >= 0),
    CHECK (Estado IN ('ACTIVO','INACTIVO'))
);

-- Tabla Bodega
CREATE TABLE Bodega (
    BodegaId    INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    Nombre      VARCHAR (50) NOT NULL UNIQUE,
    Ubicacion   VARCHAR (150) NULL,
    Activo      BIT NOT NULL DEFAULT 1
);

-- Tabla Inventario (N:M Repuesto-Bodega, R10: existencia nunca negativa)
CREATE TABLE Inventario (
    RepuestoId         INT NOT NULL,
    BodegaId           INT NOT NULL,
    Existencia         INT NOT NULL DEFAULT 0,
    StockMinimo        INT NOT NULL DEFAULT 0,
    FechaActualizacion DATETIME NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY (RepuestoId, BodegaId),
    FOREIGN KEY (RepuestoId) REFERENCES Repuesto(RepuestoId),
    FOREIGN KEY (BodegaId)   REFERENCES Bodega(BodegaId),
    CHECK (Existencia >= 0),
    CHECK (StockMinimo >= 0)
);

-- Reparación-Repuesto (N:M con precios históricos R09, FK a Inventario R06)
CREATE TABLE ReparacionRepuesto (
    ReparacionId         INT NOT NULL,
    RepuestoId           INT NOT NULL,
    BodegaId             INT NOT NULL,                     -- Bodega de donde sale el repuesto
    Cantidad             INT NOT NULL,
    CostoUnitario        DECIMAL (10,2) NOT NULL,          -- Histórico (R09)
    PrecioVentaUnitario  DECIMAL (10,2) NOT NULL,          -- Histórico (R09), se usa en factura
    FechaRegistro        DATETIME NOT NULL DEFAULT GETDATE(),
    UsuarioId            INT NOT NULL,                     -- Quién asignó el repuesto
    PRIMARY KEY (ReparacionId, RepuestoId, BodegaId),
    FOREIGN KEY (ReparacionId)          REFERENCES Reparacion(ReparacionId),
    FOREIGN KEY (RepuestoId, BodegaId)  REFERENCES Inventario(RepuestoId, BodegaId), -- R06
    FOREIGN KEY (UsuarioId)             REFERENCES Usuario(UsuarioId),
    CHECK (Cantidad > 0),
    CHECK (CostoUnitario >= 0),
    CHECK (PrecioVentaUnitario >= 0)
);

-- Tabla AuditoriaPrecio (la llena un trigger al cambiar precios del Repuesto)
CREATE TABLE AuditoriaPrecio (
    AuditoriaId           INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    RepuestoId            INT NOT NULL,
    PrecioCompraAnterior  DECIMAL (10,2) NULL,
    PrecioCompraNuevo     DECIMAL (10,2) NULL,
    PrecioVentaAnterior   DECIMAL (10,2) NULL,
    PrecioVentaNuevo      DECIMAL (10,2) NULL,
    FechaCambio           DATETIME NOT NULL DEFAULT GETDATE(),
    UsuarioBD             VARCHAR (100) NOT NULL DEFAULT SUSER_SNAME(),
    FOREIGN KEY (RepuestoId) REFERENCES Repuesto(RepuestoId)
);

/* ---------------------------------------------------------------------
   6. PROVEEDORES Y COMPRAS
   --------------------------------------------------------------------- */

-- Tabla Proveedor
CREATE TABLE Proveedor (
    ProveedorId  INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    NIT          VARCHAR (15) NOT NULL UNIQUE,
    Nombre       VARCHAR (150) NOT NULL,
    Contacto     VARCHAR (100) NULL,                       -- Persona de contacto
    Telefono     VARCHAR (15) NOT NULL,
    Correo       VARCHAR (100) NULL,
    Direccion    VARCHAR (200) NULL,
    Estado       VARCHAR (10) NOT NULL DEFAULT 'ACTIVO',
    CHECK (Estado IN ('ACTIVO','INACTIVO'))
);

-- Tabla ProveedorRepuesto (N:M: qué proveedor vende qué repuesto)
CREATE TABLE ProveedorRepuesto (
    ProveedorId       INT NOT NULL,
    RepuestoId        INT NOT NULL,
    CodigoProveedor   VARCHAR (30) NULL,                   -- Código que usa el proveedor
    PrecioReferencia  DECIMAL (10,2) NULL,
    PRIMARY KEY (ProveedorId, RepuestoId),
    FOREIGN KEY (ProveedorId) REFERENCES Proveedor(ProveedorId),
    FOREIGN KEY (RepuestoId)  REFERENCES Repuesto(RepuestoId),
    CHECK (PrecioReferencia IS NULL OR PrecioReferencia >= 0)
);

-- Tabla Compra (R08: al recibir se sube inventario en una transacción)
CREATE TABLE Compra (
    CompraId        INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    NumeroCompra    VARCHAR (20) NOT NULL UNIQUE,          -- Ej: OC-2026-0001
    ProveedorId     INT NOT NULL,
    BodegaId        INT NOT NULL,                          -- Bodega donde se recibe
    FechaCompra     DATETIME NOT NULL DEFAULT GETDATE(),
    FechaRecepcion  DATETIME NULL,                         -- NULL mientras está PENDIENTE
    Estado          VARCHAR (10) NOT NULL DEFAULT 'PENDIENTE',
    UsuarioId       INT NOT NULL,                          -- Usuario de Bodega
    Observaciones   VARCHAR (300) NULL,                    -- El total se calcula del detalle (3FN)
    FOREIGN KEY (ProveedorId) REFERENCES Proveedor(ProveedorId),
    FOREIGN KEY (BodegaId)    REFERENCES Bodega(BodegaId),
    FOREIGN KEY (UsuarioId)   REFERENCES Usuario(UsuarioId),
    CHECK (Estado IN ('PENDIENTE','RECIBIDA','ANULADA'))
);

-- Tabla DetalleCompra (N:M Compra-Repuesto con costo histórico R09)
CREATE TABLE DetalleCompra (
    CompraId      INT NOT NULL,
    RepuestoId    INT NOT NULL,
    Cantidad      INT NOT NULL,
    CostoUnitario DECIMAL (10,2) NOT NULL,                 -- Histórico (R09)
    PRIMARY KEY (CompraId, RepuestoId),
    FOREIGN KEY (CompraId)   REFERENCES Compra(CompraId),
    FOREIGN KEY (RepuestoId) REFERENCES Repuesto(RepuestoId),
    CHECK (Cantidad > 0),
    CHECK (CostoUnitario >= 0)
);

-- Tabla MovimientoInventario (entrada/salida con documento de origen)
CREATE TABLE MovimientoInventario (
    MovimientoId         INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    RepuestoId           INT NOT NULL,
    BodegaId             INT NOT NULL,
    TipoMovimiento       VARCHAR (10) NOT NULL,
    Cantidad             INT NOT NULL,
    ExistenciaResultante INT NOT NULL,
    CompraId             INT NULL,                         -- Origen si es ENTRADA por compra
    ReparacionId         INT NULL,                         -- Origen si es SALIDA por reparación
    FechaMovimiento      DATETIME NOT NULL DEFAULT GETDATE(),
    UsuarioId            INT NOT NULL,
    Observacion          VARCHAR (200) NULL,
    FOREIGN KEY (RepuestoId, BodegaId) REFERENCES Inventario(RepuestoId, BodegaId),
    FOREIGN KEY (CompraId)             REFERENCES Compra(CompraId),
    FOREIGN KEY (ReparacionId)         REFERENCES Reparacion(ReparacionId),
    FOREIGN KEY (UsuarioId)            REFERENCES Usuario(UsuarioId),
    CHECK (TipoMovimiento IN ('ENTRADA','SALIDA')),
    CHECK (Cantidad > 0),
    CHECK (ExistenciaResultante >= 0),
    -- Exactamente uno: CompraId o ReparacionId
    CHECK ((CompraId IS NOT NULL AND ReparacionId IS NULL)
        OR (CompraId IS NULL AND ReparacionId IS NOT NULL))
);

/* ---------------------------------------------------------------------
   7. FACTURACIÓN Y PAGOS
   --------------------------------------------------------------------- */

-- Tabla MetodoPago
CREATE TABLE MetodoPago (
    MetodoPagoId INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    Nombre       VARCHAR (30) NOT NULL UNIQUE,
    Activo       BIT NOT NULL DEFAULT 1,
    CHECK (Nombre IN ('EFECTIVO','TARJETA','TRANSFERENCIA'))
);

INSERT INTO MetodoPago (Nombre) VALUES
    ('EFECTIVO'), ('TARJETA'), ('TRANSFERENCIA');

-- Tabla Factura (R11: máximo una factura por orden; IVA 12%)
CREATE TABLE Factura (
    FacturaId         INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    NumeroFactura     VARCHAR (20) NOT NULL UNIQUE,
    OrdenId           INT NOT NULL UNIQUE,                 -- R11
    NITFacturacion    VARCHAR (15) NOT NULL,
    NombreFacturacion VARCHAR (150) NOT NULL,
    FechaEmision      DATETIME NOT NULL DEFAULT GETDATE(),
    TotalManoObra     DECIMAL (10,2) NOT NULL DEFAULT 0.0, -- Valor histórico (R09)
    TotalRepuestos    DECIMAL (10,2) NOT NULL DEFAULT 0.0, -- Valor histórico (R09)
    Subtotal          DECIMAL (10,2) NOT NULL DEFAULT 0.0,
    Impuesto          DECIMAL (10,2) NOT NULL DEFAULT 0.0, -- IVA 12%
    Total             DECIMAL (10,2) NOT NULL,             -- Saldo se calcula: fn_SaldoFactura (R13)
    Estado            VARCHAR (10) NOT NULL DEFAULT 'EMITIDA',
    UsuarioId         INT NOT NULL,                        -- Usuario de Caja
    FOREIGN KEY (OrdenId)    REFERENCES OrdenServicio(OrdenId),
    FOREIGN KEY (UsuarioId)  REFERENCES Usuario(UsuarioId),
    CHECK (TotalManoObra >= 0),
    CHECK (TotalRepuestos >= 0),
    CHECK (Subtotal >= 0),
    CHECK (Impuesto >= 0),
    CHECK (Total = Subtotal + Impuesto),
    CHECK (Estado IN ('EMITIDA','PAGADA','ANULADA'))
);

-- Tabla Pago (R12: varios pagos por factura; R14: se anula, no se borra)
CREATE TABLE Pago (
    PagoId       INT IDENTITY (1,1) PRIMARY KEY NOT NULL,
    FacturaId    INT NOT NULL,
    MetodoPagoId INT NOT NULL,
    Monto        DECIMAL (10,2) NOT NULL,
    FechaPago    DATETIME NOT NULL DEFAULT GETDATE(),
    Referencia   VARCHAR (50) NULL,                        -- No. de boleta o voucher
    Estado       VARCHAR (10) NOT NULL DEFAULT 'APLICADO',
    UsuarioId    INT NOT NULL,                             -- Quién cobró
    FOREIGN KEY (FacturaId)    REFERENCES Factura(FacturaId),
    FOREIGN KEY (MetodoPagoId) REFERENCES MetodoPago(MetodoPagoId),
    FOREIGN KEY (UsuarioId)    REFERENCES Usuario(UsuarioId),
    CHECK (Monto > 0),
    CHECK (Estado IN ('APLICADO','ANULADO'))
);
GO

/* =====================================================================
   TRIGGERS
   ===================================================================== */

-- TRG_AuditoriaPrecio: registra cambios de precio del catálogo de repuestos
CREATE OR ALTER TRIGGER TRG_AuditoriaPrecio
ON Repuesto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AuditoriaPrecio (
        RepuestoId,
        PrecioCompraAnterior, PrecioCompraNuevo,
        PrecioVentaAnterior,  PrecioVentaNuevo
    )
    SELECT
        i.RepuestoId,
        d.PrecioCompraReferencia, i.PrecioCompraReferencia,
        d.PrecioVenta,            i.PrecioVenta
    FROM inserted i
    INNER JOIN deleted d ON d.RepetuestoId = i.RepetuestoId
    WHERE i.PrecioCompraReferencia <> d.PrecioCompraReferencia
       OR i.PrecioVenta            <> d.PrecioVenta;
END;
GO
