// Acceso a la API de ├│rdenes de servicio. El frontend no se conecta directo a SQL Server.
const BASE = import.meta.env.VITE_API_URL ?? 'http://localhost:5245'
// Con VITE_USE_MOCK=true se usan datos de prueba en memoria (sin API ni base)
const USE_MOCK = import.meta.env.VITE_USE_MOCK === 'true'

export type Prioridad = 'BAJA' | 'MEDIA' | 'ALTA' | 'URGENTE'
export type CodigoEstado =
  | 'RECIBIDO' | 'DIAGNOSTICO' | 'ESPERANDO_AUTORIZACION' | 'REPARACION'
  | 'LISTO' | 'ENTREGADO' | 'CANCELADO'
export type Rol = 'ADMINISTRADOR' | 'RECEPCION' | 'TECNICO' | 'BODEGA' | 'CAJA'

// Mismos ids que la tabla EstadoOrden
export const ESTADOS: { id: number; codigo: CodigoEstado; nombre: string }[] = [
  { id: 1, codigo: 'RECIBIDO', nombre: 'Recibido' },
  { id: 2, codigo: 'DIAGNOSTICO', nombre: 'Diagn├│stico' },
  { id: 3, codigo: 'ESPERANDO_AUTORIZACION', nombre: 'Esperando autorizaci├│n' },
  { id: 4, codigo: 'REPARACION', nombre: 'Reparaci├│n' },
  { id: 5, codigo: 'LISTO', nombre: 'Listo' },
  { id: 6, codigo: 'ENTREGADO', nombre: 'Entregado' },
  { id: 7, codigo: 'CANCELADO', nombre: 'Cancelado' },
]

// Cambios permitidos, igual que en sp_CambiarEstadoOrden.
// ENTREGADO no va aqu├¡: se hace en el proceso de entrega (factura y pagos).
export const TRANSICIONES: Record<number, number[]> = {
  1: [2, 7],
  2: [3, 7],
  3: [4, 7],
  4: [5, 7],
}

export const PRIORIDADES: Prioridad[] = ['BAJA', 'MEDIA', 'ALTA', 'URGENTE']

export interface OrdenResumen {
  ordenId: number
  numeroOrden: string
  clienteId: number
  cliente: string
  equipoId: number
  tipoEquipo: string
  equipo: string // marca + modelo
  numeroSerie: string
  recibidoPor: string
  fechaIngreso: string
  fechaEstimada: string | null
  prioridad: Prioridad
  estadoId: number
  estado: CodigoEstado
  problemaReportado: string
  observaciones: string | null
}

export interface HistorialEstado {
  historialId: number
  fechaCambio: string
  estadoAnterior: CodigoEstado | null // null en el primer registro
  estadoNuevo: CodigoEstado
  usuario: string
  observacion: string | null
}

export interface NuevaOrden {
  clienteId: number
  equipoId: number
  usuarioRecepcionId: number
  problemaReportado: string
  prioridad: Prioridad
  fechaEstimada: string | null
  observaciones: string | null
}

export interface OpcionCliente {
  clienteId: number
  nombreRazonSocial: string
  nit: string
}

export interface OpcionEquipo {
  equipoId: number
  tipoEquipo: string
  marca: string
  modelo: string
  numeroSerie: string
}

// Usuario con el que se trabaja mientras no est├í el login (lo reemplaza Gerson)
export interface UsuarioPrueba {
  usuarioId: number
  nombreUsuario: string
  nombreCompleto: string
  rol: Rol
}

export const USUARIOS_PRUEBA: UsuarioPrueba[] = [
  { usuarioId: 2, nombreUsuario: 'recepcion1', nombreCompleto: 'Ana Luc├¡a L├│pez', rol: 'RECEPCION' },
  { usuarioId: 3, nombreUsuario: 'tecnico1', nombreCompleto: 'Carlos Enrique P├®rez', rol: 'TECNICO' },
  { usuarioId: 1, nombreUsuario: 'admin', nombreCompleto: 'Administrador del Sistema', rol: 'ADMINISTRADOR' },
]

export class ApiError extends Error {
  status: number
  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response
  const token = sessionStorage.getItem('token')
  try {
    res = await fetch(`${BASE}${path}`, {
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      ...init,
    })
  } catch {
    throw new ApiError('No se pudo conectar con el servidor. Verifique que la API est├® en ejecuci├│n.', 0)
  }
  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new ApiError(body.error ?? 'Ocurri├│ un error inesperado.', res.status)
  }
  return res.status === 204 ? (undefined as T) : ((await res.json()) as T)
}

