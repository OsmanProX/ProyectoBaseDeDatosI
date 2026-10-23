<script setup lang="ts">
// Usuarios/empleados (solo ADMINISTRADOR): lista, crear, editar, asignar rol,
// activar/inactivar y restablecer contraseña. Las reglas las valida la base (script 12):
// usuario y correo únicos, contraseña de 8+ caracteres (se guarda en hash) y
// que siempre quede un ADMINISTRADOR activo.
import { computed, onMounted, reactive, ref } from 'vue'
import { useAuthStore } from '@/features/auth/stores/auth.store'
import { usuariosApi, type Rol, type UsuarioFila } from '../api/usuarios'

const auth = useAuthStore()

const usuarios = ref<UsuarioFila[]>([])
const roles = ref<Rol[]>([])
const cargando = ref(false)
const error = ref('')
const aviso = ref('')
const buscar = ref('')
const filtroEstado = ref<'' | 'activos' | 'inactivos'>('')

const esActivo = (u: UsuarioFila) => u.activo === true || u.activo === 1
const esYo = (u: UsuarioFila) => u.usuarioId === auth.usuario?.usuarioId

function mostrarAviso(texto: string) {
  aviso.value = texto
  setTimeout(() => (aviso.value = ''), 4000)
}

async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    usuarios.value = await usuariosApi.lista()
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    cargando.value = false
  }
}

onMounted(async () => {
  await cargar()
  try {
    roles.value = await usuariosApi.roles()
  } catch (e) {
    error.value = (e as Error).message
  }
})

const visibles = computed(() => {
  const t = buscar.value.trim().toLowerCase()
  return usuarios.value.filter((u) =>
    (!filtroEstado.value || (filtroEstado.value === 'activos') === esActivo(u)) &&
    (!t || [u.nombreCompleto, u.nombreUsuario, u.correo, u.roles ?? ''].some((v) => v.toLowerCase().includes(t))))
})

// ---------- crear / editar ----------
const dlgForm = ref<HTMLDialogElement | null>(null)
const editandoId = ref<number | null>(null)
const form = reactive({ nombreUsuario: '', nombreCompleto: '', correo: '', telefono: '', contrasena: '', confirmar: '', rolId: 0 })
const errorForm = ref('')
const guardando = ref(false)

function abrir(u?: UsuarioFila) {
  editandoId.value = u?.usuarioId ?? null
  Object.assign(form, {
    nombreUsuario: u?.nombreUsuario ?? '',
    nombreCompleto: u?.nombreCompleto ?? '',
    correo: u?.correo ?? '',
    telefono: u?.telefono ?? '',
    contrasena: '',
    confirmar: '',
    rolId: Number(u?.rolIds?.split(',')[0] ?? 0),
  })
  errorForm.value = ''
  dlgForm.value?.showModal()
}

const RX_USUARIO = /^[a-z0-9._]{3,30}$/
const RX_CORREO = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
const RX_TEL = /^[0-9 +-]{8,15}$/

function validar(): string {
  if (!RX_USUARIO.test(form.nombreUsuario.trim().toLowerCase()))
    return 'Usuario: de 3 a 30 caracteres, solo letras minúsculas, números, punto o guion bajo.'
  if (!form.nombreCompleto.trim()) return 'El nombre completo es obligatorio.'
  if (!RX_CORREO.test(form.correo.trim())) return 'Correo inválido.'
  if (form.telefono.trim() && !RX_TEL.test(form.telefono.trim())) return 'Teléfono inválido (8 a 15 dígitos).'
  if (!form.rolId) return 'Seleccione el rol.'
  if (!editandoId.value) {
    if (form.contrasena.length < 8) return 'La contraseña debe tener al menos 8 caracteres.'
    if (form.contrasena !== form.confirmar) return 'Las contraseñas no coinciden.'
  }
  return ''
}

async function guardar() {
  errorForm.value = validar()
  if (errorForm.value) return
  guardando.value = true
  try {
    await usuariosApi.guardar(editandoId.value, {
      ...form,
      nombreUsuario: form.nombreUsuario.trim().toLowerCase(),
    })
    dlgForm.value?.close()
    mostrarAviso(editandoId.value ? 'Usuario actualizado.' : 'Usuario creado. Ya puede iniciar sesión con su correo.')
    await cargar()
  } catch (e) {
    errorForm.value = (e as Error).message
  } finally {
    guardando.value = false
  }
}

