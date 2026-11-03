<script setup lang="ts">
// Semana 3 — Inventario y compras: existencias por bodega, compras a proveedores
// (registrar, recibir, anular) y movimientos de entrada/salida.
// Acceso: ADMINISTRADOR y BODEGA (menú, router y policy "Inventario" del backend).
import { computed, onMounted, reactive, ref, watch } from 'vue'
import {
  inventarioApi,
  type Stock, type Bodega, type Proveedor, type RepuestoCatalogo,
  type Compra, type DetalleCompra, type Movimiento, type EstadoCompra, type CatalogoProveedor,
} from '../api/inventario'
import { mantenimientoApi } from '../../mantenimientos/api/mantenimientos'
import BuscadorSelect from '../components/BuscadorSelect.vue'
import InfoTip from '@/shared/components/InfoTip.vue'

const moneda = (n: number | null | undefined) =>
  (n ?? 0).toLocaleString('es-GT', { style: 'currency', currency: 'GTQ' })
const fechaHora = (iso: string | null) =>
  iso ? new Date(iso).toLocaleString('es-GT', { dateStyle: 'short', timeStyle: 'short' }) : '—'

type Pestana = 'stock' | 'compras' | 'movimientos'
const pestana = ref<Pestana>('stock')
const aviso = ref('')

function mostrarAviso(texto: string) {
  aviso.value = texto
  setTimeout(() => (aviso.value = ''), 4000)
}

// ---------- catálogos ----------
const bodegas = ref<Bodega[]>([])
const proveedores = ref<Proveedor[]>([])
const catalogo = ref<RepuestoCatalogo[]>([])
const errorCatalogos = ref('')

// ---------- stock ----------
const stock = ref<Stock[]>([])
const cargandoStock = ref(false)
const errorStock = ref('')
const fStock = reactive({ bodegaId: 0, soloBajo: false, buscar: '' })

async function cargarStock() {
  cargandoStock.value = true
  errorStock.value = ''
  try {
    stock.value = await inventarioApi.stock(fStock.bodegaId || undefined, fStock.soloBajo)
  } catch (e) {
    errorStock.value = (e as Error).message
  } finally {
    cargandoStock.value = false
  }
}

const ordenStock = ref<'asc' | 'desc'>('asc')
const stockVisible = computed(() => {
  const t = fStock.buscar.trim().toLowerCase()
  const dir = ordenStock.value === 'desc' ? -1 : 1
  return stock.value
    .filter((s) => !t || [s.codigo, s.repuesto, s.categoria].some((v) => v.toLowerCase().includes(t)))
    .sort((a, b) => dir * (a.codigo.localeCompare(b.codigo, 'es', { numeric: true }) || a.bodega.localeCompare(b.bodega, 'es')))
})
const valorTotal = computed(() => stockVisible.value.reduce((s, x) => s + x.valorInventario, 0))
const bajoMinimo = computed(() => stockVisible.value.filter((x) => x.estadoStock !== 'OK').length)

watch(() => [fStock.bodegaId, fStock.soloBajo], cargarStock)

// ---------- compras ----------
const compras = ref<Compra[]>([])
const cargandoCompras = ref(false)
const errorCompras = ref('')
const filtroCompra = ref<EstadoCompra | ''>('')
const abierta = ref<number | null>(null)
const detalleAbierto = ref<DetalleCompra[]>([])
const errorDetalle = ref('')

async function cargarCompras() {
  cargandoCompras.value = true
  errorCompras.value = ''
  try {
    compras.value = await inventarioApi.compras(filtroCompra.value)
  } catch (e) {
    errorCompras.value = (e as Error).message
  } finally {
    cargandoCompras.value = false
  }
}
watch(filtroCompra, cargarCompras)

async function verDetalle(c: Compra) {
  if (abierta.value === c.compraId) return void (abierta.value = null)
  abierta.value = c.compraId
  detalleAbierto.value = []
  errorDetalle.value = ''
  try {
    detalleAbierto.value = await inventarioApi.detalleCompra(c.compraId)
  } catch (e) {
    errorDetalle.value = (e as Error).message
  }
}

// ---------- movimientos ----------
const movimientos = ref<Movimiento[]>([])
const cargandoMov = ref(false)
const errorMov = ref('')
const fMov = reactive({ bodegaId: 0, tipo: '' })

async function cargarMovimientos() {
  cargandoMov.value = true
  errorMov.value = ''
  try {
    movimientos.value = await inventarioApi.movimientos(fMov.bodegaId || undefined, fMov.tipo || undefined)
  } catch (e) {
    errorMov.value = (e as Error).message
  } finally {
    cargandoMov.value = false
  }
}
watch(() => [fMov.bodegaId, fMov.tipo], cargarMovimientos)

// Cada pestaña se carga la primera vez que se abre
const cargadas = new Set<Pestana>()
function cargarPestana(p: Pestana) {
  cargadas.add(p)
  if (p === 'stock') return cargarStock()
  if (p === 'compras') return cargarCompras()
  return cargarMovimientos()
}
watch(pestana, (p) => { if (!cargadas.has(p)) cargarPestana(p) })

onMounted(async () => {
  try {
    ;[bodegas.value, proveedores.value, catalogo.value] = await Promise.all([
      inventarioApi.bodegas(), inventarioApi.proveedores(), inventarioApi.repuestos(),
    ])
  } catch (e) {
    errorCatalogos.value = (e as Error).message
  }
  await cargarPestana(pestana.value)
})

// Después de recibir una compra cambian el stock y los movimientos
function invalidarInventario() {
  cargadas.delete('stock')
  cargadas.delete('movimientos')
}

// ---------- nueva compra ----------
const dlgCompra = ref<HTMLDialogElement>()
const guardando = ref(false)
const errorForm = ref('')
const nueva = reactive({
  proveedorId: 0,
  bodegaId: 0,
  observaciones: '',
  lineas: [] as { repuestoId: number; cantidad: number; costoUnitario: number }[],
})

