<script setup lang="ts">
// Semana 4 — Los 12 reportes del proyecto (solo ADMINISTRADOR).
// Cada reporte sale de una vista, función o procedimiento de la base (scripts 04 y 07).
import { computed, onMounted, reactive, ref } from 'vue'
import {
  reportesApi, REPORTES, etiqueta, valor, esMoneda,
  type Fila, type Trazabilidad,
} from '../api/reportes'
import { ordenesApi, type OrdenResumen } from '@/features/ordenes/api/ordenes'
import { cajaApi } from '@/features/caja/api/caja'
import InfoTip from '@/shared/components/InfoTip.vue'

const actual = ref(REPORTES[0]!)
const filtros = reactive({ desde: '', hasta: '', buscar: '', bodegaId: 0, estado: '' })
const bodegas = ref<{ bodegaId: number; nombre: string }[]>([])

const filas = ref<Fila[]>([])
const traza = ref<Trazabilidad | null>(null)
const cargando = ref(false)
const error = ref('')
const generado = ref(false)

const columnas = computed(() => (filas.value[0] ? Object.keys(filas.value[0]) : []))

// ---------- buscar dentro del resultado y ordenar columnas (en pantalla, sin volver a consultar) ----------
const enTabla = ref('')
const orden = ref<{ col: string; asc: boolean } | null>(null)
const normalizar = (v: unknown) => String(v ?? '').normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()

const filasVista = computed(() => {
  const t = normalizar(enTabla.value.trim())
  let lista = t
    ? filas.value.filter((f) => columnas.value.some((c) => normalizar(valor(c, f[c] ?? null)).includes(t)))
    : [...filas.value]
  const o = orden.value
  if (o) {
    lista = lista.sort((a, b) => {
      const x = a[o.col] ?? null
      const y = b[o.col] ?? null
      if (x === y) return 0
      if (x === null) return 1 // los vacíos siempre al final
      if (y === null) return -1
      const r = typeof x === 'number' && typeof y === 'number'
        ? x - y
        : String(x).localeCompare(String(y), 'es', { numeric: true })
      return o.asc ? r : -r
    })
  }
  return lista
})

function ordenarPor(col: string) {
  const o = orden.value
  orden.value = o?.col === col ? (o.asc ? { col, asc: false } : null) : { col, asc: true }
}
function flecha(col: string) {
  const o = orden.value
  if (!o || o.col !== col) return '↕'
  return o.asc ? '▲' : '▼'
}

// Totales de las columnas de dinero (útil en ingresos, repuestos, compras y saldos); suman lo que se ve
const totales = computed(() => {
  const t: Record<string, number> = {}
  for (const c of columnas.value) {
    if (!esMoneda(c) || ['precioVenta', 'precioCompraReferencia', 'precioVentaActual', 'costoActual', 'costoHistorico', 'ventaHistorica'].includes(c)) continue
    t[c] = filasVista.value.reduce((s, f) => s + (typeof f[c] === 'number' ? (f[c] as number) : 0), 0)
  }
  return t
})

// ---------- tarjetas de resumen (arriba de la tabla) ----------
const tarjetas = computed(() => {
  const lista = [{ titulo: 'Registros', texto: filasVista.value.length.toLocaleString('es-GT') }]
  if (hayTotales.value) {
    for (const [c, v] of Object.entries(totales.value).slice(0, 3)) lista.push({ titulo: etiqueta(c), texto: valor(c, v) })
  }
  return lista
})

// ---------- gráfica de barras (agrupa lo que se ve en la tabla) ----------
// Cada reporte dice por qué columna agrupar y, si aplica, qué columna de dinero/cantidad sumar.
// Se usan nombres posibles: se toma el primero que exista en el resultado.
const GRAFICAS: Record<number, { titulo: string; agrupar: string[]; sumar?: string[] }> = {
  1: { titulo: 'Órdenes por estado', agrupar: ['estadoActual', 'estado', 'estadoOrden'] },
  4: { titulo: 'Trabajos por técnico', agrupar: ['tecnico', 'tecnicoResponsable', 'nombreTecnico'] },
  5: { titulo: 'Venta por repuesto (top 8)', agrupar: ['repuesto', 'nombreRepuesto'], sumar: ['ventaTotal', 'ventaHistorica'] },
  6: { titulo: 'Valor del inventario por bodega', agrupar: ['bodega'], sumar: ['valorInventario'] },
  7: { titulo: 'Repuestos bajo mínimo por bodega', agrupar: ['bodega'] },
  8: { titulo: 'Compras por proveedor', agrupar: ['proveedor', 'nombreProveedor'], sumar: ['costoTotal', 'total', 'costoHistorico'] },
  9: { titulo: 'Unidades por tipo de movimiento', agrupar: ['tipoMovimiento'], sumar: ['cantidad'] },
  11: { titulo: 'Ingresos por mes', agrupar: ['mes'], sumar: ['total', 'cobrado', 'subtotal'] },
}

