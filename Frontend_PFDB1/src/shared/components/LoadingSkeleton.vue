<template>
  <div role="status" aria-label="Cargando registros" class="space-y-4 p-6">
    <span class="sr-only">Cargando…</span>
    <div v-for="row in 5" :key="row" class="flex animate-pulse gap-5 border-b border-border pb-4">
      <div class="h-10 w-10 rounded-lg bg-border" />
      <div class="flex-1 space-y-2">
        <div class="h-3 w-1/3 rounded bg-border" />
        <div class="h-3 w-1/2 rounded bg-border/60" />
      </div>
      <div class="h-6 w-16 rounded-full bg-border" />
    </div>
  </div>
</template>
