<script setup lang="ts">
import { CheckCircle2, CircleAlert, X } from 'lucide-vue-next'
import { useToast } from '@/core/composables/useToast'
const toast = useToast()
</script>
<template>
  <Teleport to="body"
    ><div
      class="fixed bottom-5 right-5 z-50 flex w-[min(24rem,calc(100%-2.5rem))] flex-col gap-3"
      aria-live="polite"
      aria-atomic="false"
    >
      <div
        v-for="item in toast.messages"
        :key="item.id"
        class="panel flex items-start gap-3 p-4"
        :role="item.tone === 'danger' ? 'alert' : 'status'"
      >
        <component
          :is="item.tone === 'danger' ? CircleAlert : CheckCircle2"
          :class="item.tone === 'danger' ? 'text-danger' : 'text-success'"
          class="h-5 w-5 shrink-0"
        />
        <p class="flex-1 text-sm leading-5">{{ item.message }}</p>
        <button
          class="icon-button -mr-2 -mt-2 shrink-0"
          aria-label="Cerrar notificación"
          @click="toast.dismiss(item.id)"
        >
          <X class="h-4 w-4" />
        </button>
      </div></div
  ></Teleport>
</template>
