<script setup lang="ts">
// Mi cuenta: cada usuario edita sus datos y cambia su contraseña (sp_MiCuenta_*, sp_Usuario_CambiarMiContrasena).
// Si la cuenta es de un cliente, también edita su dirección (tabla Cliente).
import { nextTick, onMounted, reactive, ref } from 'vue'
import { useRoute } from 'vue-router'
import { Eye, EyeOff } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth.store'
import { cuentaApi, type MiCuenta } from '../api/cuenta'

const auth = useAuthStore()
const route = useRoute()
const cuenta = ref<MiCuenta | null>(null)
const error = ref('')

// ---------- mis datos ----------
const datos = reactive({ nombreCompleto: '', telefono: '', direccion: '', error: '', ok: '', enviando: false })

function llenar(c: MiCuenta) {
  cuenta.value = c
  Object.assign(datos, { nombreCompleto: c.nombreCompleto, telefono: c.telefono ?? '', direccion: c.direccion ?? '' })
}

async function guardarDatos() {
  datos.error = ''
  datos.ok = ''
  if (!datos.nombreCompleto.trim()) return void (datos.error = 'El nombre es obligatorio.')
  if (!/^[0-9]{8}$/.test(datos.telefono)) return void (datos.error = 'El teléfono debe tener 8 números.')
  if (cuenta.value?.clienteId && !datos.direccion.trim()) return void (datos.error = 'La dirección es obligatoria.')
  datos.enviando = true
  try {
    const c = await cuentaApi.actualizarMiCuenta({
      nombreCompleto: datos.nombreCompleto.trim(),
      telefono: datos.telefono,
      direccion: cuenta.value?.clienteId ? datos.direccion.trim() : null,
    })
    llenar(c)
    auth.actualizarNombre(c.nombreCompleto)
    datos.ok = 'Datos actualizados.'
  } catch (e) {
    datos.error = (e as Error).message
  } finally {
    datos.enviando = false
  }
}

// ---------- contraseña ----------
const clave = reactive({ actual: '', nueva: '', confirmar: '', error: '', ok: '', enviando: false, ver: false })

async function cambiarClave() {
  clave.error = ''
  clave.ok = ''
  if (!clave.actual) return void (clave.error = 'Escriba su contraseña actual.')
  if (clave.nueva.length < 8) return void (clave.error = 'La contraseña nueva debe tener al menos 8 caracteres.')
  if (!/\p{L}/u.test(clave.nueva) || !/\d/.test(clave.nueva))
    return void (clave.error = 'La contraseña nueva debe tener al menos una letra y un número.')
  if (clave.nueva === clave.actual) return void (clave.error = 'La contraseña nueva debe ser distinta de la actual.')
  if (clave.nueva !== clave.confirmar) return void (clave.error = 'Las contraseñas nuevas no coinciden.')
  clave.enviando = true
  try {
    await cuentaApi.cambiarContrasena(clave.actual, clave.nueva)
    Object.assign(clave, { actual: '', nueva: '', confirmar: '', ok: 'Contraseña actualizada.' })
  } catch (e) {
    clave.error = (e as Error).message
  } finally {
    clave.enviando = false
  }
}

