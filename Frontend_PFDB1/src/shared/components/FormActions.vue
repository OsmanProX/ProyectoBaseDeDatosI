<script setup lang="ts">
import { Check, ArrowRight } from 'lucide-vue-next'
import BaseButton from './BaseButton.vue'
defineProps<{ busy: boolean; disabled: boolean; editing: boolean }>()
defineEmits<{ cancel: [] }>()
</script>
<template>
  <footer
    class="sticky bottom-0 z-10 -mx-6 flex flex-wrap items-center justify-between gap-3 border-t border-border bg-surface/95 px-6 py-5 backdrop-blur"
  >
    <span class="hidden items-center gap-1.5 text-xs text-muted sm:flex"
      ><Check class="h-3.5 w-3.5 text-accent" />Revisa los datos antes de guardar</span
    >
    <div class="ml-auto flex gap-3">
      <BaseButton variant="secondary" :disabled="busy" @click="$emit('cancel')">Cancelar</BaseButton
      ><BaseButton type="submit" :loading="busy" :disabled="disabled"
        >{{ editing ? 'Guardar cambios' : 'Crear registro'
        }}<ArrowRight v-if="!busy" class="h-4 w-4"
      /></BaseButton>
    </div>
  </footer>
</template>