// ---------- activar / inactivar ----------
const dlgEstado = ref<HTMLDialogElement | null>(null)
const elegido = ref<UsuarioFila | null>(null)
const errorEstado = ref('')
const procesando = ref(false)

function pedirEstado(u: UsuarioFila) {
  elegido.value = u
  errorEstado.value = ''
  dlgEstado.value?.showModal()
}

async function confirmarEstado() {
  if (!elegido.value) return
  procesando.value = true
  errorEstado.value = ''
  try {
    const activar = !esActivo(elegido.value)
    await usuariosApi.estado(elegido.value.usuarioId, activar)
    dlgEstado.value?.close()
    mostrarAviso(activar ? 'Usuario activado.' : 'Usuario inactivado: ya no puede iniciar sesión.')
    await cargar()
  } catch (e) {
    errorEstado.value = (e as Error).message
  } finally {
    procesando.value = false
  }
}

// ---------- restablecer contraseña ----------
const dlgClave = ref<HTMLDialogElement | null>(null)
const clave = reactive({ nueva: '', confirmar: '' })
const errorClave = ref('')

function pedirClave(u: UsuarioFila) {
  elegido.value = u
  clave.nueva = ''
  clave.confirmar = ''
  errorClave.value = ''
  dlgClave.value?.showModal()
}

