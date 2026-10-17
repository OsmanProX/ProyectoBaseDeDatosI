import { defineStore } from 'pinia'
import { ref } from 'vue'
export const useConfirm = defineStore('confirm', () => {
  const open = ref(false)
  const message = ref('')
  let resolvePending: ((confirmed: boolean) => void) | undefined
  function ask(text: string): Promise<boolean> {
    resolvePending?.(false)
    message.value = text
    open.value = true
    return new Promise((resolve) => {
      resolvePending = resolve
    })
  }
  function answer(confirmed: boolean) {
    open.value = false
    resolvePending?.(confirmed)
    resolvePending = undefined
  }
  return { open, message, ask, answer }
})
