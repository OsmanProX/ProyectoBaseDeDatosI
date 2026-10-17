<script setup lang="ts">
import { computed, useId } from 'vue'
import { useField } from 'vee-validate'
const props = withDefaults(
  defineProps<{
    name: string
    label: string
    hint?: string
    trueValue?: boolean | string | number
    falseValue?: boolean | string | number
  }>(),
  { hint: undefined, trueValue: true, falseValue: false },
)
const { value, errorMessage } = useField<boolean | string | number>(() => props.name)
const checked = computed(() => value.value === props.trueValue)
const id = useId()
function toggle() {
  value.value = checked.value ? props.falseValue : props.trueValue
}
</script>
<template>
  <div
    class="flex items-center justify-between gap-5 rounded-xl border border-border bg-background/60 p-4"
  >
    <div>
      <label :id="`${id}-label`" class="text-sm font-medium">{{ label }}</label>
      <p v-if="hint" :id="`${id}-hint`" class="mt-1 text-xs leading-5 text-muted">{{ hint }}</p>
      <p v-if="errorMessage" class="field-error">{{ errorMessage }}</p>
    </div>
    <span class="flex shrink-0 items-center gap-3"
      ><span class="text-xs font-medium text-muted" aria-hidden="true">{{
        checked ? 'Sí' : 'No'
      }}</span
      ><button
        type="button"
        role="switch"
        :aria-checked="checked"
        :aria-labelledby="`${id}-label`"
        :aria-describedby="hint ? `${id}-hint` : undefined"
        :class="checked ? 'bg-primary' : 'bg-muted/30'"
        class="relative inline-flex h-7 w-12 shrink-0 items-center rounded-full p-1 transition-colors"
        @click="toggle"
      >
        <span class="sr-only">{{ checked ? 'Sí' : 'No' }}</span
        ><span
          :class="checked ? 'translate-x-5' : 'translate-x-0'"
          class="h-5 w-5 rounded-full bg-white shadow transition-transform duration-200"
        /></button
    ></span>
  </div>
</template>
