<script setup lang="ts">
withDefaults(defineProps<{ active?: boolean; label?: string }>(), {
  active: true,
  label: undefined,
})
</script>
<template>
  <span
    :class="active ? 'bg-success/10 text-green-700 dark:text-success' : 'bg-muted/10 text-muted'"
    class="inline-flex items-center gap-1.5 whitespace-nowrap rounded-full px-2.5 py-1 text-xs font-medium"
    ><span :class="active ? 'bg-success' : 'bg-muted'" class="h-1.5 w-1.5 rounded-full" />{{
      label ?? (active ? 'Activo' : 'Inactivo')
    }}</span
  >
</template>
