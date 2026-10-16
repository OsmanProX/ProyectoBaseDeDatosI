import { computed, ref, watch } from 'vue'
import type { Ref } from 'vue'
export function usePagination<T>(items: Ref<T[]>) {
  const page = ref(1)
  const pageSize = ref(10)
  const total = computed(() => items.value.length)
  const pages = computed(() => Math.max(1, Math.ceil(total.value / pageSize.value)))
  watch([pages, pageSize], () => {
    page.value = Math.min(page.value, pages.value)
  })
  const paginated = computed(() =>
    items.value.slice((page.value - 1) * pageSize.value, page.value * pageSize.value),
  )
  return { page, pageSize, total, pages, paginated }
}
