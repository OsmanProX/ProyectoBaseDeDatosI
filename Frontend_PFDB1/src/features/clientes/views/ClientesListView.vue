<script setup lang="ts">
// Pantalla de clientes (Jeyling) conectada a /api/cliente.
// Acceso: ADMINISTRADOR y RECEPCION (menú, router y policy GestionarClientes del backend).
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useAuthStore } from '@/features/auth/stores/auth.store'
import {
  clientesApi,
  type Cliente, type ClienteForm, type EstadoCliente,
} from '../api/clientes'

const auth = useAuthStore()
// Mismos roles que la policy del backend (Program.cs)
const puedeEditar = computed(() => ['ADMINISTRADOR', 'RECEPCION'].includes(auth.rol))

// ---------- listado ----------
const clientes = ref<Cliente[]>([])
const cargando = ref(false)
const errorLista = ref('')
const buscar = ref('')
const filtroEstado = ref<'' | EstadoCliente>('ACTIVO')
const aviso = ref('')

async function cargar() {
  cargando.value = true
  errorLista.value = ''
  try {
    clientes.value = await clientesApi.listar(buscar.value, filtroEstado.value)
  } catch (e) {
    errorLista.value = (e as Error).message
  } finally {
    cargando.value = false
  }
}

// Busqueda con pequena espera para no consultar en cada tecla
let timer: ReturnType<typeof setTimeout>
watch(buscar, () => { clearTimeout(timer); timer = setTimeout(cargar, 300) })
watch(filtroEstado, cargar)
onMounted(cargar)

function mostrarAviso(texto: string) {
  aviso.value = texto
  setTimeout(() => (aviso.value = ''), 3500)
}

// ---------- formulario (crear / editar) ----------
const dialogo = ref<HTMLDialogElement>()
const editandoId = ref<number | null>(null)
const guardando = ref(false)
const errorForm = ref('')
const errores = reactive<Record<string, string>>({})

const vacio = (): ClienteForm => ({
  tipoCliente: 'INDIVIDUAL', nombreRazonSocial: '', nit: '', telefono: '', correo: '', direccion: '',
})
const form = reactive<ClienteForm>(vacio())

function limpiarErrores() {
  errorForm.value = ''
  Object.keys(errores).forEach((k) => delete errores[k])
}

function abrirNuevo() {
  editandoId.value = null
  Object.assign(form, vacio())
  limpiarErrores()
  dialogo.value?.showModal()
}

function abrirEditar(c: Cliente) {
  editandoId.value = c.clienteId
  Object.assign(form, {
    tipoCliente: c.tipoCliente, nombreRazonSocial: c.nombreRazonSocial, nit: c.nit,
    telefono: c.telefono, correo: c.correo ?? '', direccion: c.direccion ?? '',
  })
  limpiarErrores()
  dialogo.value?.showModal()
}

// Validacion en la interfaz (el backend vuelve a validar)
function validar(): boolean {
  limpiarErrores()
  if (!form.nombreRazonSocial.trim()) errores.nombreRazonSocial = 'Escriba el nombre o la razón social.'
  if (!form.nit.trim()) errores.nit = 'Escriba el NIT.'
  else if (!/^(CF|[0-9]{1,13}-?[0-9Kk])$/i.test(form.nit.trim()))
    errores.nit = 'NIT inválido. Ejemplo: 1234567-8, o CF si es consumidor final.'
  if (!form.telefono.trim()) errores.telefono = 'Escriba un teléfono.'
  if (form.correo.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.correo.trim()))
    errores.correo = 'Correo inválido.'
  return Object.keys(errores).length === 0
}

async function guardar() {
  if (!validar()) return
  guardando.value = true
  try {
    if (editandoId.value === null) {
      await clientesApi.crear({ ...form })
      mostrarAviso('Cliente registrado.')
    } else {
      await clientesApi.editar(editandoId.value, { ...form })
      mostrarAviso('Cambios guardados.')
    }
    dialogo.value?.close()
    await cargar()
  } catch (e) {
    errorForm.value = (e as Error).message
    if (/NIT/.test(errorForm.value)) errores.nit = 'Ya existe un cliente con este NIT.'
  } finally {
    guardando.value = false
  }
}

// ---------- desactivar (no se elimina: regla R14, conserva su historial) ----------
const dlgDesactivar = ref<HTMLDialogElement>()
const porDesactivar = ref<Cliente | null>(null)
const desactivando = ref(false)
const errorDesactivar = ref('')

function pedirDesactivar(c: Cliente) {
  porDesactivar.value = c
  errorDesactivar.value = ''
  dlgDesactivar.value?.showModal()
}