// Opciones para los selectores con búsqueda
const opcProveedores = computed(() =>
  proveedores.value.map((p) => ({ id: p.proveedorId, texto: `${p.nombre} — NIT ${p.nit}` })))
// Solo los repuestos que vende el proveedor elegido (su catálogo), ordenados por código
const catalogoCompra = ref<CatalogoProveedor[]>([])
const cargandoCatalogo = ref(false)
const opcRepuestos = computed(() =>
  catalogoCompra.value.map((r) => ({ id: r.repuestoId, texto: `${r.codigo} · ${r.nombre}` })))

// Al cambiar de proveedor se carga su catálogo y se limpian las líneas
async function cargarCatalogoCompra(proveedorId: number) {
  catalogoCompra.value = []
  if (!proveedorId) return
  cargandoCatalogo.value = true
  try {
    catalogoCompra.value = await inventarioApi.catalogoProveedor(proveedorId)
  } catch (e) {
    errorForm.value = (e as Error).message
  } finally {
    cargandoCatalogo.value = false
  }
}
watch(() => nueva.proveedorId, (id) => {
  nueva.lineas = [{ repuestoId: 0, cantidad: 1, costoUnitario: 0 }]
  cargarCatalogoCompra(id)
})

// En cada línea no aparecen los repuestos ya elegidos en otras líneas
function opcionesLinea(i: number) {
  const usados = new Set(nueva.lineas.filter((_, j) => j !== i).map((l) => l.repuestoId))
  return opcRepuestos.value.filter((o) => !usados.has(o.id))
}

function abrirNueva() {
  Object.assign(nueva, { proveedorId: 0, bodegaId: bodegas.value[0]?.bodegaId ?? 0, observaciones: '', lineas: [] })
  agregarLinea()
  errorForm.value = ''
  dlgCompra.value?.showModal()
}

function agregarLinea() {
  nueva.lineas.push({ repuestoId: 0, cantidad: 1, costoUnitario: 0 })
}

// Al elegir el repuesto se usa el precio de referencia de ese proveedor
function elegirRepuesto(i: number) {
  const linea = nueva.lineas[i]
  const r = catalogoCompra.value.find((x) => x.repuestoId === linea?.repuestoId)
  if (linea && r) linea.costoUnitario = r.precioReferencia
}

// ---------- Proveedores y catálogo (aparte de la compra) ----------
// Nuevo proveedor con su catálogo, o editar el catálogo de uno existente (ProveedorRepuesto)
const dlgProv = ref<HTMLDialogElement>()
const provSel = ref(0) // 0 = proveedor nuevo
const nuevoProv = reactive({ nit: '', nombre: '', telefono: '', contacto: '', correo: '', direccion: '', error: '', guardando: false })
const catSel = reactive<Record<number, { marcado: boolean; precio: number }>>({})
const buscarCat = ref('')

const soloNumeros = (v: string, max: number) => v.replace(/\D/g, '').slice(0, max)
const soloLetras = (v: string) => v.replace(/[^\p{L} ]/gu, '')
const soloNit = (v: string) => v.replace(/[^\d-]/g, '').slice(0, 15)
const norm = (v: string) => v.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()

const repuestosOrdenados = computed(() =>
  [...catalogo.value].sort((a, b) => a.codigo.localeCompare(b.codigo, 'es', { numeric: true })))
const repuestosFiltrados = computed(() => {
  const t = norm(buscarCat.value.trim())
  return repuestosOrdenados.value.filter((r) => !t || norm(`${r.codigo} ${r.nombre} ${r.categoria}`).includes(t))
})
const marcados = computed(() => Object.values(catSel).filter((x) => x.marcado).length)

async function prepararCatalogo(proveedorId: number) {
  Object.keys(catSel).forEach((k) => delete catSel[Number(k)])
  for (const r of catalogo.value) catSel[r.repuestoId] = { marcado: false, precio: r.precioCompraReferencia }
  if (!proveedorId) return
  try {
    for (const it of await inventarioApi.catalogoProveedor(proveedorId))
      catSel[it.repuestoId] = { marcado: true, precio: it.precioReferencia }
  } catch (e) {
    nuevoProv.error = (e as Error).message
  }
}

function abrirProveedores(proveedorId = 0) {
  Object.assign(nuevoProv, { nit: '', nombre: '', telefono: '', contacto: '', correo: '', direccion: '', error: '' })
  buscarCat.value = ''
  provSel.value = proveedorId
  prepararCatalogo(proveedorId)
  dlgProv.value?.showModal()
}
watch(provSel, (id) => { if (dlgProv.value?.open) prepararCatalogo(id) })

