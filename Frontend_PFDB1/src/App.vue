<script setup lang="ts">
// Login (Osman) + menú por rol: cada usuario ve solo las pantallas de su rol.
import { computed, ref, watch } from 'vue'
import LoginView from './views/LoginView.vue'
import OrdenesView from './views/OrdenesView.vue'
import EquiposView from './views/EquiposView.vue'
import MenuPrincipal from './components/MenuPrincipal.vue'
import PantallaPendiente from './components/PantallaPendiente.vue'
import {
  leerSesion, cerrarSesion as borrarSesion, opcionesDelMenu, tieneRol,
  type IdVista, type Sesion,
} from './sesion'

const sesion = ref<Sesion | null>(leerSesion())

const opciones = computed(() => (sesion.value ? opcionesDelMenu(sesion.value.roles) : []))
const vista = ref<IdVista>('ordenes')
const opcionActual = computed(() => opciones.value.find((o) => o.id === vista.value))

// Al entrar (o al cambiar de usuario) se abre la primera pantalla que le toca
watch(opciones, (lista) => {
  if (!lista.some((o) => o.id === vista.value)) {
    vista.value = (lista.find((o) => !o.pendiente) ?? lista[0])?.id ?? 'ordenes'
  }
}, { immediate: true })

const puedeEditarEquipos = computed(() => !!sesion.value && tieneRol(sesion.value.roles, 'RECEPCION'))

function alIniciar() {
  // LoginView ya guardó el token y el usuario; aquí solo se vuelven a leer
  sesion.value = leerSesion()
}

function cerrarSesion() {
  borrarSesion()
  sesion.value = null
}
</script>

<template>
  <LoginView v-if="!sesion" @iniciado="alIniciar" />

  <div v-else>
    <header class="barra-sesion">
      <div class="barra-usuario">
        <span class="barra-avatar" aria-hidden="true">&#128100;</span>
        <span class="barra-nombre">{{ sesion.nombreCompleto }}</span>
        <span v-for="r in sesion.roles" :key="r" class="barra-rol">{{ r }}</span>
        <span v-if="!sesion.roles.length" class="barra-rol">SIN ROL</span>
      </div>
      <button class="barra-salir" @click="cerrarSesion">Cerrar sesión</button>
    </header>

    <MenuPrincipal v-if="opciones.length" v-model="vista" :opciones="opciones" />

    <PantallaPendiente
      v-if="!opciones.length"
      titulo="Sin acceso"
      detalle="Su usuario no tiene un rol asignado. Pida al administrador que le asigne uno."
    />
    <OrdenesView v-else-if="vista === 'ordenes'" />
    <EquiposView v-else-if="vista === 'equipos'" :puede-editar="puedeEditarEquipos" />
    <PantallaPendiente v-else-if="opcionActual" :titulo="opcionActual.texto" :detalle="opcionActual.pendiente" />
  </div>
</template>

<style scoped>
.barra-sesion {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  background: #1e2a4a;
  color: #fff;
  padding: 10px 22px;
}

.barra-usuario {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px 10px;
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
  white-space: nowrap;
}

.barra-salir:hover {
  background: rgba(255, 255, 255, 0.12);
}
</style>