async function desactivar() {
  if (!porDesactivar.value) return
  desactivando.value = true
  errorDesactivar.value = ''
  try {
    await clientesApi.desactivar(porDesactivar.value.clienteId)
    mostrarAviso(`${porDesactivar.value.nombreRazonSocial} quedó inactivo.`)
    dlgDesactivar.value?.close()
    await cargar()
  } catch (e) {
    errorDesactivar.value = (e as Error).message
  } finally {
    desactivando.value = false
  }
}
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <div>
        <h1>Clientes</h1>
        <p class="sub">Personas y empresas que entregan equipos a TechCare.</p>
      </div>
      <button v-if="puedeEditar" class="btn primario" @click="abrirNuevo">Nuevo cliente</button>
    </header>

    <p v-if="aviso" class="aviso" role="status">{{ aviso }}</p>
    <p v-if="!puedeEditar" class="nota solo-lectura">Su rol solo permite consultar clientes.</p>

    <section class="filtros">
      <label class="campo grande">
        <span>Buscar</span>
        <input v-model="buscar" type="search" placeholder="NIT o nombre" />
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
            <th>NIT</th><th>Nombre</th><th>Tipo</th><th>Teléfono</th><th>Correo</th><th>Estado</th><th></th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="cargando"><td colspan="7" class="vacio">Cargando clientes…</td></tr>
          <tr v-else-if="!clientes.length">
            <td colspan="7" class="vacio">
              No hay clientes con ese criterio.<template v-if="puedeEditar"> Use «Nuevo cliente» para registrar uno.</template>
            </td>
          </tr>
          <tr v-for="c in clientes" :key="c.clienteId" :class="{ inactivo: c.estado === 'INACTIVO' }">
            <td class="nit">{{ c.nit }}</td>
            <td>{{ c.nombreRazonSocial }}</td>
            <td>{{ c.tipoCliente === 'INDIVIDUAL' ? 'Individual' : 'Empresarial' }}</td>
            <td>{{ c.telefono }}</td>
            <td>{{ c.correo ?? '—' }}</td>
            <td><span class="chip" :class="c.estado.toLowerCase()">{{ c.estado === 'ACTIVO' ? 'Activo' : 'Inactivo' }}</span></td>
            <td class="acciones">
              <template v-if="puedeEditar && c.estado === 'ACTIVO'">
                <button class="btn enlace" @click="abrirEditar(c)">Editar</button>
                <button class="btn enlace peligro" @click="pedirDesactivar(c)">Desactivar</button>
              </template>
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <dialog ref="dialogo" class="modal">
      <form novalidate @submit.prevent="guardar">
        <h2>{{ editandoId === null ? 'Nuevo cliente' : 'Editar cliente' }}</h2>
        <p v-if="errorForm" class="error" role="alert">{{ errorForm }}</p>

        <fieldset class="tipo">
          <legend>Tipo de cliente</legend>
          <label><input v-model="form.tipoCliente" type="radio" value="INDIVIDUAL" /> Individual</label>
          <label><input v-model="form.tipoCliente" type="radio" value="EMPRESARIAL" /> Empresarial</label>
        </fieldset>

        <label class="campo">
          <span>{{ form.tipoCliente === 'EMPRESARIAL' ? 'Razón social' : 'Nombre completo' }}</span>
          <input v-model="form.nombreRazonSocial" maxlength="150" :aria-invalid="!!errores.nombreRazonSocial" />
          <small v-if="errores.nombreRazonSocial">{{ errores.nombreRazonSocial }}</small>
        </label>

        <div class="fila">
          <label class="campo">
            <span>NIT</span>
            <input v-model="form.nit" maxlength="15" placeholder="1234567-8 o CF" :aria-invalid="!!errores.nit" />
            <small v-if="errores.nit">{{ errores.nit }}</small>
          </label>
          <label class="campo">
            <span>Teléfono</span>
            <input v-model="form.telefono" maxlength="15" :aria-invalid="!!errores.telefono" />
            <small v-if="errores.telefono">{{ errores.telefono }}</small>
          </label>
        </div>

        <label class="campo">
          <span>Correo (opcional)</span>
          <input v-model="form.correo" type="email" maxlength="100" :aria-invalid="!!errores.correo" />
          <small v-if="errores.correo">{{ errores.correo }}</small>
        </label>

        <label class="campo">
          <span>Dirección (opcional)</span>
          <input v-model="form.direccion" maxlength="200" :aria-invalid="!!errores.direccion" />
          <small v-if="errores.direccion">{{ errores.direccion }}</small>
        </label>

        <div class="botones">
          <button type="button" class="btn" @click="dialogo?.close()">Cancelar</button>
          <button type="submit" class="btn primario" :disabled="guardando">
            {{ guardando ? 'Guardando…' : 'Guardar cliente' }}
          </button>
        </div>
      </form>
    </dialog>

    <!-- Confirmar desactivación -->
    <dialog ref="dlgDesactivar" class="modal">
      <div v-if="porDesactivar" class="confirmar">
        <h2>Desactivar cliente</h2>
        <p>¿Desactivar a <b>{{ porDesactivar.nombreRazonSocial }}</b> (NIT {{ porDesactivar.nit }})?</p>
        <p class="nota">No se borra: queda inactivo, no puede recibir nuevas órdenes y conserva su historial.</p>
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
.pagina { max-width: 1080px; margin: 0 auto; padding: 32px 24px 64px; text-align: left; color: var(--c-text); }
.cabecera { display: flex; justify-content: space-between; align-items: flex-end; gap: 16px;
  border-bottom: 3px solid #c8962e; padding-bottom: 16px; margin-bottom: 24px; }
h1 { margin: 0; font: 700 28px/1.2 Georgia, 'Times New Roman', serif; color: var(--c-title); letter-spacing: 0; }
h2 { margin: 0 0 16px; font: 700 22px/1.2 Georgia, serif; color: var(--c-title); letter-spacing: 0; }
.sub { margin: 4px 0 0; color: var(--c-muted); font-size: 15px; }

.filtros { display: flex; gap: 16px; margin-bottom: 16px; flex-wrap: wrap; }
.campo { display: flex; flex-direction: column; gap: 4px; font-size: 14px; }
.campo span { font-weight: 600; color: var(--c-title); }
.campo.grande { flex: 1; min-width: 220px; }
input, select { font: inherit; font-size: 15px; padding: 9px 10px; border: 1px solid var(--c-input); border-radius: 4px;
  background: var(--c-surface); color: var(--c-text); box-sizing: border-box; width: 100%; }
input:focus-visible, select:focus-visible, .btn:focus-visible { outline: 3px solid #c8962e; outline-offset: 1px; }
input[aria-invalid='true'] { border-color: #a32a2a; }
small { color: #a32a2a; font-size: 13px; }

.tabla-wrap { overflow-x: auto; border: 1px solid var(--c-border); border-radius: 4px; }
table { width: 100%; border-collapse: collapse; font-size: 15px; }
th { background: #17375e; color: #fff; text-align: left; padding: 10px 12px; font-weight: 600; white-space: nowrap; }
td { padding: 10px 12px; border-top: 1px solid var(--c-border); vertical-align: middle; }
tbody tr:nth-child(even) { background: var(--c-row); }
tr.inactivo td { color: var(--c-muted); }
.nit { font-variant-numeric: tabular-nums; white-space: nowrap; }
.vacio { text-align: center; color: var(--c-muted); padding: 28px 12px; }
.acciones { white-space: nowrap; text-align: right; }

.chip { padding: 2px 10px; border-radius: 999px; font-size: 13px; font-weight: 600; }
.chip.activo { background: #dff3e4; color: #1d6b34; }
.chip.inactivo { background: #ececec; color: #5a6472; }

.btn { font: inherit; font-size: 15px; padding: 9px 16px; border-radius: 4px; border: 1px solid var(--c-input);
  background: var(--c-surface); color: var(--c-title); cursor: pointer; }
.btn.primario { background: #17375e; border-color: var(--c-title); color: #fff; font-weight: 600; }
.btn.primario:hover:not(:disabled) { background: #0f2a4a; }
.btn:disabled { opacity: 0.6; cursor: wait; }
.btn.enlace { border: none; background: none; padding: 4px 8px; text-decoration: underline; }

.aviso { background: #dff3e4; color: #1d6b34; padding: 10px 14px; border-radius: 4px; margin: 0 0 16px; }
.error { background: #fbe4e4; color: #8a1f1f; padding: 10px 14px; border-radius: 4px; margin: 0 0 16px; }

.modal { border: none; border-radius: 6px; padding: 28px; width: min(520px, 92vw);
  box-shadow: 0 20px 50px rgba(15, 42, 74, 0.35); }
.modal::backdrop { background: rgba(15, 42, 74, 0.5); }
.modal form, .confirmar { display: flex; flex-direction: column; gap: 14px; text-align: left; }
.confirmar p { margin: 0; }
.confirmar h2 { margin: 0; }
.btn.enlace.peligro { color: var(--c-danger); }
.btn.peligro-lleno { background: #a32a2a; border-color: #a32a2a; color: #fff; font-weight: 600; }
.nota { margin: 0; color: var(--c-muted); font-size: 14px; }
.solo-lectura { margin-bottom: 16px; }
.modal .error { margin: 0; }
.fila { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
.tipo { border: 1px solid var(--c-border); border-radius: 4px; display: flex; gap: 24px; padding: 8px 12px; margin: 0; }
.tipo legend { font-size: 14px; font-weight: 600; color: var(--c-title); padding: 0 4px; }
.tipo label { display: flex; align-items: center; gap: 6px; font-size: 15px; }
.tipo input { width: auto; }
.botones { display: flex; justify-content: flex-end; gap: 10px; margin-top: 6px; }

@media (max-width: 600px) { .fila { grid-template-columns: 1fr; } .cabecera { flex-direction: column; align-items: stretch; } }
</style>