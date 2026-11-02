<script setup lang="ts">
// ¿Olvidó su contraseña?: envía una contraseña temporal al correo (sp_Usuario_RecuperarContrasena).
import { ref } from 'vue'
import { KeyRound } from 'lucide-vue-next'
import { cuentaApi } from '../api/cuenta'

const correo = ref('')
const error = ref('')
const listo = ref('')
const enviando = ref(false)

async function enviar() {
  error.value = ''
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(correo.value.trim())) return void (error.value = 'Escriba un correo válido.')
  enviando.value = true
  try {
    listo.value = (await cuentaApi.recuperar(correo.value)).mensaje
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <div class="flex min-h-dvh items-center justify-center bg-background px-5">
    <form class="panel w-full max-w-[380px] p-8" novalidate @submit.prevent="enviar">
      <div class="flex flex-col items-center text-center">
        <span class="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
          <KeyRound class="h-7 w-7" />
        </span>
        <h1 class="mt-4 text-2xl font-semibold">¿Olvidó su contraseña?</h1>
        <p class="mt-1.5 text-sm text-muted">Le enviaremos una contraseña a su correo</p>
      </div>

      <p v-if="listo" class="mt-7 text-sm" role="status">{{ listo }}</p>
      <div v-else class="mt-7">
        <label for="rec-correo" class="label">Correo</label>
        <input id="rec-correo" v-model="correo" type="email" class="control" autocomplete="email" placeholder="usuario@correo.com" />
        <p v-if="error" class="form-error mt-4" role="alert">{{ error }}</p>
        <button type="submit" class="mt-6 w-full rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-white hover:bg-primary-dark" :disabled="enviando">
          {{ enviando ? 'Enviando…' : 'Enviar contraseña' }}
        </button>
      </div>
      <p class="mt-4 text-center text-sm">
        <RouterLink :to="{ name: 'login' }" class="font-semibold text-primary hover:underline">Volver a iniciar sesión</RouterLink>
      </p>
    </form>
  </div>
</template>
