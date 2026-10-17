<script setup lang="ts">
import { computed, ref } from 'vue'
import type { Option } from '@/core/types/api.types'
import SearchInput from './SearchInput.vue'
const props = defineProps<{
  options: Option[]
  selected: number[]
  disabled?: boolean
  label: string
}>()
const emit = defineEmits<{ 'update:selected': [ids: number[]] }>()
const search = ref('')
const filtered = computed(() =>
  props.options.filter((item) =>
    item.label.toLocaleLowerCase('es').includes(search.value.toLocaleLowerCase('es')),
  ),
)
const selectedSet = computed(() => new Set(props.selected))
function toggle(id: number) {
  const ids = new Set(props.selected)
  if (ids.has(id)) ids.delete(id)
  else ids.add(id)
  emit('update:selected', [...ids])
}
</script>
<template>
  <fieldset class="space-y-3">
    <legend class="label">
      {{ label }} <span class="text-muted">({{ selected.length }})</span>
    </legend>
    <SearchInput v-model="search" placeholder="Buscar opciones…" />
    <div class="max-h-52 space-y-1 overflow-auto rounded-lg border border-border p-2">
      <label
        v-for="option in filtered"
        :key="option.value"
        class="flex cursor-pointer items-center gap-3 rounded-lg p-2.5 text-sm hover:bg-primary/5"
        ><input
          type="checkbox"
          :checked="selectedSet.has(Number(option.value))"
          :disabled="disabled"
          class="h-4 w-4 accent-primary"
          @change="toggle(Number(option.value))"
        />{{ option.label }}</label
      >
      <p v-if="!filtered.length" class="p-3 text-sm text-muted">Sin opciones disponibles.</p>
    </div>
  </fieldset>
</template>
