<script setup lang="ts">
// Ícono "!" con una explicación corta. Se ve al pasar el mouse, al enfocarlo con Tab o al tocarlo.
import { ref } from 'vue'

defineProps<{ texto: string; derecha?: boolean }>()
const abierto = ref(false)
</script>

<template>
  <span class="info" :class="{ derecha }" @mouseenter="abierto = true" @mouseleave="abierto = false">
    <button type="button" class="icono" :aria-label="texto" :aria-expanded="abierto"
      @click.stop="abierto = !abierto" @focus="abierto = true" @blur="abierto = false">!</button>
    <span v-if="abierto" class="globo" role="tooltip">{{ texto }}</span>
  </span>
</template>

<style scoped>
.info { position: relative; display: inline-flex; vertical-align: middle; margin-left: 5px; }
.icono { width: 16px; height: 16px; padding: 0; border-radius: 50%; border: none; cursor: help;
  background: #c8962e; color: #10213a; font: 700 11px/16px Arial, sans-serif; text-align: center; }
.icono:focus-visible { outline: 2px solid #fff; outline-offset: 1px; }
.globo { position: absolute; z-index: 40; top: calc(100% + 6px); left: -8px; width: 240px; padding: 8px 10px;
  border-radius: 6px; background: #10213a; color: #f2f5fa; border: 1px solid #c8962e;
  font-size: 12px; font-weight: 400; line-height: 1.45; text-align: left; white-space: normal;
  text-transform: none; letter-spacing: 0; box-shadow: 0 6px 16px rgba(0, 0, 0, 0.35); }
.derecha .globo { left: auto; right: -8px; }
</style>