const grafica = computed(() => {
  const def = GRAFICAS[actual.value.numero]
  if (!def || filasVista.value.length < 2) return null
  const cols = columnas.value
  const g = def.agrupar.find((c) => cols.includes(c))
  if (!g) return null
  const s = def.sumar?.find((c) => cols.includes(c))
  const grupos = new Map<string, number>()
  for (const f of filasVista.value) {
    // Ingresos por mes: la etiqueta lleva el año ("Oct 2026")
    const nombre = g === 'mes' && cols.includes('anio')
      ? `${valor('mes', f.mes ?? null)} ${f.anio ?? ''}`.trim()
      : valor(g, f[g] ?? null)
    const n = s ? (typeof f[s] === 'number' ? (f[s] as number) : 0) : 1
    grupos.set(nombre, (grupos.get(nombre) ?? 0) + n)
  }
  let barras = [...grupos].map(([nombre, total]) => ({ nombre, total }))
  if (g !== 'mes') barras = barras.sort((a, b) => b.total - a.total).slice(0, 8) // por mes se respeta el orden del tiempo
  const max = Math.max(...barras.map((b) => b.total), 0)
  if (max <= 0) return null
  return {
    titulo: def.titulo,
    barras: barras.map((b) => ({
      ...b,
      pct: Math.max(2, Math.round((b.total / max) * 100)),
      texto: s ? valor(s, b.total) : b.total.toLocaleString('es-GT'),
    })),
  }
})

// ---------- fechas rápidas ----------
const fechaLocal = (d: Date) => d.toLocaleDateString('en-CA') // AAAA-MM-DD en hora de Guatemala
function rango(tipo: 'mes' | 'mesAnterior' | 'dias30' | 'anio') {
  const hoy = new Date()
  const y = hoy.getFullYear()
  const m = hoy.getMonth()
  if (tipo === 'mes') Object.assign(filtros, { desde: fechaLocal(new Date(y, m, 1)), hasta: fechaLocal(hoy) })
  else if (tipo === 'mesAnterior') Object.assign(filtros, { desde: fechaLocal(new Date(y, m - 1, 1)), hasta: fechaLocal(new Date(y, m, 0)) })
  else if (tipo === 'dias30') Object.assign(filtros, { desde: fechaLocal(new Date(y, m, hoy.getDate() - 29)), hasta: fechaLocal(hoy) })
  else Object.assign(filtros, { desde: fechaLocal(new Date(y, 0, 1)), hasta: fechaLocal(hoy) })
  generar()
}

// ---------- reporte 12: elegir la orden de una lista y enviar el comprobante ----------
const ordenesLista = ref<OrdenResumen[]>([])
async function cargarOrdenes() {
  if (ordenesLista.value.length) return
  try {
    ordenesLista.value = await ordenesApi.listar('', '')
  } catch {
    ordenesLista.value = [] // si falla, se escribe el número a mano
  }
}
const recientes = computed(() => ordenesLista.value.slice(0, 8))
function verOrden(numero: string) {
  filtros.buscar = numero
  generar()
}

const entregada = computed(() => !!traza.value?.resumen?.fechaEntrega)
const accionCorreo = ref<'' | 'pdf' | 'correo'>('')
const avisoCorreo = ref('')
const errorCorreo = ref('')
async function ordenIdActual(): Promise<number | null> {
  const numero = String(traza.value?.resumen?.numeroOrden ?? '')
  if (!numero) return null
  let o = ordenesLista.value.find((x) => x.numeroOrden === numero)
  if (!o) o = (await ordenesApi.listar(numero, '')).find((x) => x.numeroOrden === numero)
  return o?.ordenId ?? null
}
async function comprobante(tipo: 'pdf' | 'correo') {
  avisoCorreo.value = ''
  errorCorreo.value = ''
  accionCorreo.value = tipo
  try {
    const id = await ordenIdActual()
    if (!id) throw new Error('No se encontró la orden.')
    const numero = String(traza.value?.resumen?.numeroOrden ?? '')
    if (tipo === 'pdf') await cajaApi.descargarComprobante(id, numero)
    else avisoCorreo.value = (await cajaApi.enviarComprobante(id)).mensaje
  } catch (e) {
    errorCorreo.value = (e as Error).message
  } finally {
    accionCorreo.value = ''
  }
}
const hayTotales = computed(() => Object.keys(totales.value).length > 0 && filas.value.length > 1
  && ![2, 10].includes(actual.value.numero)) // en 2 y 10 las filas repiten la factura

