// Portal del cliente (rol CLIENTE): GET /api/cliente/mis-ordenes (sp_Cliente_MisOrdenes)
import { apiFetch } from '@/core/api/apiFetch'

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
}

export const portalApi = {
  misOrdenes: () => apiFetch<MiOrden[]>('/api/cliente/mis-ordenes'),
}
