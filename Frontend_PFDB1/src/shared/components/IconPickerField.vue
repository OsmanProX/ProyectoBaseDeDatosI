<script setup lang="ts">
import { useId } from 'vue'
import { Check } from 'lucide-vue-next'
import { useField } from 'vee-validate'
import { iconCatalog, type IconName } from '@/core/utils/icons'

const props = defineProps<{
  name: string
  label: string
  hint?: string
}>()

const { value, errorMessage, setTouched } = useField<string>(() => props.name)
const id = useId()

function selectIcon(icon: IconName) {
  value.value = icon
  setTouched(true)
}

function moveSelection(direction: number) {
  const currentIndex = iconCatalog.findIndex(({ name }) => name === value.value)
  const nextIndex =
    (Math.max(currentIndex, 0) + direction + iconCatalog.length) % iconCatalog.length
  selectIcon(iconCatalog[nextIndex]!.name)
}
</script>

<template>
  <fieldset
    :aria-describedby="`${id}-help`"
    class="rounded-2xl border border-border bg-background/55 p-4 sm:p-5"
    @keydown.right.prevent="moveSelection(1)"
    @keydown.down.prevent="moveSelection(1)"
    @keydown.left.prevent="moveSelection(-1)"
    @keydown.up.prevent="moveSelection(-1)"
  >
    <legend class="label px-2">{{ label }}</legend>
    <div class="grid grid-cols-3 gap-2 sm:grid-cols-5" role="radiogroup" :aria-label="label">
      <button
        v-for="icon in iconCatalog"
        :key="icon.name"
        type="button"
        role="radio"
        :aria-checked="value === icon.name"
        :aria-label="icon.label"
        class="group relative flex min-h-24 flex-col items-center justify-center gap-2 rounded-xl border px-2 py-3 text-center transition duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2"
        :class="
          value === icon.name
            ? 'border-primary bg-primary text-white shadow-md shadow-primary/20'
            : 'border-border bg-surface text-muted hover:-translate-y-0.5 hover:border-primary/50 hover:text-primary hover:shadow-sm'
        "
        @click="selectIcon(icon.name)"
      >
        <span
          v-if="value === icon.name"
          class="absolute right-2 top-2 flex h-5 w-5 items-center justify-center rounded-full bg-white/20"
          aria-hidden="true"
        >
          <Check class="h-3.5 w-3.5" stroke-width="3" />
        </span>
        <component :is="icon.component" class="h-7 w-7" :stroke-width="1.7" aria-hidden="true" />
        <span class="text-xs font-semibold leading-tight">{{ icon.label }}</span>
      </button>
    </div>
    <p
      :id="`${id}-help`"
      :class="errorMessage ? 'field-error' : 'mt-3 text-xs leading-5 text-muted'"
    >
      {{ errorMessage || hint }}
    </p>
  </fieldset>
</template>