// ---------- API real ----------
const apiReal = {
  listar(buscar: string, estado: string) {
    const q = new URLSearchParams()
    if (buscar.trim()) q.set('buscar', buscar.trim())
    if (estado) q.set('estado', estado) // c├│digo del estado o ABIERTAS
    return request<OrdenResumen[]>(`/api/ordenes?${q.toString()}`)
  },
  historial(ordenId: number) {
    return request<HistorialEstado[]>(`/api/ordenes/${ordenId}/historial`)
  },
  crear(data: NuevaOrden) {
    return request<{ ordenId: number; numeroOrden: string }>('/api/ordenes', {
      method: 'POST',
      body: JSON.stringify(data),
    })
  },
  cambiarEstado(ordenId: number, estadoNuevoId: number, usuarioId: number, observacion: string | null) {
    return request<void>(`/api/ordenes/${ordenId}/estado`, {
      method: 'PUT',
      body: JSON.stringify({ estadoNuevoId, usuarioId, observacion }),
    })
  },
  clientesActivos() {
    return request<OpcionCliente[]>('/api/clientes?estado=ACTIVO')
  },
  equiposDeCliente(clienteId: number) {
    return request<OpcionEquipo[]>(`/api/clientes/${clienteId}/equipos`)
  },
}

// ---------- Datos de prueba (los mismos de 02_datos_iniciales.sql) ----------
const demoClientes: OpcionCliente[] = [
  { clienteId: 1, nombreRazonSocial: 'Juan Carlos M├®ndez', nit: '4567890-1' },
  { clienteId: 2, nombreRazonSocial: 'Luc├¡a Hern├índez', nit: 'CF' },
  { clienteId: 3, nombreRazonSocial: 'Comercial El Progreso, S.A.', nit: '7890123-4' },
  { clienteId: 4, nombreRazonSocial: 'Colegio San Andr├®s', nit: '8901234-5' },
]

const demoEquipos: (OpcionEquipo & { clienteId: number })[] = [
  { equipoId: 1, clienteId: 1, tipoEquipo: 'Laptop', marca: 'HP', modelo: 'Pavilion 15', numeroSerie: 'HP5CD1234XYZ' },
  { equipoId: 2, clienteId: 2, tipoEquipo: 'Laptop', marca: 'Lenovo', modelo: 'IdeaPad 3', numeroSerie: 'LNV-PF3ABC12' },
  { equipoId: 3, clienteId: 3, tipoEquipo: 'Desktop', marca: 'Dell', modelo: 'OptiPlex 3080', numeroSerie: 'DL-7HJK921' },
  { equipoId: 4, clienteId: 3, tipoEquipo: 'Impresora', marca: 'Epson', modelo: 'L3250', numeroSerie: 'EPS-X8QW5521' },
  { equipoId: 5, clienteId: 4, tipoEquipo: 'Laptop', marca: 'Acer', modelo: 'Aspire 5', numeroSerie: 'ACR-NXHS7AA01' },
]

// En la base esto se valida con las tablas Diagnostico y Reparacion
type OrdenDemo = OrdenResumen & { tieneDiagnostico: boolean; tieneReparacion: boolean }

function ordenDemo(
  ordenId: number, equipoId: number, prioridad: Prioridad, estadoId: number,
  fechaIngreso: string, problema: string, diag: boolean, rep: boolean,
): OrdenDemo {
  const e = demoEquipos.find((x) => x.equipoId === equipoId)!
  const c = demoClientes.find((x) => x.clienteId === e.clienteId)!
  return {
    ordenId,
    numeroOrden: `OS-2026-${String(ordenId).padStart(4, '0')}`,
    clienteId: c.clienteId,
    cliente: c.nombreRazonSocial,
    equipoId,
    tipoEquipo: e.tipoEquipo,
    equipo: `${e.marca} ${e.modelo}`,
    numeroSerie: e.numeroSerie,
    recibidoPor: 'Ana Luc├¡a L├│pez',
    fechaIngreso,
    fechaEstimada: null,
    prioridad,
    estadoId,
    estado: ESTADOS[estadoId - 1].codigo,
    problemaReportado: problema,
    observaciones: null,
    tieneDiagnostico: diag,
    tieneReparacion: rep,
  }
}

