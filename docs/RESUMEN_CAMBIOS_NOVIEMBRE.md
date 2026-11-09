# Resumen de cambios – Noviembre 2026 (rama_kevin)

Guía para que todo el grupo entienda qué cambió después de la defensa y en qué orden trabajar.

---

## 1. Orden de trabajo

1. **Base de datos (nube):** ejecutar en orden los scripts de `database/Reglas_Adicionales/`: **13 al 18**. Todos se pueden repetir sin dañar datos. Ya están en la nube; solo hay que volver a ejecutar **14, 15 y 17** (tienen correcciones de la revisión).
2. **Cada integrante:** hacer *pull* de la rama y configurar el correo en sus *user-secrets* (sección 4).
3. **Probar el programa** con la lista de la sección 5 y anotar errores (pantalla, qué hizo, qué esperaba, qué pasó + captura).
4. Corregir lo que salga y luego hacer *merge* a `rama_Combinada`.

---

## 2. Carpeta `database`

| Carpeta | Contenido |
|---|---|
| `Reglas_Obligatorias/` | Scripts 00–12: las 27 tablas, procedimientos, triggers, funciones, vistas y reportes del enunciado (reglas **R01–R16**). `00_script_maestro.sql` los junta todos. |
| `Reglas_Adicionales/` | Scripts 13–18: mejoras del grupo (el enunciado permite agregar reglas, no quitarlas). |

> Si se vuelve a ejecutar el **script maestro**, después hay que ejecutar otra vez del **13 al 18**.

| Script | Qué agrega |
|---|---|
| 13 | Rol **CLIENTE**, `Usuario.ClienteId` (una cuenta por cliente), `DebeCambiarContrasena`, `sp_Cliente_CrearAcceso`, `sp_Cliente_MisOrdenes` |
| 14 | Crear cuenta desde el login, recuperar contraseña, cambiar contraseña, Mi cuenta; `sp_LoginUsuario` acepta **correo o usuario** |
| 15 | **Correo único** en Cliente (`UX_Cliente_Correo`); al editar el correo de un cliente también cambia el de su cuenta |
| 16 | El **Técnico** puede cancelar una orden (cliente no autorizó) |
| 17 | **Catálogo del proveedor** (`ProveedorRepuesto`): una compra solo acepta repuestos que el proveedor vende (trigger 51885) |
| 18 | **Quitar** actividad o repuesto en Taller (el repuesto vuelve a la bodega con una ENTRADA y su motivo) y **R14 completa** (no se borra en ReparacionRepuesto, ActividadReparacion, DetalleCompra, Entrega, Diagnostico ni Reparacion). Ya ejecutado en la nube. |

---

## 3. Cambios por pantalla

**Login**
- Entrar con **correo o usuario**; ojo para ver la contraseña.
- **Crear cuenta** (el cliente se registra solo) y **¿Olvidó su contraseña?** (llega una contraseña nueva por correo).
- Si se entra con una contraseña enviada por correo, el sistema **obliga a cambiarla**.

**Menú del usuario** (clic en el nombre, arriba a la derecha): Editar mis datos · Cambiar contraseña · Cerrar sesión.

**Clientes:** correo y dirección obligatorios. Al registrar un cliente se le crea su cuenta (rol CLIENTE) y recibe un correo de bienvenida con PDF.

**Cliente (rol CLIENTE):** solo ve **Mis órdenes** (estado, factura y saldo) y Mi cuenta.

**Órdenes:** los equipos con una orden abierta no se pueden elegir (regla 50108). El cambio de estado manual queda solo para casos especiales (iniciar diagnóstico o cancelar con motivo).

**Taller:** botón **"Cliente no autorizó: cancelar orden"** (con motivo).

**Inventario**
- **Proveedores y catálogo:** registrar proveedor nuevo con los repuestos que vende, o editar el catálogo de uno existente.
- **Nueva compra:** solo proveedores existentes; aparecen solo los repuestos de su catálogo con su precio de referencia; costo no editable.
- Existencias con orden por código y ayudas (!) en las columnas.

**Caja y entrega**
- Pago con **efectivo o tarjeta** (16 dígitos, nombre, vencimiento, CVV; solo se guarda marca y últimos 4 dígitos). Transferencia oculta.
- **Entregadas:** descargar el **comprobante en PDF** o enviarlo por correo al cliente (Caja y Admin).

**Usuarios (Admin)**
- Un empleado puede tener **varios roles** (ej. RECEPCION + CAJA) y sus accesos se suman.
- ADMINISTRADOR no se combina con otros roles; el admin no puede quitarse su propio rol.

**Correos:** se envían desde **techcare126@gmail.com** con el logo de TechCare.

---

## 4. Configuración que cada integrante debe hacer

En Visual Studio: clic derecho en el proyecto del backend → **Administrar secretos de usuario** → agregar al final (fuera de `ConnectionStrings`):

```json
"Correo:Remitente": "techcare126@gmail.com",
"Correo:ClaveAplicacion": "(se comparte por privado)"
```

La clave **nunca** va en el código ni en GitHub.

---

## 5. Lista de pruebas

| # | Rol | Prueba | Resultado esperado |
|---|---|---|---|
| 1 | Recepción | Crear cliente con correo propio | Llega correo de bienvenida con PDF |
| 2 | Cliente | Entrar con la contraseña del correo | Pide cambiarla; luego abre Mis órdenes |
| 3 | — | Login → Crear cuenta | Entra sin pedir cambio de contraseña |
| 4 | — | ¿Olvidó su contraseña? | Llega contraseña nueva; al entrar pide cambiarla |
| 5 | Recepción | Nueva orden para un equipo con orden abierta | El equipo aparece deshabilitado |
| 6 | Técnico | Orden en Esperando autorización → "Cliente no autorizó" | Orden CANCELADO con motivo en el historial |
| 7 | Bodega | Proveedores y catálogo → agregar un repuesto | Aparece al hacer Nueva compra con ese proveedor |
| 8 | Bodega | Nueva compra → recibir | Sube la existencia y hay movimiento de ENTRADA |
| 9 | Caja | Pagar con tarjeta | Referencia tipo VISA-9010-… |
| 10 | Caja | Entregadas → Descargar PDF / Enviar por correo | PDF correcto con logo |
| 11 | Admin | Dar RECEPCION + CAJA a un usuario y entrar con él | Ve Clientes, Equipos, Órdenes y Caja |
| 12 | Admin | Editar el correo de un cliente con cuenta | Puede iniciar sesión con el correo nuevo |

---

## 6. Correcciones de la revisión (5-nov)

- El script maestro se puede volver a ejecutar (quita la FK Usuario → Cliente antes de borrar).
- Recuperar contraseña: si el correo falla, se restaura la contraseña anterior.
- El dashboard de inicio solo lo ven empleados; `api/test` solo el Administrador.
- Catálogo: no borra repuestos inactivos, valida duplicados y el trigger revisa INSERT y UPDATE.
- PDF del comprobante: "-" cuando un pago no tiene referencia.

## 7. Pendientes

- **R12 – Pagos parciales:** hoy Caja cobra el saldo completo; el enunciado pide permitir pagos parciales. Decidir y ajustar.
- **Taller:** quitar una actividad o un repuesto antes de finalizar (devolviendo inventario), junto con:
  - R09: precio histórico al asignar el mismo repuesto dos veces.
  - R14: triggers "no eliminar" en ReparacionRepuesto, DetalleCompra, Entrega y otras tablas.
- **Detalle de factura y de orden:** vistas `vw_DetalleFactura` y `vw_DetalleOrden` (sin tablas nuevas, para respetar 3FN).
