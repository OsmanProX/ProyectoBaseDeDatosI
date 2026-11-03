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
