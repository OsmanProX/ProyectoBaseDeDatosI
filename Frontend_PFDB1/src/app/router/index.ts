import { createRouter, createWebHistory } from 'vue-router'
import type { RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '@/features/auth/stores/auth.store'

declare module 'vue-router' {
  interface RouteMeta {
    title: string
    requiresAuth?: boolean
  /** Código de permiso requerido (tabla Permiso), p. ej. VER_USUARIOS */
  permiso?: string
  /** Roles con acceso directo (alternativa cuando el módulo no depende de la tabla Permiso) */
  roles?: string[]
}
}

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    component: () => import('@/shared/layouts/AuthLayout.vue'),
    meta: { title: 'Iniciar sesión' },
    children: [
      {
        path: '',
        name: 'login',
        component: () => import('@/features/auth/views/LoginView.vue'),
        meta: { title: 'Iniciar sesión' },
      },
    ],
  },
  {
    path: '/',
    component: () => import('@/shared/layouts/MainLayout.vue'),
    meta: { title: 'Inicio' },
    children: [
      {
        path: '',
        name: 'home',
        component: () => import('@/app/views/DashboardView.vue'),
        meta: { title: 'Inicio', requiresAuth: true },
      },
      {
        path: 'ordenes',
        name: 'ordenes',
        component: () => import('@/features/ordenes/views/OrdenesView.vue'),
        meta: { title: 'Órdenes', requiresAuth: true, permiso: 'VER_ORDENES' },
      },
      {
        path: 'clientes',
        name: 'clientes',
        component: () => import('@/features/clientes/views/ClientesListView.vue'),
        meta: { title: 'Clientes', requiresAuth: true, roles: ['ADMINISTRADOR', 'RECEPCION'] },
      },
      {
        path: 'equipos',
        name: 'equipos',
        component: () => import('@/features/equipos/views/EquiposListView.vue'),
        meta: { title: 'Equipos', requiresAuth: true, roles: ['ADMINISTRADOR', 'RECEPCION'] },
      },
      {
        path: 'usuarios',
        name: 'usuarios',
        component: () => import('@/features/usuarios/views/UsuariosListView.vue'),
        meta: { title: 'Usuarios', requiresAuth: true, permiso: 'VER_USUARIOS' },
      },
      // Semana 3
      {
        path: 'taller',
        name: 'taller',
        component: () => import('@/features/taller/views/TallerView.vue'),
        meta: { title: 'Taller', requiresAuth: true, roles: ['ADMINISTRADOR', 'TECNICO'] },
      },
      {
        path: 'inventario',
        name: 'inventario',
        component: () => import('@/features/inventario/views/InventarioView.vue'),
        meta: { title: 'Inventario', requiresAuth: true, roles: ['ADMINISTRADOR', 'BODEGA'] },
      },
      {
        path: 'acceso-denegado',
        name: 'acceso-denegado',
        component: () => import('@/app/views/AccesoDenegadoView.vue'),
        meta: { title: 'Acceso denegado' },
      },
      {
        path: ':pathMatch(.*)*',
        component: () => import('@/app/views/NotFoundView.vue'),
        meta: { title: 'Página no encontrada' },
      },
    ],
  },
]

export const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach((to) => {
  const auth = useAuthStore()

  // Rutas protegidas: exigir sesión
  if (to.meta.requiresAuth && !auth.isAuthenticated) {
    return { name: 'login' }
  }

  // Ya autenticado y yendo al login → al inicio
  if (to.name === 'login' && auth.isAuthenticated) {
    return { name: 'home' }
  }

  // Control de permisos por rol (tabla Permiso)
  if (to.meta.permiso && !auth.tienePermiso(to.meta.permiso)) {
    return { name: 'acceso-denegado' }
  }

  // Módulos bloqueados por rol (mismos roles que las policies del backend)
  if (to.meta.roles && !to.meta.roles.includes(auth.rol)) {
    return { name: 'acceso-denegado' }
  }

  return true
})

router.afterEach((to) => {
  document.title = `${to.meta.title} · TechCare Solutions`
})
