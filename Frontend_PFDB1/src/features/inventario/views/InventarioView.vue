<script setup lang="ts">
// Semana 3 — Inventario y compras: existencias por bodega, compras a proveedores
// (registrar, recibir, anular) y movimientos de entrada/salida.
// Acceso: ADMINISTRADOR y BODEGA (menú, router y policy "Inventario" del backend).
import { computed, onMounted, reactive, ref, watch } from 'vue'
import {
  inventarioApi,
  type Stock, type Bodega, type Proveedor, type RepuestoCatalogo,
  type Compra, type DetalleCompra, type Movimiento, type EstadoCompra,
} from '../api/inventario'

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

const stockVisible = computed(() => {
  const t = fStock.buscar.trim().toLowerCase()
  return stock.value.filter((s) => !t || [s.codigo, s.repuesto, s.categoria].some((v) => v.toLowerCase().includes(t)))
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

function abrirNueva() {
  Object.assign(nueva, { proveedorId: 0, bodegaId: bodegas.value[0]?.bodegaId ?? 0, observaciones: '', lineas: [] })
  agregarLinea()
  errorForm.value = ''
  dlgCompra.value?.showModal()
}

function agregarLinea() {
  nueva.lineas.push({ repuestoId: 0, cantidad: 1, costoUnitario: 0 })
}

// Al elegir el repuesto se propone su precio de compra de referencia
function elegirRepuesto(i: number) {
  const linea = nueva.lineas[i]
  const r = catalogo.value.find((x) => x.repuestoId === linea?.repuestoId)
  if (linea && r) linea.costoUnitario = r.precioCompraReferencia
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
      <button class="btn primario" @click="pestana = 'compras'; abrirNueva()">Nueva compra</button>
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
        <label class="check">
          <input v-model="fStock.soloBajo" type="checkbox" />
          <span>Solo bajo mínimo o sin stock</span>
        </label>
      </div>

      <div class="resumen">
        <div><span>Valor del inventario</span><b>{{ moneda(valorTotal) }}</b></div>
        <div :class="{ alerta: bajoMinimo > 0 }"><span>Bajo mínimo / sin stock</span><b>{{ bajoMinimo }}</b></div>
        <div><span>Registros</span><b>{{ stockVisible.length }}</b></div>
      </div>

      <p v-if="errorStock" class="error" role="alert">{{ errorStock }}</p>
      <div class="tabla-wrap">
        <table>
          <thead>
            <tr><th>Código</th><th>Repuesto</th><th>Categoría</th><th>Bodega</th><th class="der">Existencia</th><th class="der">Mínimo</th><th>Estado</th><th class="der">Precio venta</th><th class="der">Valor</th></tr>
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
            <tr><th>Número</th><th>Fecha</th><th>Proveedor</th><th>Bodega</th><th class="der">Líneas</th><th class="der">Total</th><th>Estado</th><th></th></tr>
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
            <tr><th>Fecha</th><th>Tipo</th><th>Repuesto</th><th>Bodega</th><th class="der">Cantidad</th><th class="der">Queda</th><th>Documento</th><th>Usuario</th></tr>
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

    <!-- Nueva compra -->
    <dialog ref="dlgCompra" class="modal ancho">
      <form novalidate @submit.prevent="guardarCompra">
        <h2>Nueva compra</h2>
        <p class="nota">Queda PENDIENTE. El inventario sube cuando se marque como recibida.</p>

        <div class="fila">
          <label class="campo">
            <span>Proveedor</span>
            <select v-model.number="nueva.proveedorId">
              <option :value="0" disabled>Seleccione…</option>
              <option v-for="p in proveedores" :key="p.proveedorId" :value="p.proveedorId">{{ p.nombre }} — NIT {{ p.nit }}</option>
            </select>
          </label>
          <label class="campo">
            <span>Bodega que recibe</span>
            <select v-model.number="nueva.bodegaId">
              <option :value="0" disabled>Seleccione…</option>
              <option v-for="b in bodegas" :key="b.bodegaId" :value="b.bodegaId">{{ b.nombre }}</option>
            </select>
          </label>
        </div>

        <div class="tabla-wrap">
          <table class="lineas">
            <thead><tr><th>Repuesto</th><th class="der">Cantidad</th><th class="der">Costo unit. (Q)</th><th class="der">Subtotal</th><th></th></tr></thead>
            <tbody>
              <tr v-for="(l, i) in nueva.lineas" :key="i">
                <td>
                  <select v-model.number="l.repuestoId" :aria-label="`Repuesto línea ${i + 1}`" @change="elegirRepuesto(i)">
                    <option :value="0" disabled>Seleccione…</option>
                    <option v-for="r in catalogo" :key="r.repuestoId" :value="r.repuestoId">{{ r.codigo }} · {{ r.nombre }}</option>
                  </select>
                </td>
                <td><input v-model.number="l.cantidad" type="number" min="1" step="1" :aria-label="`Cantidad línea ${i + 1}`" /></td>
                <td><input v-model.number="l.costoUnitario" type="number" min="0" step="0.01" :aria-label="`Costo línea ${i + 1}`" /></td>
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
.botones { display: flex; justify-content: flex-end; gap: 10px; }

@media (max-width: 700px) {
  .pagina { padding: 24px 16px 48px; }
  .pestanas button { padding: 10px 12px; }
  .fila { grid-template-columns: 1fr; }
  .cabecera { flex-direction: column; align-items: stretch; }
  .campo { min-width: 0; flex: 1 1 100%; }
}
</style>
