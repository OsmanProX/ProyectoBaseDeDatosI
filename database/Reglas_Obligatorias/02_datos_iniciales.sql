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
