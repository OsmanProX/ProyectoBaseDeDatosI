<script setup lang="ts">
import { computed } from 'vue'
import { Folder, CornerDownRight, Pencil, Trash2 } from 'lucide-vue-next'
import type { TreeNode } from '@/core/utils/tree'
import BaseBadge from './BaseBadge.vue'
const props = withDefaults(
  defineProps<{
    nodes: TreeNode[]
    selected?: number[]
    selectable?: boolean
    editable?: boolean
    disabled?: boolean
    depth?: number
  }>(),
  { selected: () => [], depth: 0 },
)
const emit = defineEmits<{
  'update:selected': [ids: number[]]
  edit: [id: number]
  remove: [id: number]
}>()
const selectedSet = computed(() => new Set(props.selected))
function toggle(id: number) {
  const ids = new Set(props.selected)
  if (ids.has(id)) ids.delete(id)
  else ids.add(id)
  emit('update:selected', [...ids])
}
</script>
<template>
  <ul :class="depth ? 'ml-5 border-l border-border pl-4' : 'space-y-1'" aria-label="Árbol de menús">
    <li v-for="node in nodes" :key="node.item.id">
      <div class="my-1 flex min-h-12 items-center gap-3 rounded-lg px-3 py-2 hover:bg-primary/5">
        <input
          v-if="selectable"
          type="checkbox"
          :aria-label="`Seleccionar ${node.item.name}`"
          :checked="selectedSet.has(node.item.id)"
          :disabled="disabled"
          class="h-4 w-4 accent-primary"
          @change="toggle(node.item.id)"
        /><component
          :is="depth ? CornerDownRight : Folder"
          class="h-4 w-4 shrink-0 text-primary"
        /><span class="flex-1 text-sm font-medium">{{ node.item.name }}</span
        ><span class="text-xs text-muted">Orden {{ node.item.order }}</span
        ><BaseBadge
          v-if="'visible' in node.item"
          :active="Boolean(node.item.visible)"
          :label="node.item.visible ? 'Visible' : 'Oculto'"
        /><template v-if="editable"
          ><button
            class="icon-button"
            :disabled="disabled"
            :aria-label="`Editar ${node.item.name}`"
            @click="emit('edit', node.item.id)"
          >
            <Pencil class="h-4 w-4" /></button
          ><button
            class="icon-button hover:!text-danger"
            :disabled="disabled"
            :aria-label="`Eliminar ${node.item.name}`"
            @click="emit('remove', node.item.id)"
          >
            <Trash2 class="h-4 w-4" /></button
        ></template>
      </div>
      <TreeView
        v-if="node.children.length"
        :nodes="node.children"
        :selected="selected"
        :selectable="selectable"
        :editable="editable"
        :disabled="disabled"
        :depth="depth + 1"
        @update:selected="emit('update:selected', $event)"
        @edit="emit('edit', $event)"
        @remove="emit('remove', $event)"
      />
    </li>
  </ul>
</template>
