<script setup lang="ts">
import { ref } from 'vue'

const emit = defineEmits<{
  iniciado: [datos: { token: string; usuario: Record<string, unknown> }]
}>()

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
    const res = await fetch('http://localhost:5245/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ correo: correo.value, password: password.value }),
    })
    const data = await res.json()

    if (data.codigo === 200 && data.token) {
      localStorage.setItem('token', data.token)
      localStorage.setItem('usuario', JSON.stringify(data.usuario))
      emit('iniciado', { token: data.token, usuario: data.usuario })
    } else {
      error.value = data.mensaje ?? 'Correo o contraseña incorrectos.'
    }
  } catch {
    error.value = 'No se pudo conectar con el servidor. Verifique que la API esté en ejecución.'
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <div class="login-pagina">
    <form class="login-tarjeta" @submit.prevent="enviar">
      <div class="login-logo">&#128295;</div>
      <h1 class="login-titulo">TechCare Solutions</h1>
      <p class="login-subtitulo">Inicie sesión para continuar</p>

      <label class="login-campo">
        <span>Correo</span>
        <input
          v-model="correo"
          type="email"
          placeholder="admin@techcare.com.gt"
          autocomplete="email"
        />
      </label>

      <label class="login-campo">
        <span>Contraseña</span>
        <input
          v-model="password"
          type="password"
          placeholder="••••••••"
          autocomplete="current-password"
        />
      </label>

      <p v-if="error" class="login-error">{{ error }}</p>

      <button type="submit" class="login-boton" :disabled="cargando">
        {{ cargando ? 'Ingresando…' : 'Ingresar' }}
      </button>
    </form>
  </div>
</template>

<style scoped>
.login-pagina {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #1e2a4a 0%, #2f3f6e 100%);
  padding: 20px;
}

.login-tarjeta {
  width: 100%;
  max-width: 380px;
  background: #fff;
  border-radius: 16px;
  padding: 36px 32px;
  box-shadow: 0 18px 50px rgba(0, 0, 0, 0.35);
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.login-logo {
  font-size: 42px;
  text-align: center;
}

.login-titulo {
  margin: 0;
  text-align: center;
  font-size: 22px;
  color: #1e2a4a;
}

.login-subtitulo {
  margin: 0 0 8px;
  text-align: center;
  font-size: 13px;
  color: #7a809a;
}

.login-campo {
  display: flex;
  flex-direction: column;
  gap: 5px;
  font-size: 13px;
  font-weight: 600;
  color: #3c4360;
}

.login-campo input {
  padding: 11px 12px;
  border: 1.5px solid #d7dcef;
  border-radius: 10px;
  font-size: 14px;
  outline: none;
  transition: border-color 0.15s;
}

.login-campo input:focus {
  border-color: #3d56a8;
}

.login-error {
  margin: 0;
  font-size: 13px;
  color: #b1303a;
  background: #ffebee;
  border-radius: 8px;
  padding: 9px 12px;
}

.login-boton {
  margin-top: 6px;
  padding: 12px;
  border: none;
  border-radius: 10px;
  background: #3d56a8;
  color: #fff;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
}

.login-boton:hover:not(:disabled) {
  background: #30458c;
}

.login-boton:disabled {
  opacity: 0.6;
  cursor: wait;
}
</style>