onMounted(async () => {
  try {
    llenar(await cuentaApi.miCuenta())
  } catch (e) {
    error.value = (e as Error).message
  }
  // Desde el menú "Cambiar contraseña" se llega directo a esa sección
  if (route.query.seccion === 'contrasena') {
    await nextTick()
    document.getElementById('contrasena')?.scrollIntoView({ behavior: 'smooth' })
    document.getElementById('mc-actual')?.focus()
  }
})
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <h1>Mi cuenta</h1>
      <p class="sub">Sus datos de acceso a TechCare. El correo no se puede cambiar porque con él inicia sesión.</p>
    </header>

    <p v-if="error" class="error" role="alert">{{ error }}</p>

    <form v-if="cuenta" class="tarjeta" novalidate @submit.prevent="guardarDatos">
      <h2>Mis datos</h2>
      <dl class="fijos">
        <div><dt>Correo</dt><dd>{{ cuenta.correo }}</dd></div>
        <div><dt>Usuario</dt><dd>{{ cuenta.nombreUsuario }}</dd></div>
        <div><dt>Rol</dt><dd>{{ auth.rol }}</dd></div>
        <template v-if="cuenta.clienteId">
          <div><dt>Tipo de cliente</dt><dd>{{ cuenta.tipoCliente === 'EMPRESARIAL' ? 'Empresarial' : 'Individual' }}</dd></div>
          <div><dt>NIT</dt><dd>{{ cuenta.nit }}</dd></div>
        </template>
      </dl>
      <div class="campos">
        <label>{{ cuenta.tipoCliente === 'EMPRESARIAL' ? 'Razón social' : 'Nombre completo' }}
          <input v-model="datos.nombreCompleto" maxlength="100" />
        </label>
        <label>Teléfono
          <input v-model="datos.telefono" maxlength="8" inputmode="numeric"
            @input="datos.telefono = datos.telefono.replace(/\D/g, '').slice(0, 8)" />
        </label>
        <label v-if="cuenta.clienteId" class="ancho">Dirección
          <input v-model="datos.direccion" maxlength="200" />
        </label>
      </div>
      <p v-if="datos.error" class="error" role="alert">{{ datos.error }}</p>
      <p v-if="datos.ok" class="ok" role="status">{{ datos.ok }}</p>
      <button type="submit" class="btn" :disabled="datos.enviando">{{ datos.enviando ? 'Guardando…' : 'Guardar datos' }}</button>
    </form>

    <form id="contrasena" class="tarjeta" novalidate @submit.prevent="cambiarClave">
      <h2>Cambiar contraseña</h2>
      <div class="campos">
        <label>Contraseña actual
          <input id="mc-actual" v-model="clave.actual" :type="clave.ver ? 'text' : 'password'" autocomplete="current-password" />
        </label>
        <label>Contraseña nueva
          <input v-model="clave.nueva" :type="clave.ver ? 'text' : 'password'" autocomplete="new-password" placeholder="Mínimo 8, con letras y números" />
        </label>
        <label>Confirmar
          <input v-model="clave.confirmar" :type="clave.ver ? 'text' : 'password'" autocomplete="new-password" />
          <small v-if="clave.confirmar && clave.confirmar !== clave.nueva" class="mal">La contraseña no coincide.</small>
        </label>
      </div>
      <button type="button" class="ver" @click="clave.ver = !clave.ver">
        <EyeOff v-if="clave.ver" class="h-4 w-4" /><Eye v-else class="h-4 w-4" />
        {{ clave.ver ? 'Ocultar contraseñas' : 'Ver contraseñas' }}
      </button>
      <p v-if="clave.error" class="error" role="alert">{{ clave.error }}</p>
      <p v-if="clave.ok" class="ok" role="status">{{ clave.ok }}</p>
      <button type="submit" class="btn" :disabled="clave.enviando">{{ clave.enviando ? 'Guardando…' : 'Cambiar contraseña' }}</button>
    </form>
  </main>
</template>

<style scoped>
.pagina {
  --c-title: #17375e; --c-text: #222b38; --c-muted: #5a6472; --c-surface: #fff; --c-border: #d0d7e2;
}
:root.dark .pagina {
  --c-title: #c7d2fe; --c-text: #e2e8f0; --c-muted: #a3b2c9; --c-surface: rgb(18 27 46); --c-border: rgb(43 56 78);
}
.pagina { max-width: 860px; margin: 0 auto; padding: 32px 24px 64px; text-align: left; color: var(--c-text); }
.cabecera { border-bottom: 2px solid #c8962e; padding-bottom: 12px; margin-bottom: 18px; }
h1 { margin: 0; font: 700 28px/1.2 Georgia, 'Times New Roman', serif; color: var(--c-title); }
h2 { margin: 0 0 12px; font: 700 19px/1.2 Georgia, serif; color: var(--c-title); }
.sub { margin: 4px 0 0; color: var(--c-muted); font-size: 15px; }
.tarjeta { border: 1px solid var(--c-border); border-radius: 8px; padding: 18px 20px; margin-bottom: 16px; background: var(--c-surface);
  display: flex; flex-direction: column; gap: 12px; }
.fijos { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px 16px; margin: 0; }
dt { font-size: 12px; color: var(--c-muted); }
dd { margin: 2px 0 0; font-weight: 600; word-break: break-all; }
.campos { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
.campos .ancho { grid-column: 1 / -1; }
label { display: flex; flex-direction: column; gap: 4px; font-size: 13px; color: var(--c-muted); }
input { font: inherit; font-size: 15px; padding: 8px 10px; border: 1px solid var(--c-border); border-radius: 4px;
  background: var(--c-surface); color: var(--c-text); }
.btn { align-self: flex-end; padding: 9px 18px; border: none; border-radius: 6px; background: #6366f1; color: #fff; font-weight: 600; cursor: pointer; }
.ver { align-self: flex-start; display: inline-flex; align-items: center; gap: 6px; padding: 0; border: none; background: none;
  color: #818cf8; font: inherit; font-size: 13px; cursor: pointer; }
.error, .mal { color: #d9534f; margin: 0; }
.mal { font-size: 12px; }
.ok { color: #2e8b57; margin: 0; }
@media (max-width: 700px) { .fijos, .campos { grid-template-columns: 1fr; } }
</style>