function elegir(n: number) {
  actual.value = REPORTES.find((r) => r.numero === n)!
  filas.value = []
  traza.value = null
  error.value = ''
  generado.value = false
  filtros.buscar = ''
  filtros.estado = '' // cada reporte tiene sus propios estados
  enTabla.value = ''
  orden.value = null
  avisoCorreo.value = ''
  errorCorreo.value = ''
  if (n === 12) cargarOrdenes()
  if (!actual.value.obligatorio) generar()
}

async function generar() {
  const r = actual.value
  error.value = ''
  if (r.obligatorio && !filtros.buscar.trim()) {
    error.value = 'Escriba el número de orden.'
    return
  }
  if (filtros.desde && filtros.hasta && filtros.desde > filtros.hasta) {
    error.value = 'La fecha "desde" no puede ser mayor que "hasta".'
    return
  }
  cargando.value = true
  avisoCorreo.value = ''
  errorCorreo.value = ''
  try {
    if (r.numero === 12) {
      traza.value = await reportesApi.trazabilidad(filtros.buscar)
      filas.value = []
    } else {
      filas.value = await reportesApi.generar(r.numero, {
        desde: r.fechas ? filtros.desde : undefined,
        hasta: r.fechas ? filtros.hasta : undefined,
        buscar: r.buscar ? filtros.buscar : undefined,
        bodegaId: r.bodega ? filtros.bodegaId || undefined : undefined,
        estado: r.estados ? filtros.estado || undefined : undefined,
      })
      traza.value = null
    }
    generado.value = true
  } catch (e) {
    error.value = (e as Error).message
    filas.value = []
    traza.value = null
  } finally {
    cargando.value = false
  }
}

function limpiar() {
  Object.assign(filtros, { desde: '', hasta: '', buscar: '', bodegaId: 0, estado: '' })
  enTabla.value = ''
  orden.value = null
  if (!actual.value.obligatorio) generar()
  else { traza.value = null; generado.value = false }
}

