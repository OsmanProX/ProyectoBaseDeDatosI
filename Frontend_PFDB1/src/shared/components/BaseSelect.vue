<script setup lang="ts">
import { useId } from 'vue'
import type { Option } from '@/core/types/api.types'
defineOptions({ inheritAttrs: false })
withDefaults(
  defineProps<{
    modelValue?: string | number | null
    options: Option[]
    label?: string
    placeholder?: string
    error?: string
  }>(),
  { placeholder: 'Seleccionar', modelValue: '', label: undefined, error: undefined },
)
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()
const id = useId()
function update(event: Event) {
  emit('update:modelValue', (event.target as HTMLSelectElement).value)
}
</script>
<template>
  <div>
    <label v-if="label" :for="id" class="label">{{ label }}</label
    ><select
      :id="id"
      v-bind="$attrs"
      :value="modelValue ?? ''"
      class="control"
      :aria-invalid="!!error"
      :aria-describedby="error ? `${id}-error` : undefined"
      @change="update"
    >
      <option value="">{{ placeholder }}</option>
      <option v-for="option in options" :key="option.value" :value="option.value">
        {{ option.label }}
      </option>
    </select>
    <p v-if="error" :id="`${id}-error`" class="field-error">{{ error }}</p>
  </div>
</template>
