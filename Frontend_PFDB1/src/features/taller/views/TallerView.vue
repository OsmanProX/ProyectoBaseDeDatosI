<script setup lang="ts">
// Semana 3 — Pantalla del taller: el técnico toma una orden y registra
// diagnóstico → (cliente autoriza) → reparación con actividades y repuestos → finaliza.
// Acceso: ADMINISTRADOR y TECNICO (menú, router y policy "Taller" del backend).
// Las reglas (estados, stock, roles) las valida la base en los procedimientos del script 04.
import { computed, onMounted, reactive, ref, watch } from 'vue'
import {
  tallerApi, ESTADOS_TALLER,
  type OrdenTaller, type DetalleTaller, type RepuestoDisponible,
} from '../api/taller'

const moneda = (n: number | null | undefined) =>
  (n ?? 0).toLocaleString('es-GT', { style: 'currency', currency: 'GTQ' })
const fechaHora = (iso: string) =>
  new Date(iso).toLocaleString('es-GT', { dateStyle: 'short', timeStyle: 'short' })
const fecha = (iso: string | null) =>
  iso ? new Date(iso.length === 10 ? iso + 'T00:00:00' : iso).toLocaleDateString('es-GT') : '—'
const nombreEstado = (id: number) => ESTADOS_TALLER.find((e) => e.id === id)?.nombre ?? ''

// ---------- listado ----------
const ordenes = ref<OrdenTaller[]>([])
const cargando = ref(false)
const errorLista = ref('')
const aviso = ref('')
const filtroEstado = ref(0)
const buscar = ref('')

async function cargar() {
  cargando.value = true
  errorLista.value = ''
  try {
    ordenes.value = await tallerApi.ordenes(filtroEstado.value || undefined)
  } catch (e) {
    errorLista.value = (e as Error).message
  } finally {
    cargando.value = false
  }
}

const visibles = computed(() => {
  const t = buscar.value.trim().toLowerCase()
  return ordenes.value.filter((o) =>
    !t || [o.numeroOrden, o.cliente, o.equipo, o.numeroSerie, o.tecnicoResponsable]
      .some((v) => v.toLowerCase().includes(t)))
})

watch(filtroEstado, cargar)
onMounted(cargar)

function mostrarAviso(texto: string) {
  aviso.value = texto
  setTimeout(() => (aviso.value = ''), 4000)
}

// ---------- detalle de la orden seleccionada ----------
const seleccionId = ref<number | null>(null)
const detalle = ref<DetalleTaller | null>(null)
const cargandoDetalle = ref(false)
const errorDetalle = ref('')
const repuestos = ref<RepuestoDisponible[]>([])

async function abrir(ordenId: number) {
  seleccionId.value = ordenId
  await recargarDetalle()
}

async function recargarDetalle() {
  if (!seleccionId.value) return
  cargandoDetalle.value = true
  errorDetalle.value = ''
  try {
    detalle.value = await tallerApi.detalle(seleccionId.value)
    limpiarFormularios()
    if (detalle.value.reparacion?.estado === 'EN_PROCESO')
      repuestos.value = await tallerApi.repuestosDisponibles()
  } catch (e) {
    detalle.value = null
    errorDetalle.value = (e as Error).message
  } finally {
    cargandoDetalle.value = false
  }
}

const orden = computed(() => detalle.value?.orden ?? null)
const rep = computed(() => detalle.value?.reparacion ?? null)
const enProceso = computed(() => rep.value?.estado === 'EN_PROCESO')

// Qué paso toca, según el estado de la orden y lo que ya existe
const paso = computed<'diagnostico' | 'autorizacion' | 'reparacion' | 'listo' | 'otro'>(() => {
  const d = detalle.value
  if (!d) return 'otro'
  const e = d.orden.estadoOrdenId
  if (!d.diagnostico && (e === 1 || e === 2)) return 'diagnostico'
  if (d.diagnostico && !d.reparacion && (e === 3 || e === 4)) return 'autorizacion'
  if (d.reparacion?.estado === 'EN_PROCESO') return 'reparacion'
  if (e === 5) return 'listo'
  return 'otro'
})

