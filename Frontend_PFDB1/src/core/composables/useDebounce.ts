import { onScopeDispose, ref, watch } from 'vue'
import type { Ref } from 'vue'
export function useDebounce(source: Ref<string>, delay = 250) {
  const debounced = ref(source.value)
  let timer: ReturnType<typeof setTimeout> | undefined
  watch(source, (value) => {
    clearTimeout(timer)
    timer = setTimeout(() => {
      debounced.value = value
    }, delay)
  })
  onScopeDispose(() => clearTimeout(timer))
  return debounced
}
