// Acceso a la API de equipos (EquipoController). El frontend no se conecta a SQL Server.
// Rutas: GET /api/equipo?clienteId=, GET /api/equipo/tipos, POST /api/equipo/crear,
//        PUT /api/equipo/actualizar, DELETE /api/equipo/eliminar/{id} (pasa a INACTIVO),
//        PUT /api/equipo/activar/{id} (vuelve a ACTIVO)
// La API responde { codigo, mensaje, data } y pide el token del login (Bearer).
import { apiFetch, ApiFetchError as ApiError } from '@/core/api/apiFetch'

// Con VITE_USE_MOCK=true se usan datos de prueba en memoria (sin API ni base)
const USE_MOCK = import.meta.env.VITE_USE_MOCK === 'true'

export type EstadoRegistro = 'ACTIVO' | 'INACTIVO'

// Mismos nombres que devuelve la API (columnas de Equipo + nombres del tipo y del cliente)
export interface Equipo {
  equipoId: number
  clienteId: number
  tipoEquipoId: number
  nombreTipoEquipo: string
  nombreCliente: string
  marca: string
  modelo: string
  numeroSerie: string
  descripcion: string | null
  estado: EstadoRegistro
}

export interface TipoEquipo {
  tipoEquipoId: number
  nombre: string
}

export interface ClienteOpcion {
  clienteId: number
  nombreRazonSocial: string
  nit: string
  estado: EstadoRegistro
}

export interface DatosEquipo {
  clienteId: number
  tipoEquipoId: number
  marca: string
  modelo: string
  numeroSerie: string
  descripcion: string | null
}

// Convierte los mensajes técnicos de la API en algo que entienda el usuario
function mensajeClaro(texto: string): string {
  if (/UQ_Equipo_NumeroSerie|duplicate key/i.test(texto)) return 'Ya existe un equipo con ese número de serie.'
  return texto
}

const request = <T>(path: string, init?: RequestInit) => apiFetch<T>(path, init, mensajeClaro)

// ---------- API real ----------
const apiReal = {
  listar(clienteId?: number) {
    return request<Equipo[]>(`/api/equipo${clienteId ? `?clienteId=${clienteId}` : ''}`)
  },
  tipos() {
    return request<TipoEquipo[]>('/api/equipo/tipos')
  },
  clientes() {
    return request<ClienteOpcion[]>('/api/cliente')
  },
  crear(d: DatosEquipo) {
    return request<{ equipoId: number }>('/api/equipo/crear', { method: 'POST', body: JSON.stringify(d) })
  },
  // La API no cambia el cliente ni el número de serie al editar, pero los pide en el cuerpo
  actualizar(equipoId: number, d: DatosEquipo) {
    return request<unknown>('/api/equipo/actualizar', {
      method: 'PUT',
      body: JSON.stringify({ equipoId, ...d }),
    })
  },
  desactivar(equipoId: number) {
    return request<unknown>(`/api/equipo/eliminar/${equipoId}`, { method: 'DELETE' })
  },
  activar(equipoId: number) {
    return request<unknown>(`/api/equipo/activar/${equipoId}`, { method: 'PUT' })
  },
}

// ---------- Datos de prueba (los mismos del script 02) ----------
const tiposMock: TipoEquipo[] = [
  { tipoEquipoId: 1, nombre: 'Laptop' },
  { tipoEquipoId: 2, nombre: 'Desktop' },
  { tipoEquipoId: 3, nombre: 'Impresora' },
  { tipoEquipoId: 4, nombre: 'Monitor' },
  { tipoEquipoId: 5, nombre: 'Tablet' },
  { tipoEquipoId: 6, nombre: 'Equipo de red' },
]

const clientesMock: ClienteOpcion[] = [
  { clienteId: 1, nombreRazonSocial: 'Juan Carlos Méndez', nit: '4567890-1', estado: 'ACTIVO' },
  { clienteId: 2, nombreRazonSocial: 'Lucía Hernández', nit: 'CF', estado: 'ACTIVO' },
  { clienteId: 3, nombreRazonSocial: 'Comercial El Progreso, S.A.', nit: '7890123-4', estado: 'ACTIVO' },
  { clienteId: 4, nombreRazonSocial: 'Colegio San Andrés', nit: '8901234-5', estado: 'ACTIVO' },
]

