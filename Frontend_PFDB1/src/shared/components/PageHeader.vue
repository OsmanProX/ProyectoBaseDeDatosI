<script setup lang="ts">
defineProps<{ title: string; description: string; eyebrow?: string }>()
</script>
<template>
  <header class="mb-7 flex flex-wrap items-end justify-between gap-4">
    <div>
      <p v-if="eyebrow" class="eyebrow mb-2">{{ eyebrow }}</p>
      <h1 class="text-2xl font-semibold sm:text-3xl">{{ title }}</h1>
      <p class="mt-2 max-w-2xl text-sm leading-6 text-muted">{{ description }}</p>
    </div>
    <div class="flex items-center gap-2"><slot /></div>
  </header>
</template>
