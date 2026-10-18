// Semana 3 — Acceso a la API de inventario y compras (InventarioController). Solo ADMINISTRADOR y BODEGA.
// Rutas: GET /api/inventario/stock?bodegaId=&soloBajo=, /bodegas, /proveedores, /repuestos,
//        GET /api/inventario/compras?estado=, GET /api/inventario/compras/{id},
//        GET /api/inventario/movimientos?bodegaId=&tipo=,
//        POST /api/inventario/compras, POST /api/inventario/compras/{id}/recibir,
//        POST /api/inventario/compras/{id}/anular
// El usuario no se envía: la API lo toma del token del login.
import { apiFetch } from '@/core/api/apiFetch'

export type EstadoCompra = 'PENDIENTE' | 'RECIBIDA' | 'ANULADA'

export interface Stock {
  bodegaId: number
  bodega: string
  categoriaId: number
  categoria: string
  repuestoId: number
  codigo: string
  repuesto: string
  existencia: number
  stockMinimo: number
  precioCompraReferencia: number
  precioVenta: number
  valorInventario: number
  estadoStock: 'OK' | 'BAJO MINIMO' | 'SIN STOCK'
  fechaActualizacion: string
}

export interface Bodega {
  bodegaId: number
  nombre: string
  ubicacion: string | null
}

export interface Proveedor {
  proveedorId: number
  nit: string
  nombre: string
}

export interface RepuestoCatalogo {
  repuestoId: number
  codigo: string
  nombre: string
  categoria: string
  precioCompraReferencia: number
}

export interface Compra {
  compraId: number
  numeroCompra: string
  fechaCompra: string
  fechaRecepcion: string | null
  estado: EstadoCompra
  proveedorId: number
  proveedor: string
  bodegaId: number
  bodega: string
  registradaPor: string
  observaciones: string | null
  lineas: number
  total: number
}

export interface DetalleCompra {
  repuestoId: number
  codigo: string
  repuesto: string
  cantidad: number
  costoUnitario: number
  subtotal: number
}

export interface Movimiento {
  movimientoId: number
  fechaMovimiento: string
  tipoMovimiento: 'ENTRADA' | 'SALIDA'
  bodegaId: number
  bodega: string
  codigo: string
  repuesto: string
  cantidad: number
  existenciaResultante: number
  tipoDocumento: 'COMPRA' | 'ORDEN'
  documentoOrigen: string | null
  proveedor: string | null
  usuario: string
  observacion: string | null
}

export interface LineaCompra {
  repuestoId: number
  cantidad: number
  costoUnitario: number
}

export interface NuevaCompra {
  proveedorId: number
  bodegaId: number
  observaciones: string | null
  detalle: LineaCompra[]
}

// Mensajes técnicos de la base → texto claro
function mensajeClaro(texto: string): string {
  if (/UQ_Compra_NumeroCompra|duplicate key/i.test(texto)) return 'Se generó un número de compra repetido. Intente de nuevo.'
  return texto
}

const request = <T>(path: string, init?: RequestInit) => apiFetch<T>(path, init, mensajeClaro)

const query = (params: Record<string, string | number | boolean | undefined>) => {
  const q = Object.entries(params)
    .filter(([, v]) => v !== undefined && v !== '' && v !== 0 && v !== false)
    .map(([k, v]) => `${k}=${encodeURIComponent(String(v))}`)
    .join('&')
  return q ? `?${q}` : ''
}

export const inventarioApi = {
  stock(bodegaId?: number, soloBajo?: boolean) {
    return request<Stock[]>(`/api/inventario/stock${query({ bodegaId, soloBajo })}`)
  },
  bodegas() {
    return request<Bodega[]>('/api/inventario/bodegas')
  },
  proveedores() {
    return request<Proveedor[]>('/api/inventario/proveedores')
  },
  repuestos() {
    return request<RepuestoCatalogo[]>('/api/inventario/repuestos')
  },
  compras(estado?: EstadoCompra | '') {
    return request<Compra[]>(`/api/inventario/compras${query({ estado })}`)
  },
  detalleCompra(compraId: number) {
    return request<DetalleCompra[]>(`/api/inventario/compras/${compraId}`)
  },
  movimientos(bodegaId?: number, tipo?: string) {
    return request<Movimiento[]>(`/api/inventario/movimientos${query({ bodegaId, tipo })}`)
  },
  registrarCompra(c: NuevaCompra) {
    return request<{ compraId: number; numeroCompra: string; totalCompra: number }>('/api/inventario/compras', {
      method: 'POST',
      body: JSON.stringify(c),
    })
  },
  recibirCompra(compraId: number) {
    return request<{ numeroCompra: string; unidadesRecibidas: number }>(`/api/inventario/compras/${compraId}/recibir`, {
      method: 'POST',
    })
  },
  anularCompra(compraId: number, motivo: string) {
    return request<unknown>(`/api/inventario/compras/${compraId}/anular`, {
      method: 'POST',
      body: JSON.stringify({ motivo }),
    })
  },
}
