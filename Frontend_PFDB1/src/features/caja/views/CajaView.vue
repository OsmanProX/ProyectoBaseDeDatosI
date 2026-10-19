<script setup lang="ts">
// Semana 4 — Caja: factura → pagos → entrega del equipo.
// Ver: ADMINISTRADOR, CAJA y RECEPCION. Facturar/cobrar: ADMINISTRADOR y CAJA. Entregar: ADMINISTRADOR y RECEPCION.
// Las reglas (orden LISTO, IVA 12 %, no pagar de más, no entregar con saldo) las valida la base (script 06).
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useAuthStore } from '@/features/auth/stores/auth.store'
import { cajaApi, type OrdenCaja, type DetalleCaja, type MetodoPago } from '../api/caja'

const auth = useAuthStore()
const puedeCobrar = computed(() => ['ADMINISTRADOR', 'CAJA'].includes(auth.rol))
const puedeEntregar = computed(() => ['ADMINISTRADOR', 'RECEPCION'].includes(auth.rol))

const moneda = (n: number | null | undefined) =>
  (n ?? 0).toLocaleString('es-GT', { style: 'currency', currency: 'GTQ' })
const fechaHora = (iso: string | null) =>
  iso ? new Date(iso).toLocaleString('es-GT', { dateStyle: 'short', timeStyle: 'short' }) : '—'

// Etiqueta de la orden en la lista según en qué paso va
function situacion(o: OrdenCaja): { texto: string; clase: string } {
  if (o.estadoOrdenId === 6) return { texto: 'Entregada', clase: 'ok' }
  if (!o.facturaId) return { texto: 'Por facturar', clase: 'pend' }
  if ((o.saldoPendiente ?? 0) > 0) return { texto: `Saldo ${moneda(o.saldoPendiente)}`, clase: 'saldo' }
  return { texto: 'Pagada · por entregar', clase: 'listo' }
}

// ---------- lista ----------
const vista = ref<'pendientes' | 'entregadas'>('pendientes')
const ordenes = ref<OrdenCaja[]>([])
const cargando = ref(false)
const errorLista = ref('')
const aviso = ref('')
const buscar = ref('')

async function cargar() {
  cargando.value = true
  errorLista.value = ''
  try {
    ordenes.value = await cajaApi.ordenes(vista.value === 'entregadas')
  } catch (e) {
    errorLista.value = (e as Error).message
  } finally {
    cargando.value = false
  }
}

const visibles = computed(() => {
  const t = buscar.value.trim().toLowerCase()
  return ordenes.value.filter((o) =>
    !t || [o.numeroOrden, o.cliente, o.nit, o.equipo, o.numeroSerie, o.numeroFactura ?? '']
      .some((v) => v.toLowerCase().includes(t)))
})

watch(vista, () => {
  seleccionId.value = null
  detalle.value = null
  cargar()
})

const metodos = ref<MetodoPago[]>([])
onMounted(async () => {
  await cargar()
  try {
    metodos.value = await cajaApi.metodosPago()
  } catch {
    /* si falla, el formulario de pago avisa al intentar cobrar */
  }
})

function mostrarAviso(texto: string) {
  aviso.value = texto
  setTimeout(() => (aviso.value = ''), 4500)
}

// ---------- detalle ----------
const seleccionId = ref<number | null>(null)
const detalle = ref<DetalleCaja | null>(null)
const cargandoDetalle = ref(false)
const errorDetalle = ref('')

async function abrir(id: number) {
  seleccionId.value = id
  await recargarDetalle()
}

async function recargarDetalle() {
  if (!seleccionId.value) return
  cargandoDetalle.value = true
  errorDetalle.value = ''
  try {
    detalle.value = await cajaApi.detalle(seleccionId.value)
    prepararFormularios()
  } catch (e) {
    detalle.value = null
    errorDetalle.value = (e as Error).message
  } finally {
    cargandoDetalle.value = false
  }
}

const orden = computed(() => detalle.value?.orden ?? null)
const factura = computed(() => detalle.value?.factura ?? null)
const saldo = computed(() => factura.value?.saldoPendiente ?? 0)
// IVA 12 % como en sp_GenerarFactura (solo para mostrar antes de facturar)
const ivaEstimado = computed(() => Math.round((orden.value?.totalSinIVA ?? 0) * 0.12 * 100) / 100)

