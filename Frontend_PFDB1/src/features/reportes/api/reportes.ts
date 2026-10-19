// Semana 4 — Reportes (ReportesController). Los 12 reportes: solo ADMINISTRADOR.
// Rutas: GET /api/reportes/{1..12}?desde=&hasta=&buscar=&bodegaId=&estado=, GET /api/reportes/dashboard
import { apiFetch } from '@/core/api/apiFetch'

export type Fila = Record<string, string | number | null>

export interface Trazabilidad {
  resumen: Fila | null
  lineaTiempo: Fila[]
}

export interface Dashboard {
  resumen: Fila | null
  actividad: Fila[]
}

// Qué filtros usa cada reporte (los mismos que acepta la API)
export interface DefReporte {
  numero: number
  titulo: string
  descripcion: string
  fechas?: boolean
  buscar?: string // texto de ayuda del buscador
  bodega?: boolean
  obligatorio?: boolean // el buscador es obligatorio (reporte 12)
  estados?: { valor: string; texto: string }[] // filtro por estado (reportes 1, 2 y 8)
}

const ESTADOS_ABIERTOS = [
  { valor: 'RECIBIDO', texto: 'Recibido' },
  { valor: 'DIAGNOSTICO', texto: 'En diagnóstico' },
  { valor: 'ESPERANDO_AUTORIZACION', texto: 'Esperando autorización' },
  { valor: 'REPARACION', texto: 'En reparación' },
  { valor: 'LISTO', texto: 'Listo para entregar' },
]
const ESTADOS_ORDEN = [
  ...ESTADOS_ABIERTOS,
  { valor: 'ENTREGADO', texto: 'Entregado' },
  { valor: 'CANCELADO', texto: 'Cancelado' },
]
const ESTADOS_COMPRA = [
  { valor: 'PENDIENTE', texto: 'Pendiente' },
  { valor: 'RECIBIDA', texto: 'Recibida' },
  { valor: 'ANULADA', texto: 'Anulada' },
]

export const REPORTES: DefReporte[] = [
  { numero: 1, titulo: 'Órdenes activas', descripcion: 'Órdenes abiertas por estado, prioridad y técnico.', buscar: 'Orden, cliente o técnico', estados: ESTADOS_ABIERTOS },
  { numero: 2, titulo: 'Historial de un cliente', descripcion: 'Todas las órdenes de un cliente con factura, saldo y entrega.', buscar: 'Cliente o NIT', estados: ESTADOS_ORDEN },
  { numero: 3, titulo: 'Historial de un equipo', descripcion: 'Historial técnico de un equipo por número de serie.', buscar: 'Número de serie o propietario' },
  { numero: 4, titulo: 'Trabajo por técnico', descripcion: 'Diagnósticos y reparaciones de cada técnico.', fechas: true, buscar: 'Técnico' },
  { numero: 5, titulo: 'Repuestos utilizados', descripcion: 'Repuestos usados por orden, técnico y bodega, con costo y venta.', fechas: true, bodega: true, buscar: 'Orden, técnico o repuesto' },
  { numero: 6, titulo: 'Inventario actual', descripcion: 'Existencias por bodega, categoría y repuesto.', bodega: true, buscar: 'Código, repuesto o categoría' },
  { numero: 7, titulo: 'Bajo mínimo', descripcion: 'Repuestos con existencia igual o menor al mínimo.', bodega: true },
  { numero: 8, titulo: 'Compras por proveedor', descripcion: 'Compras con su detalle y costo histórico.', fechas: true, buscar: 'Proveedor o número de compra', estados: ESTADOS_COMPRA },
  { numero: 9, titulo: 'Movimientos de inventario', descripcion: 'Entradas y salidas con su documento de origen.', fechas: true, bodega: true, buscar: 'Repuesto, código o documento' },
  { numero: 10, titulo: 'Saldos pendientes', descripcion: 'Facturas con saldo y los pagos recibidos.', buscar: 'Cliente, factura u orden' },
  { numero: 11, titulo: 'Ingresos por período', descripcion: 'Ingresos por mes: mano de obra, repuestos, IVA y lo cobrado.', fechas: true },
  { numero: 12, titulo: 'Trazabilidad de una orden', descripcion: 'Todo lo que pasó con una orden, de la recepción a la entrega.', buscar: 'Número de orden (OS-2026-0001)', obligatorio: true },
]

export interface Filtros {
  desde?: string
  hasta?: string
  buscar?: string
  bodegaId?: number
  estado?: string
}

function query(f: Filtros) {
  const p = new URLSearchParams()
  if (f.desde) p.set('desde', f.desde)
  if (f.hasta) p.set('hasta', f.hasta)
  if (f.buscar?.trim()) p.set('buscar', f.buscar.trim())
  if (f.bodegaId) p.set('bodegaId', String(f.bodegaId))
  if (f.estado) p.set('estado', f.estado)
  const q = p.toString()
  return q ? `?${q}` : ''
}

