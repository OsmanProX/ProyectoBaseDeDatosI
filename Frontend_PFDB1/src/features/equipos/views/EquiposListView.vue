<script setup lang="ts">
// Pantalla de equipos: listado, registro, edición y desactivación.
// Acceso: ADMINISTRADOR y RECEPCION (menú, router y policy GestionarEquipos del backend).
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useAuthStore } from '@/features/auth/stores/auth.store'
import {
  equiposApi,
  type Equipo, type TipoEquipo, type ClienteOpcion, type DatosEquipo,
} from '../api/equipos'

const auth = useAuthStore()
// Mismos roles que la policy del backend (Program.cs)
const puedeEditar = computed(() => ['ADMINISTRADOR', 'RECEPCION'].includes(auth.rol))

// ---------- catálogos ----------
const tipos = ref<TipoEquipo[]>([])
const clientes = ref<ClienteOpcion[]>([])
const clientesActivos = computed(() => clientes.value.filter((c) => c.estado === 'ACTIVO'))

// ---------- listado ----------
const equipos = ref<Equipo[]>([])
const cargando = ref(false)
const errorLista = ref('')
const aviso = ref('')
const buscar = ref('')
const filtroCliente = ref(0)
const filtroEstado = ref<'ACTIVO' | 'INACTIVO' | ''>('ACTIVO')

async function cargar() {
  cargando.value = true
  errorLista.value = ''
  try {
    equipos.value = await equiposApi.listar(filtroCliente.value || undefined)
  } catch (e) {
    errorLista.value = (e as Error).message
  } finally {
    cargando.value = false
  }
}

const visibles = computed(() => {
  const texto = buscar.value.trim().toLowerCase()
  return equipos.value.filter((e) =>
    (!filtroEstado.value || e.estado === filtroEstado.value) &&
    (!texto || [e.numeroSerie, e.marca, e.modelo, e.nombreCliente, e.nombreTipoEquipo]
      .some((v) => v.toLowerCase().includes(texto))))
})

watch(filtroCliente, cargar)

onMounted(async () => {
  try {
    ;[tipos.value, clientes.value] = await Promise.all([equiposApi.tipos(), equiposApi.clientes()])
  } catch (e) {
    errorLista.value = (e as Error).message
  }
  await cargar()
})

function mostrarAviso(texto: string) {
  aviso.value = texto
  setTimeout(() => (aviso.value = ''), 3500)
}

// ---------- registrar / editar ----------
const dlgEquipo = ref<HTMLDialogElement>()
const editando = ref<Equipo | null>(null)
const guardando = ref(false)
const errorForm = ref('')
const errores = reactive<Record<string, string>>({})

const vacio = () => ({ clienteId: 0, tipoEquipoId: 0, marca: '', modelo: '', numeroSerie: '', descripcion: '' })
const form = reactive(vacio())

function limpiarErrores() {
  errorForm.value = ''
  Object.keys(errores).forEach((k) => delete errores[k])
}

function abrirNuevo() {
  editando.value = null
  Object.assign(form, vacio(), { clienteId: filtroCliente.value || 0 })
  limpiarErrores()
  dlgEquipo.value?.showModal()
}

function abrirEditar(e: Equipo) {
  editando.value = e
  Object.assign(form, {
    clienteId: e.clienteId, tipoEquipoId: e.tipoEquipoId, marca: e.marca, modelo: e.modelo,
    numeroSerie: e.numeroSerie, descripcion: e.descripcion ?? '',
  })
  limpiarErrores()
  dlgEquipo.value?.showModal()
}

// Validación en la interfaz (la API y la base vuelven a validar)
function validar(): boolean {
  limpiarErrores()
  if (!form.clienteId) errores.clienteId = 'Seleccione el cliente.'
  if (!form.tipoEquipoId) errores.tipoEquipoId = 'Seleccione el tipo de equipo.'
  if (!form.marca.trim()) errores.marca = 'Escriba la marca.'
  if (!form.modelo.trim()) errores.modelo = 'Escriba el modelo.'
  const serie = form.numeroSerie.trim()
  if (!serie) errores.numeroSerie = 'Escriba el número de serie.'
  else if (!/^[A-Za-z0-9][A-Za-z0-9-]*$/.test(serie))
    errores.numeroSerie = 'Use solo letras, números y guiones, sin espacios.'
  return Object.keys(errores).length === 0
}

