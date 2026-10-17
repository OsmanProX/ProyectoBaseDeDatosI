import { defineStore } from 'pinia'
import { ref } from 'vue'
import { normalizeApiError } from '@/core/api/apiError'
export const useToast = defineStore('toast', () => {
  const messages = ref<{ id: number; message: string; tone: 'success' | 'danger' }[]>([])
  let id = 0
  const timers = new Map<number, ReturnType<typeof setTimeout>>()
  function dismiss(key: number) {
    clearTimeout(timers.get(key))
    timers.delete(key)
    messages.value = messages.value.filter((item) => item.id !== key)
  }
  function show(message: string, tone: 'success' | 'danger' = 'success') {
    const key = ++id
    messages.value.push({ id: key, message, tone })
    timers.set(
      key,
      setTimeout(() => dismiss(key), 6500),
    )
  }
  function error(cause: unknown) {
    show(normalizeApiError(cause).message, 'danger')
  }
  return { messages, show, error, dismiss }
})
