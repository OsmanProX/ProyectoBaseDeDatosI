<script setup lang="ts">
import { computed } from 'vue'
import { ChevronLeft, ChevronRight } from 'lucide-vue-next'
const props = defineProps<{ page: number; pageSize: number; total: number; pages: number }>()
const emit = defineEmits<{ 'update:page': [page: number]; 'update:pageSize': [size: number] }>()
const range = computed(() =>
  props.total
    ? `${(props.page - 1) * props.pageSize + 1}–${Math.min(props.page * props.pageSize, props.total)} de ${props.total}`
    : '0 registros',
)
function resize(event: Event) {
  emit('update:pageSize', Number((event.target as HTMLSelectElement).value))
}
</script>
<template>
  <footer
    class="flex flex-wrap items-center justify-between gap-4 border-t border-border px-5 py-4 text-xs text-muted"
  >
    <div class="flex items-center gap-3">
      <span>{{ range }}</span
      ><label class="flex items-center gap-2"
        >Por página<select
          :value="pageSize"
          class="rounded border border-border bg-surface px-2 py-1 text-text"
          @change="resize"
        >
          <option v-for="size in [10, 25, 50]" :key="size" :value="size">{{ size }}</option>
        </select></label
      >
    </div>
    <div class="flex items-center gap-3">
      <button
        class="icon-button"
        aria-label="Página anterior"
        :disabled="page <= 1"
        @click="emit('update:page', page - 1)"
      >
        <ChevronLeft class="h-4 w-4" /></button
      ><span>Página {{ page }} de {{ pages }}</span
      ><button
        class="icon-button"
        aria-label="Página siguiente"
        :disabled="page >= pages"
        @click="emit('update:page', page + 1)"
      >
        <ChevronRight class="h-4 w-4" />
      </button>
    </div>
  </footer>
</template>