async function guardar() {
  if (!validar()) return
  const datos: DatosEquipo = {
    clienteId: form.clienteId,
    tipoEquipoId: form.tipoEquipoId,
    marca: form.marca.trim(),
    modelo: form.modelo.trim(),
    numeroSerie: form.numeroSerie.trim().toUpperCase(),
    descripcion: form.descripcion.trim() || null,
  }
  guardando.value = true
  try {
    if (editando.value) {
      await equiposApi.actualizar(editando.value.equipoId, datos)
      mostrarAviso(`Equipo ${datos.numeroSerie} actualizado.`)
    } else {
      await equiposApi.crear(datos)
      mostrarAviso(`Equipo ${datos.numeroSerie} registrado.`)
    }
    dlgEquipo.value?.close()
    await cargar()
  } catch (e) {
    errorForm.value = (e as Error).message
  } finally {
    guardando.value = false
  }
}

// ---------- desactivar ----------
const dlgDesactivar = ref<HTMLDialogElement>()
const porDesactivar = ref<Equipo | null>(null)
const desactivando = ref(false)
const errorDesactivar = ref('')

function pedirDesactivar(e: Equipo) {
  porDesactivar.value = e
  errorDesactivar.value = ''
  dlgDesactivar.value?.showModal()
}

async function desactivar() {
  if (!porDesactivar.value) return
  desactivando.value = true
  errorDesactivar.value = ''
  try {
    await equiposApi.desactivar(porDesactivar.value.equipoId)
    mostrarAviso(`Equipo ${porDesactivar.value.numeroSerie} desactivado.`)
    dlgDesactivar.value?.close()
    await cargar()
  } catch (e) {
    errorDesactivar.value = (e as Error).message
  } finally {
    desactivando.value = false
  }
}

// ---------- activar (deshace el desactivar; el cliente debe estar activo) ----------
const activando = ref<number | null>(null)

async function activar(e: Equipo) {
  activando.value = e.equipoId
  errorLista.value = ''
  try {
    await equiposApi.activar(e.equipoId)
    mostrarAviso(`Equipo ${e.numeroSerie} activo de nuevo.`)
    await cargar()
  } catch (err) {
    errorLista.value = (err as Error).message
  } finally {
    activando.value = null
  }
}
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <div>
        <h1>Equipos</h1>
        <p class="sub">Equipos de cada cliente. El número de serie identifica al equipo en todas sus órdenes.</p>
      </div>
      <button v-if="puedeEditar" class="btn primario" @click="abrirNuevo">Nuevo equipo</button>
    </header>

    <p v-if="aviso" class="aviso" role="status">{{ aviso }}</p>
    <p v-if="!puedeEditar" class="nota solo-lectura">Su rol solo permite consultar equipos.</p>

    <section class="filtros">
      <label class="campo grande">
        <span>Buscar</span>
        <input v-model="buscar" type="search" placeholder="Número de serie, marca, modelo o cliente" />
      </label>
      <label class="campo">
        <span>Cliente</span>
        <select v-model.number="filtroCliente">
          <option :value="0">Todos</option>
          <option v-for="c in clientes" :key="c.clienteId" :value="c.clienteId">{{ c.nombreRazonSocial }}</option>
        </select>
      </label>
      <label class="campo">
        <span>Estado</span>
        <select v-model="filtroEstado">
          <option value="ACTIVO">Activos</option>
          <option value="INACTIVO">Inactivos</option>
          <option value="">Todos</option>
        </select>
      </label>
    </section>

    <p v-if="errorLista" class="error" role="alert">{{ errorLista }}</p>

    <div class="tabla-wrap">
      <table>
        <thead>
          <tr>
            <th>Número de serie</th><th>Tipo</th><th>Marca y modelo</th><th>Cliente</th><th>Estado</th><th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="cargando"><td colspan="6" class="vacio">Cargando equipos…</td></tr>
          <tr v-else-if="!visibles.length">
            <td colspan="6" class="vacio">
              No hay equipos con ese criterio.<template v-if="puedeEditar"> Use «Nuevo equipo» para registrar uno.</template>
            </td>
          </tr>
          <template v-else>
            <tr v-for="e in visibles" :key="e.equipoId">
              <td class="num">{{ e.numeroSerie }}</td>
              <td>{{ e.nombreTipoEquipo }}</td>
              <td>
                {{ e.marca }} {{ e.modelo }}
                <div v-if="e.descripcion" class="detalle">{{ e.descripcion }}</div>
              </td>
              <td>{{ e.nombreCliente }}</td>
              <td><span class="chip" :class="e.estado.toLowerCase()">{{ e.estado === 'ACTIVO' ? 'Activo' : 'Inactivo' }}</span></td>
              <td class="acciones">
                <template v-if="puedeEditar && e.estado === 'ACTIVO'">
                  <button class="btn enlace" @click="abrirEditar(e)">Editar</button>
                  <button class="btn enlace peligro" @click="pedirDesactivar(e)">Desactivar</button>
                </template>
                <button
                  v-else-if="puedeEditar"
                  class="btn enlace"
                  :disabled="activando === e.equipoId"
                  @click="activar(e)"
                >
                  {{ activando === e.equipoId ? 'Activando…' : 'Activar' }}
                </button>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>

    <!-- Registrar / editar -->
    <dialog ref="dlgEquipo" class="modal">
      <form novalidate @submit.prevent="guardar">
        <h2>{{ editando ? 'Editar equipo' : 'Nuevo equipo' }}</h2>
        <p v-if="errorForm" class="error" role="alert">{{ errorForm }}</p>

        <label class="campo">
          <span>Cliente</span>
          <select v-model.number="form.clienteId" :disabled="!!editando" :aria-invalid="!!errores.clienteId">
            <option :value="0" disabled>Seleccione un cliente…</option>
            <option v-for="c in (editando ? clientes : clientesActivos)" :key="c.clienteId" :value="c.clienteId">
              {{ c.nombreRazonSocial }} — NIT {{ c.nit }}
            </option>
          </select>
          <small v-if="errores.clienteId">{{ errores.clienteId }}</small>
        </label>

        <div class="fila">
          <label class="campo">
            <span>Tipo de equipo</span>
            <select v-model.number="form.tipoEquipoId" :aria-invalid="!!errores.tipoEquipoId">
              <option :value="0" disabled>Seleccione…</option>
              <option v-for="t in tipos" :key="t.tipoEquipoId" :value="t.tipoEquipoId">{{ t.nombre }}</option>
            </select>
            <small v-if="errores.tipoEquipoId">{{ errores.tipoEquipoId }}</small>
          </label>
          <label class="campo">
            <span>Número de serie</span>
            <input
