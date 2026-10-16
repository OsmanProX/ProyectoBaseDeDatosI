<script setup lang="ts">
import { Search, X } from 'lucide-vue-next'
withDefaults(defineProps<{ modelValue: string; placeholder?: string }>(), {
  placeholder: 'Buscar registros…',
})
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()
function update(event: Event) {
  emit('update:modelValue', (event.target as HTMLInputElement).value)
}
</script>
<template>
  <div class="relative min-w-48 flex-1">
    <Search
      class="pointer-events-none absolute left-3 top-3.5 h-4 w-4 text-muted"
      aria-hidden="true"
    /><input
      :value="modelValue"
      :placeholder="placeholder"
      type="search"
      aria-label="Buscar registros"
      class="control pl-10 pr-10"
      @input="update"
    /><button
      v-if="modelValue"
      type="button"
      class="icon-button absolute right-1 top-1"
      aria-label="Limpiar búsqueda"
      @click="emit('update:modelValue', '')"
    >
      <X class="h-4 w-4" />
    </button>
  </div>
</template>
