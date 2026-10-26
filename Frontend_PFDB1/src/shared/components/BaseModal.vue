<script setup lang="ts">
import { nextTick, onBeforeUnmount, ref, useId, watch } from 'vue'
import { X, Sparkles } from 'lucide-vue-next'
const props = defineProps<{ open: boolean; title: string; busy?: boolean }>()
const emit = defineEmits<{ close: [] }>()
const dialog = ref<HTMLDialogElement>()
const titleId = useId()
let previousFocus: HTMLElement | null = null
let previousOverflow = ''
watch(
  () => props.open,
  async (open) => {
    await nextTick()
    if (open && dialog.value && !dialog.value.open) {
      previousFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null
      previousOverflow = document.body.style.overflow
      document.body.style.overflow = 'hidden'
      dialog.value.showModal()
      dialog.value.querySelector<HTMLElement>('input, select, textarea, button')?.focus()
    } else if (!open && dialog.value?.open) {
      dialog.value.close()
      document.body.style.overflow = previousOverflow
      previousFocus?.focus()
    }
  },
  { immediate: true },
)
function close() {
  if (!props.busy) emit('close')
}
function trapFocus(event: KeyboardEvent) {
  if (event.key !== 'Tab' || !dialog.value) return
  const controls = Array.from(
    dialog.value.querySelectorAll<HTMLElement>(
      'a[href], button, input, select, textarea, [tabindex]',
    ),
  ).filter(
    (element) =>
      element.tabIndex >= 0 && !element.matches(':disabled') && element.getClientRects().length > 0,
  )
  const first = controls[0]
  const last = controls.at(-1)
  if (!first || !last) {
    event.preventDefault()
    dialog.value.focus()
    return
  }
  // El recorrido explícito impide que Tab pase a los controles del navegador al llegar al borde.
  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault()
    last.focus()
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault()
    first.focus()
  }
}
// showModal vuelve inerte el contenido que queda detrás del formulario.
onBeforeUnmount(() => {
  if (dialog.value?.open) {
    dialog.value.close()
    document.body.style.overflow = previousOverflow
    previousFocus?.focus()
  }
})
</script>
<template>
  <Teleport to="body"
    ><dialog
      ref="dialog"
      :aria-labelledby="titleId"
      :aria-busy="busy"
      class="m-auto max-h-[90dvh] w-[calc(100%-2rem)] max-w-3xl overflow-auto rounded-2xl border border-border bg-surface p-0 text-text shadow-2xl backdrop:bg-slate-950/55"
      @cancel.prevent="close"
      @keydown="trapFocus"
      @click="$event.target === dialog && close()"
    >
      <header
        class="sticky top-0 z-10 flex items-center justify-between gap-4 border-b border-border bg-surface px-6 py-5"
      >
        <div class="flex items-center gap-3">
          <span
            class="flex h-11 w-11 items-center justify-center rounded-xl bg-primary/10 text-primary"
            ><Sparkles class="h-5 w-5"
          /></span>
          <div>
            <p class="mb-1 text-[10px] font-semibold uppercase tracking-[0.18em] text-muted">
              TechCare Solutions
            </p>
            <h2 :id="titleId" class="text-lg font-semibold">{{ title }}</h2>
          </div>
        </div>
        <button
          type="button"
          class="icon-button"
          aria-label="Cerrar diálogo"
          :disabled="busy"
          @click="close"
        >
          <X class="h-5 w-5" />
        </button>
      </header>
      <div class="p-6"><slot /></div></dialog
  ></Teleport>
</template>