const equiposMock: Omit<Equipo, 'nombreTipoEquipo' | 'nombreCliente'>[] = [
  { equipoId: 1, clienteId: 1, tipoEquipoId: 1, marca: 'HP', modelo: 'Pavilion 15', numeroSerie: 'HP5CD1234XYZ', descripcion: 'Color plateado, con cargador', estado: 'ACTIVO' },
  { equipoId: 2, clienteId: 2, tipoEquipoId: 1, marca: 'Lenovo', modelo: 'IdeaPad 3', numeroSerie: 'LNV-PF3ABC12', descripcion: 'Sin cargador', estado: 'ACTIVO' },
  { equipoId: 3, clienteId: 3, tipoEquipoId: 2, marca: 'Dell', modelo: 'OptiPlex 3080', numeroSerie: 'DL-7HJK921', descripcion: 'Equipo de facturación', estado: 'ACTIVO' },
  { equipoId: 4, clienteId: 3, tipoEquipoId: 3, marca: 'Epson', modelo: 'L3250', numeroSerie: 'EPS-X8QW5521', descripcion: 'Multifuncional de tinta continua', estado: 'ACTIVO' },
  { equipoId: 5, clienteId: 4, tipoEquipoId: 1, marca: 'Acer', modelo: 'Aspire 5', numeroSerie: 'ACR-NXHS7AA01', descripcion: 'Laptop del laboratorio de cómputo', estado: 'ACTIVO' },
]

const espera = <T>(valor: T) => new Promise<T>((r) => setTimeout(() => r(structuredClone(valor)), 250))

function completar(e: (typeof equiposMock)[number]): Equipo {
  return {
    ...e,
    nombreTipoEquipo: tiposMock.find((t) => t.tipoEquipoId === e.tipoEquipoId)?.nombre ?? '',
    nombreCliente: clientesMock.find((c) => c.clienteId === e.clienteId)?.nombreRazonSocial ?? '',
  }
}

// Mismas validaciones que la API y la base (cliente activo, tipo válido, serie única)
function validarMock(d: DatosEquipo, equipoId?: number) {
  if (!clientesMock.some((c) => c.clienteId === d.clienteId && c.estado === 'ACTIVO'))
    throw new ApiError('El cliente no existe o está inactivo.', 400)
  if (!tiposMock.some((t) => t.tipoEquipoId === d.tipoEquipoId))
    throw new ApiError('El tipo de equipo no existe.', 400)
  if (equiposMock.some((e) => e.equipoId !== equipoId && e.numeroSerie.toUpperCase() === d.numeroSerie.toUpperCase()))
    throw new ApiError('Ya existe un equipo con ese número de serie.', 400)
}

const apiDemo = {
  listar(clienteId?: number) {
    return espera(equiposMock.filter((e) => !clienteId || e.clienteId === clienteId).map(completar))
  },
  tipos() {
    return espera(tiposMock)
  },
  clientes() {
    return espera(clientesMock)
  },
  crear(d: DatosEquipo) {
    validarMock(d)
    const equipoId = Math.max(0, ...equiposMock.map((e) => e.equipoId)) + 1
    equiposMock.push({ ...d, equipoId, estado: 'ACTIVO' })
    return espera({ equipoId })
  },
  actualizar(equipoId: number, d: DatosEquipo) {
    const e = equiposMock.find((x) => x.equipoId === equipoId)
    if (!e) return Promise.reject(new ApiError('Equipo no encontrado.', 404))
    validarMock({ ...d, clienteId: e.clienteId }, equipoId)
    // igual que la API: el cliente y el número de serie no cambian al editar
    Object.assign(e, { tipoEquipoId: d.tipoEquipoId, marca: d.marca, modelo: d.modelo, descripcion: d.descripcion })
    return espera(null)
  },
  desactivar(equipoId: number) {
    const e = equiposMock.find((x) => x.equipoId === equipoId)
    if (!e) return Promise.reject(new ApiError('Equipo no encontrado.', 404))
    e.estado = 'INACTIVO'
    return espera(null)
  },
  activar(equipoId: number) {
    const e = equiposMock.find((x) => x.equipoId === equipoId)
    if (!e) return Promise.reject(new ApiError('Equipo no encontrado.', 404))
    e.estado = 'ACTIVO'
    return espera(null)
  },
}

export const equiposApi = USE_MOCK ? apiDemo : apiReal
