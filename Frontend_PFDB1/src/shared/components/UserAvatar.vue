<script setup lang="ts">
import { computed, ref, watch } from 'vue'
const props = defineProps<{ name: string; photo?: string }>()
const failed = ref(false)
const initials = computed(
  () =>
    props.name
      .trim()
      .split(/\s+/)
      .slice(0, 2)
      .map((word) => word[0] ?? '')
      .join('')
      .toUpperCase() || 'U',
)
const safePhoto = computed(() => {
  if (!props.photo) return ''
  try {
    const url = new URL(props.photo, window.location.origin)
    return ['http:', 'https:'].includes(url.protocol) ? url.href : ''
  } catch {
    return ''
  }
})
watch(
  () => props.photo,
  () => {
    failed.value = false
  },
)
</script>
<template>
  <span
    class="inline-flex h-10 w-10 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-primary/10 text-xs font-semibold text-primary"
    ><img
      v-if="safePhoto && !failed"
      :src="safePhoto"
      alt=""
      class="h-full w-full object-cover"
      loading="lazy"
      referrerpolicy="no-referrer"
      @error="failed = true"
    /><span v-else>{{ initials }}</span></span
  >
</template>
