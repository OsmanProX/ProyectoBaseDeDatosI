<script setup lang="ts">
// Crear cuenta (cliente): registra el cliente y su usuario con rol CLIENTE (sp_Cliente_Registrarse).
import { reactive, ref } from 'vue'
import { Eye, EyeOff, Wrench } from 'lucide-vue-next'
import { cuentaApi, type RegistroForm } from '../api/cuenta'

const form = reactive<RegistroForm & { confirmar: string }>({
  tipoCliente: 'INDIVIDUAL', nombreRazonSocial: '', nit: '', telefono: '', correo: '', direccion: '',
  contrasena: '', confirmar: '',
})
const error = ref('')
const listo = ref('')
const enviando = ref(false)
const verPass = ref(false)
const verConf = ref(false)

function validar(): string {
  if (!form.nombreRazonSocial.trim())
    return form.tipoCliente === 'EMPRESARIAL' ? 'Escriba la razón social.' : 'Escriba su nombre completo.'
  if (!/^(CF|[0-9]{1,13}-?[0-9Kk])$/i.test(form.nit.trim())) return 'NIT inválido. Ejemplo: 1234567-8, o CF.'
  if (!/^[0-9]{8}$/.test(form.telefono)) return 'El teléfono debe tener 8 números.'
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(form.correo.trim())) return 'Correo inválido.'
  if (!form.direccion.trim()) return 'Escriba la dirección.'
  if (form.contrasena.length < 8) return 'La contraseña debe tener al menos 8 caracteres.'
  if (!/\p{L}/u.test(form.contrasena) || !/\d/.test(form.contrasena)) return 'La contraseña debe tener al menos una letra y un número.'
  if (form.contrasena !== form.confirmar) return 'Las contraseñas no coinciden.'
  return ''
}

async function enviar() {
  error.value = validar()
  if (error.value) return
  enviando.value = true
  try {
    const { confirmar: _, ...datos } = form
    listo.value = (await cuentaApi.registro(datos)).mensaje
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <div class="flex min-h-dvh items-center justify-center bg-background px-5 py-10">
    <form class="panel w-full max-w-[460px] p-8" novalidate @submit.prevent="enviar">
      <div class="flex flex-col items-center text-center">
        <span class="flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary">
          <Wrench class="h-7 w-7" />
        </span>
        <h1 class="mt-4 text-2xl font-semibold">Crear cuenta</h1>
        <p class="mt-1.5 text-sm text-muted">Consulte en línea el estado de sus equipos en TechCare</p>
      </div>

      <div v-if="listo" class="mt-7 space-y-4 text-center">
        <p class="text-sm" role="status">{{ listo }}</p>
        <RouterLink :to="{ name: 'login' }" class="inline-block w-full rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-white hover:bg-primary-dark">
          Ir a iniciar sesión
        </RouterLink>
      </div>

      <template v-else>
        <div class="mt-7 space-y-4">
          <fieldset>
            <legend class="label">Tipo de cliente</legend>
            <label class="mr-5 text-sm"><input v-model="form.tipoCliente" type="radio" value="INDIVIDUAL" /> Individual</label>
            <label class="text-sm"><input v-model="form.tipoCliente" type="radio" value="EMPRESARIAL" /> Empresarial</label>
          </fieldset>
          <div>
            <label for="r-nombre" class="label">{{ form.tipoCliente === 'EMPRESARIAL' ? 'Razón social' : 'Nombre completo' }}</label>
            <input id="r-nombre" v-model="form.nombreRazonSocial" class="control" maxlength="150" autocomplete="name" />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label for="r-nit" class="label">NIT</label>
              <input id="r-nit" v-model="form.nit" class="control" maxlength="15" placeholder="1234567-8 o CF" />
            </div>
            <div>
              <label for="r-tel" class="label">Teléfono</label>
              <input id="r-tel" v-model="form.telefono" class="control" maxlength="8" inputmode="numeric" placeholder="55551234"
                @input="form.telefono = form.telefono.replace(/\D/g, '').slice(0, 8)" />
            </div>
          </div>
          <div>
            <label for="r-correo" class="label">Correo (con este inicia sesión)</label>
            <input id="r-correo" v-model="form.correo" type="email" class="control" maxlength="100" autocomplete="email" />
          </div>
          <div>
            <label for="r-dir" class="label">Dirección</label>
            <input id="r-dir" v-model="form.direccion" class="control" maxlength="200" autocomplete="street-address" />
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label for="r-pass" class="label">Contraseña</label>
              <div class="relative">
                <input id="r-pass" v-model="form.contrasena" :type="verPass ? 'text' : 'password'" class="control pr-10" autocomplete="new-password" placeholder="Mínimo 8, con letras y números" />
                <button type="button" class="absolute inset-y-0 right-0 flex items-center px-3 text-muted hover:text-primary"
                  :aria-label="verPass ? 'Ocultar contraseña' : 'Ver contraseña'" @click="verPass = !verPass">
                  <EyeOff v-if="verPass" class="h-4 w-4" /><Eye v-else class="h-4 w-4" />
                </button>
              </div>
            </div>
            <div>
              <label for="r-conf" class="label">Confirmar</label>
              <div class="relative">
                <input id="r-conf" v-model="form.confirmar" :type="verConf ? 'text' : 'password'" class="control pr-10" autocomplete="new-password"
                  :aria-invalid="!!form.confirmar && form.confirmar !== form.contrasena" />
                <button type="button" class="absolute inset-y-0 right-0 flex items-center px-3 text-muted hover:text-primary"
                  :aria-label="verConf ? 'Ocultar confirmación' : 'Ver confirmación'" @click="verConf = !verConf">
                  <EyeOff v-if="verConf" class="h-4 w-4" /><Eye v-else class="h-4 w-4" />
                </button>
              </div>
              <small v-if="form.confirmar && form.confirmar !== form.contrasena" class="mt-1 block text-xs text-red-500">
                La contraseña no coincide.
              </small>
              <small v-else-if="form.confirmar && form.contrasena.length >= 8" class="mt-1 block text-xs text-green-500">
                Las contraseñas coinciden.
              </small>
            </div>
          </div>
        </div>

        <p v-if="error" class="form-error mt-4" role="alert">{{ error }}</p>

        <button type="submit" class="mt-6 w-full rounded-lg bg-primary px-4 py-3 text-sm font-semibold text-white hover:bg-primary-dark" :disabled="enviando">
          {{ enviando ? 'Creando cuenta…' : 'Crear cuenta' }}
        </button>
        <p class="mt-4 text-center text-sm text-muted">
          ¿Ya tiene cuenta? <RouterLink :to="{ name: 'login' }" class="font-semibold text-primary hover:underline">Iniciar sesión</RouterLink>
        </p>
      </template>
    </form>
  </div>
</template>
