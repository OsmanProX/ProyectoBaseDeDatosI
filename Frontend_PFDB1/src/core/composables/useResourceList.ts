import { computed, onMounted, ref, watch } from 'vue'
import type { Entity } from '@/core/types/api.types'
import { useAsyncState } from './useAsyncState'
import { useDebounce } from './useDebounce'
import { usePagination } from './usePagination'
import { useToast } from './useToast'
export function useResourceList<T extends Entity>(
  loader: (signal: AbortSignal) => Promise<T[]>,
  searchText: (item: T) => string,
) {
  const state = useAsyncState(loader, [] as T[])
  const toast = useToast()
  const search = ref('')
  const active = ref('')
  const stateId = ref('')
  const sortKey = ref('id')
  const ascending = ref(true)
  const query = useDebounce(search)
  const filtered = computed(() => {
    const needle = query.value.trim().toLocaleLowerCase('es')
    return state.data.value
      .filter(
        (item) =>
          (!needle || searchText(item).toLocaleLowerCase('es').includes(needle)) &&
          (!active.value || item.active === (active.value === '1')) &&
          (!stateId.value || item.stateId === Number(stateId.value)),
      )
      .sort((a, b) => {
        const left: unknown = Reflect.get(a, sortKey.value)
        const right: unknown = Reflect.get(b, sortKey.value)
        const order =
          typeof left === 'number' && typeof right === 'number'
            ? left - right
            : String(left ?? '').localeCompare(String(right ?? ''), 'es', { numeric: true })
        return ascending.value ? order : -order
      })
  })
  const pagination = usePagination(filtered)
  watch([query, active, stateId, pagination.pageSize], () => {
    pagination.page.value = 1
  })
  watch(state.error, (cause) => {
    if (cause) toast.error(cause)
  })
  const stateOptions = computed(() =>
    [
      ...new Set(
        state.data.value.map((item) => item.stateId).filter((id): id is number => id !== null),
      ),
    ]
      .sort((a, b) => a - b)
      .map((value) => ({ value, label: `Estado ${value}` })),
  )
  function sort(key: string) {
    if (sortKey.value === key) ascending.value = !ascending.value
    else {
      sortKey.value = key
      ascending.value = true
    }
  }
  onMounted(() => {
    void state.execute()
  })
  return {
    ...state,
    search,
    active,
    stateId,
    stateOptions,
    sortKey,
    ascending,
    filtered,
    ...pagination,
    sort,
  }
}
