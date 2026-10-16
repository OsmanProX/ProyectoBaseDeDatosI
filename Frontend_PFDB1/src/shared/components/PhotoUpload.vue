<script setup lang="ts">
import { ref, useId } from 'vue'
import { Camera, UploadCloud, X } from 'lucide-vue-next'
const props = defineProps<{ preview: string; error: string; disabled: boolean }>()
const emit = defineEmits<{ select: [file: File]; remove: [] }>()
const id = useId()
const dragging = ref(false)
function select(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (file) emit('select', file)
  input.value = ''
}
function drop(event: DragEvent) {
  dragging.value = false
  if (props.disabled) return
  const file = event.dataTransfer?.files[0]
  if (file) emit('select', file)
}
</script>
<template>
  <div>
    <div
      :class="dragging ? 'border-primary bg-primary/10' : 'border-border bg-background/60'"
      class="relative flex flex-col items-center gap-4 rounded-2xl border-2 border-dashed p-5 sm:flex-row"
      @dragover.prevent="dragging = true"
      @dragleave.prevent="dragging = false"
      @drop.prevent="drop"
    >
      <div
        class="flex h-20 w-20 shrink-0 items-center justify-center overflow-hidden rounded-2xl border border-border bg-surface"
      >
        <img
          v-if="preview"
          :src="preview"
          alt="Vista previa de la fotografía"
          class="h-full w-full object-cover"
        /><Camera v-else class="h-8 w-8 text-primary/50" stroke-width="1.5" />
      </div>
      <div class="flex-1 text-center sm:text-left">
        <h4 class="text-sm font-semibold">Fotografía de perfil</h4>
        <p class="mb-3 mt-1 text-xs leading-5 text-muted">
          Arrastra una imagen aquí o selecciónala desde tu dispositivo.
        </p>
        <label
          :for="id"
          class="inline-flex cursor-pointer items-center gap-2 rounded-lg border border-border bg-surface px-3 py-2 text-xs font-medium hover:border-primary hover:text-primary"
          ><UploadCloud class="h-4 w-4" />{{
            preview ? 'Cambiar fotografía' : 'Seleccionar fotografía'
          }}</label
        ><input
          :id="id"
          type="file"
          accept="image/jpeg,image/png,image/webp"
          :disabled="disabled"
          class="sr-only"
          aria-label="Seleccionar fotografía"
          @change="select"
        /><span class="ml-3 text-[11px] text-muted">JPG, PNG o WebP · hasta 5 MB</span>
      </div>
      <button
        v-if="preview"
        type="button"
        class="icon-button absolute right-2 top-2"
        aria-label="Quitar fotografía"
        :disabled="disabled"
        @click="emit('remove')"
      >
        <X class="h-4 w-4" />
      </button>
    </div>
    <p v-if="error" class="field-error" role="alert">{{ error }}</p>
  </div>
</template>