async function guardarProveedorCatalogo() {
  nuevoProv.error = ''
  let proveedorId = provSel.value
  if (!proveedorId) {
    const nit = nuevoProv.nit.trim().toUpperCase()
    if (!/^\d{1,13}-?\d$/.test(nit)) return void (nuevoProv.error = 'NIT inválido. Ejemplo: 1234567-8.')
    if (!nuevoProv.nombre.trim()) return void (nuevoProv.error = 'Escriba el nombre del proveedor.')
    if (nuevoProv.telefono.length !== 8) return void (nuevoProv.error = 'El teléfono debe tener 8 números.')
    if (nuevoProv.contacto && nuevoProv.contacto.length !== 8) return void (nuevoProv.error = 'El teléfono de contacto debe tener 8 números.')
    if (nuevoProv.correo.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(nuevoProv.correo.trim()))
      return void (nuevoProv.error = 'Correo inválido.')
  }
  if (!marcados.value) return void (nuevoProv.error = 'Marque al menos un repuesto que vende el proveedor.')
  if (Object.values(catSel).some((x) => x.marcado && !(Number(x.precio) >= 0)))
    return void (nuevoProv.error = 'Los precios no pueden ser negativos.')
  nuevoProv.guardando = true
  try {
    if (!proveedorId) {
      const nit = nuevoProv.nit.trim().toUpperCase()
      await mantenimientoApi.guardarProveedor(null, {
        nit, nombre: nuevoProv.nombre.trim(), contacto: nuevoProv.contacto.trim(),
        telefono: nuevoProv.telefono.trim(), correo: nuevoProv.correo.trim(), direccion: nuevoProv.direccion.trim(),
      })
      proveedores.value = await inventarioApi.proveedores()
      proveedorId = proveedores.value.find((x) => x.nit.toUpperCase() === nit)?.proveedorId ?? 0
      if (!proveedorId) throw new Error('No se encontró el proveedor recién creado.')
    }
    await inventarioApi.guardarCatalogo(proveedorId, Object.entries(catSel)
      .filter(([, v]) => v.marcado)
      .map(([id, v]) => ({ repuestoId: Number(id), precioReferencia: Number(v.precio) })))
    dlgProv.value?.close()
    mostrarAviso(provSel.value ? 'Catálogo del proveedor actualizado.' : 'Proveedor y catálogo registrados.')
    if (nueva.proveedorId === proveedorId) cargarCatalogoCompra(proveedorId)
  } catch (e) {
    nuevoProv.error = (e as Error).message
  } finally {
    nuevoProv.guardando = false
  }
}

const totalNueva = computed(() =>
  nueva.lineas.reduce((s, l) => s + (Number(l.cantidad) || 0) * (Number(l.costoUnitario) || 0), 0))

function validarCompra(): string {
  if (!nueva.proveedorId) return 'Seleccione el proveedor.'
  if (!nueva.bodegaId) return 'Seleccione la bodega donde se recibirá.'
  if (!nueva.lineas.length) return 'Agregue al menos un repuesto.'
  const ids = new Set<number>()
  for (const [i, l] of nueva.lineas.entries()) {
    if (!l.repuestoId) return `Línea ${i + 1}: seleccione el repuesto.`
    if (!(Number.isInteger(Number(l.cantidad)) && Number(l.cantidad) > 0)) return `Línea ${i + 1}: la cantidad debe ser un entero mayor que cero.`
    if (!(Number(l.costoUnitario) >= 0)) return `Línea ${i + 1}: el costo no puede ser negativo.`
    if (ids.has(l.repuestoId)) return `Línea ${i + 1}: el repuesto está repetido; junte las cantidades en una sola línea.`
    ids.add(l.repuestoId)
  }
  return ''
}

async function guardarCompra() {
  errorForm.value = validarCompra()
  if (errorForm.value) return
  guardando.value = true
  try {
    const r = await inventarioApi.registrarCompra({
      proveedorId: nueva.proveedorId,
      bodegaId: nueva.bodegaId,
      observaciones: nueva.observaciones.trim() || null,
      detalle: nueva.lineas.map((l) => ({
        repuestoId: l.repuestoId, cantidad: Number(l.cantidad), costoUnitario: Number(l.costoUnitario),
      })),
    })
    dlgCompra.value?.close()
    mostrarAviso(`Compra ${r?.numeroCompra ?? ''} registrada como PENDIENTE.`)
    filtroCompra.value = ''
    await cargarCompras()
  } catch (e) {
    errorForm.value = (e as Error).message
  } finally {
    guardando.value = false
  }
}

// ---------- recibir / anular ----------
const dlgAccion = ref<HTMLDialogElement>()
const accion = ref<{ tipo: 'recibir' | 'anular'; compra: Compra } | null>(null)
const motivo = ref('')
const procesando = ref(false)
const errorAccion = ref('')

function pedir(tipo: 'recibir' | 'anular', compra: Compra) {
  accion.value = { tipo, compra }
  motivo.value = ''
  errorAccion.value = ''
  dlgAccion.value?.showModal()
}

async function confirmarAccion() {
  if (!accion.value) return
  const { tipo, compra } = accion.value
  if (tipo === 'anular' && !motivo.value.trim()) return void (errorAccion.value = 'Indique el motivo de la anulación.')
  procesando.value = true
  errorAccion.value = ''
  try {
    if (tipo === 'recibir') {
      await inventarioApi.recibirCompra(compra.compraId)
      invalidarInventario()
      mostrarAviso(`Compra ${compra.numeroCompra} recibida en ${compra.bodega}. El inventario se actualizó.`)
    } else {
      await inventarioApi.anularCompra(compra.compraId, motivo.value.trim())
      mostrarAviso(`Compra ${compra.numeroCompra} anulada.`)
    }
    dlgAccion.value?.close()
    abierta.value = null
    await cargarCompras()
  } catch (e) {
    errorAccion.value = (e as Error).message
  } finally {
    procesando.value = false
  }
}

