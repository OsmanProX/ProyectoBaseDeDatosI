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
