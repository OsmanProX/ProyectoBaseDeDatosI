import { effectScope } from 'vue'
import { describe, expect, it } from 'vitest'
import { ApiError } from '@/core/api/apiError'
import { useAsyncState } from './useAsyncState'

function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((done) => {
    resolve = done
  })
  return { promise, resolve }
}

describe('useAsyncState', () => {
  it('una respuesta antigua no reemplaza el resultado de la petición más reciente', async () => {
    const first = deferred<string>()
    const second = deferred<string>()
    const signals: AbortSignal[] = []
    const scope = effectScope()
    const state = scope.run(() =>
      useAsyncState((signal) => {
        signals.push(signal)
        return signals.length === 1 ? first.promise : second.promise
      }, 'inicial'),
    )!
    const firstRequest = state.execute()
    const secondRequest = state.execute()
    expect(signals[0]?.aborted).toBe(true)
    second.resolve('resultado reciente')
    await secondRequest
    first.resolve('resultado antiguo')
    await firstRequest
    expect(state.data.value).toBe('resultado reciente')
    expect(state.loading.value).toBe(false)
    scope.stop()
  })

  it('normaliza errores y conserva el último valor disponible', async () => {
    const scope = effectScope()
    const state = scope.run(() =>
      useAsyncState<string>(async () => {
        throw new Error('No disponible')
      }, 'anterior'),
    )!
    await state.execute()
    expect(state.data.value).toBe('anterior')
    expect(state.error.value).toBeInstanceOf(ApiError)
    expect(state.error.value?.message).toBe('No disponible')
    expect(state.loading.value).toBe(false)
    scope.stop()
  })

  it('aborta al destruir el scope e ignora el resultado que llegue después', async () => {
    const pending = deferred<string>()
    let signal: AbortSignal | undefined
    const scope = effectScope()
    const state = scope.run(() =>
      useAsyncState((received) => {
        signal = received
        return pending.promise
      }, 'inicial'),
    )!
    const request = state.execute()
    scope.stop()
    expect(signal?.aborted).toBe(true)
    pending.resolve('respuesta tardía')
    await request
    expect(state.data.value).toBe('inicial')
  })
})