const nombreEstadoCompra: Record<EstadoCompra, string> = {
  PENDIENTE: 'Pendiente', RECIBIDA: 'Recibida', ANULADA: 'Anulada',
}
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <div>
        <h1>Inventario y compras</h1>
        <p class="sub">Existencias por bodega, compras a proveedores y movimientos de repuestos.</p>
      </div>
      <div class="acciones-cabecera">
        <button class="btn" @click="pestana = 'compras'; abrirProveedores()">Proveedores y catálogo</button>
        <button class="btn primario" @click="pestana = 'compras'; abrirNueva()">Nueva compra</button>
      </div>
    </header>

    <p v-if="aviso" class="aviso" role="status">{{ aviso }}</p>
    <p v-if="errorCatalogos" class="error" role="alert">{{ errorCatalogos }}</p>

    <nav class="pestanas" role="tablist" aria-label="Secciones de inventario">
      <button
        v-for="p in (['stock', 'compras', 'movimientos'] as Pestana[])" :key="p" role="tab"
        :aria-selected="pestana === p" :class="{ activa: pestana === p }" @click="pestana = p">
        {{ p === 'stock' ? 'Existencias' : p === 'compras' ? 'Compras' : 'Movimientos' }}
      </button>
    </nav>

    <!-- ===== Existencias ===== -->
    <section v-show="pestana === 'stock'" role="tabpanel">
      <div class="filtros">
        <label class="campo grande">
          <span>Buscar</span>
          <input v-model="fStock.buscar" type="search" placeholder="Código, repuesto o categoría" />
        </label>
        <label class="campo">
          <span>Bodega</span>
          <select v-model.number="fStock.bodegaId">
            <option :value="0">Todas</option>
            <option v-for="b in bodegas" :key="b.bodegaId" :value="b.bodegaId">{{ b.nombre }}</option>
          </select>
        </label>
        <label class="campo">
          <span>Orden por código</span>
          <select v-model="ordenStock">
            <option value="asc">Ascendente (REP-0001 → …)</option>
            <option value="desc">Descendente (… → REP-0001)</option>
          </select>
        </label>
        <label class="check">
          <input v-model="fStock.soloBajo" type="checkbox" />
          <span>Solo bajo mínimo o sin stock</span>
        </label>
      </div>

      <div class="resumen">
        <div><span>Valor del inventario <InfoTip texto="Suma del valor (existencia × precio de compra) de las filas que se muestran." /></span><b>{{ moneda(valorTotal) }}</b></div>
        <div :class="{ alerta: bajoMinimo > 0 }"><span>Bajo mínimo / sin stock <InfoTip texto="Filas en SIN STOCK o BAJO MÍNIMO: repuestos que conviene comprar pronto." /></span><b>{{ bajoMinimo }}</b></div>
        <div><span>Registros <InfoTip texto="Cantidad de filas: una por cada repuesto en cada bodega." derecha /></span><b>{{ stockVisible.length }}</b></div>
      </div>

      <p v-if="errorStock" class="error" role="alert">{{ errorStock }}</p>
      <div class="tabla-wrap">
        <table>
          <thead>
            <tr><th>Código</th><th>Repuesto</th><th>Categoría</th><th>Bodega <InfoTip texto="Un mismo repuesto aparece una vez por cada bodega donde está registrado." /></th>
              <th class="der">Existencia <InfoTip texto="Unidades que hay ahora en esa bodega. Sube al recibir una compra y baja cuando el técnico usa el repuesto." /></th>
              <th class="der">Mínimo <InfoTip texto="Punto de reorden: si la existencia es igual o menor a este número, hay que comprar. Se define en Mantenimientos → Repuestos." /></th>
              <th>Estado <InfoTip texto="SIN STOCK: existencia 0. BAJO MÍNIMO: existencia ≤ mínimo. OK: existencia mayor que el mínimo." /></th>
              <th class="der">Precio venta <InfoTip texto="Lo que se le cobra al cliente al usar el repuesto en una reparación (entra en la factura)." derecha /></th>
              <th class="der">Valor <InfoTip texto="Existencia × precio de compra. Es lo que vale el inventario de esa fila." derecha /></th></tr>
          </thead>
          <tbody>
            <tr v-if="cargandoStock"><td colspan="9" class="vacio">Cargando existencias…</td></tr>
            <tr v-else-if="!stockVisible.length"><td colspan="9" class="vacio">No hay repuestos con ese criterio.</td></tr>
            <template v-else>
              <tr v-for="s in stockVisible" :key="`${s.repuestoId}-${s.bodegaId}`">
                <td class="num">{{ s.codigo }}</td>
                <td>{{ s.repuesto }}</td>
                <td>{{ s.categoria }}</td>
                <td>{{ s.bodega }}</td>
                <td class="der fuerte">{{ s.existencia }}</td>
                <td class="der">{{ s.stockMinimo }}</td>
                <td><span class="chip" :class="s.estadoStock === 'OK' ? 'ok' : s.estadoStock === 'SIN STOCK' ? 'sin' : 'bajo'">{{ s.estadoStock }}</span></td>
                <td class="der">{{ moneda(s.precioVenta) }}</td>
                <td class="der">{{ moneda(s.valorInventario) }}</td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </section>

    <!-- ===== Compras ===== -->
    <section v-show="pestana === 'compras'" role="tabpanel">
      <div class="filtros">
        <label class="campo">
          <span>Estado</span>
          <select v-model="filtroCompra">
            <option value="">Todas</option>
            <option value="PENDIENTE">Pendientes</option>
            <option value="RECIBIDA">Recibidas</option>
            <option value="ANULADA">Anuladas</option>
          </select>
        </label>
      </div>

      <p v-if="errorCompras" class="error" role="alert">{{ errorCompras }}</p>
      <div class="tabla-wrap">
        <table>
          <thead>
            <tr><th>Número <InfoTip texto="Correlativo de la compra (OC-2026-0001). Lo genera sp_RegistrarCompra." /></th><th>Fecha <InfoTip texto="Cuándo se registró el pedido. Si ya se recibió, abajo aparece la fecha de recepción." /></th><th>Proveedor <InfoTip texto="A quién se le compra. Debajo: el usuario de Bodega o Administrador que registró la compra." /></th><th>Bodega <InfoTip texto="Bodega donde entrarán los repuestos al recibir la compra." /></th><th class="der">Líneas <InfoTip texto="Cuántos repuestos distintos tiene la compra (no es la cantidad de unidades)." /></th><th class="der">Total <InfoTip texto="Suma de cantidad × costo unitario de todas las líneas." /></th><th>Estado <InfoTip texto="PENDIENTE: pedida, el inventario no ha cambiado. RECIBIDA: llegó y subió la existencia (movimiento de ENTRADA). ANULADA: se canceló; solo se puede anular si está pendiente." derecha /></th><th><span class="sr-only">Acciones</span> <InfoTip texto="Detalle: ver las líneas. Recibir: sube el inventario (sp_RecibirCompra). Anular: cancela una compra pendiente con un motivo (sp_AnularCompra)." derecha /></th></tr>
          </thead>
          <tbody>
            <tr v-if="cargandoCompras"><td colspan="8" class="vacio">Cargando compras…</td></tr>
            <tr v-else-if="!compras.length"><td colspan="8" class="vacio">No hay compras. Use «Nueva compra» para registrar una.</td></tr>
            <template v-else>
            <template v-for="c in compras" :key="c.compraId">
              <tr>
                <td class="num">{{ c.numeroCompra }}</td>
                <td>
                  {{ fechaHora(c.fechaCompra) }}
                  <div v-if="c.fechaRecepcion" class="detalle">Recibida {{ fechaHora(c.fechaRecepcion) }}</div>
                </td>
                <td>{{ c.proveedor }}<div class="detalle">Registró {{ c.registradaPor }}</div></td>
                <td>{{ c.bodega }}</td>
                <td class="der">{{ c.lineas }}</td>
                <td class="der fuerte">{{ moneda(c.total) }}</td>
                <td><span class="chip" :class="c.estado.toLowerCase()">{{ nombreEstadoCompra[c.estado] }}</span></td>
                <td class="acciones">
                  <button class="btn enlace" :aria-expanded="abierta === c.compraId" @click="verDetalle(c)">
                    {{ abierta === c.compraId ? 'Ocultar' : 'Detalle' }}
                  </button>
                  <template v-if="c.estado === 'PENDIENTE'">
                    <button class="btn enlace" @click="pedir('recibir', c)">Recibir</button>
                    <button class="btn enlace peligro" @click="pedir('anular', c)">Anular</button>
                  </template>
                </td>
              </tr>
              <tr v-if="abierta === c.compraId" class="sub-fila">
                <td colspan="8">
                  <p v-if="errorDetalle" class="error" role="alert">{{ errorDetalle }}</p>
                  <table v-else class="interna">
                    <thead><tr><th>Código</th><th>Repuesto</th><th class="der">Cantidad</th><th class="der">Costo unit.</th><th class="der">Subtotal</th></tr></thead>
                    <tbody>
                      <tr v-for="d in detalleAbierto" :key="d.repuestoId">
                        <td class="num">{{ d.codigo }}</td><td>{{ d.repuesto }}</td>
                        <td class="der">{{ d.cantidad }}</td><td class="der">{{ moneda(d.costoUnitario) }}</td>
                        <td class="der">{{ moneda(d.subtotal) }}</td>
                      </tr>
                    </tbody>
                  </table>
                  <p v-if="c.observaciones" class="nota obs">Obs.: {{ c.observaciones }}</p>
                </td>
              </tr>
            </template>
            </template>
          </tbody>
        </table>
      </div>
    </section>

    <!-- ===== Movimientos ===== -->
    <section v-show="pestana === 'movimientos'" role="tabpanel">
      <div class="filtros">
        <label class="campo">
          <span>Bodega</span>
          <select v-model.number="fMov.bodegaId">
            <option :value="0">Todas</option>
            <option v-for="b in bodegas" :key="b.bodegaId" :value="b.bodegaId">{{ b.nombre }}</option>
          </select>
        </label>
        <label class="campo">
          <span>Tipo</span>
          <select v-model="fMov.tipo">
            <option value="">Entradas y salidas</option>
            <option value="ENTRADA">Entradas (compras)</option>
            <option value="SALIDA">Salidas (órdenes)</option>
          </select>
        </label>
        <p class="nota al-final">Se muestran los últimos 200 movimientos.</p>
      </div>

      <p v-if="errorMov" class="error" role="alert">{{ errorMov }}</p>
      <div class="tabla-wrap">
        <table>
          <thead>
            <tr><th>Fecha <InfoTip texto="Cuándo se movió el inventario. Cada movimiento queda guardado y no se puede borrar (trazabilidad)." /></th><th>Tipo <InfoTip texto="ENTRADA: suma existencia (compra recibida). SALIDA: resta existencia (repuesto usado en una reparación)." /></th><th>Repuesto <InfoTip texto="Repuesto que entró o salió." /></th><th>Bodega <InfoTip texto="Bodega donde cambió la existencia." /></th><th class="der">Cantidad <InfoTip texto="Unidades que entraron o salieron en ese movimiento." /></th><th class="der">Queda <InfoTip texto="Existencia que quedó en la bodega justo después del movimiento." /></th><th>Documento <InfoTip texto="De dónde viene: la compra (OC-…) si es ENTRADA o la orden de servicio (OS-…) si es SALIDA." derecha /></th><th>Usuario <InfoTip texto="Quién hizo el movimiento: Bodega al recibir o el técnico al usar el repuesto." derecha /></th></tr>
          </thead>
          <tbody>
            <tr v-if="cargandoMov"><td colspan="8" class="vacio">Cargando movimientos…</td></tr>
            <tr v-else-if="!movimientos.length"><td colspan="8" class="vacio">No hay movimientos con ese criterio.</td></tr>
            <template v-else>
              <tr v-for="m in movimientos" :key="m.movimientoId">
                <td>{{ fechaHora(m.fechaMovimiento) }}</td>
                <td><span class="chip" :class="m.tipoMovimiento === 'ENTRADA' ? 'entrada' : 'salida'">{{ m.tipoMovimiento === 'ENTRADA' ? 'Entrada' : 'Salida' }}</span></td>
                <td><span class="num">{{ m.codigo }}</span> {{ m.repuesto }}</td>
                <td>{{ m.bodega }}</td>
                <td class="der fuerte">{{ m.tipoMovimiento === 'ENTRADA' ? '+' : '−' }}{{ m.cantidad }}</td>
                <td class="der">{{ m.existenciaResultante }}</td>
                <td>{{ m.documentoOrigen ?? '—' }}<div v-if="m.proveedor" class="detalle">{{ m.proveedor }}</div></td>
                <td>{{ m.usuario }}</td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Proveedores y catálogo -->
    <dialog ref="dlgProv" class="modal ancho">
      <form novalidate @submit.prevent="guardarProveedorCatalogo">
        <h2>Proveedores y catálogo</h2>
        <p class="nota">Registre un proveedor nuevo con los repuestos que vende, o edite el catálogo de uno existente.
          Los repuestos nuevos se crean primero en Mantenimientos → Repuestos.</p>

        <label class="campo">
          <span>Proveedor</span>
          <select v-model.number="provSel">
            <option :value="0">➕ Nuevo proveedor</option>
            <option v-for="p in proveedores" :key="p.proveedorId" :value="p.proveedorId">{{ p.nombre }} — NIT {{ p.nit }}</option>
          </select>
        </label>

        <div v-if="!provSel" class="mini">
          <p class="mini-titulo">Datos del proveedor nuevo</p>
          <div class="mini-campos">
            <label class="campo"><span>NIT</span><input v-model="nuevoProv.nit" maxlength="15" inputmode="numeric" placeholder="1234567-8" @input="nuevoProv.nit = soloNit(nuevoProv.nit)" /></label>
            <label class="campo"><span>Nombre</span><input v-model="nuevoProv.nombre" maxlength="150" @input="nuevoProv.nombre = soloLetras(nuevoProv.nombre)" /></label>
            <label class="campo"><span>Teléfono</span><input v-model="nuevoProv.telefono" maxlength="8" inputmode="numeric" placeholder="22001000" @input="nuevoProv.telefono = soloNumeros(nuevoProv.telefono, 8)" /></label>
            <label class="campo"><span>Tel. contacto (opcional)</span><input v-model="nuevoProv.contacto" maxlength="8" inputmode="numeric" @input="nuevoProv.contacto = soloNumeros(nuevoProv.contacto, 8)" /></label>
            <label class="campo"><span>Correo (opcional)</span><input v-model="nuevoProv.correo" type="email" maxlength="100" /></label>
            <label class="campo"><span>Dirección (opcional)</span><input v-model="nuevoProv.direccion" maxlength="200" /></label>
          </div>
        </div>

        <div class="mini">
          <p class="mini-titulo">Catálogo: repuestos que vende ({{ marcados }} marcados)</p>
          <input v-model="buscarCat" type="search" placeholder="Buscar por código, nombre o categoría…" />
          <div class="cat-lista">
            <label v-for="r in repuestosFiltrados" :key="r.repuestoId" class="cat-item">
              <input v-if="catSel[r.repuestoId]" v-model="catSel[r.repuestoId]!.marcado" type="checkbox" />
              <span class="cat-nombre">{{ r.codigo }} · {{ r.nombre }} <small>{{ r.categoria }}</small></span>
              <span v-if="catSel[r.repuestoId]?.marcado" class="cat-precio">Q
                <input v-model.number="catSel[r.repuestoId]!.precio" type="number" min="0" step="0.01" aria-label="Precio de referencia" />
              </span>
            </label>
          </div>
        </div>

        <p v-if="nuevoProv.error" class="error" role="alert">{{ nuevoProv.error }}</p>
        <div class="botones">
          <button type="button" class="btn" @click="dlgProv?.close()">Cancelar</button>
          <button type="submit" class="btn primario" :disabled="nuevoProv.guardando">
            {{ nuevoProv.guardando ? 'Guardando…' : provSel ? 'Guardar catálogo' : 'Registrar proveedor y catálogo' }}
          </button>
        </div>
      </form>
    </dialog>

    <!-- Nueva compra -->
    <dialog ref="dlgCompra" class="modal ancho">
      <form novalidate @submit.prevent="guardarCompra">
        <h2>Nueva compra</h2>
        <p class="nota">Queda PENDIENTE. El inventario sube cuando se marque como recibida.</p>

        <div class="fila">
          <label class="campo">
            <span>Proveedor
              <InfoTip texto="Solo proveedores ya registrados. En los repuestos aparecen únicamente los que vende este proveedor (su catálogo). Si no lo vende, use otro proveedor o regístrelo en 'Proveedores y catálogo'." />
            </span>
            <BuscadorSelect v-model="nueva.proveedorId" :opciones="opcProveedores" etiqueta="Proveedor"
              placeholder="Escriba nombre, NIT o seleccione…" />
          </label>
          <label class="campo">
            <span>Bodega que recibe</span>
            <select v-model.number="nueva.bodegaId">
              <option :value="0" disabled>Seleccione…</option>
              <option v-for="b in bodegas" :key="b.bodegaId" :value="b.bodegaId">{{ b.nombre }}</option>
            </select>
          </label>
        </div>

        <p v-if="nueva.proveedorId && !cargandoCatalogo && !catalogoCompra.length" class="nota aviso-cat">
          Este proveedor no tiene repuestos en su catálogo.
          <button type="button" class="btn enlace" @click="abrirProveedores(nueva.proveedorId)">Agregar a su catálogo</button>
        </p>
        <p v-else-if="nueva.proveedorId" class="nota">
          {{ catalogoCompra.length }} repuesto(s) en el catálogo de este proveedor.
          <button type="button" class="btn enlace mini-enlace" @click="abrirProveedores(nueva.proveedorId)">Editar catálogo</button>
        </p>

        <div class="tabla-wrap">
          <table class="lineas">
            <thead><tr><th>Repuesto</th><th class="der">Cantidad</th><th class="der">Costo unit. (Q)</th><th class="der">Subtotal</th><th></th></tr></thead>
            <tbody>
              <tr v-for="(l, i) in nueva.lineas" :key="i">
                <td>
                  <BuscadorSelect v-model="l.repuestoId" :opciones="opcionesLinea(i)" :etiqueta="`Repuesto línea ${i + 1}`"
                    placeholder="Escriba código, nombre o seleccione…" @elegir="elegirRepuesto(i)" />
                </td>
                <td><input v-model.number="l.cantidad" type="number" min="1" step="1" :aria-label="`Cantidad línea ${i + 1}`" /></td>
                <td><input :value="Number(l.costoUnitario).toFixed(2)" type="text" readonly tabindex="-1" title="Precio de compra del repuesto (se cambia en Mantenimientos)" :aria-label="`Costo línea ${i + 1}`" /></td>
                <td class="der">{{ moneda((Number(l.cantidad) || 0) * (Number(l.costoUnitario) || 0)) }}</td>
                <td><button type="button" class="btn enlace peligro" :disabled="nueva.lineas.length === 1" @click="nueva.lineas.splice(i, 1)">Quitar</button></td>
              </tr>
            </tbody>
            <tfoot>
              <tr>
                <td colspan="3"><button type="button" class="btn enlace" @click="agregarLinea">+ Agregar repuesto</button></td>
                <td class="der fuerte">{{ moneda(totalNueva) }}</td><td></td>
              </tr>
            </tfoot>
          </table>
        </div>

        <label class="campo">
          <span>Observaciones (opcional)</span>
          <input v-model="nueva.observaciones" maxlength="300" placeholder="Ej. Factura del proveedor No. 1234" />
        </label>

        <p v-if="errorForm" class="error" role="alert">{{ errorForm }}</p>
        <div class="botones">
          <button type="button" class="btn" @click="dlgCompra?.close()">Cancelar</button>
          <button type="submit" class="btn primario" :disabled="guardando">{{ guardando ? 'Guardando…' : 'Registrar compra' }}</button>
        </div>
      </form>
    </dialog>

    <!-- Recibir / anular -->
    <dialog ref="dlgAccion" class="modal">
      <form v-if="accion" novalidate @submit.prevent="confirmarAccion">
        <h2>{{ accion.tipo === 'recibir' ? 'Recibir compra' : 'Anular compra' }}</h2>
        <template v-if="accion.tipo === 'recibir'">
          <p>¿Recibir la compra <b>{{ accion.compra.numeroCompra }}</b> de {{ accion.compra.proveedor }} en la bodega <b>{{ accion.compra.bodega }}</b>?</p>
          <p class="nota">Se suman {{ accion.compra.lineas }} repuesto(s) al inventario y se registran las entradas. No se puede deshacer.</p>
        </template>
        <template v-else>
          <p>¿Anular la compra <b>{{ accion.compra.numeroCompra }}</b> de {{ accion.compra.proveedor }}?</p>
          <label class="campo">
            <span>Motivo</span>
            <input v-model="motivo" maxlength="200" placeholder="Ej. El proveedor no tenía existencia" />
          </label>
          <p class="nota">No se borra: queda como anulada con el motivo.</p>
        </template>
        <p v-if="errorAccion" class="error" role="alert">{{ errorAccion }}</p>
        <div class="botones">
          <button type="button" class="btn" @click="dlgAccion?.close()">Cancelar</button>
          <button type="submit" class="btn" :class="accion.tipo === 'recibir' ? 'primario' : 'peligro-lleno'" :disabled="procesando">
            {{ procesando ? 'Procesando…' : accion.tipo === 'recibir' ? 'Recibir' : 'Anular' }}
          </button>
        </div>
      </form>
    </dialog>
  </main>