const demoOrdenes: OrdenDemo[] = [
  ordenDemo(1, 1, 'ALTA', 2, '2026-10-12T09:15:00', 'La laptop no enciende, se apag├│ de golpe.', false, false),
  ordenDemo(2, 2, 'MEDIA', 7, '2026-10-12T10:40:00', 'Teclado no responde.', false, false),
  ordenDemo(3, 4, 'MEDIA', 3, '2026-10-13T08:30:00', 'La impresora no jala las hojas.', true, false),
  ordenDemo(4, 5, 'URGENTE', 4, '2026-10-13T14:05:00', 'Pantalla con rayas verticales.', true, true),
]

let siguienteHistorial = 1
const demoHistorial: (HistorialEstado & { ordenId: number })[] = []
function agregarHistorial(
  ordenId: number, fecha: string, anterior: number | null, nuevo: number, usuario: string, obs: string | null,
) {
  demoHistorial.push({
    historialId: siguienteHistorial++,
    ordenId,
    fechaCambio: fecha,
    estadoAnterior: anterior ? ESTADOS[anterior - 1].codigo : null,
    estadoNuevo: ESTADOS[nuevo - 1].codigo,
    usuario,
    observacion: obs,
  })
}
agregarHistorial(1, '2026-10-12T09:15:00', null, 1, 'recepcion1', 'Orden registrada en recepci├│n')
agregarHistorial(1, '2026-10-12T11:00:00', 1, 2, 'tecnico1', 'Inicia revisi├│n del equipo')
agregarHistorial(2, '2026-10-12T10:40:00', null, 1, 'recepcion1', 'Orden registrada en recepci├│n')
agregarHistorial(2, '2026-10-12T12:10:00', 1, 7, 'recepcion1', 'El cliente decidi├│ no reparar')
agregarHistorial(3, '2026-10-13T08:30:00', null, 1, 'recepcion1', 'Orden registrada en recepci├│n')
agregarHistorial(3, '2026-10-13T09:20:00', 1, 2, 'tecnico2', 'Revisi├│n del rodillo de arrastre')
agregarHistorial(3, '2026-10-13T15:45:00', 2, 3, 'tecnico2', 'Se cotiz├│ cambio de rodillo, falta respuesta del cliente')
agregarHistorial(4, '2026-10-13T14:05:00', null, 1, 'recepcion1', 'Orden registrada en recepci├│n')
agregarHistorial(4, '2026-10-13T14:30:00', 1, 2, 'tecnico1', null)
agregarHistorial(4, '2026-10-13T16:00:00', 2, 3, 'tecnico1', 'Cambio de pantalla, Q 650')
agregarHistorial(4, '2026-10-14T08:10:00', 3, 4, 'tecnico1', 'Cliente autoriz├│ por tel├®fono')

const esperar = () => new Promise((r) => setTimeout(r, 250))
const ahora = () => new Date().toISOString()
const hoy = () => new Date().toISOString().slice(0, 10)
const usuarioDemo = (id: number) => USUARIOS_PRUEBA.find((u) => u.usuarioId === id)

