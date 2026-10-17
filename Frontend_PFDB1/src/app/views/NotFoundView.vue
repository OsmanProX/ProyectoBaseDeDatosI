<script setup lang="ts">
import { ArrowLeft } from 'lucide-vue-next'
</script>
<template>
  <section class="py-24 text-center">
    <p class="text-7xl font-semibold text-primary/30">404</p>
    <h1 class="mt-5 text-2xl font-semibold">Esta página no está aquí</h1>
    <p class="mt-3 text-sm text-muted">
      La dirección puede haber cambiado o todavía no tiene una pantalla asignada.
    </p>
    <RouterLink
      to="/"
      class="mt-7 inline-flex items-center gap-2 rounded-lg bg-primary px-4 py-3 text-sm text-white dark:text-background"
      ><ArrowLeft class="h-4 w-4" />Volver al inicio</RouterLink
    >
  </section>
</template>
