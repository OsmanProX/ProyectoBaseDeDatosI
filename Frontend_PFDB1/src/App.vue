<script setup lang="ts">
import { ref } from 'vue'
import LoginView from './views/LoginView.vue'
import OrdenesView from './views/OrdenesView.vue'

interface UsuarioSesion {
  nombreCompleto?: string
  roles?: string
}

const token = ref<string | null>(localStorage.getItem('token'))
const usuario = ref<UsuarioSesion | null>(
  JSON.parse(localStorage.getItem('usuario') ?? 'null'),
)

function alIniciar(datos: { token: string; usuario: Record<string, unknown> }) {
  token.value = datos.token
  usuario.value = datos.usuario as UsuarioSesion
}

function cerrarSesion() {
  localStorage.removeItem('token')
  localStorage.removeItem('usuario')
  token.value = null
  usuario.value = null
}
</script>

<template>
  <LoginView v-if="!token" @iniciado="alIniciar" />

  <div v-else>
    <header class="barra-sesion">
      <div class="barra-usuario">
        <span class="barra-avatar">&#128100;</span>
        <span class="barra-nombre">{{ usuario?.nombreCompleto }}</span>
        <span class="barra-rol">{{ usuario?.roles }}</span>
      </div>
      <button class="barra-salir" @click="cerrarSesion">Cerrar sesión</button>
    </header>
    <OrdenesView />
  </div>
</template>

<style scoped>
.barra-sesion {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #1e2a4a;
  color: #fff;
  padding: 10px 22px;
}

.barra-usuario {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 14px;
}

.barra-nombre {
  font-weight: 600;
}

.barra-rol {
  background: #3d56a8;
  border-radius: 999px;
  padding: 2px 10px;
  font-size: 11px;
  font-weight: 600;
}

.barra-salir {
  background: transparent;
  border: 1px solid rgba(255, 255, 255, 0.4);
  color: #fff;
  border-radius: 8px;
  padding: 6px 14px;
  font-size: 13px;
  cursor: pointer;
}

.barra-salir:hover {
  background: rgba(255, 255, 255, 0.12);
}
</style>
