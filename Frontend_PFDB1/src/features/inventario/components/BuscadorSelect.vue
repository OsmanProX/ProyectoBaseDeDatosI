<script setup lang="ts">
// Selector con búsqueda: al escribir aparecen las coincidencias debajo y se elige con clic o Enter.
import { computed, ref, watch } from 'vue'

export interface Opcion { id: number; texto: string }

const props = defineProps<{ opciones: Opcion[]; modelValue: number; placeholder?: string; etiqueta?: string }>()
const emit = defineEmits<{ 'update:modelValue': [id: number]; elegir: [id: number] }>()

const texto = ref('')
const abierto = ref(false)
const activo = ref(0)
const norm = (v: string) => v.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()

const elegida = computed(() => props.opciones.find((o) => o.id === props.modelValue))
watch(elegida, (o) => { texto.value = o?.texto ?? '' }, { immediate: true })

const filtradas = computed(() => {
  const t = norm(texto.value.trim())
  if (!t || texto.value === elegida.value?.texto) return props.opciones.slice(0, 50)
  return props.opciones.filter((o) => norm(o.texto).includes(t)).slice(0, 50)
})

function elegir(o: Opcion) {
  emit('update:modelValue', o.id)
  emit('elegir', o.id)
  texto.value = o.texto
  abierto.value = false
}

function tecla(e: KeyboardEvent) {
  if (e.key === 'ArrowDown') {
    e.preventDefault()
    if (!abierto.value) abierto.value = true
    else activo.value = Math.min(activo.value + 1, filtradas.value.length - 1)
  } else if (e.key === 'ArrowUp') {
    e.preventDefault()
    activo.value = Math.max(activo.value - 1, 0)
  } else if (e.key === 'Enter') {
    const o = filtradas.value[activo.value]
    if (abierto.value && o) { e.preventDefault(); elegir(o) }
  } else if (e.key === 'Escape') {
    abierto.value = false
  }
}

// Al salir sin elegir, vuelve a mostrar la opción elegida
function salir() {
  setTimeout(() => { abierto.value = false; texto.value = elegida.value?.texto ?? '' }, 150)
}
</script>

<template>
  <div class="buscador">
    <input v-model="texto" type="text" role="combobox" autocomplete="off" :aria-label="etiqueta"
      :aria-expanded="abierto" :placeholder="placeholder ?? 'Escriba para buscar…'"
      @focus="abierto = true" @input="abierto = true; activo = 0" @keydown="tecla" @blur="salir" />
    <!-- mousedown.prevent: usar la barra de desplazamiento no quita el foco del cuadro -->
    <ul v-if="abierto" class="lista" role="listbox" @mousedown.prevent>
      <li v-for="(o, i) in filtradas" :key="o.id" role="option" :aria-selected="o.id === modelValue"
        :class="{ activo: i === activo, elegido: o.id === modelValue }" @mousedown.prevent="elegir(o)">
        {{ o.texto }}
      </li>
      <li v-if="!filtradas.length" class="vacio">Sin resultados</li>
    </ul>
  </div>
</template>

<style scoped>
.buscador { position: relative; width: 100%; }
.buscador input { font: inherit; font-size: 15px; padding: 9px 10px; border: 1px solid var(--c-input); border-radius: 4px;
  background: var(--c-surface); color: var(--c-text); box-sizing: border-box; width: 100%; }
.buscador input { width: 100%; box-sizing: border-box; }
.buscador input:focus-visible { outline: 3px solid #c8962e; outline-offset: 1px; }
.lista { position: absolute; z-index: 30; left: 0; right: 0; top: 100%; margin: 2px 0 0; padding: 4px 0; list-style: none;
  max-height: 220px; overflow-y: auto; background: var(--c-surface, #fff); color: var(--c-text, #222);
  border: 1px solid var(--c-input, #c9d2de); border-radius: 4px; box-shadow: 0 6px 16px rgba(0, 0, 0, 0.3); }
.lista li { padding: 6px 10px; cursor: pointer; font-size: 14px; text-align: left; }
.lista li.elegido { font-weight: 600; }
.lista li.activo, .lista li:hover { background: #1d4f8a; color: #fff; }
.lista li.vacio { cursor: default; opacity: 0.7; }
</style>