v-model="form.numeroSerie" maxlength="50" :disabled="!!editando" autocomplete="off"
                   placeholder="Ej. HP5CD1234XYZ" :aria-invalid="!!errores.numeroSerie" />
            <small v-if="errores.numeroSerie">{{ errores.numeroSerie }}</small>
          </label>
        </div>

        <div class="fila">
          <label class="campo">
            <span>Marca</span>
            <input v-model="form.marca" maxlength="50" :aria-invalid="!!errores.marca" />
            <small v-if="errores.marca">{{ errores.marca }}</small>
          </label>
          <label class="campo">
            <span>Modelo</span>
            <input v-model="form.modelo" maxlength="50" :aria-invalid="!!errores.modelo" />
            <small v-if="errores.modelo">{{ errores.modelo }}</small>
          </label>
        </div>

        <label class="campo">
          <span>Descripción (opcional)</span>
          <textarea
v-model="form.descripcion" rows="2" maxlength="200"
                    placeholder="Color, accesorios, uso que le da el cliente…"></textarea>
        </label>

        <p v-if="editando" class="nota">El cliente y el número de serie no se cambian, para no alterar el historial del equipo.</p>

        <div class="botones">
          <button type="button" class="btn" @click="dlgEquipo?.close()">Cancelar</button>
          <button type="submit" class="btn primario" :disabled="guardando">
            {{ guardando ? 'Guardando…' : editando ? 'Guardar cambios' : 'Registrar equipo' }}
          </button>
        </div>
      </form>
    </dialog>

    <!-- Confirmar desactivación -->
    <dialog ref="dlgDesactivar" class="modal">
      <div v-if="porDesactivar" class="confirmar">
        <h2>Desactivar equipo</h2>
        <p>
          ¿Desactivar el equipo <b>{{ porDesactivar.numeroSerie }}</b> ({{ porDesactivar.marca }} {{ porDesactivar.modelo }})
          de {{ porDesactivar.nombreCliente }}?
        </p>
        <p class="nota">No se borra: queda como inactivo y conserva su historial de órdenes.</p>
        <p v-if="errorDesactivar" class="error" role="alert">{{ errorDesactivar }}</p>
        <div class="botones">
          <button type="button" class="btn" @click="dlgDesactivar?.close()">Cancelar</button>
          <button type="button" class="btn peligro-lleno" :disabled="desactivando" @click="desactivar">
            {{ desactivando ? 'Desactivando…' : 'Desactivar' }}
          </button>
        </div>
      </div>
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
.pagina { max-width: 1180px; margin: 0 auto; padding: 32px 24px 64px; text-align: left; color: var(--c-text); }
.cabecera { display: flex; justify-content: space-between; align-items: flex-end; gap: 16px; flex-wrap: wrap;
  border-bottom: 3px solid #c8962e; padding-bottom: 16px; margin-bottom: 24px; }
h1 { margin: 0; font: 700 28px/1.2 Georgia, 'Times New Roman', serif; color: var(--c-title); }
h2 { margin: 0; font: 700 22px/1.2 Georgia, serif; color: var(--c-title); }
.sub { margin: 4px 0 0; color: var(--c-muted); font-size: 15px; }

.filtros { display: flex; gap: 16px; margin-bottom: 16px; flex-wrap: wrap; }
.campo { display: flex; flex-direction: column; gap: 4px; font-size: 14px; min-width: 180px; }
.campo span { font-weight: 600; color: var(--c-title); }
.campo.grande { flex: 1; min-width: 240px; }
input, select, textarea { font: inherit; font-size: 15px; padding: 9px 10px; border: 1px solid var(--c-input); border-radius: 4px;
  background: var(--c-surface); color: var(--c-text); box-sizing: border-box; width: 100%; }
textarea { resize: vertical; }
input:disabled, select:disabled { background: var(--c-disabled); color: var(--c-muted); }
input:focus-visible, select:focus-visible, textarea:focus-visible, .btn:focus-visible { outline: 3px solid #c8962e; outline-offset: 1px; }
[aria-invalid='true'] { border-color: #a32a2a; }
small { color: #a32a2a; font-size: 13px; }

.tabla-wrap { overflow-x: auto; border: 1px solid var(--c-border); border-radius: 4px; }
table { width: 100%; border-collapse: collapse; font-size: 15px; }
th { background: #17375e; color: #fff; text-align: left; padding: 10px 12px; font-weight: 600; white-space: nowrap; }
td { padding: 10px 12px; border-top: 1px solid var(--c-border); vertical-align: middle; }
tbody tr:nth-child(even) { background: var(--c-row); }
.num { font-variant-numeric: tabular-nums; white-space: nowrap; font-weight: 600; color: var(--c-title); }
.detalle { font-size: 13px; color: var(--c-muted); }
.vacio { text-align: center; color: var(--c-muted); padding: 28px 12px; }
.acciones { text-align: right; white-space: nowrap; }

.chip { padding: 2px 10px; border-radius: 999px; font-size: 13px; font-weight: 600; white-space: nowrap; }
.chip.activo { background: #dff3e4; color: #1d6b34; }
.chip.inactivo { background: #ececec; color: #3c4450; }

.btn { font: inherit; font-size: 15px; padding: 9px 16px; border-radius: 4px; border: 1px solid var(--c-input);
  background: var(--c-surface); color: var(--c-title); cursor: pointer; }
.btn.primario { background: #17375e; border-color: var(--c-title); color: #fff; font-weight: 600; }
.btn.primario:hover:not(:disabled) { background: #0f2a4a; }
.btn:disabled { opacity: 0.6; cursor: wait; }
.btn.enlace { border: none; background: none; padding: 4px 8px; text-decoration: underline; }
.btn.enlace.peligro { color: var(--c-danger); }
.btn.peligro-lleno { background: #a32a2a; border-color: #a32a2a; color: #fff; font-weight: 600; }

.aviso { background: #dff3e4; color: #1d6b34; padding: 10px 14px; border-radius: 4px; margin: 0 0 16px; }
.error { background: #fbe4e4; color: #8a1f1f; padding: 10px 14px; border-radius: 4px; margin: 0 0 16px; }
.modal .error { margin: 0; }
.nota { margin: 0; color: var(--c-muted); font-size: 14px; }
.solo-lectura { margin-bottom: 16px; }

.modal { border: none; border-radius: 6px; padding: 28px; width: min(560px, 92vw);
  box-shadow: 0 20px 50px rgba(15, 42, 74, 0.35); }
.modal::backdrop { background: rgba(15, 42, 74, 0.5); }
.modal form, .confirmar { display: flex; flex-direction: column; gap: 14px; text-align: left; }
.confirmar p { margin: 0; }
.fila { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
.fila .campo { min-width: 0; }
.botones { display: flex; justify-content: flex-end; gap: 10px; }

@media (max-width: 700px) {
  .fila { grid-template-columns: 1fr; }
  .cabecera { flex-direction: column; align-items: stretch; }
  .campo { min-width: 0; flex: 1 1 100%; }
}
</style>
