import type { App } from 'vue'
import { createPinia } from 'pinia'
import { router } from '@/app/router'
export function installProviders(app: App): void {
  app.use(createPinia())
  app.use(router)
}
