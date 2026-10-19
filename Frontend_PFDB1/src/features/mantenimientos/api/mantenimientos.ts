// Mantenimientos (MantenimientoController): repuestos, proveedores, bodegas, categorías y tipos de equipo.
// Repuestos y proveedores: ADMINISTRADOR y BODEGA. Bodegas, categorías y tipos de equipo: los modifica ADMINISTRADOR.
import { apiFetch } from '@/core/api/apiFetch'

export type EstadoRegistro = 'ACTIVO' | 'INACTIVO'

export interface Categoria {
  categoriaId: number
  nombre: string
  descripcion: string | null
  activo: boolean
  repuestos: number
}

export interface TipoEquipo {
  tipoEquipoId: number
  nombre: string
  equipos: number
}

export interface Repuesto {
  repuestoId: number
  categoriaId: number
  categoria: string
  codigo: string
  nombre: string
  descripcion: string | null
  precioCompraReferencia: number
  precioVenta: number
  estado: EstadoRegistro
  existencia: number
  bodegas: number
}

export interface RepuestoBodega {
  bodegaId: number
  bodega: string
  existencia: number
  stockMinimo: number
  registrado: boolean
}

export interface Bodega {
  bodegaId: number
  nombre: string
  ubicacion: string | null
  activo: boolean
  repuestosConExistencia: number
  unidades: number
  valorInventario: number
}

export interface Proveedor {
  proveedorId: number
  nit: string
  nombre: string
  contacto: string | null
  telefono: string
  correo: string | null
  direccion: string | null
  estado: EstadoRegistro
  compras: number
  comprasPendientes: number
}

export interface RepuestoForm {
  categoriaId: number
  codigo: string
  nombre: string
  descripcion: string
  precioCompraReferencia: number
  precioVenta: number
  bodegaId: number
  stockMinimo: number
}

export interface ProveedorForm {
  nit: string
  nombre: string
  contacto: string
  telefono: string
  correo: string
  direccion: string
}

const BASE = '/api/mantenimiento'
const json = (method: 'POST' | 'PUT', body: unknown): RequestInit => ({ method, body: JSON.stringify(body) })

function query(p: Record<string, string | number | undefined>) {
  const q = new URLSearchParams()
  for (const [k, v] of Object.entries(p)) if (v !== undefined && v !== '' && v !== 0) q.set(k, String(v))
  const t = q.toString()
  return t ? `?${t}` : ''
}

export const mantenimientoApi = {
  // categorías
  categorias: () => apiFetch<Categoria[]>(`${BASE}/categorias`),
  guardarCategoria: (id: number | null, f: { nombre: string; descripcion: string }) =>
    apiFetch(id ? `${BASE}/categorias/${id}` : `${BASE}/categorias`, json(id ? 'PUT' : 'POST', f)),
  estadoCategoria: (id: number, activo: boolean) =>
    apiFetch(`${BASE}/categorias/${id}/estado`, json('PUT', { activo })),

  // tipos de equipo
  tiposEquipo: () => apiFetch<TipoEquipo[]>(`${BASE}/tipos-equipo`),
  guardarTipoEquipo: (id: number | null, f: { nombre: string }) =>
    apiFetch(id ? `${BASE}/tipos-equipo/${id}` : `${BASE}/tipos-equipo`, json(id ? 'PUT' : 'POST', f)),

  // repuestos
  repuestos: (f: { buscar?: string; categoriaId?: number; estado?: string }) =>
    apiFetch<Repuesto[]>(`${BASE}/repuestos${query(f)}`),
  guardarRepuesto: (id: number | null, f: RepuestoForm) =>
    apiFetch(id ? `${BASE}/repuestos/${id}` : `${BASE}/repuestos`, json(id ? 'PUT' : 'POST', {
      ...f,
      bodegaId: f.bodegaId || null,
    })),
  estadoRepuesto: (id: number, estado: EstadoRegistro) =>
    apiFetch(`${BASE}/repuestos/${id}/estado`, json('PUT', { estado })),
  inventarioRepuesto: (id: number) => apiFetch<RepuestoBodega[]>(`${BASE}/repuestos/${id}/inventario`),
  guardarMinimo: (id: number, bodegaId: number, stockMinimo: number) =>
    apiFetch(`${BASE}/repuestos/${id}/inventario/${bodegaId}`, json('PUT', { stockMinimo })),

  // bodegas
  bodegas: () => apiFetch<Bodega[]>(`${BASE}/bodegas`),
  guardarBodega: (id: number | null, f: { nombre: string; ubicacion: string }) =>
    apiFetch(id ? `${BASE}/bodegas/${id}` : `${BASE}/bodegas`, json(id ? 'PUT' : 'POST', f)),
  estadoBodega: (id: number, activo: boolean) =>
    apiFetch(`${BASE}/bodegas/${id}/estado`, json('PUT', { activo })),

  // proveedores
  proveedores: (f: { buscar?: string; estado?: string }) =>
    apiFetch<Proveedor[]>(`${BASE}/proveedores${query(f)}`),
  guardarProveedor: (id: number | null, f: ProveedorForm) =>
    apiFetch(id ? `${BASE}/proveedores/${id}` : `${BASE}/proveedores`, json(id ? 'PUT' : 'POST', f)),
  estadoProveedor: (id: number, estado: EstadoRegistro) =>
    apiFetch(`${BASE}/proveedores/${id}/estado`, json('PUT', { estado })),
}
