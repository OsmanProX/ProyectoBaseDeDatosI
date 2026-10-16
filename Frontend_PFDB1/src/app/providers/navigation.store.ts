export interface NavigationItem {
  id: number
  name: string
  path: string
  icon: string
  /** Código de permiso (tabla Permiso) requerido para mostrar el item. */
  permiso?: string
}

// Este arreglo crecerá en clase conforme se agreguen los módulos.
// El menú se filtra en MainLayout según los permisos del usuario (auth store).
export const staticNavigation: NavigationItem[] = [
  { id: -1, name: 'Inicio', path: '/', icon: 'LayoutDashboard' },
  { id: -2, name: 'Órdenes', path: '/ordenes', icon: 'ClipboardList', permiso: 'VER_ORDENES' },
  { id: -3, name: 'Usuarios', path: '/usuarios', icon: 'Users', permiso: 'VER_USUARIOS' },
]
