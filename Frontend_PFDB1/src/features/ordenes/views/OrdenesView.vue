<script setup lang="ts">
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useAuthStore } from '@/features/auth/stores/auth.store'
import {
  ordenesApi, ESTADOS, TRANSICIONES, PRIORIDADES,
  type OrdenResumen, type HistorialEstado, type OpcionCliente, type OpcionEquipo,
  type Prioridad, type CodigoEstado,
} from '../api/ordenes'

// ---------- usuario de la sesión (guardado por el login; permisos por rol) ----------
const auth = useAuthStore()
const usuarioId = computed(() => auth.usuario?.usuarioId ?? 0)
const usuario = computed(() => ({
  nombreCompleto: auth.usuario?.nombreCompleto ?? '',
  rol: auth.rol,
}))
const puedeCrear = computed(() => auth.tienePermiso('CREAR_ORDENES'))
const puedeCambiarEstado = computed(() => auth.tienePermiso('CAMBIAR_ESTADO_ORDEN'))

// ---------- utilidades de formato ----------
const nombreEstado = (codigo: CodigoEstado) => ESTADOS.find((e) => e.codigo === codigo)?.nombre ?? codigo
const fechaHora = (iso: string) =>
  new Date(iso).toLocaleString('es-GT', { dateStyle: 'short', timeStyle: 'short' })
const fecha = (iso: string | null) =>
  iso ? new Date(iso.length === 10 ? iso + 'T00:00:00' : iso).toLocaleDateString('es-GT') : '—'
const hoy = new Date().toISOString().slice(0, 10)

// ---------- listado ----------
const ordenes = ref<OrdenResumen[]>([])
const cargando = ref(false)
const errorLista = ref('')
const buscar = ref('')
const filtroEstado = ref('ABIERTAS')
const aviso = ref('')

async function cargar() {
  cargando.value = true
  errorLista.value = ''
  try {
    ordenes.value = await ordenesApi.listar(buscar.value, filtroEstado.value)
  } catch (e) {
    errorLista.value = (e as Error).message
  } finally {
    cargando.value = false
  }
}

let timer: ReturnType<typeof setTimeout>
watch(buscar, () => { clearTimeout(timer); timer = setTimeout(cargar, 300) })
watch(filtroEstado, cargar)
onMounted(cargar)

function mostrarAviso(texto: string) {
  aviso.value = texto
  setTimeout(() => (aviso.value = ''), 3500)
}

// ---------- nueva orden ----------
const dlgNueva = ref<HTMLDialogElement>()
const clientes = ref<OpcionCliente[]>([])
const equipos = ref<OpcionEquipo[]>([])
const cargandoEquipos = ref(false)
const guardando = ref(false)
const errorNueva = ref('')
const errores = reactive<Record<string, string>>({})

const vacia = () => ({
  clienteId: 0,
  equipoId: 0,
  problemaReportado: '',
  prioridad: 'MEDIA' as Prioridad,
  fechaEstimada: '',
  observaciones: '',
})
const nueva = reactive(vacia())

function limpiarErrores() {
  errorNueva.value = ''
  Object.keys(errores).forEach((k) => delete errores[k])
}

async function abrirNueva() {
  Object.assign(nueva, vacia())
  equipos.value = []
  limpiarErrores()
  dlgNueva.value?.showModal()
  try {
    clientes.value = await ordenesApi.clientesActivos()
  } catch (e) {
    errorNueva.value = (e as Error).message
  }
}

// al cambiar de cliente se cargan solo sus equipos
watch(() => nueva.clienteId, async (id) => {
  nueva.equipoId = 0
  equipos.value = []
  if (!id) return
  cargandoEquipos.value = true
  try {
    equipos.value = await ordenesApi.equiposDeCliente(id)
  } catch (e) {
    errorNueva.value = (e as Error).message
  } finally {
    cargandoEquipos.value = false
  }
})

