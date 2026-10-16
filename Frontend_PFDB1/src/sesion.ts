// Sesión del usuario y menú por rol.
// El login (LoginView) guarda en localStorage el token JWT y los datos del usuario
// que devuelve la API (sp_LoginUsuario). Aquí se leen y se decide qué ve cada rol.

export type Rol = 'ADMINISTRADOR' | 'RECEPCION' | 'TECNICO' | 'BODEGA' | 'CAJA'

export interface Sesion {
  token: string
  usuarioId: number
  nombreUsuario: string
  nombreCompleto: string
  correo: string
  roles: Rol[]
}

// Lo que devuelve la API en "usuario" al iniciar sesión
interface UsuarioApi {
  usuarioId?: number
  nombreUsuario?: string
  nombreCompleto?: string
  correo?: string
  roles?: string // "RECEPCION, CAJA"
}

const ROLES_VALIDOS: Rol[] = ['ADMINISTRADOR', 'RECEPCION', 'TECNICO', 'BODEGA', 'CAJA']

// El token trae la fecha de vencimiento (exp); si ya venció se pide login otra vez
function tokenVencido(token: string): boolean {
  try {
    const parte = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/')
    const datos = JSON.parse(atob(parte)) as { exp?: number }
    return typeof datos.exp === 'number' && datos.exp * 1000 <= Date.now()
  } catch {
    return false // si no se puede leer, que decida la API (responde 401)
  }
}

export function leerSesion(): Sesion | null {
  try {
    const token = localStorage.getItem('token')
    const usuario = JSON.parse(localStorage.getItem('usuario') ?? 'null') as UsuarioApi | null
    if (!token || !usuario) return null
    if (tokenVencido(token)) {
      cerrarSesion()
      return null
    }
    const roles = (usuario.roles ?? '')
      .split(',')
      .map((r) => r.trim().toUpperCase())
      .filter((r): r is Rol => (ROLES_VALIDOS as string[]).includes(r))
    return {
      token,
      usuarioId: usuario.usuarioId ?? 0,
      nombreUsuario: usuario.nombreUsuario ?? '',
      nombreCompleto: usuario.nombreCompleto ?? usuario.nombreUsuario ?? 'Usuario',
      correo: usuario.correo ?? '',
      roles,
    }
  } catch {
    return null
  }
}

export function cerrarSesion() {
  try {
    localStorage.removeItem('token')
    localStorage.removeItem('usuario')
  } catch {
    /* sin almacenamiento disponible: no hay nada que borrar */
  }
}

// El ADMINISTRADOR siempre tiene permiso, igual que fn_UsuarioTieneRol en la base
export function tieneRol(roles: Rol[], ...permitidos: Rol[]): boolean {
  return roles.includes('ADMINISTRADOR') || roles.some((r) => permitidos.includes(r))
}

// ---------- Menú por rol ----------
export type IdVista =
  | 'ordenes' | 'clientes' | 'equipos' | 'taller' | 'inventario' | 'facturacion' | 'reportes'

export interface OpcionMenu {
  id: IdVista
  texto: string
  roles: Rol[] // además del ADMINISTRADOR
  pendiente?: string // si la pantalla todavía no está, en qué semana va
}

// Mismos permisos que validan los procedimientos almacenados
export const MENU: OpcionMenu[] = [
  { id: 'ordenes', texto: 'Órdenes', roles: ['RECEPCION', 'TECNICO', 'CAJA'] },
  {
    id: 'clientes', texto: 'Clientes', roles: ['RECEPCION'],
    pendiente: 'La pantalla de Clientes (Jeyling) se agrega cuando se una a rama_Combinada.',
  },
  { id: 'equipos', texto: 'Equipos', roles: ['RECEPCION', 'TECNICO'] },
  {
    id: 'taller', texto: 'Diagnóstico y reparación', roles: ['TECNICO'],
    pendiente: 'Semana 3: diagnóstico, reparación y repuestos usados.',
  },
  {
    id: 'inventario', texto: 'Inventario y compras', roles: ['BODEGA'],
    pendiente: 'Semana 3: repuestos, compras y movimientos de inventario.',
  },
  {
    id: 'facturacion', texto: 'Facturación y pagos', roles: ['CAJA'],
    pendiente: 'Semana 4: factura, pagos parciales y entrega.',
  },
  {
    id: 'reportes', texto: 'Reportes', roles: [],
    pendiente: 'Semana 4: los 12 reportes y el dashboard.',
  },
]

export function opcionesDelMenu(roles: Rol[]): OpcionMenu[] {
  return MENU.filter((o) => tieneRol(roles, ...o.roles))
}
