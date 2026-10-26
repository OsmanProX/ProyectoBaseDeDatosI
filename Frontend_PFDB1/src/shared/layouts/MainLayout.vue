<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import {
  ChevronRight,
  LogOut,
  Menu as MenuIcon,
  Moon,
  PanelRightClose,
  PanelRightOpen,
  Sun,
  Wrench,
  X,
} from 'lucide-vue-next'
import { useThemeStore } from '@/app/providers/theme.store'
import { useAuthStore } from '@/features/auth/stores/auth.store'
import { staticNavigation } from '@/app/providers/navigation.store'
import { resolveIcon } from '@/core/utils/icons'
import UserAvatar from '@/shared/components/UserAvatar.vue'

const route = useRoute()
const router = useRouter()
const theme = useThemeStore()
const auth = useAuthStore()
const collapsed = ref(false)
const mobileOpen = ref(false)
const title = computed(() => String(route.meta.title ?? 'Inicio'))
// Menú filtrado por permisos (tabla Permiso vía /api/Permiso/mios) y por rol
const navItems = computed(() =>
  staticNavigation.filter(
    (item) =>
      (!item.permiso || auth.tienePermiso(item.permiso)) &&
      (!item.roles || item.roles.includes(auth.rol)),
  ))
// Se muestra el título de la sección solo en el primer elemento de cada grupo
const conTitulo = (index: number) =>
  index > 0 && navItems.value[index]?.grupo !== navItems.value[index - 1]?.grupo

function cerrarSesion() {
  auth.logout()
  router.push({ name: 'login' })
}
</script>

<template>
  <div class="min-h-dvh">
    <a
      href="#main-content"
      class="sr-only z-50 rounded bg-primary p-3 text-white focus:not-sr-only focus:fixed focus:left-4 focus:top-4"
    >
      Saltar al contenido
    </a>
    <div
      v-if="mobileOpen"
      class="fixed inset-0 z-30 bg-slate-950/50 lg:hidden"
      aria-hidden="true"
      @click="mobileOpen = false"
    />
    <aside
      :class="[
        collapsed ? 'lg:w-20' : 'lg:w-64',
        mobileOpen ? 'translate-x-0' : 'translate-x-full lg:translate-x-0',
      ]"
      class="fixed inset-y-0 right-0 z-40 flex w-64 flex-col border-l border-border bg-surface transition-all duration-200"
      aria-label="Navegación principal"
      @keydown.esc="mobileOpen = false"
    >
      <div class="flex h-20 items-center gap-3 border-b border-border px-5">
        <div
          class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-primary text-white"
        >
          <Wrench class="h-6 w-6" />
        </div>
        <div v-if="!collapsed" class="min-w-0">
          <p class="text-sm font-semibold">TechCare<span class="text-primary">.</span></p>
          <p class="mt-0.5 text-[10px] font-medium uppercase tracking-[0.15em] text-muted">
            Servicio técnico
          </p>
        </div>
        <button
          class="icon-button ml-auto lg:hidden"
          aria-label="Cerrar navegación"
          @click="mobileOpen = false"
        >
          <X class="h-5 w-5" />
        </button>
      </div>
      <div class="flex-1 overflow-y-auto p-3">
        <p v-if="!collapsed" class="eyebrow px-3 pb-3 pt-5 text-[10px]">Navegación</p>
        <nav>
          <template v-for="(item, index) in navItems" :key="item.id">
            <p v-if="conTitulo(index) && !collapsed" class="eyebrow px-3 pb-2 pt-4 text-[10px]">
              {{ item.grupo }}
            </p>
            <hr v-else-if="conTitulo(index)" class="mx-3 my-2 border-border" />
            <RouterLink
              :to="item.path"
              :aria-label="item.name"
              :title="collapsed ? item.name : undefined"
              class="mb-1 flex min-h-11 items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-muted hover:bg-primary/5 hover:text-primary"
              exact-active-class="!bg-primary/10 !font-medium !text-primary"
              @click="mobileOpen = false"
            >
              <component :is="resolveIcon(item.icon)" class="h-[18px] w-[18px] shrink-0" />
              <span v-if="!collapsed">{{ item.name }}</span>
            </RouterLink>
          </template>
        </nav>
      </div>
      <div class="border-t border-border p-3">
        <button
          class="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-muted hover:bg-background"
          :aria-label="collapsed ? 'Expandir navegación' : 'Colapsar navegación'"
          :aria-expanded="!collapsed"
          @click="collapsed = !collapsed"
        >
          <component :is="collapsed ? PanelRightOpen : PanelRightClose" class="h-[18px] w-[18px]" />
          <span v-if="!collapsed" class="text-xs">Contraer navegación</span>
        </button>
      </div>
    </aside>

    <div :class="collapsed ? 'lg:pr-20' : 'lg:pr-64'" class="transition-all duration-200">
      <header
        class="sticky top-0 z-20 flex h-20 items-center justify-between gap-3 border-b border-border bg-surface/95 px-5 backdrop-blur sm:px-8"
      >
        <div class="flex items-center gap-3">
          <button
            class="icon-button lg:hidden"
            aria-label="Abrir navegación"
            :aria-expanded="mobileOpen"
            @click="mobileOpen = true"
          >
            <MenuIcon class="h-5 w-5" />
          </button>
          <nav class="flex items-center gap-2 text-sm" aria-label="Ruta de navegación">
            <RouterLink to="/" class="text-muted hover:text-primary">Inicio</RouterLink>
            <ChevronRight v-if="route.path !== '/'" class="h-3.5 w-3.5 text-muted" />
            <span v-if="route.path !== '/'" class="font-medium">{{ title }}</span>
          </nav>
        </div>
        <div class="flex items-center gap-2 sm:gap-3">
          <div class="hidden items-center gap-2.5 text-right sm:flex">
            <div class="min-w-0">
              <p class="truncate text-sm font-medium leading-tight">{{ auth.nombreCompleto || 'Usuario' }}</p>
              <p class="truncate text-[11px] leading-tight text-muted">{{ auth.rol }}</p>
            </div>
            <UserAvatar :name="auth.nombreCompleto || 'Usuario'" />
          </div>
          <button
            class="icon-button"
            aria-label="Cerrar sesión"
            title="Cerrar sesión"
            @click="cerrarSesion"
          >
            <LogOut class="h-[18px] w-[18px]" />
          </button>
          <button
            class="icon-button"
            :aria-label="theme.dark ? 'Activar modo claro' : 'Activar modo oscuro'"
            @click="theme.toggle"
          >
            <component :is="theme.dark ? Sun : Moon" class="h-[18px] w-[18px]" />
          </button>
        </div>
      </header>
      <main
        id="main-content"
        tabindex="-1"
        class="mx-auto max-w-[1500px] px-5 py-8 outline-none sm:px-8 sm:py-9"
      >
        <!-- Transición suave al cambiar de pantalla (clases .pagina-* en animaciones.css) -->
        <RouterView v-slot="{ Component, route: actual }">
          <Transition name="pagina" mode="out-in">
            <component :is="Component" :key="actual.path" />
          </Transition>
        </RouterView>
      </main>
      <footer class="px-5 pb-6 text-[11px] text-muted sm:px-8">
        TechCare Solutions · Proyecto final de Base de Datos I · UMG
      </footer>
    </div>
  </div>
</template>