const totalRepuestos = computed(() =>
  (detalle.value?.repuestos ?? []).reduce((s, r) => s + r.subtotal, 0))
const totalHoras = computed(() =>
  (detalle.value?.actividades ?? []).reduce((s, a) => s + (a.horasTrabajadas ?? 0), 0))

// ---------- formularios ----------
const fDiag = reactive({ descripcion: '', costo: 0, observaciones: '' })
const fInicio = reactive({ descripcion: '' })
const fAct = reactive({ descripcion: '', horas: '' as string | number })
const fRep = reactive({ clave: '', cantidad: 1 })
const fFin = reactive({ costo: 0, descripcion: '' })
const errores = reactive<Record<string, string>>({})
const enviando = ref('')

function limpiarFormularios() {
  Object.assign(fDiag, { descripcion: '', costo: 0, observaciones: '' })
  fInicio.descripcion = ''
  Object.assign(fAct, { descripcion: '', horas: '' })
  Object.assign(fRep, { clave: '', cantidad: 1 })
  Object.assign(fFin, {
    costo: rep.value?.costoManoObra ?? 0,
    descripcion: rep.value?.descripcionTrabajo ?? '',
  })
  Object.keys(errores).forEach((k) => delete errores[k])
}

// La opción del repuesto combina repuesto y bodega: "repuestoId-bodegaId"
const repuestoElegido = computed(() =>
  repuestos.value.find((r) => `${r.repuestoId}-${r.bodegaId}` === fRep.clave) ?? null)

// Ejecuta una acción del taller, muestra el error donde corresponde y recarga
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

function registrarDiagnostico() {
  if (!orden.value) return
  if (!fDiag.descripcion.trim()) return void (errores.diagnostico = 'Escriba la descripción del diagnóstico.')
  if (fDiag.costo < 0) return void (errores.diagnostico = 'El costo estimado no puede ser negativo.')
  const o = orden.value
  ejecutar('diagnostico', () => tallerApi.registrarDiagnostico({
    ordenId: o.ordenId,
    descripcion: fDiag.descripcion.trim(),
    costoManoObraEstimado: Number(fDiag.costo) || 0,
    observaciones: fDiag.observaciones.trim() || null,
  }), `Diagnóstico de ${o.numeroOrden} registrado. Queda esperando la autorización del cliente.`)
}

function iniciarReparacion() {
  if (!orden.value) return
  const o = orden.value
  ejecutar('inicio', () => tallerApi.iniciarReparacion({
    ordenId: o.ordenId,
    descripcionTrabajo: fInicio.descripcion.trim() || null,
  }), `Reparación de ${o.numeroOrden} iniciada.`)
}

function registrarActividad() {
  if (!rep.value) return
  const horas = fAct.horas === '' ? null : Number(fAct.horas)
  if (!fAct.descripcion.trim()) return void (errores.actividad = 'Describa la actividad realizada.')
  if (horas !== null && !(horas > 0)) return void (errores.actividad = 'Las horas deben ser mayores que cero.')
  const r = rep.value
  ejecutar('actividad', () => tallerApi.registrarActividad({
    reparacionId: r.reparacionId, descripcion: fAct.descripcion.trim(), horasTrabajadas: horas,
  }), 'Actividad registrada.')
}

function asignarRepuesto() {
  if (!rep.value) return
  const elegido = repuestoElegido.value
  if (!elegido) return void (errores.repuesto = 'Seleccione el repuesto y la bodega.')
  const cantidad = Math.trunc(Number(fRep.cantidad))
  if (!(cantidad > 0)) return void (errores.repuesto = 'La cantidad debe ser mayor que cero.')
  if (cantidad > elegido.existencia)
    return void (errores.repuesto = `Solo hay ${elegido.existencia} en la bodega ${elegido.bodega}.`)
  const r = rep.value
  ejecutar('repuesto', () => tallerApi.asignarRepuesto({
    reparacionId: r.reparacionId, repuestoId: elegido.repuestoId, bodegaId: elegido.bodegaId, cantidad,
  }), `${cantidad} × ${elegido.repuesto} asignado(s) y descontado(s) de ${elegido.bodega}.`)
}

