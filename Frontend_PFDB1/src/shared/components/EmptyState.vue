<script setup lang="ts">
import { FolderSearch } from 'lucide-vue-next'
withDefaults(defineProps<{ title?: string; description?: string }>(), {
  title: 'No hay registros para mostrar',
  description: 'Prueba otra búsqueda o crea tu primer registro.',
})
</script>
<template>
  <div class="flex flex-col items-center px-6 py-16 text-center">
    <div class="mb-4 rounded-2xl bg-primary/5 p-5 text-primary">
      <FolderSearch class="h-8 w-8" />
    </div>
    <h2 class="font-semibold">{{ title }}</h2>
    <p class="mt-2 max-w-sm text-sm leading-6 text-muted">{{ description }}</p>
    <div class="mt-5"><slot /></div>
  </div>
</template>
