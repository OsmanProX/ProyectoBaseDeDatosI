<script setup lang="ts">
import { computed, ref } from 'vue'
import LoginView from './views/LoginView.vue'
import OrdenesView from './views/OrdenesView.vue'
import UsuariosView from './views/UsuariosView.vue'
import AccesoDenegado from './views/AccesoDenegado.vue'

interface UsuarioSesion {
  nombreCompleto?: string
  roles?: string
}

type IdSeccion = 'ordenes' | 'usuarios'

// Secciones disponibles y los roles que pueden abrirlas
const SECCIONES: { id: IdSeccion; titulo: string; roles: string[] }[] = [
  { id: 'ordenes', titulo: 'Órdenes', roles: ['ADMINISTRADOR', 'RECEPCION', 'TECNICO', 'BODEGA', 'CAJA'] },
  { id: 'usuarios', titulo: 'Usuarios', roles: ['ADMINISTRADOR'] },
]

const token = ref<string | null>(localStorage.getItem('token'))
const usuario = ref<UsuarioSesion | null>(
  JSON.parse(localStorage.getItem('usuario') ?? 'null'),
)

const rol = computed(() => (usuario.value?.roles ?? '').toUpperCase())
const vista = ref<IdSeccion>('ordenes')

// true si el rol de este usuario puede abrir la sección
function puedeAbrir(id: IdSeccion): boolean {
  const seccion = SECCIONES.find((s) => s.id === id)
  return !!seccion && seccion.roles.includes(rol.value)
}

function abrir(id: IdSeccion) {
  vista.value = id
}

function alIniciar(datos: { token: string; usuario: Record<string, unknown> }) {
  token.value = datos.token
  usuario.value = datos.usuario as UsuarioSesion
  vista.value = 'ordenes'
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
      <nav class="barra-menu">
        <button
          v-for="s in SECCIONES"
          :key="s.id"
          class="menu-item"
          :class="{ activo: vista === s.id }"
          @click="abrir(s.id)"
        >
          {{ s.titulo }}
        </button>
      </nav>
      <div class="barra-der">
        <div class="barra-usuario">
          <span class="barra-nombre">{{ usuario?.nombreCompleto }}</span>
          <span class="barra-rol">{{ usuario?.roles }}</span>
        </div>
        <button class="barra-salir" @click="cerrarSesion">Cerrar sesión</button>
      </div>
    </header>

    <AccesoDenegado
      v-if="!puedeAbrir(vista)"
      :seccion="SECCIONES.find((s) => s.id === vista)?.titulo ?? vista"
      @volver="vista = 'ordenes'"
    />
    <UsuariosView v-else-if="vista === 'usuarios'" />
    <OrdenesView v-else />
  </div>
</template>

<style scoped>
.barra-sesion {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #1e2a4a;
  color: #fff;
  padding: 0 22px;
}

.barra-menu {
  display: flex;
  gap: 4px;
}

.menu-item {
  background: transparent;
  border: none;
  color: rgba(255, 255, 255, 0.75);
  font-size: 14px;
  font-weight: 600;
  padding: 14px 16px;
  cursor: pointer;
  border-bottom: 3px solid transparent;
}

.menu-item:hover {
  color: #fff;
}

.menu-item.activo {
  color: #fff;
  border-bottom-color: #6c8bff;
}

.barra-der {
  display: flex;
  align-items: center;
  gap: 14px;
}

.barra-usuario {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
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
