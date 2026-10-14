// Capa de acceso a la API de clientes. El frontend NUNCA habla con SQL Server.
const BASE = import.meta.env.VITE_API_URL ?? 'http://localhost:5245'
// Con VITE_USE_MOCK=true la pantalla usa datos de prueba en memoria (sin API ni base de datos)
const USE_MOCK = import.meta.env.VITE_USE_MOCK === 'true'

export type TipoCliente = 'INDIVIDUAL' | 'EMPRESARIAL'
export type EstadoCliente = 'ACTIVO' | 'INACTIVO'

export interface Cliente {
  clienteId: number
  tipoCliente: TipoCliente
  nombreRazonSocial: string
  nit: string
  telefono: string
  correo: string | null
  direccion: string | null
  estado: EstadoCliente
  fechaRegistro: string
}

export interface ClienteForm {
  tipoCliente: TipoCliente
  nombreRazonSocial: string
  nit: string
  telefono: string
  correo: string
  direccion: string
}

// Error con mensaje legible y detalle por campo (si el backend lo envia)
export class ApiError extends Error {
  status: number
  detalles: Record<string, string>
  constructor(message: string, status: number, detalles: Record<string, string> = {}) {
    super(message)
    this.status = status
    this.detalles = detalles
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let res: Response
  try {
    res = await fetch(`${BASE}${path}`, {
      headers: { 'Content-Type': 'application/json' },
      ...init,
    })
  } catch {
    throw new ApiError('No se pudo conectar con el servidor. Verifique que la API este en ejecucion.', 0)
  }
  if (!res.ok) {
    const body = await res.json().catch(() => ({}))
    throw new ApiError(body.error ?? 'Ocurrio un error inesperado.', res.status, body.detalles ?? {})
  }
  return res.status === 204 ? (undefined as T) : ((await res.json()) as T)
}

// ---------- API real ----------
const apiReal = {
  listar(buscar: string, estado: string) {
    const q = new URLSearchParams()
    if (buscar.trim()) q.set('buscar', buscar.trim())
    if (estado) q.set('estado', estado)
    return request<Cliente[]>(`/api/clientes?${q.toString()}`)
  },
  crear(data: ClienteForm) {
    return request<{ clienteId: number }>('/api/clientes', { method: 'POST', body: JSON.stringify(data) })
  },
  editar(id: number, data: ClienteForm) {
    return request<void>(`/api/clientes/${id}`, { method: 'PUT', body: JSON.stringify(data) })
  },
  cambiarEstado(id: number, estado: EstadoCliente) {
    return request<void>(`/api/clientes/${id}/estado`, { method: 'PATCH', body: JSON.stringify({ estado }) })
  },
}

// ---------- Datos de prueba (solo para desarrollar la pantalla) ----------
const demoClientes: Cliente[] = [
  { clienteId: 1, tipoCliente: 'INDIVIDUAL', nombreRazonSocial: 'María Fernanda López', nit: '1234567-8', telefono: '5551-2201', correo: 'maria.lopez@correo.com', direccion: 'Zona 10, Guatemala', estado: 'ACTIVO', fechaRegistro: '2026-09-01T09:00:00' },
  { clienteId: 2, tipoCliente: 'EMPRESARIAL', nombreRazonSocial: 'Distribuidora Los Andes, S.A.', nit: '2345678-9', telefono: '2200-3344', correo: 'compras@losandes.com.gt', direccion: 'Zona 4, Guatemala', estado: 'ACTIVO', fechaRegistro: '2026-09-03T10:30:00' },
  { clienteId: 3, tipoCliente: 'INDIVIDUAL', nombreRazonSocial: 'Carlos Alberto Pérez', nit: '3456789-K', telefono: '4455-1020', correo: null, direccion: null, estado: 'ACTIVO', fechaRegistro: '2026-09-05T14:15:00' },
  { clienteId: 4, tipoCliente: 'EMPRESARIAL', nombreRazonSocial: 'Clínica Santa Lucía', nit: '4567890-1', telefono: '2388-7766', correo: 'admin@clinicasantalucia.com', direccion: 'Zona 1, Mixco', estado: 'ACTIVO', fechaRegistro: '2026-09-10T08:45:00' },
  { clienteId: 5, tipoCliente: 'INDIVIDUAL', nombreRazonSocial: 'Ana Lucía Morales', nit: '5678901-2', telefono: '5012-8890', correo: 'ana.morales@correo.com', direccion: 'Villa Nueva', estado: 'ACTIVO', fechaRegistro: '2026-09-12T16:00:00' },
  { clienteId: 6, tipoCliente: 'EMPRESARIAL', nombreRazonSocial: 'Colegio El Roble', nit: '6789012-3', telefono: '2455-9001', correo: 'info@colegioelroble.edu.gt', direccion: 'Zona 11, Guatemala', estado: 'INACTIVO', fechaRegistro: '2026-08-20T11:20:00' },
  { clienteId: 7, tipoCliente: 'INDIVIDUAL', nombreRazonSocial: 'Luis Eduardo Ramírez', nit: '7890123-4', telefono: '3099-4412', correo: 'luis.ramirez@correo.com', direccion: null, estado: 'ACTIVO', fechaRegistro: '2026-09-18T13:05:00' },
]

const esperar = () => new Promise((r) => setTimeout(r, 250))

const apiDemo = {
  async listar(buscar: string, estado: string): Promise<Cliente[]> {
    await esperar()
    const b = buscar.trim().toLowerCase()
    return demoClientes
      .filter((c) => !estado || c.estado === estado)
      .filter((c) => !b || c.nit.toLowerCase().includes(b) || c.nombreRazonSocial.toLowerCase().includes(b))
      .sort((a, c) => a.nombreRazonSocial.localeCompare(c.nombreRazonSocial))
      .map((c) => ({ ...c }))
  },
  async crear(data: ClienteForm): Promise<{ clienteId: number }> {
    await esperar()
    if (demoClientes.some((c) => c.nit.toLowerCase() === data.nit.trim().toLowerCase()))
      throw new ApiError('Ya existe un cliente con ese NIT.', 409)
    const clienteId = Math.max(...demoClientes.map((c) => c.clienteId)) + 1
    demoClientes.push({
      clienteId, tipoCliente: data.tipoCliente, nombreRazonSocial: data.nombreRazonSocial.trim(),
      nit: data.nit.trim().toUpperCase(), telefono: data.telefono.trim(),
      correo: data.correo.trim() || null, direccion: data.direccion.trim() || null,
      estado: 'ACTIVO', fechaRegistro: new Date().toISOString(),
    })
    return { clienteId }
  },
  async editar(id: number, data: ClienteForm): Promise<void> {
    await esperar()
    const c = demoClientes.find((x) => x.clienteId === id)
    if (!c) throw new ApiError('El cliente no existe.', 404)
    if (demoClientes.some((x) => x.clienteId !== id && x.nit.toLowerCase() === data.nit.trim().toLowerCase()))
      throw new ApiError('Ya existe un cliente con ese NIT.', 409)
    Object.assign(c, {
      tipoCliente: data.tipoCliente, nombreRazonSocial: data.nombreRazonSocial.trim(),
      nit: data.nit.trim().toUpperCase(), telefono: data.telefono.trim(),
      correo: data.correo.trim() || null, direccion: data.direccion.trim() || null,
    })
  },
  async cambiarEstado(id: number, estado: EstadoCliente): Promise<void> {
    await esperar()
    const c = demoClientes.find((x) => x.clienteId === id)
    if (!c) throw new ApiError('El cliente no existe.', 404)
    c.estado = estado
  },
}

// La pantalla usa siempre este objeto; cambia solo segun VITE_USE_MOCK
export const clientesApi = USE_MOCK ? apiDemo : apiReal