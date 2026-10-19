export interface NavigationItem {
  id: number
  name: string
  path: string
  icon: string
  /** Código de permiso (tabla Permiso) requerido para mostrar el item. */
  permiso?: string
  /** Roles con acceso directo (cuando el módulo no depende de la tabla Permiso). */
  roles?: string[]
}

// Este arreglo crecerá en clase conforme se agreguen los módulos.
// El menú se filtra en MainLayout según permisos (tabla Permiso) y rol del usuario.
export const staticNavigation: NavigationItem[] = [
  { id: -1, name: 'Inicio', path: '/', icon: 'LayoutDashboard' },
  { id: -2, name: 'Órdenes', path: '/ordenes', icon: 'ClipboardList', permiso: 'VER_ORDENES' },
  { id: -3, name: 'Clientes', path: '/clientes', icon: 'Contact', roles: ['ADMINISTRADOR', 'RECEPCION'] },
  { id: -4, name: 'Equipos', path: '/equipos', icon: 'Laptop', roles: ['ADMINISTRADOR', 'RECEPCION'] },
  { id: -5, name: 'Usuarios', path: '/usuarios', icon: 'Users', permiso: 'VER_USUARIOS' },
  // Semana 3
  { id: -6, name: 'Taller', path: '/taller', icon: 'Wrench', roles: ['ADMINISTRADOR', 'TECNICO'] },
  { id: -7, name: 'Inventario', path: '/inventario', icon: 'Package', roles: ['ADMINISTRADOR', 'BODEGA'] },
  // Semana 4
  { id: -8, name: 'Caja y entrega', path: '/caja', icon: 'Receipt', roles: ['ADMINISTRADOR', 'CAJA', 'RECEPCION'] },
  { id: -9, name: 'Reportes', path: '/reportes', icon: 'ChartColumn', roles: ['ADMINISTRADOR'] },
  // Mantenimientos (6.1): repuestos y proveedores (BODEGA); bodegas y catálogos (ADMINISTRADOR)
  { id: -10, name: 'Mantenimientos', path: '/mantenimientos', icon: 'Settings', roles: ['ADMINISTRADOR', 'BODEGA'] },
]
