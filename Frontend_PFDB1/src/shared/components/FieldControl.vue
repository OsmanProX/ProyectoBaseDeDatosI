<script setup lang="ts">
import { useId } from 'vue'
import { useField } from 'vee-validate'
import type { Option } from '@/core/types/api.types'
defineOptions({ inheritAttrs: false })
const props = withDefaults(
  defineProps<{
    name: string
    label: string
    type?: string
    options?: Option[]
    hint?: string
    disabled?: boolean
  }>(),
  { type: 'text', options: () => [], hint: undefined },
)
const { value, errorMessage, handleBlur } = useField<string | number | boolean | null>(
  () => props.name,
)
const id = useId()
function update(event: Event) {
  const input = event.target as HTMLInputElement
  value.value =
    props.type === 'checkbox'
      ? input.checked
      : props.type === 'number'
        ? input.value === ''
          ? null
          : Number(input.value)
        : input.value
}
</script>
<template>
  <div :class="type === 'checkbox' ? 'flex flex-col justify-end' : ''">
    <label
      :for="id"
      :class="
        type === 'checkbox'
          ? 'flex min-h-11 cursor-pointer items-center gap-3 rounded-lg border border-border px-3 text-sm'
          : 'label'
      "
      ><input
        v-if="type === 'checkbox'"
        :id="id"
        type="checkbox"
        :checked="Boolean(value)"
        :disabled="disabled"
        class="h-4 w-4 accent-primary"
        @change="update"
        @blur="handleBlur"
      />{{ label }}</label
    ><textarea
      v-if="type === 'textarea'"
      :id="id"
      v-bind="$attrs"
      :value="String(value ?? '')"
      :disabled="disabled"
      :aria-invalid="!!errorMessage"
      :aria-describedby="`${id}-help`"
      class="control min-h-24 resize-y"
      @input="update"
      @blur="handleBlur"
    /><select
      v-else-if="type === 'select'"
      :id="id"
      v-bind="$attrs"
      :value="value ?? ''"
      :disabled="disabled"
      :aria-invalid="!!errorMessage"
      :aria-describedby="`${id}-help`"
      class="control"
      @change="update"
      @blur="handleBlur"
    >
      <option value="">Seleccionar</option>
      <option v-for="option in options" :key="option.value" :value="option.value">
        {{ option.label }}
      </option></select
    ><input
      v-else-if="type !== 'checkbox'"
      :id="id"
      v-bind="$attrs"
      :value="value"
      :type="type"
      :disabled="disabled"
      :aria-invalid="!!errorMessage"
      :aria-describedby="`${id}-help`"
      class="control"
      @input="update"
      @blur="handleBlur"
    />
    <p
      :id="`${id}-help`"
      :class="errorMessage ? 'field-error' : 'mt-1.5 text-xs leading-5 text-muted'"
    >
      {{ errorMessage || hint }}
    </p>
  </div>
</template>
