import { onScopeDispose, ref, shallowRef } from 'vue'
import { isCancellation, normalizeApiError } from '@/core/api/apiError'
import type { ApiError } from '@/core/api/apiError'

export function useAsyncState<T>(loader: (signal: AbortSignal) => Promise<T>, initial: T) {
  const data = shallowRef<T>(initial)
  const loading = ref(false)
  const error = shallowRef<ApiError | null>(null)
  let controller: AbortController | undefined
  let generation = 0
  async function execute(): Promise<T | undefined> {
    controller?.abort()
    controller = new AbortController()
    const current = ++generation
    loading.value = true
    error.value = null
    try {
      const result = await loader(controller.signal)
      if (current !== generation) return
      data.value = result
      return result
    } catch (cause) {
      if (current === generation && !isCancellation(cause)) error.value = normalizeApiError(cause)
    } finally {
      if (current === generation) loading.value = false
    }
  }
  function cancel() {
    generation++
    controller?.abort()
    loading.value = false
  }
  onScopeDispose(cancel)
  return { data, loading, error, execute, cancel }
}
