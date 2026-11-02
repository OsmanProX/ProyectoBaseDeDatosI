<script setup lang="ts">
// Cambio obligatorio: aparece al entrar con una contraseña temporal (DebeCambiarContrasena = 1).
// El router no deja abrir otra pantalla hasta cambiarla (sp_Usuario_CambiarMiContrasena).
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { ShieldCheck } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth.store'
import { cuentaApi } from '../api/cuenta'

const auth = useAuthStore()
const router = useRouter()
const actual = ref('')
const nueva = ref('')
const confirmar = ref('')
const error = ref('')
const enviando = ref(false)

async function enviar() {
  error.value = ''
  if (!actual.value) return void (error.value = 'Escriba la contraseña que recibió por correo.')
  if (nueva.value.length < 8) return void (error.value = 'La contraseña nueva debe tener al menos 8 caracteres.')
  if (nueva.value !== confirmar.value) return void (error.value = 'Las contraseñas nuevas no coinciden.')
  enviando.value = true
  try {
    await cuentaApi.cambiarContrasena(actual.value, nueva.value)
    auth.contrasenaCambiada()
    router.replace({ name: auth.rol === 'CLIENTE' ? 'mis-ordenes' : 'home' })
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    enviando.value = false
  }
}

function salir() {
  auth.logout()
  router.replace({ name: 'login' })
}
</script>

<template>
  <div class="flex min-h-dvh items-center justify-center bg-background px-5">
    <form class="panel w-full max-w-[400px] p-8" novalidate @submit.prevent="enviar">
      <div class="flex flex-col items-center text-center">
        <span class="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
          <ShieldCheck class="h-7 w-7" />
        </span>
        <h1 class="mt-4 text-2xl font-semibold">Cambie su contraseña</h1>
        <p class="mt-1.5 text-sm text-muted">
          Hola, {{ auth.nombreCompleto }}. Por seguridad, cambie la contraseña que recibió por correo para continuar.
        </p>
      </div>

      <div class="mt-7 space-y-4">
        <div>
          <label for="cc-actual" class="label">Contraseña (la del correo)</label>
          <input id="cc-actual" v-model="actual" type="password" class="control" autocomplete="current-password" />
        </div>
        <div>
          <label for="cc-nueva" class="label">Contraseña nueva</label>
          <input id="cc-nueva" v-model="nueva" type="password" class="control" autocomplete="new-password" placeholder="Mínimo 8 caracteres" />
        </div>
        <div>
          <label for="cc-conf" class="label">Confirmar contraseña nueva</label>
          <input id="cc-conf" v-model="confirmar" type="password" class="control" autocomplete="new-password" />
        </div>
      </div>

      <p v-if="error" class="form-error mt-4" role="alert">{{ error }}</p>

      <button type="submit" class="mt-6 w-full rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-white hover:bg-primary-dark" :disabled="enviando">
        {{ enviando ? 'Guardando…' : 'Guardar y continuar' }}
      </button>
      <p class="mt-4 text-center text-sm">
        <button type="button" class="text-muted hover:underline" @click="salir">Cerrar sesión</button>
      </p>
    </form>
  </div>
</template>
