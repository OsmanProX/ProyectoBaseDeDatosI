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
  /** Qué se hace en esa pantalla (se muestra debajo del nombre en el menú). */
  descripcion?: string
  /** Oculto para el rol CLIENTE (solo usa su portal). */
  sinCliente?: boolean
}

// El menú va en el orden del flujo del negocio, de arriba hacia abajo:
// Cliente -> Equipo -> Orden -> Diagnóstico/Reparación (Taller) -> Repuestos (Inventario)
// -> Factura, pago y entrega (Caja) -> Reportes. Al final, la administración del sistema.
// MainLayout lo filtra según permisos (tabla Permiso) y rol del usuario.
export const staticNavigation: NavigationItem[] = [
  { id: -1, name: 'Inicio', path: '/', descripcion: 'Resumen del día', icon: 'LayoutDashboard', grupo: 'Inicio', sinCliente: true },
  // Portal del cliente (rol CLIENTE): solo ve sus órdenes
  { id: -11, name: 'Mis órdenes', descripcion: 'Estado y saldo de mis equipos', path: '/mis-ordenes', icon: 'ClipboardList', roles: ['CLIENTE'], grupo: 'Inicio' },
  // Proceso de servicio
  { id: -3, name: 'Clientes', descripcion: 'Registrar y editar clientes', path: '/clientes', icon: 'Contact', roles: ['ADMINISTRADOR', 'RECEPCION'], grupo: 'Proceso de servicio' },
  { id: -4, name: 'Equipos', descripcion: 'Equipos de cada cliente', path: '/equipos', icon: 'Laptop', roles: ['ADMINISTRADOR', 'RECEPCION'], grupo: 'Proceso de servicio' },
  { id: -2, name: 'Órdenes', descripcion: 'Recibir equipos y seguir su estado', path: '/ordenes', icon: 'ClipboardList', permiso: 'VER_ORDENES', grupo: 'Proceso de servicio' },
  { id: -6, name: 'Taller', descripcion: 'Diagnóstico y reparación', path: '/taller', icon: 'Wrench', roles: ['ADMINISTRADOR', 'TECNICO'], grupo: 'Proceso de servicio' },
  { id: -7, name: 'Inventario', descripcion: 'Existencias, compras y movimientos', path: '/inventario', icon: 'Package', roles: ['ADMINISTRADOR', 'BODEGA'], grupo: 'Proceso de servicio' },
  { id: -8, name: 'Caja y entrega', descripcion: 'Facturar, cobrar y entregar', path: '/caja', icon: 'Receipt', roles: ['ADMINISTRADOR', 'CAJA', 'RECEPCION'], grupo: 'Proceso de servicio' },
  // Consultas
  { id: -9, name: 'Reportes', descripcion: 'Ingresos, órdenes y repuestos', path: '/reportes', icon: 'ChartColumn', roles: ['ADMINISTRADOR'], grupo: 'Consultas' },
  // Administración (6.1): repuestos y proveedores (BODEGA); bodegas, catálogos y usuarios (ADMINISTRADOR)
  { id: -10, name: 'Mantenimientos', descripcion: 'Crear repuestos, proveedores, bodegas y catálogos', path: '/mantenimientos', icon: 'Settings', roles: ['ADMINISTRADOR', 'BODEGA'], grupo: 'Administración' },
  { id: -5, name: 'Usuarios', descripcion: 'Cuentas y roles del personal', path: '/usuarios', icon: 'Users', permiso: 'VER_USUARIOS', grupo: 'Administración' },
]
