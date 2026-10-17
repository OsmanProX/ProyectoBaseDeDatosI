<script setup lang="ts">
import { computed, ref, useId } from 'vue'
import { Eye, EyeOff, KeyRound } from 'lucide-vue-next'
import { useField } from 'vee-validate'
defineProps<{ label: string }>()
const { value, errorMessage, handleBlur } = useField<string>('password')
const reveal = ref(false)
const id = useId()
const strength = computed(() => {
  const password = value.value ?? ''
  if (!password.length)
    return { score: 0, label: 'Usa al menos 8 caracteres; combina letras, números y símbolos.' }
  const score =
    Number(password.length >= 8) +
    Number(/[a-z]/.test(password) && /[A-Z]/.test(password)) +
    Number(/\d/.test(password)) +
    Number(/[^\w]/.test(password))
  return {
    score,
    label:
      score >= 3
        ? 'Buena combinación de caracteres'
        : 'Puedes reforzarla combinando letras, números y símbolos.',
  }
})
</script>
<template>
  <div>
    <label :for="id" class="label">{{ label }}</label>
    <div class="relative">
      <KeyRound class="absolute left-3 top-3.5 h-4 w-4 text-muted" /><input
        :id="id"
        v-model="value"
        :type="reveal ? 'text' : 'password'"
        autocomplete="new-password"
        class="control pl-10 pr-12"
        :aria-invalid="!!errorMessage"
        :aria-describedby="`${id}-help`"
        placeholder="Mínimo 8 caracteres"
        @blur="handleBlur"
      /><button
        type="button"
        class="icon-button absolute right-1 top-1"
        :aria-label="reveal ? 'Ocultar contraseña' : 'Mostrar contraseña'"
        @click="reveal = !reveal"
      >
        <component :is="reveal ? EyeOff : Eye" class="h-4 w-4" />
      </button>
    </div>
    <div class="mt-3 flex gap-1.5" aria-hidden="true">
      <span
        v-for="step in 4"
        :key="step"
        :class="step <= strength.score ? 'bg-accent' : 'bg-border'"
        class="h-1 flex-1 rounded-full"
      />
    </div>
    <p
      :id="`${id}-help`"
      :class="errorMessage ? 'field-error' : 'mt-2 text-xs leading-5 text-muted'"
    >
      {{ errorMessage || strength.label }}
    </p>
  </div>
</template>
