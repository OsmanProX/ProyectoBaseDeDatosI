// Acceso a la API de clientes (ClienteController). Pantalla de Jeyling conectada a la API.
// Rutas: GET /api/cliente?busqueda=, POST /api/cliente/crear,
//        PUT /api/cliente/actualizar, DELETE /api/cliente/eliminar/{id} (pasa a INACTIVO),
//        PUT /api/cliente/activar/{id} (vuelve a ACTIVO)
import { apiFetch, ApiFetchError as ApiError } from '@/core/api/apiFetch'

// Con VITE_USE_MOCK=true la pantalla usa datos de prueba en memoria (sin API ni base de datos)
const USE_MOCK = import.meta.env.VITE_USE_MOCK === 'true'

export { ApiError }
export type TipoCliente = 'INDIVIDUAL' | 'EMPRESARIAL'
export type EstadoCliente = 'ACTIVO' | 'INACTIVO'

// Mismos nombres que devuelve la API (ClienteModel en camelCase)
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

// Lo que se manda a la API: los opcionales vacíos van como null
const cuerpo = (d: ClienteForm) => ({
  tipoCliente: d.tipoCliente,
  nombreRazonSocial: d.nombreRazonSocial.trim(),
  nit: d.nit.trim().toUpperCase(),
  telefono: d.telefono.trim(),
  correo: d.correo.trim() || null,
  direccion: d.direccion.trim() || null,
})

function mensajeClaro(texto: string): string {
  if (/UX_Cliente_NIT|duplicate key/i.test(texto)) return 'Ya existe un cliente con ese NIT.'
  return texto
}

const request = <T>(path: string, init?: RequestInit) => apiFetch<T>(path, init, mensajeClaro)

// ---------- API real ----------
const apiReal = {
  async listar(buscar: string, estado: string): Promise<Cliente[]> {
    const q = buscar.trim() ? `?busqueda=${encodeURIComponent(buscar.trim())}` : ''
    const lista = await request<Cliente[]>(`/api/cliente${q}`)
    // La API no filtra por estado; se filtra aquí
    return lista.filter((c) => !estado || c.estado === estado)
  },
  crear(data: ClienteForm) {
    return request<{ clienteId: number }>('/api/cliente/crear', {
      method: 'POST',
      body: JSON.stringify(cuerpo(data)),
    })
  },
  editar(id: number, data: ClienteForm) {
    return request<unknown>('/api/cliente/actualizar', {
      method: 'PUT',
      body: JSON.stringify({ clienteId: id, ...cuerpo(data) }),
    })
  },
  desactivar(id: number) {
    return request<unknown>(`/api/cliente/eliminar/${id}`, { method: 'DELETE' })
  },
  activar(id: number) {
    return request<unknown>(`/api/cliente/activar/${id}`, { method: 'PUT' })
  },
}

// ---------- Datos de prueba (los mismos de 02_datos_iniciales.sql) ----------
const demoClientes: Cliente[] = [
  { clienteId: 1, tipoCliente: 'INDIVIDUAL', nombreRazonSocial: 'Juan Carlos Méndez', nit: '4567890-1', telefono: '55012233', correo: null, direccion: null, estado: 'ACTIVO', fechaRegistro: '2026-10-01T09:00:00' },
  { clienteId: 2, tipoCliente: 'INDIVIDUAL', nombreRazonSocial: 'Lucía Hernández', nit: 'CF', telefono: '44556677', correo: null, direccion: null, estado: 'ACTIVO', fechaRegistro: '2026-10-01T10:30:00' },
  { clienteId: 3, tipoCliente: 'EMPRESARIAL', nombreRazonSocial: 'Comercial El Progreso, S.A.', nit: '7890123-4', telefono: '22334455', correo: null, direccion: null, estado: 'ACTIVO', fechaRegistro: '2026-10-02T14:15:00' },
  { clienteId: 4, tipoCliente: 'EMPRESARIAL', nombreRazonSocial: 'Colegio San Andrés', nit: '8901234-5', telefono: '24567890', correo: null, direccion: null, estado: 'ACTIVO', fechaRegistro: '2026-10-03T08:45:00' },
]

const esperar = () => new Promise((r) => setTimeout(r, 250))
const nitRepetido = (nit: string, id?: number) =>
  nit.trim().toUpperCase() !== 'CF' &&
  demoClientes.some((c) => c.clienteId !== id && c.nit.toUpperCase() === nit.trim().toUpperCase())

const apiDemo = {
  async listar(buscar: string, estado: string): Promise<Cliente[]> {
    await esperar()
    const b = buscar.trim().toLowerCase()
    return demoClientes
      .filter((c) => !estado || c.estado === estado)
      .filter((c) => !b || c.nit.toLowerCase().includes(b) || c.nombreRazonSocial.toLowerCase().includes(b))
      .map((c) => ({ ...c }))
  },
  async crear(data: ClienteForm): Promise<{ clienteId: number }> {
    await esperar()
    if (nitRepetido(data.nit)) throw new ApiError('Ya existe un cliente con ese NIT.', 500)
    const clienteId = Math.max(...demoClientes.map((c) => c.clienteId)) + 1
    demoClientes.push({ clienteId, ...cuerpo(data), estado: 'ACTIVO', fechaRegistro: new Date().toISOString() })
    return { clienteId }
  },
  async editar(id: number, data: ClienteForm): Promise<void> {
    await esperar()
    const c = demoClientes.find((x) => x.clienteId === id)
    if (!c) throw new ApiError('Cliente no encontrado.', 404)
    if (nitRepetido(data.nit, id)) throw new ApiError('Ya existe un cliente con ese NIT.', 500)
    Object.assign(c, cuerpo(data))
  },
  async desactivar(id: number): Promise<void> {
    await esperar()
    const c = demoClientes.find((x) => x.clienteId === id)
    if (!c) throw new ApiError('Cliente no encontrado.', 404)
    c.estado = 'INACTIVO'
  },
  async activar(id: number): Promise<void> {
    await esperar()
    const c = demoClientes.find((x) => x.clienteId === id)
    if (!c) throw new ApiError('Cliente no encontrado.', 404)
    c.estado = 'ACTIVO'
  },
}

// La pantalla usa siempre este objeto; cambia solo según VITE_USE_MOCK
export const clientesApi = USE_MOCK ? apiDemo : apiReal