// Las validaciones y mensajes son los mismos que devuelven los procedimientos
const apiDemo = {
  async listar(buscar: string, estado: string): Promise<OrdenResumen[]> {
    await esperar()
    const b = buscar.trim().toLowerCase()
    return demoOrdenes
      .filter((o) => !estado
        || (estado === 'ABIERTAS' ? o.estadoId !== 6 && o.estadoId !== 7 : o.estado === estado))
      .filter((o) => !b
        || o.numeroOrden.toLowerCase().includes(b)
        || o.cliente.toLowerCase().includes(b)
        || o.numeroSerie.toLowerCase().includes(b))
      .sort((a, c) => c.fechaIngreso.localeCompare(a.fechaIngreso))
      .map(({ tieneDiagnostico: _d, tieneReparacion: _r, ...o }) => ({ ...o }))
  },

  async historial(ordenId: number): Promise<HistorialEstado[]> {
    await esperar()
    return demoHistorial
      .filter((h) => h.ordenId === ordenId)
      .map(({ ordenId: _o, ...h }) => ({ ...h }))
  },

  async crear(data: NuevaOrden): Promise<{ ordenId: number; numeroOrden: string }> {
    await esperar()
    if (!data.problemaReportado.trim())
      throw new ApiError('Debe describir el problema reportado por el cliente.', 400)
    if (!PRIORIDADES.includes(data.prioridad))
      throw new ApiError('Prioridad inv├ílida. Use BAJA, MEDIA, ALTA o URGENTE.', 400)
    if (data.fechaEstimada && data.fechaEstimada < hoy())
      throw new ApiError('La fecha estimada no puede ser anterior a hoy.', 400)
    const equipo = demoEquipos.find((e) => e.equipoId === data.equipoId)
    if (!equipo) throw new ApiError('El equipo no existe o est├í inactivo.', 400)
    if (equipo.clienteId !== data.clienteId)
      throw new ApiError('El equipo no pertenece al cliente indicado.', 400)
    const u = usuarioDemo(data.usuarioRecepcionId)
    if (!u || (u.rol !== 'RECEPCION' && u.rol !== 'ADMINISTRADOR'))
      throw new ApiError('El usuario no est├í autorizado para recibir equipos (rol RECEPCION o ADMINISTRADOR).', 403)
    if (demoOrdenes.some((o) => o.equipoId === data.equipoId && o.estadoId !== 6 && o.estadoId !== 7))
      throw new ApiError('El equipo ya tiene una orden abierta. Cierre o cancele esa orden primero.', 409)

    const ordenId = Math.max(...demoOrdenes.map((o) => o.ordenId)) + 1
    const nueva = ordenDemo(ordenId, data.equipoId, data.prioridad, 1, ahora(), data.problemaReportado.trim(), false, false)
    nueva.recibidoPor = u.nombreCompleto
    nueva.fechaEstimada = data.fechaEstimada
    nueva.observaciones = data.observaciones
    demoOrdenes.push(nueva)
    agregarHistorial(ordenId, ahora(), null, 1, u.nombreUsuario, 'Orden registrada en recepci├│n')
    return { ordenId, numeroOrden: nueva.numeroOrden }
  },

  async cambiarEstado(ordenId: number, estadoNuevoId: number, usuarioId: number, observacion: string | null) {
    await esperar()
    if (estadoNuevoId === 6)
      throw new ApiError('Para ENTREGAR una orden use el proceso de entrega (valida factura y pagos).', 400)
    if (estadoNuevoId === 1) throw new ApiError('Una orden no puede regresar al estado RECIBIDO.', 400)
    const u = usuarioDemo(usuarioId)
    const permitido = u && (u.rol === 'ADMINISTRADOR'
      || ([2, 3, 4, 5].includes(estadoNuevoId) && u.rol === 'TECNICO')
      || (estadoNuevoId === 7 && u.rol === 'RECEPCION'))
    if (!permitido) throw new ApiError('El usuario no tiene permiso para asignar ese estado.', 403)
    const o = demoOrdenes.find((x) => x.ordenId === ordenId)
    if (!o) throw new ApiError('La orden no existe.', 404)
    if (o.estadoId === 6 || o.estadoId === 7)
      throw new ApiError('La orden ya est├í cerrada (ENTREGADO o CANCELADO) y no admite cambios.', 409)
    if (o.estadoId === estadoNuevoId) throw new ApiError('La orden ya se encuentra en ese estado.', 409)
    if (!(TRANSICIONES[o.estadoId] ?? []).includes(estadoNuevoId))
      throw new ApiError('Cambio de estado no permitido para el estado actual de la orden.', 409)
    if ((estadoNuevoId === 3 || estadoNuevoId === 4) && !o.tieneDiagnostico)
      throw new ApiError('La orden todav├¡a no tiene diagn├│stico registrado.', 409)
    if (estadoNuevoId === 5 && !o.tieneReparacion)
      throw new ApiError('La orden todav├¡a no tiene una reparaci├│n registrada.', 409)
    if (estadoNuevoId === 7 && !observacion?.trim())
      throw new ApiError('Indique el motivo de la cancelaci├│n en la observaci├│n.', 400)

    agregarHistorial(ordenId, ahora(), o.estadoId, estadoNuevoId, u!.nombreUsuario, observacion?.trim() || null)
    o.estadoId = estadoNuevoId
    o.estado = ESTADOS[estadoNuevoId - 1].codigo
  },

  async clientesActivos(): Promise<OpcionCliente[]> {
    await esperar()
    return demoClientes.map((c) => ({ ...c }))
  },

  async equiposDeCliente(clienteId: number): Promise<OpcionEquipo[]> {
    await esperar()
    return demoEquipos
      .filter((e) => e.clienteId === clienteId)
      .map(({ clienteId: _c, ...e }) => ({ ...e }))
  },
}

// La pantalla usa siempre este objeto; cambia solo con VITE_USE_MOCK
export const ordenesApi = USE_MOCK ? apiDemo : apiReal