function finalizar() {
  if (!rep.value || !orden.value) return
  if (fFin.costo < 0) return void (errores.finalizar = 'El costo de mano de obra no puede ser negativo.')
  if (!fFin.descripcion.trim()) return void (errores.finalizar = 'Describa el trabajo realizado antes de finalizar.')
  const r = rep.value
  const o = orden.value
  ejecutar('finalizar', () => tallerApi.finalizarReparacion({
    reparacionId: r.reparacionId,
    costoManoObra: Number(fFin.costo) || 0,
    descripcionTrabajo: fFin.descripcion.trim(),
  }), `Reparación de ${o.numeroOrden} finalizada. La orden queda LISTO.`)
}
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <div>
        <h1>Taller</h1>
        <p class="sub">Diagnóstico, reparación, actividades y repuestos de las órdenes abiertas.</p>
      </div>
      <button class="btn" :disabled="cargando" @click="cargar">Actualizar</button>
    </header>

    <p v-if="aviso" class="aviso" role="status">{{ aviso }}</p>

    <div class="mesa">
      <!-- Lista de órdenes -->
      <section class="lista" aria-label="Órdenes del taller">
        <div class="filtros">
          <label class="campo grande">
            <span>Buscar</span>
            <input v-model="buscar" type="search" placeholder="Orden, cliente, equipo o serie" />
          </label>
          <label class="campo">
            <span>Estado</span>
            <select v-model.number="filtroEstado">
              <option :value="0">Todos</option>
              <option v-for="e in ESTADOS_TALLER" :key="e.id" :value="e.id">{{ e.nombre }}</option>
            </select>
          </label>
        </div>

        <p v-if="errorLista" class="error" role="alert">{{ errorLista }}</p>
        <p v-if="cargando" class="vacio">Cargando órdenes…</p>
        <p v-else-if="!visibles.length" class="vacio">No hay órdenes con ese criterio.</p>
        <ul v-else class="tarjetas">
          <li v-for="o in visibles" :key="o.ordenId">
            <button class="tarjeta" :class="{ activa: o.ordenId === seleccionId }" @click="abrir(o.ordenId)">
              <span class="t-fila">
                <b class="num">{{ o.numeroOrden }}</b>
                <span class="prio" :class="o.prioridad.toLowerCase()">{{ o.prioridad }}</span>
              </span>
              <span class="t-cliente">{{ o.cliente }}</span>
              <span class="detalle">{{ o.tipoEquipo }} · {{ o.equipo }}</span>
              <span class="t-fila">
                <span class="estado" :class="'e' + o.estadoOrdenId">{{ nombreEstado(o.estadoOrdenId) }}</span>
                <span class="detalle">{{ o.diasAbierta }} día(s)</span>
              </span>
            </button>
          </li>
        </ul>
      </section>

      <!-- Detalle -->
      <section class="panel" aria-live="polite">
        <p v-if="!seleccionId" class="vacio">Seleccione una orden de la lista para trabajarla.</p>
        <p v-else-if="cargandoDetalle && !detalle" class="vacio">Cargando orden…</p>
        <p v-else-if="errorDetalle" class="error" role="alert">{{ errorDetalle }}</p>

        <template v-else-if="detalle && orden">
          <div class="panel-cab">
            <div>
              <h2>{{ orden.numeroOrden }}</h2>
              <p class="sub">{{ orden.cliente }} · {{ orden.tipoEquipo }} {{ orden.equipo }} · Serie {{ orden.numeroSerie }}</p>
            </div>
            <span class="estado grande" :class="'e' + orden.estadoOrdenId">{{ nombreEstado(orden.estadoOrdenId) }}</span>
          </div>

          <dl class="datos">
            <div><dt>Ingreso</dt><dd>{{ fecha(orden.fechaIngreso) }}</dd></div>
            <div><dt>Fecha estimada</dt><dd>{{ fecha(orden.fechaEstimada) }}</dd></div>
            <div><dt>Recibido por</dt><dd>{{ orden.recibidoPor }}</dd></div>
            <div><dt>Técnico</dt><dd>{{ orden.tecnicoResponsable }}</dd></div>
            <div class="ancho"><dt>Problema reportado</dt><dd>{{ orden.problemaReportado }}</dd></div>
          </dl>

          <!-- Pasos del proceso -->
          <ol class="pasos" aria-label="Avance">
            <li :class="{ hecho: !!detalle.diagnostico, actual: paso === 'diagnostico' }">Diagnóstico</li>
            <li :class="{ hecho: !!rep, actual: paso === 'autorizacion' }">Autorización</li>
            <li :class="{ hecho: rep?.estado === 'FINALIZADA', actual: paso === 'reparacion' }">Reparación</li>
            <li :class="{ hecho: orden.estadoOrdenId === 5, actual: paso === 'listo' }">Listo</li>
          </ol>

          <!-- 1. Diagnóstico -->
          <article class="bloque">
            <h3>1. Diagnóstico</h3>
            <template v-if="detalle.diagnostico">
              <p>{{ detalle.diagnostico.descripcion }}</p>
              <p class="nota">
                {{ detalle.diagnostico.tecnico }} · {{ fechaHora(detalle.diagnostico.fechaDiagnostico) }} ·
                Mano de obra estimada {{ moneda(detalle.diagnostico.costoManoObraEstimado) }}
              </p>
              <p v-if="detalle.diagnostico.observaciones" class="nota">Obs.: {{ detalle.diagnostico.observaciones }}</p>
            </template>
            <form v-else-if="paso === 'diagnostico'" novalidate @submit.prevent="registrarDiagnostico">
              <label class="campo">
                <span>Descripción del diagnóstico</span>
                <textarea
                  v-model="fDiag.descripcion" rows="3" maxlength="500"
                  placeholder="Qué falla tiene el equipo y qué hay que hacer"></textarea>
              </label>
              <div class="fila">
                <label class="campo">
                  <span>Mano de obra estimada (Q)</span>
                  <input v-model.number="fDiag.costo" type="number" min="0" step="0.01" />
                </label>
                <label class="campo">
                  <span>Observaciones (opcional)</span>
                  <input v-model="fDiag.observaciones" maxlength="300" />
                </label>
              </div>
              <p v-if="errores.diagnostico" class="error" role="alert">{{ errores.diagnostico }}</p>
              <div class="botones">
                <button type="submit" class="btn primario" :disabled="enviando === 'diagnostico'">
                  {{ enviando === 'diagnostico' ? 'Guardando…' : 'Registrar diagnóstico' }}
                </button>
              </div>
            </form>
            <p v-else class="nota">Sin diagnóstico.</p>
          </article>

          <!-- 2. Autorización del cliente / inicio de la reparación -->
          <article v-if="detalle.diagnostico" class="bloque">
            <h3>2. Autorización del cliente</h3>
            <p v-if="rep" class="nota">El cliente autorizó. Reparación iniciada el {{ fechaHora(rep.fechaInicio) }}</p>
            <form v-else-if="paso === 'autorizacion'" novalidate @submit.prevent="iniciarReparacion">
              <p class="nota">
                Cuando el cliente autorice el diagnóstico, inicie la reparación.
                Si no autoriza, la orden se cancela desde «Órdenes».
              </p>
              <label class="campo">
                <span>Plan de trabajo (opcional)</span>
                <input v-model="fInicio.descripcion" maxlength="500" placeholder="Ej. Cambio de pantalla y limpieza interna" />
              </label>
              <p v-if="errores.inicio" class="error" role="alert">{{ errores.inicio }}</p>
              <div class="botones">
                <button type="submit" class="btn primario" :disabled="enviando === 'inicio'">
                  {{ enviando === 'inicio' ? 'Iniciando…' : 'Cliente autorizó: iniciar reparación' }}
                </button>
              </div>
            </form>
            <p v-else class="nota">La orden no está en un estado que permita iniciar la reparación.</p>
          </article>

          <!-- 3. Reparación -->
          <article v-if="rep" class="bloque">
            <h3>3. Reparación <span class="chip" :class="rep.estado.toLowerCase()">{{ rep.estado === 'EN_PROCESO' ? 'En proceso' : rep.estado === 'FINALIZADA' ? 'Finalizada' : 'Cancelada' }}</span></h3>
            <p v-if="rep.descripcionTrabajo">{{ rep.descripcionTrabajo }}</p>
            <p class="nota">
              {{ rep.tecnico }} · Inicio {{ fechaHora(rep.fechaInicio) }}
              <template v-if="rep.fechaFin"> · Fin {{ fechaHora(rep.fechaFin) }}</template>
              · Mano de obra {{ moneda(rep.costoManoObra) }}
            </p>

            <!-- Actividades -->
            <h4>Actividades <span class="nota">({{ totalHoras }} h)</span></h4>
            <div class="tabla-wrap">
              <table>
                <thead><tr><th>#</th><th>Actividad</th><th>Horas</th><th>Fecha</th></tr></thead>
                <tbody>
                  <tr v-if="!detalle.actividades.length"><td colspan="4" class="vacio">Sin actividades registradas.</td></tr>
                  <tr v-for="a in detalle.actividades" :key="a.numeroActividad">
                    <td class="num">{{ a.numeroActividad }}</td>
                    <td>{{ a.descripcion }}</td>
                    <td>{{ a.horasTrabajadas ?? '—' }}</td>
                    <td class="detalle">{{ fechaHora(a.fechaRegistro) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <form v-if="enProceso" class="en-linea" novalidate @submit.prevent="registrarActividad">
              <label class="campo grande">
                <span>Nueva actividad</span>
                <input v-model="fAct.descripcion" maxlength="300" placeholder="Ej. Se reemplazó la pantalla" />
              </label>
              <label class="campo corto">
                <span>Horas</span>
                <input v-model="fAct.horas" type="number" min="0" step="0.25" placeholder="—" />
              </label>
              <button type="submit" class="btn primario" :disabled="enviando === 'actividad'">Agregar</button>
            </form>
            <p v-if="errores.actividad" class="error" role="alert">{{ errores.actividad }}</p>

            <!-- Repuestos -->
            <h4>Repuestos <span class="nota">({{ moneda(totalRepuestos) }})</span></h4>
            <div class="tabla-wrap">
              <table>
                <thead><tr><th>Código</th><th>Repuesto</th><th>Bodega</th><th>Cant.</th><th>Precio</th><th>Subtotal</th></tr></thead>
                <tbody>
                  <tr v-if="!detalle.repuestos.length"><td colspan="6" class="vacio">Sin repuestos asignados.</td></tr>
                  <tr v-for="r in detalle.repuestos" :key="r.codigo + r.bodega">
                    <td class="num">{{ r.codigo }}</td>
                    <td>{{ r.repuesto }}</td>
                    <td>{{ r.bodega }}</td>
                    <td>{{ r.cantidad }}</td>
                    <td>{{ moneda(r.precioVentaUnitario) }}</td>
                    <td>{{ moneda(r.subtotal) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
            <form v-if="enProceso" class="en-linea" novalidate @submit.prevent="asignarRepuesto">
              <label class="campo grande">
                <span>Repuesto y bodega</span>
                <select v-model="fRep.clave">
                  <option value="" disabled>Seleccione…</option>
                  <option v-for="r in repuestos" :key="`${r.repuestoId}-${r.bodegaId}`" :value="`${r.repuestoId}-${r.bodegaId}`">
                    {{ r.codigo }} · {{ r.repuesto }} — {{ r.bodega }} (hay {{ r.existencia }}) · {{ moneda(r.precioVenta) }}
                  </option>
                </select>
              </label>
              <label class="campo corto">
                <span>Cantidad</span>
                <input v-model.number="fRep.cantidad" type="number" min="1" step="1" />
              </label>
              <button type="submit" class="btn primario" :disabled="enviando === 'repuesto'">Asignar</button>
            </form>
            <p v-if="enProceso && !repuestos.length" class="nota">No hay repuestos con existencia en ninguna bodega.</p>
            <p v-if="errores.repuesto" class="error" role="alert">{{ errores.repuesto }}</p>

            <!-- Finalizar -->
            <form v-if="enProceso" class="cierre" novalidate @submit.prevent="finalizar">
              <h4>Finalizar reparación</h4>
              <div class="fila">
                <label class="campo">
                  <span>Mano de obra final (Q)</span>
                  <input v-model.number="fFin.costo" type="number" min="0" step="0.01" />
                </label>
                <label class="campo">
                  <span>Trabajo realizado</span>
                  <input v-model="fFin.descripcion" maxlength="500" placeholder="Resumen para la factura y el cliente" />
                </label>
              </div>
              <p v-if="errores.finalizar" class="error" role="alert">{{ errores.finalizar }}</p>
              <div class="botones">
                <button type="submit" class="btn primario" :disabled="enviando === 'finalizar'">
                  {{ enviando === 'finalizar' ? 'Finalizando…' : 'Finalizar: orden LISTO' }}
                </button>
              </div>
            </form>
          </article>

          <p v-if="paso === 'listo'" class="aviso">
            Reparación terminada. Total sin IVA: <b>{{ moneda(orden.totalSinIVA) }}</b>. Sigue facturar y entregar.
          </p>
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
h3 { margin: 0 0 8px; font-size: 17px; color: var(--c-title); display: flex; align-items: center; gap: 10px; }
h4 { margin: 14px 0 6px; font-size: 15px; color: var(--c-title); }
.sub { margin: 4px 0 0; color: var(--c-muted); font-size: 15px; }

.mesa { display: grid; grid-template-columns: minmax(300px, 380px) 1fr; gap: 24px; align-items: start; }
.lista { display: flex; flex-direction: column; gap: 12px; min-width: 0; }
.panel { border: 1px solid var(--c-border); border-radius: 6px; padding: 20px; background: var(--c-surface);
  display: flex; flex-direction: column; gap: 16px; min-height: 240px; min-width: 0; }

.filtros { display: flex; gap: 12px; flex-wrap: wrap; }
.campo { display: flex; flex-direction: column; gap: 4px; font-size: 14px; min-width: 140px; }
.campo span { font-weight: 600; color: var(--c-title); }
.campo.grande { flex: 1; min-width: 200px; }
.campo.corto { width: 110px; min-width: 0; }
input, select, textarea { font: inherit; font-size: 15px; padding: 9px 10px; border: 1px solid var(--c-input); border-radius: 4px;
  background: var(--c-surface); color: var(--c-text); box-sizing: border-box; width: 100%; }
textarea { resize: vertical; }
input:focus-visible, select:focus-visible, textarea:focus-visible, .btn:focus-visible, .tarjeta:focus-visible {
  outline: 3px solid #c8962e; outline-offset: 1px; }

.tarjetas { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px;
  max-height: calc(100vh - 260px); overflow-y: auto; }
.tarjeta { width: 100%; text-align: left; font: inherit; color: var(--c-text); background: var(--c-surface);
  border: 1px solid var(--c-border); border-left: 4px solid var(--c-border); border-radius: 4px; padding: 10px 12px;
  display: flex; flex-direction: column; gap: 3px; cursor: pointer; }
.tarjeta:hover { background: var(--c-row); }
.tarjeta.activa { background: var(--c-sel); border-left-color: #c8962e; }
.t-fila { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.t-cliente { font-weight: 600; }

.panel-cab { display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; flex-wrap: wrap; }
.datos { display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px 16px; margin: 0; }
.datos div { min-width: 0; }
.datos .ancho { grid-column: 1 / -1; }
dt { font-size: 13px; color: var(--c-muted); }
dd { margin: 0; font-weight: 600; }

.pasos { display: flex; list-style: none; margin: 0; padding: 0; gap: 4px; counter-reset: paso; }
.pasos li { flex: 1; text-align: center; font-size: 13px; padding: 6px 4px; border-bottom: 4px solid var(--c-border); color: var(--c-muted); }
.pasos li.hecho { border-color: #2f8a4c; color: var(--c-text); }
.pasos li.actual { border-color: #c8962e; color: var(--c-title); font-weight: 700; }

.bloque { border-top: 1px solid var(--c-border); padding-top: 14px; }
.bloque > p { margin: 0 0 6px; }
.bloque form { display: flex; flex-direction: column; gap: 10px; }
.bloque form.en-linea { flex-direction: row; align-items: flex-end; flex-wrap: wrap; margin-top: 10px; }
.cierre { margin-top: 18px; padding: 14px; border: 1px dashed var(--c-input); border-radius: 4px; }
.cierre h4 { margin-top: 0; }

.tabla-wrap { overflow-x: auto; border: 1px solid var(--c-border); border-radius: 4px; }
table { width: 100%; border-collapse: collapse; font-size: 14px; }
th { background: #17375e; color: #fff; text-align: left; padding: 8px 10px; font-weight: 600; white-space: nowrap; }
td { padding: 8px 10px; border-top: 1px solid var(--c-border); vertical-align: top; }
tbody tr:nth-child(even) { background: var(--c-row); }
.num { font-variant-numeric: tabular-nums; white-space: nowrap; font-weight: 600; color: var(--c-title); }
.detalle { font-size: 13px; color: var(--c-muted); }
.vacio { text-align: center; color: var(--c-muted); padding: 24px 12px; margin: 0; }

.prio { font-size: 12px; font-weight: 700; letter-spacing: 0.02em; padding: 2px 8px; border-radius: 3px; border: 1px solid; }
.prio.baja { color: #5a6472; border-color: #b9c2d0; }
.prio.media { color: #17375e; border-color: #8aa2c4; }
.prio.alta { color: #8a5200; border-color: #d9a441; background: #fff7e6; }
.prio.urgente { color: #fff; border-color: #a32a2a; background: #a32a2a; }
:root.dark .prio.baja { color: #a3b2c9; border-color: #475569; }
:root.dark .prio.media { color: #c7d2fe; border-color: #6477a8; }

.estado { font-size: 12px; font-weight: 700; padding: 2px 8px; border-radius: 999px; background: #e7ecf3; color: #17375e; white-space: nowrap; }
.estado.grande { font-size: 14px; padding: 4px 12px; }
.estado.e2 { background: #e6f0fb; color: #1d4f8a; }
.estado.e3 { background: #fff2d6; color: #7a4c00; }
.estado.e4 { background: #ece6fb; color: #4b2a8a; }
.estado.e5 { background: #dff3e4; color: #1d6b34; }

.chip { padding: 2px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; white-space: nowrap; }
.chip.en_proceso { background: #ece6fb; color: #4b2a8a; }
.chip.finalizada { background: #dff3e4; color: #1d6b34; }
.chip.cancelada { background: #ececec; color: #3c4450; }

.btn { font: inherit; font-size: 15px; padding: 9px 16px; border-radius: 4px; border: 1px solid var(--c-input);
  background: var(--c-surface); color: var(--c-title); cursor: pointer; }
.btn.primario { background: #17375e; border-color: var(--c-title); color: #fff; font-weight: 600; }
.btn.primario:hover:not(:disabled) { background: #0f2a4a; }
.btn:disabled { opacity: 0.6; cursor: wait; }

.aviso { background: #dff3e4; color: #1d6b34; padding: 10px 14px; border-radius: 4px; margin: 0 0 16px; }
.panel .aviso { margin: 0; }
.error { background: #fbe4e4; color: #8a1f1f; padding: 10px 14px; border-radius: 4px; margin: 0; }
.nota { margin: 0; color: var(--c-muted); font-size: 14px; font-weight: 400; }
.fila { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.fila .campo { min-width: 0; }
.botones { display: flex; justify-content: flex-end; gap: 10px; }

@media (max-width: 900px) {
  .mesa { grid-template-columns: 1fr; }
  .tarjetas { max-height: 320px; }
  .datos { grid-template-columns: 1fr 1fr; }
}
@media (max-width: 600px) {
  .pagina { padding: 24px 16px 48px; }
  .panel { padding: 14px; }
  .fila { grid-template-columns: 1fr; }
  .campo { min-width: 0; flex: 1 1 100%; }
  .campo.corto { width: auto; }
}
</style>
