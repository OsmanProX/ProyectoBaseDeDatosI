<script setup lang="ts">
import { useId } from 'vue'
defineOptions({ inheritAttrs: false })
withDefaults(
  defineProps<{
    modelValue?: string | number | null
    label?: string
    type?: string
    error?: string
    placeholder?: string
  }>(),
  { type: 'text', modelValue: '', label: undefined, error: undefined, placeholder: undefined },
)
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()
const id = useId()
function update(event: Event) {
  emit('update:modelValue', (event.target as HTMLInputElement).value)
}
</script>
<template>
  <div>
    <label v-if="label" :for="id" class="label">{{ label }}</label
    ><input
      :id="id"
      v-bind="$attrs"
      :value="modelValue"
      :type="type"
      :placeholder="placeholder"
      :aria-invalid="!!error"
      :aria-describedby="error ? `${id}-error` : undefined"
      class="control"
      @input="update"
    />
    <p v-if="error" :id="`${id}-error`" class="field-error">{{ error }}</p>
  </div>
</template>