async function guardarClave() {
  if (!elegido.value) return
  if (clave.nueva.length < 8) return void (errorClave.value = 'La contraseña debe tener al menos 8 caracteres.')
  if (clave.nueva !== clave.confirmar) return void (errorClave.value = 'Las contraseñas no coinciden.')
  procesando.value = true
  errorClave.value = ''
  try {
    await usuariosApi.contrasena(elegido.value.usuarioId, clave.nueva)
    dlgClave.value?.close()
    mostrarAviso(`Contraseña de ${elegido.value.nombreCompleto} actualizada.`)
  } catch (e) {
    errorClave.value = (e as Error).message
  } finally {
    procesando.value = false
  }
}
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <div>
        <h1>Usuarios</h1>
        <p class="sub">Empleados con acceso al sistema y su rol.</p>
      </div>
      <button class="btn primario" @click="abrir()">+ Nuevo usuario</button>
    </header>

    <p v-if="aviso" class="aviso" role="status">{{ aviso }}</p>
    <p v-if="error" class="error" role="alert">{{ error }}</p>

    <div class="filtros">
      <label class="campo grande">
        <span>Buscar</span>
        <input v-model="buscar" type="search" placeholder="Nombre, usuario, correo o rol" />
      </label>
      <label class="campo">
        <span>Estado</span>
        <select v-model="filtroEstado">
          <option value="">Todos</option>
          <option value="activos">Activos</option>
          <option value="inactivos">Inactivos</option>
        </select>
      </label>
    </div>

    <div class="tabla-wrap">
      <table>
        <thead>
          <tr><th>Nombre completo</th><th>Usuario</th><th>Correo</th><th>Teléfono</th><th>Rol</th><th>Estado</th><th></th></tr>
        </thead>
        <tbody>
          <tr v-if="cargando"><td colspan="7" class="vacio">Cargando usuarios…</td></tr>
          <tr v-else-if="!visibles.length"><td colspan="7" class="vacio">No hay usuarios con ese criterio.</td></tr>
          <template v-else>
            <tr v-for="u in visibles" :key="u.usuarioId">
              <td class="fuerte">{{ u.nombreCompleto }}<span v-if="esYo(u)" class="detalle"> (usted)</span></td>
              <td>@{{ u.nombreUsuario }}</td>
              <td>{{ u.correo }}</td>
              <td>{{ u.telefono ?? '—' }}</td>
              <td><span class="chip rol">{{ u.roles ?? 'SIN ROL' }}</span></td>
              <td><span class="chip" :class="esActivo(u) ? 'ok' : 'inactivo'">{{ esActivo(u) ? 'Activo' : 'Inactivo' }}</span></td>
              <td class="acciones">
                <button class="btn enlace" @click="abrir(u)">Editar</button>
                <button class="btn enlace" @click="pedirClave(u)">Contraseña</button>
                <button v-if="!esYo(u)" class="btn enlace" :class="{ peligro: esActivo(u) }" @click="pedirEstado(u)">
                  {{ esActivo(u) ? 'Inactivar' : 'Activar' }}
                </button>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>

    <!-- Crear / editar -->
    <dialog ref="dlgForm" class="modal">
      <form novalidate @submit.prevent="guardar">
        <h2>{{ editandoId ? 'Editar usuario' : 'Nuevo usuario' }}</h2>
        <label class="campo">
          <span>Nombre completo</span>
          <input v-model="form.nombreCompleto" maxlength="100" autocomplete="off" />
        </label>
        <div class="fila">
          <label class="campo">
            <span>Usuario</span>
            <input v-model="form.nombreUsuario" maxlength="30" autocomplete="off" placeholder="tecnico5" />
          </label>
          <label class="campo">
            <span>Rol</span>
            <select v-model.number="form.rolId">
              <option :value="0" disabled>Seleccione…</option>
              <option v-for="r in roles" :key="r.rolId" :value="r.rolId">{{ r.nombre }}</option>
            </select>
          </label>
        </div>
        <p v-if="form.rolId" class="nota">{{ roles.find((r) => r.rolId === form.rolId)?.descripcion }}</p>
        <div class="fila">
          <label class="campo">
            <span>Correo (para iniciar sesión)</span>
            <input v-model="form.correo" type="email" maxlength="100" autocomplete="off" />
          </label>
          <label class="campo">
            <span>Teléfono (opcional)</span>
            <input v-model="form.telefono" maxlength="15" inputmode="tel" />
          </label>
        </div>
        <div v-if="!editandoId" class="fila">
          <label class="campo">
            <span>Contraseña</span>
            <input v-model="form.contrasena" type="password" autocomplete="new-password" />
          </label>
          <label class="campo">
            <span>Confirmar contraseña</span>
            <input v-model="form.confirmar" type="password" autocomplete="new-password" />
          </label>
        </div>
        <p v-if="!editandoId" class="nota">Mínimo 8 caracteres. Se guarda cifrada (hash), nunca en texto plano.</p>
        <p v-if="errorForm" class="error" role="alert">{{ errorForm }}</p>
        <div class="botones">
          <button type="button" class="btn" @click="dlgForm?.close()">Cancelar</button>
          <button type="submit" class="btn primario" :disabled="guardando">{{ guardando ? 'Guardando…' : 'Guardar' }}</button>
        </div>
      </form>
    </dialog>

    <!-- Activar / inactivar -->
    <dialog ref="dlgEstado" class="modal">
      <form v-if="elegido" novalidate @submit.prevent="confirmarEstado">
        <h2>{{ esActivo(elegido) ? 'Inactivar usuario' : 'Activar usuario' }}</h2>
        <p>¿{{ esActivo(elegido) ? 'Inactivar' : 'Activar' }} a <b>{{ elegido.nombreCompleto }}</b>?</p>
        <p v-if="esActivo(elegido)" class="nota">No podrá iniciar sesión. Su historial (órdenes, reparaciones, pagos) se conserva.</p>
        <p v-if="errorEstado" class="error" role="alert">{{ errorEstado }}</p>
        <div class="botones">
          <button type="button" class="btn" @click="dlgEstado?.close()">Cancelar</button>
          <button type="submit" class="btn" :class="esActivo(elegido) ? 'peligro-lleno' : 'primario'" :disabled="procesando">
            {{ procesando ? 'Procesando…' : esActivo(elegido) ? 'Inactivar' : 'Activar' }}
          </button>
        </div>
      </form>
    </dialog>

    <!-- Restablecer contraseña -->
    <dialog ref="dlgClave" class="modal">
      <form v-if="elegido" novalidate @submit.prevent="guardarClave">
        <h2>Restablecer contraseña</h2>
        <p>Nueva contraseña para <b>{{ elegido.nombreCompleto }}</b>.</p>
        <div class="fila">
          <label class="campo">
            <span>Contraseña nueva</span>
            <input v-model="clave.nueva" type="password" autocomplete="new-password" />
          </label>
          <label class="campo">
            <span>Confirmar</span>
            <input v-model="clave.confirmar" type="password" autocomplete="new-password" />
          </label>
        </div>
        <p class="nota">Mínimo 8 caracteres.</p>
        <p v-if="errorClave" class="error" role="alert">{{ errorClave }}</p>
        <div class="botones">
          <button type="button" class="btn" @click="dlgClave?.close()">Cancelar</button>
          <button type="submit" class="btn primario" :disabled="procesando">{{ procesando ? 'Guardando…' : 'Guardar' }}</button>
        </div>
      </form>
    </dialog>
  </main>
