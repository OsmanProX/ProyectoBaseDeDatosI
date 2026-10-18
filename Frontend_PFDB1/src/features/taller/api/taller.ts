// Semana 3 — Acceso a la API del taller (TallerController). Solo ADMINISTRADOR y TECNICO.
// Rutas: GET /api/taller/ordenes?estadoId=, GET /api/taller/orden/{id}, GET /api/taller/repuestos,
//        POST /api/taller/diagnostico, POST /api/taller/reparacion/iniciar,
//        POST /api/taller/reparacion/actividad, POST /api/taller/reparacion/repuesto,
//        POST /api/taller/reparacion/finalizar
// El técnico no se envía: la API lo toma del token del login.
import { apiFetch } from '@/core/api/apiFetch'

export type Prioridad = 'BAJA' | 'MEDIA' | 'ALTA' | 'URGENTE'

export interface OrdenTaller {
  ordenId: number
  numeroOrden: string
  fechaIngreso: string
  fechaEstimada: string | null
  diasAbierta: number
  estadoOrdenId: number
  estado: string
  prioridad: Prioridad
  nivelPrioridad: number
  clienteId: number
  cliente: string
  tipoEquipo: string
  equipo: string
  numeroSerie: string
  recibidoPor: string
  tecnicoResponsable: string
  problemaReportado: string
  totalSinIVA: number | null
}

export interface Diagnostico {
  diagnosticoId: number
  ordenId: number
  tecnico: string
  fechaDiagnostico: string
  descripcion: string
  costoManoObraEstimado: number
  observaciones: string | null
}

export interface Reparacion {
  reparacionId: number
  tecnico: string
  fechaInicio: string
  fechaFin: string | null
  descripcionTrabajo: string | null
  costoManoObra: number
  estado: 'EN_PROCESO' | 'FINALIZADA' | 'CANCELADA'
}

export interface Actividad {
  numeroActividad: number
  descripcion: string
  horasTrabajadas: number | null
  fechaRegistro: string
}

export interface RepuestoUsado {
  repuestoId: number
  codigo: string
  repuesto: string
  bodega: string
  cantidad: number
  precioVentaUnitario: number
  subtotal: number
  fechaRegistro: string
}

export interface DetalleTaller {
  orden: OrdenTaller
  diagnostico: Diagnostico | null
  reparacion: Reparacion | null
  actividades: Actividad[]
  repuestos: RepuestoUsado[]
}

export interface RepuestoDisponible {
  bodegaId: number
  bodega: string
  repuestoId: number
  codigo: string
  repuesto: string
  categoria: string
  existencia: number
  precioVenta: number
}

// Mismos ids que la tabla EstadoOrden (el taller trabaja del 1 al 5)
export const ESTADOS_TALLER: { id: number; nombre: string }[] = [
  { id: 1, nombre: 'Recibido' },
  { id: 2, nombre: 'Diagnóstico' },
  { id: 3, nombre: 'Esperando autorización' },
  { id: 4, nombre: 'Reparación' },
  { id: 5, nombre: 'Listo' },
]

const post = <T>(path: string, body: unknown) =>
  apiFetch<T>(path, { method: 'POST', body: JSON.stringify(body) })

export const tallerApi = {
  ordenes(estadoId?: number) {
    return apiFetch<OrdenTaller[]>(`/api/taller/ordenes${estadoId ? `?estadoId=${estadoId}` : ''}`)
  },
  detalle(ordenId: number) {
    return apiFetch<DetalleTaller>(`/api/taller/orden/${ordenId}`)
  },
  repuestosDisponibles() {
    return apiFetch<RepuestoDisponible[]>('/api/taller/repuestos')
  },
  registrarDiagnostico(d: { ordenId: number; descripcion: string; costoManoObraEstimado: number; observaciones: string | null }) {
    return post<unknown>('/api/taller/diagnostico', d)
  },
  iniciarReparacion(d: { ordenId: number; descripcionTrabajo: string | null }) {
    return post<unknown>('/api/taller/reparacion/iniciar', d)
  },
  registrarActividad(d: { reparacionId: number; descripcion: string; horasTrabajadas: number | null }) {
    return post<unknown>('/api/taller/reparacion/actividad', d)
  },
  asignarRepuesto(d: { reparacionId: number; repuestoId: number; bodegaId: number; cantidad: number }) {
    return post<{ existenciaResultante: number }>('/api/taller/reparacion/repuesto', d)
  },
  finalizarReparacion(d: { reparacionId: number; costoManoObra: number | null; descripcionTrabajo: string | null }) {
    return post<{ totalSinIVA: number }>('/api/taller/reparacion/finalizar', d)
  },
}