// ---------- formularios ----------
const fFac = reactive({ nit: '', nombre: '' })
const fPago = reactive({ metodoPagoId: 0, monto: 0, referencia: '' })
const fEnt = reactive({ nombreRecibe: '', observaciones: '' })
const errores = reactive<Record<string, string>>({})
const enviando = ref('')

const metodoElegido = computed(() => metodos.value.find((m) => m.metodoPagoId === fPago.metodoPagoId))
const pideReferencia = computed(() => !!metodoElegido.value && metodoElegido.value.nombre !== 'EFECTIVO')

function prepararFormularios() {
  const o = orden.value
  Object.assign(fFac, { nit: o?.nit ?? '', nombre: o?.cliente ?? '' })
  Object.assign(fPago, {
    metodoPagoId: metodos.value[0]?.metodoPagoId ?? 0,
    monto: factura.value?.saldoPendiente ?? 0,
    referencia: '',
  })
  Object.assign(fEnt, { nombreRecibe: '', observaciones: '' })
  Object.keys(errores).forEach((k) => delete errores[k])
}

async function ejecutar(clave: string, accion: () => Promise<unknown>, ok: string) {
  enviando.value = clave
  delete errores[clave]
  try {
    await accion()
    mostrarAviso(ok)
    await Promise.all([recargarDetalle(), cargar()])
  } catch (e) {
    errores[clave] = (e as Error).message
  } finally {
    enviando.value = ''
  }
}

function facturar() {
  if (!orden.value) return
  const nit = fFac.nit.trim().toUpperCase()
  if (nit && nit !== 'CF' && !/^[0-9]{1,13}-?[0-9K]$/.test(nit))
    return void (errores.factura = 'NIT inválido. Use el formato 1234567-8 o CF.')
  const o = orden.value
  ejecutar('factura', () => cajaApi.facturar({
    ordenId: o.ordenId,
    nitFacturacion: nit || null,
    nombreFacturacion: fFac.nombre.trim() || null,
  }), `Factura emitida para ${o.numeroOrden}.`)
}

function cobrar() {
  if (!factura.value) return
  const monto = Math.round(Number(fPago.monto) * 100) / 100
  if (!fPago.metodoPagoId) return void (errores.pago = 'Seleccione el método de pago.')
  if (!(monto > 0)) return void (errores.pago = 'El monto debe ser mayor que cero.')
  if (monto > saldo.value) return void (errores.pago = `El monto no puede pasar del saldo (${moneda(saldo.value)}).`)
  if (pideReferencia.value && !fPago.referencia.trim())
    return void (errores.pago = 'Para tarjeta o transferencia escriba el número de referencia.')
  if (fPago.referencia.trim() && !/^[A-Za-z0-9-]{4,50}$/.test(fPago.referencia.trim()))
    return void (errores.pago = 'Referencia inválida: use de 4 a 50 caracteres, solo letras, números y guiones (ej. AUT-482915).')
  const f = factura.value
  ejecutar('pago', () => cajaApi.registrarPago({
    facturaId: f.facturaId,
    metodoPagoId: fPago.metodoPagoId,
    monto,
    referencia: fPago.referencia.trim() || null,
  }), `Pago de ${moneda(monto)} registrado en ${f.numeroFactura}.`)
}