</template>

<style scoped>
.pagina {
  --c-title: #17375e; --c-text: #222b38; --c-muted: #5a6472; --c-surface: #fff;
  --c-row: #f4f6fa; --c-border: #d0d7e2; --c-input: #b9c2d0; --c-danger: #8a1f1f;
}
:root.dark .pagina {
  --c-title: #c7d2fe; --c-text: #e2e8f0; --c-muted: #a3b2c9; --c-surface: rgb(18 27 46);
  --c-row: rgb(24 36 60); --c-border: rgb(43 56 78); --c-input: rgb(71 85 105); --c-danger: #f87171;
}
.modal { background: var(--c-surface); color: var(--c-text); margin: auto; }
.pagina { max-width: 1280px; margin: 0 auto; padding: 32px 24px 64px; text-align: left; color: var(--c-text); }
.cabecera { display: flex; justify-content: space-between; align-items: flex-end; gap: 16px; flex-wrap: wrap;
  border-bottom: 3px solid #c8962e; padding-bottom: 16px; margin-bottom: 20px; }
h1 { margin: 0; font: 700 28px/1.2 Georgia, 'Times New Roman', serif; color: var(--c-title); }
h2 { margin: 0; font: 700 22px/1.2 Georgia, serif; color: var(--c-title); }
.sub { margin: 4px 0 0; color: var(--c-muted); font-size: 15px; }

.filtros { display: flex; gap: 16px; margin-bottom: 16px; flex-wrap: wrap; align-items: flex-end; }
.campo { display: flex; flex-direction: column; gap: 4px; font-size: 14px; min-width: 180px; }
.campo span { font-weight: 600; color: var(--c-title); }
.campo.grande { flex: 1; min-width: 240px; }
input, select { font: inherit; font-size: 15px; padding: 9px 10px; border: 1px solid var(--c-input); border-radius: 4px;
  background: var(--c-surface); color: var(--c-text); box-sizing: border-box; width: 100%; }
input:focus-visible, select:focus-visible, .btn:focus-visible { outline: 3px solid #c8962e; outline-offset: 1px; }

.tabla-wrap { overflow-x: auto; border: 1px solid var(--c-border); border-radius: 4px; }
table { width: 100%; border-collapse: collapse; font-size: 15px; }
th { background: #17375e; color: #fff; text-align: left; padding: 10px 12px; font-weight: 600; white-space: nowrap; }
td { padding: 10px 12px; border-top: 1px solid var(--c-border); vertical-align: middle; }
tbody tr:nth-child(even) { background: var(--c-row); }
.fuerte { font-weight: 700; }
.detalle { font-size: 13px; color: var(--c-muted); font-weight: 400; }
.vacio { text-align: center; color: var(--c-muted); padding: 28px 12px; }
.acciones { text-align: right; white-space: nowrap; }

.chip { padding: 2px 10px; border-radius: 999px; font-size: 13px; font-weight: 600; white-space: nowrap; }
.chip.ok { background: #dff3e4; color: #1d6b34; }
.chip.inactivo { background: #ececec; color: #3c4450; }
.chip.rol { background: #e6f0fb; color: #1d4f8a; }

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
.modal .error { margin: 0; }
.nota { margin: 0; color: var(--c-muted); font-size: 14px; }

.modal { border: none; border-radius: 6px; padding: 28px; width: min(600px, 92vw);
  box-shadow: 0 20px 50px rgba(15, 42, 74, 0.35); }
.modal::backdrop { background: rgba(15, 42, 74, 0.5); }
.modal form { display: flex; flex-direction: column; gap: 14px; text-align: left; }
.modal form > p { margin: 0; }
.fila { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
.fila .campo { min-width: 0; }
.botones { display: flex; justify-content: flex-end; gap: 10px; }

@media (max-width: 700px) {
  .pagina { padding: 24px 16px 48px; }
  .fila { grid-template-columns: 1fr; }
  .cabecera { flex-direction: column; align-items: stretch; }
  .campo { min-width: 0; flex: 1 1 100%; }
}
</style>
