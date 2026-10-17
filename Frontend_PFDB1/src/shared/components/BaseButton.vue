<script setup lang="ts">
import { LoaderCircle } from 'lucide-vue-next'
withDefaults(
  defineProps<{
    variant?: 'primary' | 'secondary' | 'danger'
    loading?: boolean
    disabled?: boolean
    type?: 'button' | 'submit' | 'reset'
  }>(),
  { variant: 'primary', type: 'button' },
)
const variants = {
  primary: 'bg-primary text-white hover:bg-primary-dark dark:text-background',
  secondary: 'border border-border bg-surface text-text hover:bg-background',
  danger: 'bg-danger text-white hover:opacity-90 dark:text-background',
}
</script>
<template>
  <button
    :type="type"
    :disabled="disabled || loading"
    :aria-busy="loading"
    :class="variants[variant]"
    class="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg px-4 py-2.5 text-sm font-medium"
  >
    <LoaderCircle v-if="loading" class="h-4 w-4 animate-spin" aria-hidden="true" /><slot />
  </button>
</template>
