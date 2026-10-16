export interface NavigationItem {
  id: number
  name: string
  path: string
  icon: string
}

// Este arreglo crecerá en clase conforme se agreguen los módulos.
export const staticNavigation: NavigationItem[] = [
  { id: -1, name: 'Inicio', path: '/', icon: 'LayoutDashboard' },
  { id: -2, name: 'Usuarios', path: '/usuarios', icon: 'Users' },
]
