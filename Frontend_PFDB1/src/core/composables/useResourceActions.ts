import { onScopeDispose, ref, shallowRef } from 'vue'
import type { Entity, MutationOutput } from '@/core/types/api.types'
import { isCancellation } from '@/core/api/apiError'
import { useConfirm } from './useConfirm'
import { useToast } from './useToast'
export function useResourceActions<T extends Entity, Input>(
  operations: {
    create(input: Input, signal: AbortSignal): Promise<MutationOutput>
    update(input: Input, signal: AbortSignal): Promise<MutationOutput>
    remove(id: number, signal: AbortSignal): Promise<MutationOutput>
  },
  reload: () => Promise<unknown>,
) {
  const toast = useToast()
  const confirm = useConfirm()
  const editing = shallowRef<T | null>(null)
  const modalOpen = ref(false)
  const saving = ref(false)
  const controller = new AbortController()
  onScopeDispose(() => controller.abort())
  function create() {
    editing.value = null
    modalOpen.value = true
  }
  function edit(item: T) {
    editing.value = item
    modalOpen.value = true
  }
  async function save(input: Input) {
    if (saving.value) return
    saving.value = true
    try {
      await (editing.value
        ? operations.update(input, controller.signal)
        : operations.create(input, controller.signal))
      modalOpen.value = false
      toast.show('Los cambios se guardaron correctamente.')
      await reload()
    } catch (cause) {
      if (!isCancellation(cause)) toast.error(cause)
    } finally {
      saving.value = false
    }
  }
  async function remove(item: T) {
    if (
      saving.value ||
      !(await confirm.ask(
        `¿Eliminar el registro #${item.id}? Esta operación no se puede deshacer.`,
      ))
    )
      return
    saving.value = true
    try {
      await operations.remove(item.id, controller.signal)
      toast.show('Registro eliminado.')
      await reload()
    } catch (cause) {
      if (!isCancellation(cause)) toast.error(cause)
    } finally {
      saving.value = false
    }
  }
  return { editing, modalOpen, saving, create, edit, save, remove }
}
