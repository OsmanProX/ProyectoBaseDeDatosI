<script setup lang="ts">
import type { Option } from '@/core/types/api.types'
import SearchInput from './SearchInput.vue'
import BaseSelect from './BaseSelect.vue'
defineProps<{ search: string; active: string; stateId: string; states: Option[] }>()
defineEmits<{
  'update:search': [value: string]
  'update:active': [value: string]
  'update:stateId': [value: string]
}>()
const activeOptions = [
  { value: 1, label: 'Activos' },
  { value: 0, label: 'Inactivos' },
]
</script>
<template>
  <div class="flex flex-wrap items-center gap-3 p-5">
    <SearchInput
      :model-value="search"
      @update:model-value="$emit('update:search', $event)"
    /><BaseSelect
      :model-value="active"
      :options="activeOptions"
      placeholder="Todos los registros"
      aria-label="Filtrar por activo"
      class="min-w-40"
      @update:model-value="$emit('update:active', $event)"
    /><BaseSelect
      :model-value="stateId"
      :options="states"
      placeholder="Todos los estados"
      aria-label="Filtrar por estado"
      class="min-w-40"
      @update:model-value="$emit('update:stateId', $event)"
    />
  </div>
</template>
