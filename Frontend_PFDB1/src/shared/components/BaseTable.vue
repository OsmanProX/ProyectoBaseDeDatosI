<script setup lang="ts">
import { ArrowUpDown, ArrowUp, ArrowDown, Pencil, Trash2 } from 'lucide-vue-next'
import type { Column, DisplayRow } from '@/core/types/api.types'
import BaseBadge from './BaseBadge.vue'
defineProps<{
  rows: DisplayRow[]
  columns: Column[]
  sortKey: string
  ascending: boolean
  busy?: boolean
}>()
const emit = defineEmits<{ sort: [key: string]; edit: [id: number]; remove: [id: number] }>()
function text(value: unknown) {
  return value === null || value === undefined || value === '' ? '—' : String(value)
}
</script>
<template>
  <div class="overflow-x-auto">
    <table class="w-full whitespace-nowrap text-left text-sm">
      <caption class="sr-only">
        Listado de registros; usa los encabezados para ordenar.
      </caption>
      <thead class="border-y border-border bg-background/80 text-xs text-muted">
        <tr>
          <th
            v-for="column in columns"
            :key="column.key"
            scope="col"
            class="px-5 py-3.5 font-medium"
            :aria-sort="column.key === sortKey ? (ascending ? 'ascending' : 'descending') : 'none'"
          >
            <button
              v-if="column.sortable !== false"
              class="flex items-center gap-2"
              @click="emit('sort', column.key)"
            >
              {{ column.label
              }}<component
                :is="column.key === sortKey ? (ascending ? ArrowUp : ArrowDown) : ArrowUpDown"
                class="h-3 w-3"
              /></button
            ><span v-else>{{ column.label }}</span>
          </th>
          <th scope="col" class="px-5 py-3.5 text-right font-medium">Acciones</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-border">
        <tr v-for="row in rows" :key="row.id" class="hover:bg-primary/[0.025]">
          <td v-for="column in columns" :key="column.key" class="px-5 py-4">
            <slot :name="`cell-${column.key}`" :row="row" :value="row[column.key]"
              ><BaseBadge v-if="column.key === 'active'" :active="row.active" /><span
                v-else
                :class="column.key === 'name' ? 'font-medium' : 'text-muted'"
                >{{ text(row[column.key]) }}</span
              ></slot
            >
          </td>
          <td class="px-5 py-4 text-right">
            <button
              class="icon-button"
              :aria-label="`Editar registro ${row.id}`"
              :disabled="busy"
              @click="emit('edit', row.id)"
            >
              <Pencil class="h-4 w-4" /></button
            ><button
              class="icon-button hover:!bg-danger/10 hover:!text-danger"
              :aria-label="`Eliminar registro ${row.id}`"
              :disabled="busy"
              @click="emit('remove', row.id)"
            >
              <Trash2 class="h-4 w-4" />
            </button>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
