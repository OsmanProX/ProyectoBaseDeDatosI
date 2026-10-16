<script setup lang="ts">
// Lugar reservado para las pantallas que todavía no están listas
defineProps<{ titulo: string; detalle?: string }>()
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <h1>{{ titulo }}</h1>
    </header>
    <section class="caja">
      <p class="titulo">Esta sección todavía está en construcción.</p>
      <p v-if="detalle" class="detalle">{{ detalle }}</p>
    </section>
  </main>
</template>

<style scoped>
.pagina { max-width: 1180px; margin: 0 auto; padding: 32px 24px 64px; text-align: left; color: #222b38; }
.cabecera { border-bottom: 3px solid #c8962e; padding-bottom: 16px; margin-bottom: 24px; }
h1 { margin: 0; font: 700 28px/1.2 Georgia, 'Times New Roman', serif; color: #17375e; }
.caja { border: 1px dashed #b9c2d0; border-radius: 4px; padding: 28px 24px; background: #f8f9fc; }
.titulo { margin: 0; font-weight: 600; color: #17375e; }
.detalle { margin: 6px 0 0; color: #5a6472; }
</style>
