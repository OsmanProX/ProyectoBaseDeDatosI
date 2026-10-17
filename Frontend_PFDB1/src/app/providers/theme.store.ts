import { defineStore } from 'pinia'
import { ref, watch } from 'vue'
export const useThemeStore = defineStore('theme', () => {
  const media = window.matchMedia('(prefers-color-scheme: dark)')
  function storedTheme(): string | null {
    try {
      return localStorage.getItem('umg-theme')
    } catch {
      return null
    }
  }
  const saved = storedTheme()
  const dark = ref(saved ? saved === 'dark' : media.matches)
  watch(
    dark,
    (value) => {
      document.documentElement.classList.toggle('dark', value)
    },
    { immediate: true },
  )
  media.addEventListener('change', (event) => {
    if (!storedTheme()) dark.value = event.matches
  })
  function toggle() {
    dark.value = !dark.value
    try {
      localStorage.setItem('umg-theme', dark.value ? 'dark' : 'light')
    } catch {
      /* El tema sigue funcionando si el navegador bloquea el almacenamiento. */
    }
  }
  return { dark, toggle }
})
