// Portal del cliente (rol CLIENTE): GET /api/cliente/mis-ordenes (sp_Cliente_MisOrdenes)
import { apiFetch } from '@/core/api/apiFetch'
import { env } from '@/core/config/env'

export interface MiOrden {
  ordenId: number
  numeroOrden: string
  fechaIngreso: string
  fechaEstimada: string | null
  prioridad: string
  estado: string
  estadoDescripcion: string | null
  tipoEquipo: string
  equipo: string
  numeroSerie: string
  problemaReportado: string
  numeroFactura: string | null
  total: number | null
  saldo: number | null
  // detalle extra (solo lectura)
  diagnostico: string | null
  costoEstimado: number | null
  pagado: number | null
  ultimoCambio: string | null
  motivoCancelacion: string | null
  fechaEntrega: string | null
  nombreRecibe: string | null
}

export const portalApi = {
  misOrdenes: () => apiFetch<MiOrden[]>('/api/cliente/mis-ordenes'),

  /** Descarga el comprobante en PDF (solo órdenes entregadas del propio cliente) */
  async descargarComprobante(ordenId: number, numeroOrden: string) {
    const token = sessionStorage.getItem('token')
    const res = await fetch(`${env.VITE_API_BASE_URL}/api/cliente/mis-ordenes/${ordenId}/comprobante`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    })
    if (!res.ok) {
      const body = await res.json().catch(() => ({}))
      throw new Error(body.mensaje ?? 'No se pudo generar el PDF.')
    }
    const url = URL.createObjectURL(await res.blob())
    const a = document.createElement('a')
    a.href = url
    a.download = `Comprobante_${numeroOrden}.pdf`
    a.click()
    URL.revokeObjectURL(url)
  },

  /** Envía el comprobante al correo registrado del cliente */
  enviarComprobante: (ordenId: number) =>
    apiFetch<{ mensaje: string }>(`/api/cliente/mis-ordenes/${ordenId}/comprobante/enviar`, { method: 'POST' }),
}