function entregar() {
  if (!orden.value) return
  if (!fEnt.nombreRecibe.trim()) return void (errores.entrega = 'Escriba el nombre de la persona que recibe.')
  const o = orden.value
  ejecutar('entrega', () => cajaApi.entregar({
    ordenId: o.ordenId,
    nombreRecibe: fEnt.nombreRecibe.trim(),
    observaciones: fEnt.observaciones.trim() || null,
  }), `Equipo de ${o.numeroOrden} entregado. La orden queda ENTREGADO.`)
}
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <div>
        <h1>Caja y entrega</h1>
        <p class="sub">Facturar las órdenes listas, registrar pagos y entregar el equipo al cliente.</p>
      </div>
      <button class="btn" :disabled="cargando" @click="cargar">Actualizar</button>
    </header>

    <p v-if="aviso" class="aviso" role="status">{{ aviso }}</p>

    <div class="mesa">
      <!-- Lista -->
      <section class="lista" aria-label="Órdenes en caja">
        <nav class="pestanas" role="tablist" aria-label="Vista">
          <button role="tab" :aria-selected="vista === 'pendientes'" :class="{ activa: vista === 'pendientes' }" @click="vista = 'pendientes'">
            Por cobrar / entregar
          </button>
          <button role="tab" :aria-selected="vista === 'entregadas'" :class="{ activa: vista === 'entregadas' }" @click="vista = 'entregadas'">
            Entregadas
          </button>
        </nav>
        <label class="campo">
          <span>Buscar</span>
          <input v-model="buscar" type="search" placeholder="Orden, cliente, NIT, factura o serie" />
        </label>

        <p v-if="errorLista" class="error" role="alert">{{ errorLista }}</p>
        <p v-if="cargando" class="vacio">Cargando órdenes…</p>
        <p v-else-if="!visibles.length" class="vacio">
          {{ vista === 'pendientes' ? 'No hay órdenes en estado LISTO.' : 'Todavía no hay entregas.' }}
        </p>
        <ul v-else class="tarjetas">
          <li v-for="o in visibles" :key="o.ordenId">
            <button class="tarjeta" :class="{ activa: o.ordenId === seleccionId }" @click="abrir(o.ordenId)">
              <span class="t-fila">
                <b class="num">{{ o.numeroOrden }}</b>
                <span class="fuerte">{{ moneda(o.totalFactura ?? o.totalSinIVA) }}</span>
              </span>
              <span class="t-cliente">{{ o.cliente }}</span>
              <span class="detalle">{{ o.equipo }} · NIT {{ o.nit }}</span>
              <span class="t-fila">
                <span class="chip" :class="situacion(o).clase">{{ situacion(o).texto }}</span>
                <span v-if="o.numeroFactura" class="detalle">{{ o.numeroFactura }}</span>
              </span>
            </button>
          </li>
        </ul>
      </section>

      <!-- Detalle -->
      <section class="panel" aria-live="polite">
        <p v-if="!seleccionId" class="vacio">Seleccione una orden de la lista.</p>
        <p v-else-if="cargandoDetalle && !detalle" class="vacio">Cargando orden…</p>
        <p v-else-if="errorDetalle" class="error" role="alert">{{ errorDetalle }}</p>

        <template v-else-if="detalle && orden">
          <div class="panel-cab">
            <div>
              <h2>{{ orden.numeroOrden }}</h2>
              <p class="sub">{{ orden.cliente }} · NIT {{ orden.nit }} · {{ orden.equipo }} · Serie {{ orden.numeroSerie }}</p>
            </div>
            <span class="chip grande" :class="situacion(orden).clase">{{ situacion(orden).texto }}</span>
          </div>

          <ol class="pasos" aria-label="Avance">
            <li :class="{ hecho: !!factura, actual: !factura }">Factura</li>
            <li :class="{ hecho: !!factura && saldo === 0, actual: !!factura && saldo > 0 }">Pago</li>
            <li :class="{ hecho: !!detalle.entrega, actual: !!factura && saldo === 0 && !detalle.entrega }">Entrega</li>
          </ol>

          <!-- 1. Factura -->
          <article class="bloque">
            <h3>1. Factura</h3>
            <template v-if="factura">
              <table class="resumen">
                <tbody>
                  <tr><th>Número</th><td class="num">{{ factura.numeroFactura }}</td></tr>
                  <tr><th>A nombre de</th><td>{{ factura.nombreFacturacion }} · NIT {{ factura.nitFacturacion }}</td></tr>
                  <tr><th>Mano de obra</th><td>{{ moneda(factura.totalManoObra) }}</td></tr>
                  <tr><th>Repuestos</th><td>{{ moneda(factura.totalRepuestos) }}</td></tr>
                  <tr><th>Subtotal</th><td>{{ moneda(factura.subtotal) }}</td></tr>
                  <tr><th>IVA 12 %</th><td>{{ moneda(factura.impuesto) }}</td></tr>
                  <tr class="total"><th>Total</th><td>{{ moneda(factura.total) }}</td></tr>
                </tbody>
              </table>
              <p class="nota">Emitida el {{ fechaHora(factura.fechaEmision) }} por {{ factura.emitidaPor }}.</p>
            </template>
            <template v-else>
              <table class="resumen">
                <tbody>
                  <tr><th>Mano de obra</th><td>{{ moneda(orden.manoObra) }}</td></tr>
                  <tr><th>Repuestos</th><td>{{ moneda(orden.repuestos) }}</td></tr>
                  <tr><th>Subtotal</th><td>{{ moneda(orden.totalSinIVA) }}</td></tr>
                  <tr><th>IVA 12 %</th><td>{{ moneda(ivaEstimado) }}</td></tr>
                  <tr class="total"><th>Total a facturar</th><td>{{ moneda(orden.totalSinIVA + ivaEstimado) }}</td></tr>
                </tbody>
              </table>
              <form v-if="puedeCobrar" novalidate @submit.prevent="facturar">
                <div class="fila">
                  <label class="campo">
                    <span>NIT</span>
                    <input v-model="fFac.nit" maxlength="15" placeholder="1234567-8 o CF" />
                  </label>
                  <label class="campo">
                    <span>Nombre en la factura</span>
                    <input v-model="fFac.nombre" maxlength="150" />
                  </label>
                </div>
                <p v-if="errores.factura" class="error" role="alert">{{ errores.factura }}</p>
                <div class="botones">
                  <button type="submit" class="btn primario" :disabled="enviando === 'factura'">
                    {{ enviando === 'factura' ? 'Emitiendo…' : 'Emitir factura' }}
                  </button>
                </div>
              </form>
              <p v-else class="nota">La factura la emite caja.</p>
            </template>
          </article>

          <!-- 2. Pagos -->
          <article v-if="factura" class="bloque">
            <h3>2. Pagos <span class="nota">Pagado {{ moneda(factura.total - saldo) }} · Saldo <b>{{ moneda(saldo) }}</b></span></h3>
            <div class="tabla-wrap">
              <table>
                <thead><tr><th>Fecha</th><th>Método</th><th>Referencia</th><th class="der">Monto</th><th>Cobró</th></tr></thead>
                <tbody>
                  <tr v-if="!detalle.pagos.length"><td colspan="5" class="vacio">Sin pagos registrados.</td></tr>
                  <tr v-for="p in detalle.pagos" :key="p.pagoId">
                    <td>{{ fechaHora(p.fechaPago) }}</td>
                    <td>{{ p.metodo }}</td>
                    <td>{{ p.referencia ?? '—' }}</td>
                    <td class="der fuerte">{{ moneda(p.monto) }}</td>
                    <td class="detalle">{{ p.cobradoPor }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <form v-if="puedeCobrar && saldo > 0" class="en-linea" novalidate @submit.prevent="cobrar">
              <label class="campo">
                <span>Método</span>
                <select v-model.number="fPago.metodoPagoId">
                  <option v-for="m in metodos" :key="m.metodoPagoId" :value="m.metodoPagoId">{{ m.nombre }}</option>
                </select>
              </label>
              <label class="campo corto">
                <span>Monto (Q)</span>
                <input v-model.number="fPago.monto" type="number" min="0.01" step="0.01" />
              </label>
              <label v-if="pideReferencia" class="campo">
                <span>Referencia</span>
                <input v-model="fPago.referencia" maxlength="50" placeholder="Ej. AUT-482915" />
              </label>
              <button type="submit" class="btn primario" :disabled="enviando === 'pago'">
                {{ enviando === 'pago' ? 'Registrando…' : 'Registrar pago' }}
              </button>
            </form>
            <p v-if="errores.pago" class="error" role="alert">{{ errores.pago }}</p>
            <p v-if="saldo === 0" class="nota">Factura pagada por completo.</p>
          </article>

          <!-- 3. Entrega -->
          <article v-if="factura" class="bloque">
            <h3>3. Entrega del equipo</h3>
            <p v-if="detalle.entrega">
              Entregado el {{ fechaHora(detalle.entrega.fechaEntrega) }} a <b>{{ detalle.entrega.nombreRecibe }}</b>
              por {{ detalle.entrega.entregadoPor }}.
              <span v-if="detalle.entrega.observaciones" class="detalle"><br />{{ detalle.entrega.observaciones }}</span>
            </p>
            <p v-else-if="saldo > 0" class="nota">El equipo se entrega cuando la factura no tenga saldo pendiente.</p>
            <form v-else-if="puedeEntregar" novalidate @submit.prevent="entregar">
              <div class="fila">
                <label class="campo">
                  <span>Nombre de quien recibe</span>
                  <input v-model="fEnt.nombreRecibe" maxlength="100" />
                </label>
                <label class="campo">
                  <span>Observaciones (opcional)</span>
                  <input v-model="fEnt.observaciones" maxlength="300" placeholder="Ej. Se entrega con cargador" />
                </label>
              </div>
              <p v-if="errores.entrega" class="error" role="alert">{{ errores.entrega }}</p>
              <div class="botones">
                <button type="submit" class="btn primario" :disabled="enviando === 'entrega'">
                  {{ enviando === 'entrega' ? 'Entregando…' : 'Entregar equipo' }}
                </button>
              </div>
            </form>
            <p v-else class="nota">La entrega la registra recepción.</p>
          </article>
        </template>
      </section>
    </div>
  </main>
</template>

<style scoped>
/* Colores que cambian con el tema (modo claro / oscuro de la plantilla) */
.pagina {
  --c-title: #17375e; --c-text: #222b38; --c-muted: #5a6472; --c-surface: #fff;
  --c-row: #f4f6fa; --c-border: #d0d7e2; --c-input: #b9c2d0; --c-disabled: #f1f3f7;
  --c-danger: #8a1f1f; --c-sel: #e8eef8;
}
:root.dark .pagina {
  --c-title: #c7d2fe; --c-text: #e2e8f0; --c-muted: #a3b2c9; --c-surface: rgb(18 27 46);
  --c-row: rgb(24 36 60); --c-border: rgb(43 56 78); --c-input: rgb(71 85 105); --c-disabled: rgb(30 41 59);
  --c-danger: #f87171; --c-sel: rgb(30 48 82);
}
.pagina { max-width: 1280px; margin: 0 auto; padding: 32px 24px 64px; text-align: left; color: var(--c-text); }
.cabecera { display: flex; justify-content: space-between; align-items: flex-end; gap: 16px; flex-wrap: wrap;
  border-bottom: 3px solid #c8962e; padding-bottom: 16px; margin-bottom: 24px; }
h1 { margin: 0; font: 700 28px/1.2 Georgia, 'Times New Roman', serif; color: var(--c-title); }
h2 { margin: 0; font: 700 22px/1.2 Georgia, serif; color: var(--c-title); }
h3 { margin: 0 0 8px; font-size: 17px; color: var(--c-title); display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
.sub { margin: 4px 0 0; color: var(--c-muted); font-size: 15px; }

.mesa { display: grid; grid-template-columns: minmax(300px, 380px) 1fr; gap: 24px; align-items: start; }
.lista { display: flex; flex-direction: column; gap: 12px; min-width: 0; }
.panel { border: 1px solid var(--c-border); border-radius: 6px; padding: 20px; background: var(--c-surface);
  display: flex; flex-direction: column; gap: 16px; min-height: 240px; min-width: 0; }

.pestanas { display: flex; gap: 4px; border-bottom: 1px solid var(--c-border); overflow-x: auto; overflow-y: hidden; }
.pestanas button { font: inherit; font-size: 14px; padding: 8px 12px; border: none; background: none; color: var(--c-muted);
  border-bottom: 3px solid transparent; margin-bottom: -1px; cursor: pointer; white-space: nowrap; }
.pestanas button.activa { color: var(--c-title); font-weight: 700; border-bottom-color: #c8962e; }

.campo { display: flex; flex-direction: column; gap: 4px; font-size: 14px; min-width: 160px; flex: 1; }
.campo span { font-weight: 600; color: var(--c-title); }
.campo.corto { flex: 0 0 140px; min-width: 0; }
input, select { font: inherit; font-size: 15px; padding: 9px 10px; border: 1px solid var(--c-input); border-radius: 4px;
  background: var(--c-surface); color: var(--c-text); box-sizing: border-box; width: 100%; }
input:focus-visible, select:focus-visible, .btn:focus-visible, .tarjeta:focus-visible, .pestanas button:focus-visible {
  outline: 3px solid #c8962e; outline-offset: 1px; }

.tarjetas { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px;
  max-height: calc(100vh - 300px); overflow-y: auto; }
.tarjeta { width: 100%; text-align: left; font: inherit; color: var(--c-text); background: var(--c-surface);
  border: 1px solid var(--c-border); border-left: 4px solid var(--c-border); border-radius: 4px; padding: 10px 12px;
  display: flex; flex-direction: column; gap: 3px; cursor: pointer; }
.tarjeta:hover { background: var(--c-row); }
.tarjeta.activa { background: var(--c-sel); border-left-color: #c8962e; }
.t-fila { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.t-cliente { font-weight: 600; }

.panel-cab { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; flex-wrap: wrap; }
.pasos { display: flex; list-style: none; margin: 0; padding: 0; gap: 4px; }
.pasos li { flex: 1; text-align: center; font-size: 13px; padding: 6px 4px; border-bottom: 4px solid var(--c-border); color: var(--c-muted); }
.pasos li.hecho { border-color: #2f8a4c; color: var(--c-text); }
.pasos li.actual { border-color: #c8962e; color: var(--c-title); font-weight: 700; }

.bloque { border-top: 1px solid var(--c-border); padding-top: 14px; display: flex; flex-direction: column; gap: 10px; }
.bloque > p { margin: 0; }
.bloque form { display: flex; flex-direction: column; gap: 10px; }
.bloque form.en-linea { flex-direction: row; align-items: flex-end; flex-wrap: wrap; }

table.resumen { width: auto; min-width: 280px; border-collapse: collapse; font-size: 15px; }
table.resumen th { text-align: left; font-weight: 400; color: var(--c-muted); padding: 3px 24px 3px 0; background: none; }
table.resumen td { text-align: right; padding: 3px 0; border: none; font-variant-numeric: tabular-nums; }
table.resumen tr.total th, table.resumen tr.total td { font-weight: 700; color: var(--c-title); border-top: 2px solid var(--c-border); padding-top: 6px; }
table.resumen tbody tr:nth-child(even) { background: none; }

.tabla-wrap { overflow-x: auto; border: 1px solid var(--c-border); border-radius: 4px; }
table { width: 100%; border-collapse: collapse; font-size: 14px; }
th { background: #17375e; color: #fff; text-align: left; padding: 8px 10px; font-weight: 600; white-space: nowrap; }
td { padding: 8px 10px; border-top: 1px solid var(--c-border); vertical-align: top; }
tbody tr:nth-child(even) { background: var(--c-row); }
.der { text-align: right; }
.fuerte { font-weight: 700; }
.num { font-variant-numeric: tabular-nums; white-space: nowrap; font-weight: 600; color: var(--c-title); }
.detalle { font-size: 13px; color: var(--c-muted); }
.vacio { text-align: center; color: var(--c-muted); padding: 24px 12px; margin: 0; }

.chip { padding: 2px 10px; border-radius: 999px; font-size: 12px; font-weight: 700; white-space: nowrap; }
.chip.grande { font-size: 14px; padding: 4px 12px; }
.chip.pend { background: #e6f0fb; color: #1d4f8a; }
.chip.saldo { background: #fff2d6; color: #7a4c00; }
.chip.listo { background: #ece6fb; color: #4b2a8a; }
.chip.ok { background: #dff3e4; color: #1d6b34; }

.btn { font: inherit; font-size: 15px; padding: 9px 16px; border-radius: 4px; border: 1px solid var(--c-input);
  background: var(--c-surface); color: var(--c-title); cursor: pointer; }
.btn.primario { background: #17375e; border-color: var(--c-title); color: #fff; font-weight: 600; }
.btn.primario:hover:not(:disabled) { background: #0f2a4a; }
.btn:disabled { opacity: 0.6; cursor: wait; }

.aviso { background: #dff3e4; color: #1d6b34; padding: 10px 14px; border-radius: 4px; margin: 0 0 16px; }
.error { background: #fbe4e4; color: #8a1f1f; padding: 10px 14px; border-radius: 4px; margin: 0; }
.nota { margin: 0; color: var(--c-muted); font-size: 14px; font-weight: 400; }
.fila { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.fila .campo { min-width: 0; }
.botones { display: flex; justify-content: flex-end; gap: 10px; }

@media (max-width: 900px) {
  .mesa { grid-template-columns: 1fr; }
  .tarjetas { max-height: 320px; }
}
@media (max-width: 600px) {
  .pagina { padding: 24px 16px 48px; }
  .panel { padding: 14px; }
  .fila { grid-template-columns: 1fr; }
  .campo.corto { flex: 1 1 100%; }
  table.resumen { min-width: 0; width: 100%; }
}
</style>
