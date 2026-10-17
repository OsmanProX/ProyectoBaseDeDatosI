<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { Wrench } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth.store'

const router = useRouter()
const auth = useAuthStore()

const correo = ref('')
const password = ref('')
const cargando = ref(false)
const error = ref('')

async function enviar() {
  error.value = ''
  if (!correo.value || !password.value) {
    error.value = 'Ingrese su correo y su contraseña.'
    return
  }
  cargando.value = true
  try {
    await auth.login(correo.value, password.value)
    router.push({ name: 'home' })
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'No se pudo iniciar sesión.'
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <div class="flex min-h-dvh items-center justify-center bg-background px-5">
    <form class="panel w-full max-w-[380px] p-8" @submit.prevent="enviar">
      <div class="flex flex-col items-center text-center">
        <span
          class="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary"
        >
          <Wrench class="h-7 w-7" />
        </span>
        <h1 class="mt-4 text-2xl font-semibold">TechCare Solutions</h1>
        <p class="mt-1.5 text-sm text-muted">Inicie sesión para continuar</p>
      </div>

      <div class="mt-7 space-y-4">
        <div>
          <label for="correo" class="label">Correo</label>
          <input
            id="correo"
            v-model="correo"
            type="email"
            class="control"
            placeholder="admin@techcare.com.gt"
            autocomplete="email"
          />
        </div>
        <div>
          <label for="password" class="label">Contraseña</label>
          <input
            id="password"
            v-model="password"
            type="password"
            class="control"
            placeholder="••••••••"
            autocomplete="current-password"
          />
        </div>
      </div>

      <p v-if="error" class="form-error mt-4" role="alert">{{ error }}</p>

      <button type="submit" class="mt-6 w-full rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-white hover:bg-primary-dark" :disabled="cargando">
        {{ cargando ? 'Ingresando…' : 'Ingresar' }}
      </button>
    </form>
  </div>
</template>