// Descargar lo que se ve en pantalla como CSV (abre en Excel)
function descargarCsv() {
  const r = actual.value
  const datos: Fila[] = r.numero === 12 ? (traza.value?.lineaTiempo ?? []) : filasVista.value
  if (!datos.length) return
  const cols = Object.keys(datos[0]!)
  const celda = (v: unknown) => `"${String(v ?? '').replace(/"/g, '""')}"`
  const lineas = [cols.map((c) => celda(etiqueta(c))).join(';'),
    ...datos.map((f) => cols.map((c) => celda(typeof f[c] === 'number' ? f[c] : valor(c, f[c] ?? null))).join(';'))]
  const blob = new Blob(['﻿' + lineas.join('\r\n')], { type: 'text/csv;charset=utf-8' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = `Reporte_${String(r.numero).padStart(2, '0')}_${r.titulo.replace(/\s+/g, '_')}.csv`
  a.click()
  URL.revokeObjectURL(a.href)
}

// Imprimir o guardar como PDF: arma una hoja limpia (solo el reporte, sin menú ni botones)
// y abre la ventana de imprimir del navegador. Ahí se elige «Guardar como PDF».
const ENTIDADES: Record<string, string> = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }
const esc = (v: unknown) => String(v ?? '').replace(/[&<>"]/g, (ch) => ENTIDADES[ch] ?? ch)
const fechaCorta = (iso: string) => iso.split('-').reverse().join('/')

function filtrosAplicados() {
  const r = actual.value
  const lista: string[] = []
  if (r.buscar && filtros.buscar.trim()) lista.push(`${r.obligatorio ? 'Orden' : 'Buscar'}: ${filtros.buscar.trim()}`)
  if (r.fechas && filtros.desde) lista.push(`Desde: ${fechaCorta(filtros.desde)}`)
  if (r.fechas && filtros.hasta) lista.push(`Hasta: ${fechaCorta(filtros.hasta)}`)
  if (r.estados && filtros.estado) {
    lista.push(`Estado: ${r.estados.find((e) => e.valor === filtros.estado)?.texto ?? filtros.estado}`)
  }
  if (r.bodega && filtros.bodegaId) {
    lista.push(`Bodega: ${bodegas.value.find((b) => b.bodegaId === filtros.bodegaId)?.nombre ?? filtros.bodegaId}`)
  }
  return lista.length ? lista.join(' · ') : 'Sin filtros'
}

function tablaHtml(cols: string[], datos: Fila[], pie = '') {
  const enc = cols.map((c) => `<th class="${esMoneda(c) ? 'der' : ''}">${esc(etiqueta(c))}</th>`).join('')
  const cuerpo = datos
    .map((f) => `<tr>${cols
      .map((c) => `<td class="${esMoneda(c) || typeof f[c] === 'number' ? 'der' : ''}">${esc(valor(c, f[c] ?? null))}</td>`)
      .join('')}</tr>`)
    .join('')
  return `<table><thead><tr>${enc}</tr></thead><tbody>${cuerpo}</tbody>${pie}</table>`
}

function imprimirPdf() {
  const r = actual.value
  let contenido = ''
  if (r.numero === 12) {
    if (!traza.value?.resumen) return
    const ficha = Object.entries(traza.value.resumen)
      .map(([k, v]) => `<div><dt>${esc(etiqueta(k))}</dt><dd>${esc(valor(k, v))}</dd></div>`)
      .join('')
    contenido = `<dl class="ficha">${ficha}</dl><h3>Línea de tiempo</h3>`
      + tablaHtml(['fecha', 'etapa', 'detalle', 'usuario', 'monto'], traza.value.lineaTiempo)
  } else {
    if (!filasVista.value.length) return
    const cols = columnas.value
    const g = grafica.value
    const graficaHtml = g
      ? `<h3>${esc(g.titulo)}</h3><div class="barras">${g.barras
        .map((b) => `<div class="b"><span class="n">${esc(b.nombre)}</span><span class="pista"><span style="width:${b.pct}%"></span></span><span class="v">${esc(b.texto)}</span></div>`)
        .join('')}</div>`
      : ''
    const pie = hayTotales.value
      ? `<tfoot><tr>${cols
        .map((c, i) => (c in totales.value
          ? `<td class="der"><b>${esc(valor(c, totales.value[c] ?? 0))}</b></td>`
          : `<td>${i === 0 ? '<b>Total</b>' : ''}</td>`))
        .join('')}</tr></tfoot>`
      : ''
    const enPantalla = enTabla.value.trim() ? ` · filtrados por «${esc(enTabla.value.trim())}»` : ''
    contenido = graficaHtml + `<p class="nota">${filasVista.value.length} registro(s)${enPantalla}</p>` + tablaHtml(cols, filasVista.value, pie)
  }

  const nombre = `Reporte_${String(r.numero).padStart(2, '0')}_${r.titulo.replace(/\s+/g, '_')}`
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8"><title>${esc(nombre)}</title><style>
    @page { size: landscape; margin: 12mm; }
    * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    body { margin: 0; font: 11px/1.4 Arial, Helvetica, sans-serif; color: #222b38; }
    header { border-bottom: 2px solid #c8962e; padding-bottom: 8px; margin-bottom: 12px; }
    .marca { margin: 0; font-size: 10px; color: #5a6472; text-transform: uppercase; letter-spacing: .08em; }
    h1 { margin: 2px 0; font: 700 18px Georgia, 'Times New Roman', serif; color: #17375e; }
    h3 { margin: 14px 0 6px; font-size: 13px; color: #17375e; }
    .sub, .nota { margin: 2px 0; color: #5a6472; }
    .nota { margin-bottom: 6px; }
    table { width: 100%; border-collapse: collapse; }
    thead { display: table-header-group; }
    tr { break-inside: avoid; }
    th { background: #17375e; color: #fff; text-align: left; padding: 5px 6px; }
    td { padding: 4px 6px; border-bottom: 1px solid #d0d7e2; vertical-align: top; }
    tbody tr:nth-child(even) td { background: #f4f6fa; }
    tfoot td { border-top: 2px solid #17375e; }
    .der { text-align: right; }
    .ficha { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px 14px; margin: 0;
      border: 1px solid #d0d7e2; padding: 10px; }
    dt { color: #5a6472; font-size: 10px; }
    dd { margin: 0; font-weight: 700; }
    .barras { margin: 0 0 12px; display: grid; gap: 4px; max-width: 760px; }
    .b { display: grid; grid-template-columns: 180px 1fr 110px; gap: 8px; align-items: center; }
    .b .n { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
    .pista { background: #eef1f6; height: 12px; border-radius: 3px; }
    .pista span { display: block; height: 12px; background: #17375e; border-radius: 3px; }
    .b .v { text-align: right; font-weight: 700; }
  </style></head><body>
    <header>
      <p class="marca">TechCare Solutions · Servicio técnico</p>
      <h1>${r.numero}. ${esc(r.titulo)}</h1>
      <p class="sub">${esc(r.descripcion)}</p>
      <p class="sub">Filtros: ${esc(filtrosAplicados())} · Generado: ${esc(new Date().toLocaleString('es-GT'))}</p>
    </header>
    ${contenido}
  </body></html>`

  // Se imprime desde un marco invisible para que no salgan el menú ni los botones
  document.getElementById('marco-impresion')?.remove()
  const marco = document.createElement('iframe')
  marco.id = 'marco-impresion'
  marco.setAttribute('aria-hidden', 'true')
  marco.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0'
  marco.onload = () => {
    const w = marco.contentWindow
    if (!w) return
    const tituloOriginal = document.title
    document.title = nombre // nombre sugerido del archivo PDF
    w.onafterprint = () => marco.remove()
    w.focus()
    w.print()
    document.title = tituloOriginal
  }
  marco.srcdoc = html
  document.body.appendChild(marco)
}

onMounted(async () => {
  generar()
  try {
    bodegas.value = await reportesApi.bodegas()
  } catch {
    bodegas.value = []
  }
})
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <div>
        <h1>Reportes</h1>
        <p class="sub">Los 12 reportes del proyecto, calculados directamente desde la base de datos.</p>
      </div>
    </header>

    <div class="mesa">
      <!-- Lista de reportes -->
      <nav class="menu" aria-label="Reportes">
        <label class="campo solo-movil">
          <span>Reporte</span>
          <select :value="actual.numero" @change="elegir(Number(($event.target as HTMLSelectElement).value))">
            <option v-for="r in REPORTES" :key="r.numero" :value="r.numero">{{ r.numero }}. {{ r.titulo }}</option>
          </select>
        </label>
        <ul class="solo-escritorio">
          <li v-for="r in REPORTES" :key="r.numero">
            <button :class="{ activo: r.numero === actual.numero }" :aria-current="r.numero === actual.numero" @click="elegir(r.numero)">
              <span class="n">{{ r.numero }}</span>{{ r.titulo }}
            </button>
          </li>
        </ul>
      </nav>

      <section class="contenido">
        <div class="titulo-rep">
          <h2>{{ actual.numero }}. {{ actual.titulo }}</h2>
          <p class="sub">{{ actual.descripcion }}</p>
        </div>

        <form class="filtros" novalidate @submit.prevent="generar">
          <label v-if="actual.buscar" class="campo grande">
            <span>{{ actual.obligatorio ? 'Número de orden' : 'Buscar' }}</span>
            <input
v-model="filtros.buscar" type="search" :placeholder="actual.buscar"
                   :list="actual.numero === 12 ? 'lista-ordenes' : undefined" />
            <datalist v-if="actual.numero === 12" id="lista-ordenes">
              <option v-for="o in ordenesLista" :key="o.ordenId" :value="o.numeroOrden">{{ o.cliente }} · {{ o.estado }}</option>
            </datalist>
          </label>
          <template v-if="actual.fechas">
            <label class="campo"><span>Desde</span><input v-model="filtros.desde" type="date" /></label>
            <label class="campo"><span>Hasta</span><input v-model="filtros.hasta" type="date" /></label>
            <div class="rapidos" role="group" aria-label="Fechas rápidas">
              <button type="button" class="chip-btn" @click="rango('mes')">Este mes</button>
              <button type="button" class="chip-btn" @click="rango('mesAnterior')">Mes anterior</button>
              <button type="button" class="chip-btn" @click="rango('dias30')">Últimos 30 días</button>
              <button type="button" class="chip-btn" @click="rango('anio')">Este año</button>
            </div>
          </template>
          <label v-if="actual.estados" class="campo">
            <span>Estado</span>
            <select v-model="filtros.estado">
              <option value="">Todos</option>
              <option v-for="e in actual.estados" :key="e.valor" :value="e.valor">{{ e.texto }}</option>
            </select>
          </label>
          <label v-if="actual.bodega && bodegas.length" class="campo">
            <span>Bodega</span>
            <select v-model.number="filtros.bodegaId">
              <option :value="0">Todas</option>
              <option v-for="b in bodegas" :key="b.bodegaId" :value="b.bodegaId">{{ b.nombre }}</option>
            </select>
          </label>
          <div class="acciones">
            <button type="submit" class="btn primario" :disabled="cargando">{{ cargando ? 'Generando…' : 'Generar' }}</button>
            <button type="button" class="btn" @click="limpiar">Limpiar</button>
            <button type="button" class="btn" :disabled="!(filas.length || traza?.lineaTiempo.length)" @click="descargarCsv">
              Descargar CSV
            </button>
            <button type="button" class="btn" :disabled="!(filas.length || traza?.resumen)" @click="imprimirPdf">
              Imprimir / PDF
            </button>
          </div>
        </form>

        <p v-if="error" class="error" role="alert">{{ error }}</p>

        <!-- Reporte 12: resumen + línea de tiempo -->
        <template v-if="actual.numero === 12">
          <template v-if="!traza?.resumen">
            <p v-if="!generado && !error" class="nota">Escriba o elija el número de orden y presione «Generar», o toque una orden reciente:</p>
            <div v-if="recientes.length" class="recientes">
              <button v-for="o in recientes" :key="o.ordenId" type="button" class="reciente" @click="verOrden(o.numeroOrden)">
                <b>{{ o.numeroOrden }}</b><span>{{ o.cliente }}</span><small>{{ o.estado }}</small>
              </button>
            </div>
            <p v-else-if="!generado && !error" class="vacio">Escriba un número de orden y presione «Generar».</p>
          </template>
          <template v-if="traza?.resumen">
            <div class="correo">
              <span>Comprobante de entrega <InfoTip texto="PDF con la factura, los pagos y quién recibió el equipo. Solo existe cuando la orden ya fue ENTREGADA en Caja." /></span>
              <button type="button" class="btn" :disabled="!entregada || !!accionCorreo" @click="comprobante('pdf')">
                {{ accionCorreo === 'pdf' ? 'Descargando…' : 'Descargar PDF' }}
              </button>
              <InfoTip texto="Descarga el comprobante de entrega en PDF a esta computadora." />
              <button type="button" class="btn primario" :disabled="!entregada || !!accionCorreo" @click="comprobante('correo')">
                {{ accionCorreo === 'correo' ? 'Enviando…' : 'Enviar al correo del cliente' }}
              </button>
              <InfoTip texto="Envía el comprobante en PDF al correo registrado del cliente, desde techcare126@gmail.com." derecha />
            </div>
            <p v-if="!entregada" class="nota">Los botones se habilitan cuando la orden se entrega (estado actual: <b>{{ traza.resumen.estadoActual ?? '—' }}</b>).</p>
            <p v-if="avisoCorreo" class="aviso" role="status">{{ avisoCorreo }}</p>
            <p v-if="errorCorreo" class="error" role="alert">{{ errorCorreo }}</p>
            <dl class="ficha">
              <div v-for="(v, k) in traza.resumen" :key="k">
                <dt>{{ etiqueta(String(k)) }}</dt><dd>{{ valor(String(k), v) }}</dd>
              </div>
            </dl>
            <h3>Línea de tiempo</h3>
            <div class="tabla-wrap">
              <table>
                <thead><tr><th>Fecha</th><th>Etapa</th><th>Detalle</th><th>Usuario</th><th class="der">Monto</th></tr></thead>
                <tbody>
                  <tr v-for="(t, i) in traza.lineaTiempo" :key="i">
                    <td class="nowrap">{{ valor('fecha', t.fecha ?? null) }}</td>
                    <td><span class="chip" :class="String(t.etapa).toLowerCase()">{{ t.etapa }}</span></td>
                    <td>{{ t.detalle }}</td>
                    <td>{{ t.usuario }}</td>
                    <td class="der">{{ valor('monto', t.monto ?? null) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </template>
        </template>

        <!-- Reportes 1 al 11 -->
        <template v-else>
          <!-- Tarjetas de resumen -->
          <div v-if="filas.length && !cargando" class="tarjetas">
            <div v-for="t in tarjetas" :key="t.titulo" class="tarjeta">
              <span>{{ t.titulo }}</span><b>{{ t.texto }}</b>
            </div>
          </div>

          <!-- Gráfica de barras -->
          <figure v-if="grafica && !cargando" class="grafica">
            <figcaption>{{ grafica.titulo }}</figcaption>
            <div v-for="b in grafica.barras" :key="b.nombre" class="barra">
              <span class="nombre" :title="b.nombre">{{ b.nombre }}</span>
              <span class="pista"><span class="relleno" :style="{ width: b.pct + '%' }"></span></span>
              <span class="cifra">{{ b.texto }}</span>
            </div>
          </figure>

          <div class="sobre-tabla">
            <p class="nota">
              {{ cargando ? 'Generando…' : enTabla.trim() ? `${filasVista.length} de ${filas.length} registro(s)` : `${filas.length} registro(s)` }}
              <span v-if="filas.length > 1"> · toque un encabezado para ordenar</span>
            </p>
            <label v-if="filas.length" class="campo buscar-tabla">
              <span class="sr-only">Buscar en el resultado</span>
              <input v-model="enTabla" type="search" placeholder="Buscar en el resultado…" />
            </label>
          </div>
          <div class="tabla-wrap">
            <table>
              <thead>
                <tr>
                  <th
v-for="c in columnas" :key="c" :class="{ der: esMoneda(c) }"
                      :aria-sort="orden?.col === c ? (orden.asc ? 'ascending' : 'descending') : 'none'">
                    <button type="button" class="orden-btn" @click="ordenarPor(c)">
                      {{ etiqueta(c) }} <span class="flecha" aria-hidden="true">{{ flecha(c) }}</span>
                    </button>
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr v-if="!cargando && !filasVista.length">
                  <td class="vacio" :colspan="columnas.length || 1">{{ filas.length ? 'Nada coincide con la búsqueda.' : 'Sin datos con esos filtros.' }}</td>
                </tr>
                <tr v-for="(f, i) in filasVista" :key="i">
                  <td v-for="c in columnas" :key="c" :class="{ der: esMoneda(c) || typeof f[c] === 'number', nowrap: c.startsWith('fecha') || c.startsWith('numero') }">
                    {{ valor(c, f[c] ?? null) }}
                  </td>
                </tr>
              </tbody>
              <tfoot v-if="hayTotales">
                <tr>
                  <td v-for="(c, i) in columnas" :key="c" :class="{ der: c in totales }">
                    <b v-if="c in totales">{{ valor(c, totales[c] ?? 0) }}</b>
                    <b v-else-if="i === 0">Total</b>
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>
        </template>
      </section>
    </div>
  </main>
</template>

<style scoped>
.pagina {
  --c-title: #17375e; --c-text: #222b38; --c-muted: #5a6472; --c-surface: #fff;
  --c-row: #f4f6fa; --c-border: #d0d7e2; --c-input: #b9c2d0; --c-sel: #e8eef8;
}
:root.dark .pagina {
  --c-title: #c7d2fe; --c-text: #e2e8f0; --c-muted: #a3b2c9; --c-surface: rgb(18 27 46);
  --c-row: rgb(24 36 60); --c-border: rgb(43 56 78); --c-input: rgb(71 85 105); --c-sel: rgb(30 48 82);
}
.pagina { max-width: 1400px; margin: 0 auto; padding: 32px 24px 64px; text-align: left; color: var(--c-text); }
.cabecera { border-bottom: 3px solid #c8962e; padding-bottom: 16px; margin-bottom: 24px; }
h1 { margin: 0; font: 700 28px/1.2 Georgia, 'Times New Roman', serif; color: var(--c-title); }
h2 { margin: 0; font: 700 21px/1.2 Georgia, serif; color: var(--c-title); }
h3 { margin: 8px 0 0; font-size: 16px; color: var(--c-title); }
.sub { margin: 4px 0 0; color: var(--c-muted); font-size: 15px; }

.mesa { display: grid; grid-template-columns: 250px 1fr; gap: 24px; align-items: start; }
.menu ul { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 2px;
  position: sticky; top: 16px; }
.menu button { width: 100%; text-align: left; font: inherit; font-size: 14px; color: var(--c-text); background: none;
  border: none; border-left: 3px solid transparent; padding: 8px 10px; border-radius: 0 4px 4px 0; cursor: pointer;
  display: flex; gap: 10px; align-items: baseline; }
.menu button:hover { background: var(--c-row); }
.menu button.activo { background: var(--c-sel); border-left-color: #c8962e; color: var(--c-title); font-weight: 700; }
.menu .n { font-variant-numeric: tabular-nums; color: var(--c-muted); min-width: 18px; text-align: right; font-weight: 600; }
.campo.solo-movil { display: none; }

.contenido { display: flex; flex-direction: column; gap: 14px; min-width: 0; }
.filtros { display: flex; gap: 12px; flex-wrap: wrap; align-items: flex-end; }
.campo { display: flex; flex-direction: column; gap: 4px; font-size: 14px; min-width: 150px; }
.campo span { font-weight: 600; color: var(--c-title); }
.campo.grande { flex: 1; min-width: 220px; }
input, select { font: inherit; font-size: 15px; padding: 8px 10px; border: 1px solid var(--c-input); border-radius: 4px;
  background: var(--c-surface); color: var(--c-text); box-sizing: border-box; width: 100%; }
input:focus-visible, select:focus-visible, .btn:focus-visible, .menu button:focus-visible { outline: 3px solid #c8962e; outline-offset: 1px; }
.acciones { display: flex; gap: 8px; flex-wrap: wrap; }

.tabla-wrap { overflow-x: auto; border: 1px solid var(--c-border); border-radius: 4px; max-height: 65vh; }
table { width: 100%; border-collapse: collapse; font-size: 13.5px; }
th { background: #17375e; color: #fff; text-align: left; padding: 8px 10px; font-weight: 600; white-space: nowrap;
  position: sticky; top: 0; z-index: 1; }
td { padding: 7px 10px; border-top: 1px solid var(--c-border); vertical-align: top; }
tbody tr:nth-child(even) { background: var(--c-row); }
tfoot td { border-top: 2px solid var(--c-title); background: var(--c-surface); position: sticky; bottom: 0; }
.der { text-align: right; }
.nowrap { white-space: nowrap; }
.vacio { text-align: center; color: var(--c-muted); padding: 28px 12px; margin: 0; }
.nota { margin: 0; color: var(--c-muted); font-size: 14px; }

.ficha { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 10px 18px; margin: 0;
  border: 1px solid var(--c-border); border-radius: 6px; padding: 16px; background: var(--c-surface); }
.ficha div { min-width: 0; }
dt { font-size: 12.5px; color: var(--c-muted); }
dd { margin: 0; font-weight: 600; overflow-wrap: anywhere; }

.chip { padding: 2px 8px; border-radius: 999px; font-size: 11.5px; font-weight: 700; white-space: nowrap; background: #e7ecf3; color: #17375e; }
.chip.diagnostico { background: #e6f0fb; color: #1d4f8a; }
.chip.reparacion, .chip.actividad { background: #ece6fb; color: #4b2a8a; }
.chip.repuesto { background: #fff2d6; color: #7a4c00; }
.chip.factura, .chip.pago { background: #dff3e4; color: #1d6b34; }
.chip.entrega { background: #17375e; color: #fff; }

/* Fechas rápidas */
.rapidos { display: flex; gap: 6px; flex-wrap: wrap; flex-basis: 100%; }
.chip-btn { font: inherit; font-size: 13px; padding: 5px 12px; border-radius: 999px; border: 1px solid var(--c-input);
  background: var(--c-surface); color: var(--c-title); cursor: pointer; }
.chip-btn:hover { background: var(--c-sel); }
.chip-btn:focus-visible { outline: 3px solid #c8962e; outline-offset: 1px; }

/* Tarjetas de resumen */
.tarjetas { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 10px; }
.tarjeta { border: 1px solid var(--c-border); border-left: 4px solid #c8962e; border-radius: 6px; padding: 10px 14px;
  background: var(--c-surface); display: flex; flex-direction: column; gap: 2px; }
.tarjeta span { font-size: 12.5px; color: var(--c-muted); }
.tarjeta b { font-size: 20px; color: var(--c-title); font-variant-numeric: tabular-nums; }

/* Gráfica de barras */
.grafica { margin: 0; border: 1px solid var(--c-border); border-radius: 6px; padding: 14px 16px; background: var(--c-surface);
  display: grid; gap: 6px; }
.grafica figcaption { font-weight: 700; color: var(--c-title); margin-bottom: 4px; }
.barra { display: grid; grid-template-columns: minmax(110px, 220px) 1fr minmax(80px, auto); gap: 10px; align-items: center; font-size: 13.5px; }
.barra .nombre { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.pista { background: var(--c-row); border-radius: 4px; height: 14px; overflow: hidden; }
.relleno { display: block; height: 100%; background: linear-gradient(90deg, #17375e, #2f5c94); border-radius: 4px; }
:root.dark .relleno { background: linear-gradient(90deg, #6d8fd1, #a5b8f0); }
.barra .cifra { text-align: right; font-weight: 700; font-variant-numeric: tabular-nums; }

/* Buscar en el resultado y ordenar */
.sobre-tabla { display: flex; justify-content: space-between; align-items: center; gap: 12px; flex-wrap: wrap; }
.buscar-tabla { min-width: 240px; }
.orden-btn { all: unset; cursor: pointer; display: inline-flex; gap: 6px; align-items: center; }
.orden-btn:focus-visible { outline: 2px solid #c8962e; outline-offset: 2px; }
.flecha { font-size: 10px; opacity: 0.75; }
.sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; }

/* Reporte 12 */
.recientes { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 8px; }
.reciente { font: inherit; text-align: left; border: 1px solid var(--c-border); border-radius: 6px; padding: 10px 12px;
  background: var(--c-surface); color: var(--c-text); cursor: pointer; display: flex; flex-direction: column; gap: 2px; }
.reciente:hover { border-color: #c8962e; background: var(--c-sel); }
.reciente b { color: var(--c-title); }
.reciente small { color: var(--c-muted); }
.correo { display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
.correo span { font-weight: 600; color: var(--c-title); }
.aviso { background: #dff3e4; color: #1d6b34; padding: 10px 14px; border-radius: 4px; margin: 0; }

.btn { font: inherit; font-size: 15px; padding: 8px 14px; border-radius: 4px; border: 1px solid var(--c-input);
  background: var(--c-surface); color: var(--c-title); cursor: pointer; }
.btn.primario { background: #17375e; border-color: var(--c-title); color: #fff; font-weight: 600; }
.btn.primario:hover:not(:disabled) { background: #0f2a4a; }
.btn:disabled { opacity: 0.55; cursor: not-allowed; }
.error { background: #fbe4e4; color: #8a1f1f; padding: 10px 14px; border-radius: 4px; margin: 0; }

@media (max-width: 900px) {
  .mesa { grid-template-columns: 1fr; }
  .campo.solo-movil { display: flex; }
  .solo-escritorio { display: none !important; }
}
@media (max-width: 600px) {
  .pagina { padding: 24px 16px 48px; }
  .campo { min-width: 0; flex: 1 1 100%; }
}
</style>
