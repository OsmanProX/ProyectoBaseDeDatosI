<script setup lang="ts">
defineProps<{ number: string; title: string; description: string }>()
</script>
<template>
  <section class="form-section">
    <header class="mb-5 flex items-start gap-3">
      <span
        class="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-primary/10 text-xs font-semibold text-primary"
        >{{ number }}</span
      >
      <div>
        <h3 class="text-sm font-semibold">{{ title }}</h3>
        <p class="mt-1 text-xs leading-5 text-muted">{{ description }}</p>
      </div>
    </header>
    <div class="space-y-4"><slot /></div>
  </section>
</template>
