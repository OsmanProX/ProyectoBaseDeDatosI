<script setup lang="ts">
// Semana 4 — Los 12 reportes del proyecto (solo ADMINISTRADOR).
// Cada reporte sale de una vista, función o procedimiento de la base (scripts 04 y 07).
import { computed, onMounted, reactive, ref } from 'vue'
import {
  reportesApi, REPORTES, etiqueta, valor, esMoneda,
  type Fila, type Trazabilidad,
} from '../api/reportes'

const actual = ref(REPORTES[0]!)
const filtros = reactive({ desde: '', hasta: '', buscar: '', bodegaId: 0, estado: '' })
const bodegas = ref<{ bodegaId: number; nombre: string }[]>([])

const filas = ref<Fila[]>([])
const traza = ref<Trazabilidad | null>(null)
const cargando = ref(false)
const error = ref('')
const generado = ref(false)

const columnas = computed(() => (filas.value[0] ? Object.keys(filas.value[0]) : []))

// Totales de las columnas de dinero (útil en ingresos, repuestos, compras y saldos)
const totales = computed(() => {
  const t: Record<string, number> = {}
  for (const c of columnas.value) {
    if (!esMoneda(c) || ['precioVenta', 'precioCompraReferencia', 'precioVentaActual', 'costoActual', 'costoHistorico', 'ventaHistorica'].includes(c)) continue
    t[c] = filas.value.reduce((s, f) => s + (typeof f[c] === 'number' ? (f[c] as number) : 0), 0)
  }
  return t
})
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
  if (!actual.value.obligatorio) generar()
  else { traza.value = null; generado.value = false }
}

// Descargar lo que se ve en pantalla como CSV (abre en Excel)
function descargarCsv() {
  const r = actual.value
  const datos: Fila[] = r.numero === 12 ? (traza.value?.lineaTiempo ?? []) : filas.value
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
            <input v-model="filtros.buscar" type="search" :placeholder="actual.buscar" />
          </label>
          <template v-if="actual.fechas">
            <label class="campo"><span>Desde</span><input v-model="filtros.desde" type="date" /></label>
            <label class="campo"><span>Hasta</span><input v-model="filtros.hasta" type="date" /></label>
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
          </div>
        </form>

        <p v-if="error" class="error" role="alert">{{ error }}</p>

        <!-- Reporte 12: resumen + línea de tiempo -->
        <template v-if="actual.numero === 12">
          <p v-if="!generado && !error" class="vacio">Escriba un número de orden y presione «Generar».</p>
          <template v-if="traza?.resumen">
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
          <p class="nota">{{ cargando ? 'Generando…' : `${filas.length} registro(s)` }}</p>
          <div class="tabla-wrap">
            <table>
              <thead>
                <tr><th v-for="c in columnas" :key="c" :class="{ der: esMoneda(c) }">{{ etiqueta(c) }}</th></tr>
              </thead>
              <tbody>
                <tr v-if="!cargando && !filas.length"><td class="vacio" :colspan="columnas.length || 1">Sin datos con esos filtros.</td></tr>
                <tr v-for="(f, i) in filas" :key="i">
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
