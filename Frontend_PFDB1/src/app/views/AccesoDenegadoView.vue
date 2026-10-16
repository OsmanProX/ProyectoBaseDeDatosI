<script setup lang="ts">
import { useRouter } from 'vue-router'
import { ShieldAlert } from 'lucide-vue-next'
import { useAuthStore } from '@/features/auth/stores/auth.store'

const router = useRouter()
const auth = useAuthStore()

/** Para loguearse con otro usuario hay que cerrar la sesión actual;
 *  además el guard devolvería /login → home si queda un token activo. */
function cambiarUsuario() {
  auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <section class="mx-auto max-w-[560px] py-10 text-center">
    <div class="panel p-10">
      <span
        class="mx-auto flex h-16 w-16 items-center justify-center rounded-2xl bg-danger/10 text-danger"
      >
        <ShieldAlert class="h-8 w-8" />
      </span>
      <h1 class="mt-6 text-2xl font-semibold">Acceso denegado</h1>
      <p class="mt-3 text-sm leading-6 text-muted">
        Tu rol no tiene permiso para ver esta sección. Si necesitas acceso, comunícate con el
        administrador del sistema.
      </p>
      <div class="mt-8 flex justify-center gap-3">
        <button
          type="button"
          class="rounded-lg bg-primary px-4 py-2.5 text-sm font-semibold text-white hover:bg-primary-dark"
          @click="router.push({ name: 'home' })"
        >
          Volver al inicio
        </button>
        <button
          type="button"
          class="rounded-lg border border-border px-4 py-2.5 text-sm text-muted hover:bg-background"
          @click="cambiarUsuario"
        >
          Iniciar sesión con otro usuario
        </button>
      </div>
    </div>
  </section>
</template>
