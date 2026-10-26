export interface NavigationItem {
  id: number
  name: string
  path: string
  icon: string
  /** Código de permiso (tabla Permiso) requerido para mostrar el item. */
  permiso?: string
  /** Roles con acceso directo (cuando el módulo no depende de la tabla Permiso). */
  roles?: string[]
  /** Sección del menú donde aparece. */
  grupo: string
}

// El menú va en el orden del flujo del negocio, de arriba hacia abajo:
// Cliente -> Equipo -> Orden -> Diagnóstico/Reparación (Taller) -> Repuestos (Inventario)
// -> Factura, pago y entrega (Caja) -> Reportes. Al final, la administración del sistema.
// MainLayout lo filtra según permisos (tabla Permiso) y rol del usuario.
export const staticNavigation: NavigationItem[] = [
  { id: -1, name: 'Inicio', path: '/', icon: 'LayoutDashboard', grupo: 'Inicio' },
  // Proceso de servicio
  { id: -3, name: 'Clientes', path: '/clientes', icon: 'Contact', roles: ['ADMINISTRADOR', 'RECEPCION'], grupo: 'Proceso de servicio' },
  { id: -4, name: 'Equipos', path: '/equipos', icon: 'Laptop', roles: ['ADMINISTRADOR', 'RECEPCION'], grupo: 'Proceso de servicio' },
  { id: -2, name: 'Órdenes', path: '/ordenes', icon: 'ClipboardList', permiso: 'VER_ORDENES', grupo: 'Proceso de servicio' },
  { id: -6, name: 'Taller', path: '/taller', icon: 'Wrench', roles: ['ADMINISTRADOR', 'TECNICO'], grupo: 'Proceso de servicio' },
  { id: -7, name: 'Inventario', path: '/inventario', icon: 'Package', roles: ['ADMINISTRADOR', 'BODEGA'], grupo: 'Proceso de servicio' },
  { id: -8, name: 'Caja y entrega', path: '/caja', icon: 'Receipt', roles: ['ADMINISTRADOR', 'CAJA', 'RECEPCION'], grupo: 'Proceso de servicio' },
  // Consultas
  { id: -9, name: 'Reportes', path: '/reportes', icon: 'ChartColumn', roles: ['ADMINISTRADOR'], grupo: 'Consultas' },
  // Administración (6.1): repuestos y proveedores (BODEGA); bodegas, catálogos y usuarios (ADMINISTRADOR)
  { id: -10, name: 'Mantenimientos', path: '/mantenimientos', icon: 'Settings', roles: ['ADMINISTRADOR', 'BODEGA'], grupo: 'Administración' },
  { id: -5, name: 'Usuarios', path: '/usuarios', icon: 'Users', permiso: 'VER_USUARIOS', grupo: 'Administración' },
]