// Validación en la interfaz (el procedimiento vuelve a validar todo)
function validarNueva(): boolean {
  limpiarErrores()
  if (!nueva.clienteId) errores.clienteId = 'Seleccione el cliente.'
  if (!nueva.equipoId) errores.equipoId = 'Seleccione el equipo.'
  if (!nueva.problemaReportado.trim()) errores.problemaReportado = 'Describa el problema que reporta el cliente.'
  if (nueva.fechaEstimada && nueva.fechaEstimada < hoy)
    errores.fechaEstimada = 'La fecha estimada no puede ser anterior a hoy.'
  return Object.keys(errores).length === 0
}

async function guardarNueva() {
  if (!validarNueva()) return
  guardando.value = true
  try {
    const r = await ordenesApi.crear({
      clienteId: nueva.clienteId,
      equipoId: nueva.equipoId,
      usuarioRecepcionId: usuarioId.value,
      problemaReportado: nueva.problemaReportado.trim(),
      prioridad: nueva.prioridad,
      fechaEstimada: nueva.fechaEstimada || null,
      observaciones: nueva.observaciones.trim() || null,
    })
    dlgNueva.value?.close()
    mostrarAviso(`Orden ${r.numeroOrden} registrada.`)
    await cargar()
  } catch (e) {
    errorNueva.value = (e as Error).message
  } finally {
    guardando.value = false
  }
}

// ---------- detalle, historial y cambio de estado ----------
const dlgDetalle = ref<HTMLDialogElement>()
const actual = ref<OrdenResumen | null>(null)
const historial = ref<HistorialEstado[]>([])
const cargandoHistorial = ref(false)
const estadoNuevoId = ref(0)
const observacion = ref('')
const cambiando = ref(false)
const errorCambio = ref('')

const opcionesEstado = computed(() =>
  actual.value ? (TRANSICIONES[actual.value.estadoId] ?? []).map((id) => ESTADOS[id - 1]) : [])
const cerrada = computed(() => !!actual.value && (actual.value.estadoId === 6 || actual.value.estadoId === 7))

async function cargarHistorial() {
  if (!actual.value) return
  cargandoHistorial.value = true
  try {
    historial.value = await ordenesApi.historial(actual.value.ordenId)
  } catch (e) {
    errorCambio.value = (e as Error).message
  } finally {
    cargandoHistorial.value = false
  }
}

async function abrirDetalle(o: OrdenResumen) {
  actual.value = { ...o }
  historial.value = []
  estadoNuevoId.value = 0
  observacion.value = ''
  errorCambio.value = ''
  dlgDetalle.value?.showModal()
  await cargarHistorial()
}

