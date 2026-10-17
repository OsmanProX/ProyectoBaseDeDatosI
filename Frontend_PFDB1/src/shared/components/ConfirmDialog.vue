<script setup lang="ts">
import { Trash2 } from 'lucide-vue-next'
import { useConfirm } from '@/core/composables/useConfirm'
import BaseModal from './BaseModal.vue'
import BaseButton from './BaseButton.vue'
const confirm = useConfirm()
</script>
<template>
  <BaseModal :open="confirm.open" title="Confirmar eliminación" @close="confirm.answer(false)"
    ><div
      class="mb-5 flex h-12 w-12 items-center justify-center rounded-xl bg-danger/10 text-danger"
    >
      <Trash2 class="h-6 w-6" />
    </div>
    <p class="text-sm leading-6 text-muted">{{ confirm.message }}</p>
    <div class="mt-7 flex justify-end gap-3">
      <BaseButton variant="secondary" @click="confirm.answer(false)">Cancelar</BaseButton
      ><BaseButton variant="danger" @click="confirm.answer(true)">Sí, eliminar</BaseButton>
    </div></BaseModal
  >
</template>
