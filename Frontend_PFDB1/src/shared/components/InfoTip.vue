<script setup lang="ts">
// Ícono "!" con una explicación corta. Se ve al pasar el mouse, al enfocarlo con Tab o al tocarlo.
// El globo se dibuja con position: fixed y se acomoda dentro de la pantalla, para que no lo corte
// una ventana (modal) ni haga aparecer una barra de desplazamiento.
import { ref } from 'vue'

const props = defineProps<{ texto: string; derecha?: boolean }>()
const abierto = ref(false)
const ancla = ref<HTMLElement | null>(null)
const pos = ref({ top: 0, left: 0 })

const ANCHO = 240
const MARGEN = 8

function abrir() {
  const r = ancla.value?.getBoundingClientRect()
  if (r) {
    let left = props.derecha ? r.right + MARGEN - ANCHO : r.left - MARGEN
    left = Math.min(Math.max(left, MARGEN), window.innerWidth - ANCHO - MARGEN)
    pos.value = { top: r.bottom + 6, left }
  }
  abierto.value = true
}
function alternar() {
  if (abierto.value) abierto.value = false
  else abrir()
}
</script>

<template>
  <span ref="ancla" class="info" @mouseenter="abrir" @mouseleave="abierto = false">
    <button type="button" class="icono" :aria-label="texto" :aria-expanded="abierto"
      @click.stop="alternar" @focus="abrir" @blur="abierto = false">!</button>
    <span v-if="abierto" class="globo" role="tooltip" :style="{ top: pos.top + 'px', left: pos.left + 'px' }">{{ texto }}</span>
  </span>
</template>

<style scoped>
.info { position: relative; display: inline-flex; vertical-align: middle; margin-left: 5px; }
.icono { width: 16px; height: 16px; padding: 0; border-radius: 50%; border: none; cursor: help;
  background: #c8962e; color: #10213a; font: 700 11px/16px Arial, sans-serif; text-align: center; }
.icono:focus-visible { outline: 2px solid #fff; outline-offset: 1px; }
.globo { position: fixed; z-index: 1000; width: 240px; padding: 8px 10px;
  border-radius: 6px; background: #10213a; color: #f2f5fa; border: 1px solid #c8962e;
  font-size: 12px; font-weight: 400; line-height: 1.45; text-align: left; white-space: normal;
  text-transform: none; letter-spacing: 0; box-shadow: 0 6px 16px rgba(0, 0, 0, 0.35); pointer-events: none; }
</style>