async function cambiarEstado() {
  if (!actual.value) return
  errorCambio.value = ''
  if (!estadoNuevoId.value) { errorCambio.value = 'Seleccione el nuevo estado.'; return }
  if (estadoNuevoId.value === 7 && !observacion.value.trim()) {
    errorCambio.value = 'Indique el motivo de la cancelación.'
    return
  }
  cambiando.value = true
  try {
    await ordenesApi.cambiarEstado(
      actual.value.ordenId, estadoNuevoId.value, usuarioId.value, observacion.value.trim() || null)
    const est = ESTADOS[estadoNuevoId.value - 1]
    actual.value.estadoId = est.id
    actual.value.estado = est.codigo
    estadoNuevoId.value = 0
    observacion.value = ''
    mostrarAviso(`${actual.value.numeroOrden} pasó a ${est.nombre}.`)
    await Promise.all([cargarHistorial(), cargar()])
  } catch (e) {
    errorCambio.value = (e as Error).message
  } finally {
    cambiando.value = false
  }
}
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <div>
        <h1>Órdenes de servicio</h1>
        <p class="sub">Ingreso de equipos y seguimiento de su estado.</p>
      </div>
      <div class="cabecera-der">
        <button v-if="puedeCrear" class="btn primario" @click="abrirNueva">Nueva orden</button>
      </div>
    </header>

    <p v-if="aviso" class="aviso" role="status">{{ aviso }}</p>

    <section class="filtros">
      <label class="campo grande">
        <span>Buscar</span>
        <input v-model="buscar" type="search" placeholder="Número de orden, cliente o número de serie" />
      </label>
      <label class="campo">
        <span>Estado</span>
        <select v-model="filtroEstado">
          <option value="ABIERTAS">Abiertas</option>
          <option v-for="e in ESTADOS" :key="e.id" :value="e.codigo">{{ e.nombre }}</option>
          <option value="">Todas</option>
        </select>
      </label>
    </section>

    <p v-if="errorLista" class="error" role="alert">{{ errorLista }}</p>

    <div class="tabla-wrap">
      <table>
        <thead>
          <tr>
            <th>Orden</th><th>Cliente</th><th>Equipo</th><th>Prioridad</th><th>Estado</th><th>Ingreso</th><th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="cargando"><td colspan="7" class="vacio">Cargando órdenes…</td></tr>
          <tr v-else-if="!ordenes.length">
            <td colspan="7" class="vacio">No hay órdenes con ese criterio. Use «Nueva orden» para registrar un ingreso.</td>
          </tr>
          <tr v-for="o in ordenes" :key="o.ordenId">
            <td class="num">{{ o.numeroOrden }}</td>
            <td>{{ o.cliente }}</td>
            <td>
              {{ o.tipoEquipo }} · {{ o.equipo }}
              <div class="serie">{{ o.numeroSerie }}</div>
            </td>
            <td><span class="prio" :class="o.prioridad.toLowerCase()">{{ o.prioridad }}</span></td>
            <td><span class="chip" :class="'e' + o.estadoId">{{ nombreEstado(o.estado) }}</span></td>
            <td class="fecha">{{ fechaHora(o.fechaIngreso) }}</td>
            <td class="acciones"><button class="btn enlace" @click="abrirDetalle(o)">Ver</button></td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Nueva orden -->
    <dialog ref="dlgNueva" class="modal">
      <form @submit.prevent="guardarNueva" novalidate>
        <h2>Nueva orden de servicio</h2>
        <p class="nota">Recibe: <b>{{ usuario.nombreCompleto }}</b> ({{ usuario.rol }})</p>
        <p v-if="errorNueva" class="error" role="alert">{{ errorNueva }}</p>

        <label class="campo">
          <span>Cliente</span>
          <select v-model.number="nueva.clienteId" :aria-invalid="!!errores.clienteId">
            <option :value="0" disabled>Seleccione un cliente…</option>
            <option v-for="c in clientes" :key="c.clienteId" :value="c.clienteId">
              {{ c.nombreRazonSocial }} — NIT {{ c.nit }}
            </option>
          </select>
          <small v-if="errores.clienteId">{{ errores.clienteId }}</small>
        </label>

        <label class="campo">
          <span>Equipo</span>
          <select v-model.number="nueva.equipoId" :disabled="!nueva.clienteId || cargandoEquipos"
                  :aria-invalid="!!errores.equipoId">
            <option :value="0" disabled>
              {{ !nueva.clienteId ? 'Primero seleccione el cliente' : cargandoEquipos ? 'Cargando equipos…'
                : equipos.length ? 'Seleccione un equipo…' : 'El cliente no tiene equipos registrados' }}
            </option>
            <option v-for="e in equipos" :key="e.equipoId" :value="e.equipoId">
              {{ e.tipoEquipo }} {{ e.marca }} {{ e.modelo }} — Serie {{ e.numeroSerie }}
            </option>
          </select>
          <small v-if="errores.equipoId">{{ errores.equipoId }}</small>
        </label>

        <label class="campo">
          <span>Problema reportado</span>
          <textarea v-model="nueva.problemaReportado" rows="3" maxlength="500"
                    placeholder="Lo que dice el cliente que le pasa al equipo"
                    :aria-invalid="!!errores.problemaReportado"></textarea>
          <small v-if="errores.problemaReportado">{{ errores.problemaReportado }}</small>
        </label>

        <div class="fila">
          <label class="campo">
            <span>Prioridad</span>
            <select v-model="nueva.prioridad">
              <option v-for="p in PRIORIDADES" :key="p" :value="p">{{ p }}</option>
            </select>
          </label>
          <label class="campo">
            <span>Fecha estimada (opcional)</span>
            <input v-model="nueva.fechaEstimada" type="date" :min="hoy" :aria-invalid="!!errores.fechaEstimada" />
            <small v-if="errores.fechaEstimada">{{ errores.fechaEstimada }}</small>
          </label>
        </div>

        <label class="campo">
          <span>Observaciones (opcional)</span>
          <textarea v-model="nueva.observaciones" rows="2" maxlength="500"
                    placeholder="Accesorios que deja, estado físico, etc."></textarea>
        </label>

        <div class="botones">
          <button type="button" class="btn" @click="dlgNueva?.close()">Cancelar</button>
          <button type="submit" class="btn primario" :disabled="guardando">
            {{ guardando ? 'Registrando…' : 'Registrar orden' }}
          </button>
        </div>
      </form>
    </dialog>

    <!-- Detalle de la orden -->
    <dialog ref="dlgDetalle" class="modal ancho">
      <div v-if="actual" class="detalle">
        <div class="det-cabecera">
          <h2>{{ actual.numeroOrden }}</h2>
          <span class="chip" :class="'e' + actual.estadoId">{{ nombreEstado(actual.estado) }}</span>
        </div>

        <dl class="datos">
          <div><dt>Cliente</dt><dd>{{ actual.cliente }}</dd></div>
          <div><dt>Equipo</dt><dd>{{ actual.tipoEquipo }} · {{ actual.equipo }}</dd></div>
          <div><dt>Número de serie</dt><dd class="num">{{ actual.numeroSerie }}</dd></div>
          <div><dt>Recibido por</dt><dd>{{ actual.recibidoPor }}</dd></div>
          <div><dt>Ingreso</dt><dd>{{ fechaHora(actual.fechaIngreso) }}</dd></div>
          <div><dt>Fecha estimada</dt><dd>{{ fecha(actual.fechaEstimada) }}</dd></div>
          <div><dt>Prioridad</dt><dd><span class="prio" :class="actual.prioridad.toLowerCase()">{{ actual.prioridad }}</span></dd></div>
          <div class="completo"><dt>Problema reportado</dt><dd>{{ actual.problemaReportado }}</dd></div>
          <div v-if="actual.observaciones" class="completo"><dt>Observaciones</dt><dd>{{ actual.observaciones }}</dd></div>
        </dl>

        <h3>Historial de estados</h3>
        <div class="tabla-wrap">
          <table class="compacta">
            <thead><tr><th>Fecha</th><th>De</th><th>A</th><th>Usuario</th><th>Observación</th></tr></thead>
            <tbody>
              <tr v-if="cargandoHistorial"><td colspan="5" class="vacio">Cargando historial…</td></tr>
              <tr v-for="h in historial" :key="h.historialId">
                <td class="fecha">{{ fechaHora(h.fechaCambio) }}</td>
                <td>{{ h.estadoAnterior ? nombreEstado(h.estadoAnterior) : '(inicio)' }}</td>
                <td>{{ nombreEstado(h.estadoNuevo) }}</td>
                <td>{{ h.usuario }}</td>
                <td>{{ h.observacion ?? '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <h3>Cambiar estado</h3>
        <p v-if="!puedeCambiarEstado && !cerrada && actual.estadoId !== 5" class="nota">
          No tiene permiso para cambiar el estado de la orden (requiere CAMBIAR_ESTADO_ORDEN).
        </p>
        <p v-else-if="cerrada" class="nota">La orden está cerrada ({{ nombreEstado(actual.estado) }}) y ya no admite cambios.</p>
        <p v-else-if="actual.estadoId === 5" class="nota">
          La orden está lista. El paso a Entregado se hace desde Entrega, después de facturar y pagar.
        </p>
        <form v-else-if="puedeCambiarEstado && actual.estadoId !== 5" class="cambio" @submit.prevent="cambiarEstado" novalidate>
          <p v-if="errorCambio" class="error" role="alert">{{ errorCambio }}</p>
          <div class="fila">
            <label class="campo">
              <span>Nuevo estado</span>
              <select v-model.number="estadoNuevoId">
                <option :value="0" disabled>Seleccione…</option>
                <option v-for="e in opcionesEstado" :key="e.id" :value="e.id">{{ e.nombre }}</option>
              </select>
            </label>
            <label class="campo">
              <span>Observación {{ estadoNuevoId === 7 ? '(obligatoria)' : '(opcional)' }}</span>
              <input v-model="observacion" maxlength="300"
                     :placeholder="estadoNuevoId === 7 ? 'Motivo de la cancelación' : ''" />
            </label>
          </div>
          <p class="nota">Cambia: <b>{{ usuario.nombreCompleto }}</b> ({{ usuario.rol }})</p>
          <div class="botones">
            <button type="submit" class="btn primario" :disabled="cambiando">
              {{ cambiando ? 'Guardando…' : 'Cambiar estado' }}
            </button>
          </div>
        </form>

        <div class="botones">
          <button type="button" class="btn" @click="dlgDetalle?.close()">Cerrar</button>
        </div>
      </div>
    </dialog>
  </main>
</template>

<style scoped>
.pagina { max-width: 1180px; margin: 0 auto; padding: 32px 24px 64px; text-align: left; color: #222b38; }
.cabecera { display: flex; justify-content: space-between; align-items: flex-end; gap: 16px; flex-wrap: wrap;
  border-bottom: 3px solid #c8962e; padding-bottom: 16px; margin-bottom: 24px; }
.cabecera-der { display: flex; align-items: flex-end; gap: 12px; flex-wrap: wrap; }
.usuario { min-width: 220px; }
h1 { margin: 0; font: 700 28px/1.2 Georgia, 'Times New Roman', serif; color: #17375e; }
h2 { margin: 0; font: 700 22px/1.2 Georgia, serif; color: #17375e; }
h3 { margin: 8px 0 0; font: 700 17px/1.2 Georgia, serif; color: #17375e; }
.sub { margin: 4px 0 0; color: #5a6472; font-size: 15px; }

.filtros { display: flex; gap: 16px; margin-bottom: 16px; flex-wrap: wrap; }
.campo { display: flex; flex-direction: column; gap: 4px; font-size: 14px; }
.campo span { font-weight: 600; color: #17375e; }
.campo.grande { flex: 1; min-width: 240px; }
input, select, textarea { font: inherit; font-size: 15px; padding: 9px 10px; border: 1px solid #b9c2d0; border-radius: 4px;
  background: #fff; color: #222b38; box-sizing: border-box; width: 100%; }
textarea { resize: vertical; }
select:disabled { background: #f1f3f7; color: #7b8594; }
input:focus-visible, select:focus-visible, textarea:focus-visible, .btn:focus-visible { outline: 3px solid #c8962e; outline-offset: 1px; }
[aria-invalid='true'] { border-color: #a32a2a; }
small { color: #a32a2a; font-size: 13px; }

.tabla-wrap { overflow-x: auto; border: 1px solid #d0d7e2; border-radius: 4px; }
table { width: 100%; border-collapse: collapse; font-size: 15px; }
th { background: #17375e; color: #fff; text-align: left; padding: 10px 12px; font-weight: 600; white-space: nowrap; }
td { padding: 10px 12px; border-top: 1px solid #e3e8f0; vertical-align: middle; }
tbody tr:nth-child(even) { background: #f4f6fa; }
table.compacta { font-size: 14px; }
table.compacta th, table.compacta td { padding: 7px 10px; }
.num { font-variant-numeric: tabular-nums; white-space: nowrap; font-weight: 600; color: #17375e; }
.serie { font-size: 13px; color: #5a6472; font-variant-numeric: tabular-nums; }
.fecha { white-space: nowrap; font-variant-numeric: tabular-nums; }
.vacio { text-align: center; color: #5a6472; padding: 28px 12px; }
.acciones { text-align: right; }

.chip { padding: 2px 10px; border-radius: 999px; font-size: 13px; font-weight: 600; white-space: nowrap; }
.chip.e1 { background: #e3ecf8; color: #17375e; }
.chip.e2 { background: #fff1d6; color: #7a5200; }
.chip.e3 { background: #f6e3f3; color: #7a2a6c; }
.chip.e4 { background: #dcefff; color: #0d4f8a; }
.chip.e5 { background: #dff3e4; color: #1d6b34; }
.chip.e6 { background: #ececec; color: #3c4450; }
.chip.e7 { background: #fbe4e4; color: #8a1f1f; }
.prio { font-size: 12px; font-weight: 700; letter-spacing: 0.02em; padding: 2px 8px; border-radius: 3px; border: 1px solid; }
.prio.baja { color: #5a6472; border-color: #b9c2d0; }
.prio.media { color: #17375e; border-color: #8aa2c4; }
.prio.alta { color: #8a5200; border-color: #d9a441; background: #fff7e6; }
.prio.urgente { color: #fff; border-color: #a32a2a; background: #a32a2a; }

.btn { font: inherit; font-size: 15px; padding: 9px 16px; border-radius: 4px; border: 1px solid #b9c2d0;
  background: #fff; color: #17375e; cursor: pointer; }
.btn.primario { background: #17375e; border-color: #17375e; color: #fff; font-weight: 600; }
.btn.primario:hover:not(:disabled) { background: #0f2a4a; }
.btn:disabled { opacity: 0.6; cursor: wait; }
.btn.enlace { border: none; background: none; padding: 4px 8px; text-decoration: underline; }

.aviso { background: #dff3e4; color: #1d6b34; padding: 10px 14px; border-radius: 4px; margin: 0 0 16px; }
.error { background: #fbe4e4; color: #8a1f1f; padding: 10px 14px; border-radius: 4px; margin: 0; }
.nota { margin: 0; color: #5a6472; font-size: 14px; }

.modal { border: none; border-radius: 6px; padding: 28px; width: min(560px, 92vw);
  box-shadow: 0 20px 50px rgba(15, 42, 74, 0.35); }
.modal.ancho { width: min(820px, 94vw); }
.modal::backdrop { background: rgba(15, 42, 74, 0.5); }
.modal form, .detalle { display: flex; flex-direction: column; gap: 14px; text-align: left; }
.cambio { border: 1px solid #d0d7e2; border-radius: 4px; padding: 14px; background: #f8f9fc; }
.fila { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
.botones { display: flex; justify-content: flex-end; gap: 10px; }
.det-cabecera { display: flex; align-items: center; gap: 12px; }
.datos { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px 20px; margin: 0;
  padding: 14px; background: #f4f6fa; border-radius: 4px; }
.datos div { min-width: 0; }
.datos .completo { grid-column: 1 / -1; }
.datos dt { font-size: 13px; font-weight: 600; color: #5a6472; }
.datos dd { margin: 2px 0 0; overflow-wrap: anywhere; }

@media (max-width: 700px) {
  .fila, .datos { grid-template-columns: 1fr; }
  .cabecera { flex-direction: column; align-items: stretch; }
}
</style>