export const reportesApi = {
  generar(numero: number, filtros: Filtros) {
    return apiFetch<Fila[]>(`/api/reportes/${numero}${query(filtros)}`)
  },
  trazabilidad(numeroOrden: string) {
    return apiFetch<Trazabilidad>(`/api/reportes/12${query({ buscar: numeroOrden })}`)
  },
  dashboard() {
    return apiFetch<Dashboard>('/api/reportes/dashboard')
  },
  bodegas() {
    // Catálogo de bodegas (lo publica InventarioController; si el rol no tiene acceso se omite el filtro)
    return apiFetch<{ bodegaId: number; nombre: string }[]>('/api/inventario/bodegas')
  },
}

// ---------- formato de columnas ----------
const ETIQUETAS: Record<string, string> = {
  numeroOrden: 'Orden', fechaIngreso: 'Ingreso', diasAbierta: 'Días', tipoEquipo: 'Tipo', numeroSerie: 'Serie',
  recibidoPor: 'Recibió', tecnicoResponsable: 'Técnico', problemaReportado: 'Problema', totalSinIVA: 'Total sin IVA',
  tipoCliente: 'Tipo cliente', nit: 'NIT', numeroFactura: 'Factura', totalFacturado: 'Facturado', saldoPendiente: 'Saldo',
  fechaEntrega: 'Entrega', estadoOrden: 'Estado', tecnicoDiagnostico: 'Técnico diag.', diagnostico: 'Diagnóstico',
  tecnicoReparacion: 'Técnico rep.', estadoReparacion: 'Reparación', trabajoRealizado: 'Trabajo realizado',
  tipoTrabajo: 'Tipo', fechaFin: 'Fin', manoObra: 'Mano de obra', categoria: 'Categoría', codigo: 'Código',
  costoHistorico: 'Costo', ventaHistorica: 'Venta', costoTotal: 'Costo total', ventaTotal: 'Venta total',
  precioVentaActual: 'Venta actual', fechaRegistro: 'Fecha', stockMinimo: 'Mínimo', precioCompraReferencia: 'Precio compra',
  precioVenta: 'Precio venta', valorInventario: 'Valor', estadoStock: 'Estado', faltante: 'Faltante',
  nitProveedor: 'NIT', numeroCompra: 'Compra', fechaCompra: 'Fecha', fechaRecepcion: 'Recepción', registradaPor: 'Registró',
  costoActual: 'Costo actual', fechaMovimiento: 'Fecha', tipoMovimiento: 'Tipo', existenciaResultante: 'Queda',
  tipoDocumento: 'Documento', documentoOrigen: 'Origen', observacion: 'Observación', fechaEmision: 'Emisión',
  totalPagado: 'Pagado', fechaPago: 'Fecha pago', metodoPago: 'Método', montoPago: 'Monto', cobradoPor: 'Cobró',
  anio: 'Año', iva: 'IVA', porCobrar: 'Por cobrar', estadoActual: 'Estado', costoManoObra: 'Mano de obra',
  costoManoObraEstimado: 'M. obra estimada', repuestosUsados: 'Repuestos', ventaRepuestos: 'Venta repuestos',
  movimientosSalida: 'Salidas', totalFactura: 'Total factura', nombreRecibe: 'Recibió', entregadoPor: 'Entregó',
  etapa: 'Etapa', detalle: 'Detalle', usuario: 'Usuario', monto: 'Monto', inicioReparacion: 'Inicio rep.', finReparacion: 'Fin rep.',
}

const MONEDA = new Set([
  'totalSinIVA', 'totalFacturado', 'saldoPendiente', 'manoObra', 'costoHistorico', 'ventaHistorica', 'costoTotal',
  'ventaTotal', 'precioVentaActual', 'precioCompraReferencia', 'precioVenta', 'valorInventario', 'subtotal', 'costoActual',
  'total', 'totalPagado', 'montoPago', 'repuestos', 'iva', 'cobrado', 'porCobrar', 'costoManoObra',
  'costoManoObraEstimado', 'ventaRepuestos', 'totalFactura', 'monto',
])

export function etiqueta(clave: string) {
  if (ETIQUETAS[clave]) return ETIQUETAS[clave]
  const t = clave.replace(/([A-Z])/g, ' $1').toLowerCase()
  return t.charAt(0).toUpperCase() + t.slice(1)
}

export const esMoneda = (clave: string) => MONEDA.has(clave)

const MESES = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic']

export function valor(clave: string, v: string | number | null): string {
  if (v === null || v === undefined || v === '') return '—'
  if (typeof v === 'number') {
    if (MONEDA.has(clave)) return v.toLocaleString('es-GT', { style: 'currency', currency: 'GTQ' })
    if (clave === 'mes') return MESES[v - 1] ?? String(v)
    if (clave === 'anio') return String(v)
    return v.toLocaleString('es-GT')
  }
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(v)) {
    const d = new Date(v)
    return d.getHours() === 0 && d.getMinutes() === 0
      ? d.toLocaleDateString('es-GT')
      : d.toLocaleString('es-GT', { dateStyle: 'short', timeStyle: 'short' })
  }
  return v
}
