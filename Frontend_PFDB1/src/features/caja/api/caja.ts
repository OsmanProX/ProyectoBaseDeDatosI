// Semana 4 — Acceso a la API de caja (CajaController).
// Ver: ADMINISTRADOR, CAJA y RECEPCION. Facturar y cobrar: ADMINISTRADOR y CAJA.
// Entregar: ADMINISTRADOR y RECEPCION.
// Rutas: GET /api/caja/ordenes?entregadas=, GET /api/caja/orden/{id}, GET /api/caja/metodos-pago,
//        POST /api/caja/facturar, POST /api/caja/pagos, POST /api/caja/entregar
// El usuario no se envía: la API lo toma del token del login.
import { apiFetch } from '@/core/api/apiFetch'
import { env } from '@/core/config/env'

export interface OrdenCaja {
  ordenId: number
  numeroOrden: string
  fechaIngreso: string
  estadoOrdenId: number
  estado: string
  prioridad: 'BAJA' | 'MEDIA' | 'ALTA' | 'URGENTE'
  clienteId: number
  cliente: string
  nit: string
  equipo: string
  numeroSerie: string
  manoObra: number
  repuestos: number
  totalSinIVA: number
  facturaId: number | null
  numeroFactura: string | null
  totalFactura: number | null
  saldoPendiente: number | null
  estadoFactura: 'EMITIDA' | 'PAGADA' | 'ANULADA' | null
  fechaEntrega: string | null
}

export interface Factura {
  facturaId: number
  numeroFactura: string
  fechaEmision: string
  nitFacturacion: string
  nombreFacturacion: string
  totalManoObra: number
  totalRepuestos: number
  subtotal: number
  impuesto: number
  total: number
  saldoPendiente: number
  estado: 'EMITIDA' | 'PAGADA' | 'ANULADA'
  emitidaPor: string
}

export interface Pago {
  pagoId: number
  fechaPago: string
  metodo: string
  monto: number
  referencia: string | null
  estado: string
  cobradoPor: string
}

export interface Entrega {
  fechaEntrega: string
  nombreRecibe: string
  observaciones: string | null
  entregadoPor: string
}

export interface DetalleCaja {
  orden: OrdenCaja
  factura: Factura | null
  pagos: Pago[]
  entrega: Entrega | null
}

export interface MetodoPago {
  metodoPagoId: number
  nombre: string
}

const post = <T>(path: string, body: unknown) =>
  apiFetch<T>(path, { method: 'POST', body: JSON.stringify(body) })

export const cajaApi = {
  /** Descarga el comprobante de entrega en PDF (Caja y Admin) */
  async descargarComprobante(ordenId: number, numeroOrden: string) {
    const token = sessionStorage.getItem('token')
    const res = await fetch(`${env.VITE_API_BASE_URL}/api/caja/orden/${ordenId}/comprobante`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    })
    if (!res.ok) {
      const body = await res.json().catch(() => ({}))
      throw new Error(body.mensaje ?? (res.status === 403 ? 'Su usuario no tiene permiso.' : 'No se pudo generar el PDF.'))
    }
    const url = URL.createObjectURL(await res.blob())
    const a = document.createElement('a')
    a.href = url
    a.download = `Comprobante_${numeroOrden}.pdf`
    a.click()
    URL.revokeObjectURL(url)
  },
  /** Envía el comprobante en PDF al correo del cliente */
  enviarComprobante(ordenId: number) {
    return apiFetch<{ mensaje: string }>(`/api/caja/orden/${ordenId}/comprobante/enviar`, { method: 'POST' })
  },
  ordenes(entregadas = false) {
    return apiFetch<OrdenCaja[]>(`/api/caja/ordenes${entregadas ? '?entregadas=true' : ''}`)
  },
  detalle(ordenId: number) {
    return apiFetch<DetalleCaja>(`/api/caja/orden/${ordenId}`)
  },
  metodosPago() {
    return apiFetch<MetodoPago[]>('/api/caja/metodos-pago')
  },
  facturar(d: { ordenId: number; nitFacturacion: string | null; nombreFacturacion: string | null }) {
    return post<{ numeroFactura: string; total: number }>('/api/caja/facturar', d)
  },
  registrarPago(d: { facturaId: number; metodoPagoId: number; monto: number; referencia: string | null }) {
    return post<{ saldoPendiente: number; estadoFactura: string }>('/api/caja/pagos', d)
  },
  entregar(d: { ordenId: number; nombreRecibe: string; observaciones: string | null }) {
    return post<unknown>('/api/caja/entregar', d)
  },
}
