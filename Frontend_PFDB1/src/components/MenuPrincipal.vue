<script setup lang="ts">
// Menú principal: solo muestra las opciones que le tocan al rol del usuario
import type { IdVista, OpcionMenu } from '../sesion'

defineProps<{ opciones: OpcionMenu[] }>()
const vista = defineModel<IdVista>({ required: true })
</script>

<template>
  <nav class="menu" aria-label="Menú principal">
    <ul>
      <li v-for="o in opciones" :key="o.id">
        <button
          type="button"
          class="opcion"
          :class="{ activa: vista === o.id, pendiente: !!o.pendiente }"
          :aria-current="vista === o.id ? 'page' : undefined"
          @click="vista = o.id"
        >
          {{ o.texto }}
          <span v-if="o.pendiente" class="marca">Pronto</span>
        </button>
      </li>
    </ul>
  </nav>
</template>

<style scoped>
.menu {
  background: #fff;
  border-bottom: 1px solid #d0d7e2;
  overflow-x: auto;
}
ul {
  display: flex;
  gap: 4px;
  max-width: 1180px;
  margin: 0 auto;
  padding: 0 16px;
  list-style: none;
}
.opcion {
  font: inherit;
  font-size: 15px;
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 12px 14px 10px;
  border: none;
  border-bottom: 3px solid transparent;
  background: none;
  color: #17375e;
  cursor: pointer;
  white-space: nowrap;
}
.opcion:hover { background: #f4f6fa; }
.opcion.activa {
  border-bottom-color: #c8962e;
  font-weight: 700;
}
.opcion.pendiente { color: #5a6472; }
.opcion:focus-visible { outline: 3px solid #c8962e; outline-offset: -3px; }
.marca {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.02em;
  padding: 1px 6px;
  border-radius: 3px;
  background: #eef1f6;
  color: #5a6472;
}
</style>