</template>

<style scoped>
/* Colores que cambian con el tema (modo claro / oscuro de la plantilla) */
.pagina {
  --c-title: #17375e; --c-text: #222b38; --c-muted: #5a6472; --c-surface: #fff;
  --c-row: #f4f6fa; --c-border: #d0d7e2; --c-input: #b9c2d0; --c-disabled: #f1f3f7;
  --c-danger: #8a1f1f;
}
:root.dark .pagina {
  --c-title: #c7d2fe; --c-text: #e2e8f0; --c-muted: #a3b2c9; --c-surface: rgb(18 27 46);
  --c-row: rgb(24 36 60); --c-border: rgb(43 56 78); --c-input: rgb(71 85 105); --c-disabled: rgb(30 41 59);
  --c-danger: #f87171;
}
.modal { background: var(--c-surface); color: var(--c-text); margin: auto; }
.pagina { max-width: 1280px; margin: 0 auto; padding: 32px 24px 64px; text-align: left; color: var(--c-text); }
.cabecera { display: flex; justify-content: space-between; align-items: flex-end; gap: 16px; flex-wrap: wrap;
  border-bottom: 3px solid #c8962e; padding-bottom: 16px; margin-bottom: 20px; }
h1 { margin: 0; font: 700 28px/1.2 Georgia, 'Times New Roman', serif; color: var(--c-title); }
h2 { margin: 0; font: 700 22px/1.2 Georgia, serif; color: var(--c-title); }
.sub { margin: 4px 0 0; color: var(--c-muted); font-size: 15px; }

.pestanas { display: flex; gap: 4px; border-bottom: 1px solid var(--c-border); margin-bottom: 18px; overflow-x: auto; overflow-y: hidden; }
.pestanas button { font: inherit; font-size: 15px; padding: 10px 18px; border: none; background: none; color: var(--c-muted);
  border-bottom: 3px solid transparent; margin-bottom: -1px; cursor: pointer; }
.pestanas button.activa { color: var(--c-title); font-weight: 700; border-bottom-color: #c8962e; }
.pestanas button:focus-visible { outline: 3px solid #c8962e; }

.filtros { display: flex; gap: 16px; margin-bottom: 16px; flex-wrap: wrap; align-items: flex-end; }
.campo { display: flex; flex-direction: column; gap: 4px; font-size: 14px; min-width: 180px; }
.campo span { font-weight: 600; color: var(--c-title); }
.campo.grande { flex: 1; min-width: 240px; }
.check { display: flex; align-items: center; gap: 8px; font-size: 14px; padding-bottom: 10px; }
.check input { width: auto; }
.al-final { padding-bottom: 10px; }
input, select, textarea { font: inherit; font-size: 15px; padding: 9px 10px; border: 1px solid var(--c-input); border-radius: 4px;
  background: var(--c-surface); color: var(--c-text); box-sizing: border-box; width: 100%; }
input:focus-visible, select:focus-visible, .btn:focus-visible { outline: 3px solid #c8962e; outline-offset: 1px; }

.resumen { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 16px; }
.resumen div { flex: 1; min-width: 180px; border: 1px solid var(--c-border); border-left: 4px solid #17375e; border-radius: 4px;
  padding: 10px 14px; display: flex; flex-direction: column; background: var(--c-surface); }
.resumen span { font-size: 13px; color: var(--c-muted); }
.resumen b { font-size: 20px; color: var(--c-title); }
.resumen .alerta { border-left-color: #c8962e; }

.tabla-wrap { overflow-x: auto; border: 1px solid var(--c-border); border-radius: 4px; }
table { width: 100%; border-collapse: collapse; font-size: 15px; }
th { background: #17375e; color: #fff; text-align: left; padding: 10px 12px; font-weight: 600; white-space: nowrap; }
td { padding: 10px 12px; border-top: 1px solid var(--c-border); vertical-align: middle; }
tbody tr:nth-child(even) { background: var(--c-row); }
.der { text-align: right; }
.fuerte { font-weight: 700; }
.num { font-variant-numeric: tabular-nums; white-space: nowrap; font-weight: 600; color: var(--c-title); }
.detalle { font-size: 13px; color: var(--c-muted); }
.vacio { text-align: center; color: var(--c-muted); padding: 28px 12px; }
.acciones { text-align: right; white-space: nowrap; }
.sub-fila > td { background: var(--c-row); padding: 12px 16px 16px; }
table.interna { font-size: 14px; border: 1px solid var(--c-border); }
table.interna th { background: var(--c-disabled); color: var(--c-title); }
.obs { margin-top: 8px; }

.chip { padding: 2px 10px; border-radius: 999px; font-size: 13px; font-weight: 600; white-space: nowrap; }
.chip.ok, .chip.recibida, .chip.entrada { background: #dff3e4; color: #1d6b34; }
.chip.bajo, .chip.pendiente { background: #fff2d6; color: #7a4c00; }
.chip.sin { background: #fbe4e4; color: #8a1f1f; }
.chip.anulada { background: #ececec; color: #3c4450; }
.chip.salida { background: #e6f0fb; color: #1d4f8a; }

.btn { font: inherit; font-size: 15px; padding: 9px 16px; border-radius: 4px; border: 1px solid var(--c-input);
  background: var(--c-surface); color: var(--c-title); cursor: pointer; }
.btn.primario { background: #17375e; border-color: var(--c-title); color: #fff; font-weight: 600; }
.btn.primario:hover:not(:disabled) { background: #0f2a4a; }
.btn:disabled { opacity: 0.6; cursor: not-allowed; }
.btn.enlace { border: none; background: none; padding: 4px 8px; text-decoration: underline; }
.btn.enlace.peligro { color: var(--c-danger); }
.btn.peligro-lleno { background: #a32a2a; border-color: #a32a2a; color: #fff; font-weight: 600; }

.aviso { background: #dff3e4; color: #1d6b34; padding: 10px 14px; border-radius: 4px; margin: 0 0 16px; }
.error { background: #fbe4e4; color: #8a1f1f; padding: 10px 14px; border-radius: 4px; margin: 0 0 16px; }
.modal .error, .sub-fila .error { margin: 0; }
.nota { margin: 0; color: var(--c-muted); font-size: 14px; }

.modal { border: none; border-radius: 6px; padding: 28px; width: min(560px, 92vw);
  box-shadow: 0 20px 50px rgba(15, 42, 74, 0.35); }
.modal.ancho { width: min(860px, 94vw); }
.modal::backdrop { background: rgba(15, 42, 74, 0.5); }
.modal form { display: flex; flex-direction: column; gap: 14px; text-align: left; }
.modal form > p { margin: 0; }
.lineas td { padding: 6px 8px; }
.lineas td:nth-child(2), .lineas td:nth-child(3) { width: 130px; }
.lineas tfoot td { border-top: 2px solid var(--c-border); }
.fila { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
.fila .campo { min-width: 0; }
.mini { border: 1px dashed var(--c-input, #c9d2de); border-radius: 6px; padding: 10px 12px; display: flex; flex-direction: column; gap: 8px; }
.mini .mini-titulo { margin: 0; font-weight: 600; }
.mini-campos { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; }
.mini-campos .campo { min-width: 0; }
.mini-botones { display: flex; gap: 8px; justify-content: flex-end; }
.mini-enlace { font-size: 12px; margin-left: 8px; padding: 0; }
.mini small { font-size: 12px; }
.modal .tabla-wrap { overflow: visible; }
.mini small.ok { color: #2e8b57; }
.mini small.mal { color: #d9534f; }
.botones { display: flex; justify-content: flex-end; gap: 10px; }

@media (max-width: 700px) {
  .pagina { padding: 24px 16px 48px; }
  .pestanas button { padding: 10px 12px; }
  .fila { grid-template-columns: 1fr; }
  .cabecera { flex-direction: column; align-items: stretch; }
  .campo { min-width: 0; flex: 1 1 100%; }
}
.sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
.acciones-cabecera { display: flex; gap: 8px; flex-wrap: wrap; }
.aviso-cat { color: #b45309; }
.cat-lista { max-height: 260px; overflow-y: auto; border: 1px solid var(--c-input, #c9d2de); border-radius: 4px; }
.cat-item { display: flex; align-items: center; gap: 10px; padding: 6px 10px; border-bottom: 1px solid var(--c-input, #e2e8f0); font-size: 14px; cursor: pointer; }
.cat-item > input[type='checkbox'] { width: auto; }
.cat-nombre { flex: 1; }
.cat-nombre small { opacity: 0.7; margin-left: 6px; }
.cat-precio { display: inline-flex; align-items: center; gap: 4px; }
.cat-precio input { width: 100px; padding: 4px 6px; }
</style>
