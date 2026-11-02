<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { Eye, EyeOff, Wrench } from 'lucide-vue-next'
import { useAuthStore } from '../stores/auth.store'

const router = useRouter()
const auth = useAuthStore()

const correo = ref('')
const password = ref('')
const cargando = ref(false)
const verPass = ref(false)
const error = ref('')

async function enviar() {
  error.value = ''
  if (!correo.value || !password.value) {
    error.value = 'Ingrese su correo o usuario y su contraseña.'
    return
  }
  cargando.value = true
  try {
    await auth.login(correo.value, password.value)
    router.push({ name: auth.rol === 'CLIENTE' ? 'mis-ordenes' : 'home' })
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
          <label for="correo" class="label">Correo o usuario</label>
          <input
            id="correo"
            v-model="correo"
            type="text"
            class="control"
            placeholder="admin@techcare.com.gt o admin"
            autocomplete="username"
          />
        </div>
        <div>
          <label for="password" class="label">Contraseña</label>
          <div class="relative">
            <input
              id="password"
              v-model="password"
              :type="verPass ? 'text' : 'password'"
              class="control pr-10"
              placeholder="••••••••"
              autocomplete="current-password"
            />
            <button type="button" class="absolute inset-y-0 right-0 flex items-center px-3 text-muted hover:text-primary"
              :aria-label="verPass ? 'Ocultar contraseña' : 'Ver contraseña'" @click="verPass = !verPass">
              <EyeOff v-if="verPass" class="h-4 w-4" /><Eye v-else class="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>

      <p v-if="error" class="form-error mt-4" role="alert">{{ error }}</p>

      <button type="submit" class="mt-6 w-full rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-white hover:bg-primary-dark" :disabled="cargando">
        {{ cargando ? 'Ingresando…' : 'Ingresar' }}
      </button>

      <div class="mt-4 flex flex-col items-center gap-2 text-sm">
        <RouterLink :to="{ name: 'recuperar' }" class="text-primary hover:underline">¿Olvidó su contraseña?</RouterLink>
        <p class="text-muted">
          ¿Es cliente y no tiene cuenta?
          <RouterLink :to="{ name: 'registro' }" class="font-semibold text-primary hover:underline">Crear cuenta</RouterLink>
        </p>
      </div>
    </form>
  </div>
</template>
