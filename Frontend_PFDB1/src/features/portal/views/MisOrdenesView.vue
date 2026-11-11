<script setup lang="ts">
// Portal del cliente: sus órdenes en solo lectura (estado, equipo, factura y saldo).
import { computed, onMounted, ref } from 'vue'
import { useAuthStore } from '@/features/auth/stores/auth.store'
import { portalApi, type MiOrden } from '../api/portal'
const auth = useAuthStore()
const ordenes = ref<MiOrden[]>([])
const cargando = ref(true)
const error = ref('')

const moneda = (n: number | null | undefined) =>
  (n ?? 0).toLocaleString('es-GT', { style: 'currency', currency: 'GTQ' })
const fecha = (iso: string | null) =>
  iso ? new Date(iso).toLocaleDateString('es-GT', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—'
// Agrega punto final al motivo si no lo trae
const conPunto = (t: string) => (/[.!?]$/.test(t.trim()) ? t.trim() : t.trim() + '.')
const fechaHora = (iso: string | null) =>
  iso ? new Date(iso).toLocaleString('es-GT', { dateStyle: 'short', timeStyle: 'short' }) : '—'

// Pasos del proceso, en el orden del flujo de TechCare
const PASOS = [
  { codigo: 'RECIBIDO', texto: 'Recibido' },
  { codigo: 'DIAGNOSTICO', texto: 'Diagnóstico' },
  { codigo: 'ESPERANDO_AUTORIZACION', texto: 'Esperando su autorización' },
  { codigo: 'REPARACION', texto: 'En reparación' },
  { codigo: 'LISTO', texto: 'Listo para entregar' },
  { codigo: 'ENTREGADO', texto: 'Entregado' },
]
const paso = (estado: string) => PASOS.findIndex((p) => p.codigo === estado)
const textoEstado = (estado: string) =>
  estado === 'CANCELADO' ? 'Cancelado' : (PASOS.find((p) => p.codigo === estado)?.texto ?? estado)

const activas = computed(() => ordenes.value.filter((o) => !['ENTREGADO', 'CANCELADO'].includes(o.estado)).length)
const saldoTotal = computed(() => ordenes.value.reduce((s, o) => s + (o.saldo ?? 0), 0))

// Filtro: en proceso / historial (entregadas y canceladas) / todas
const filtro = ref<'activas' | 'historial' | 'todas'>('todas')
const cerrada = (o: MiOrden) => o.estado === 'ENTREGADO' || o.estado === 'CANCELADO'
const visibles = computed(() =>
  ordenes.value.filter((o) => filtro.value === 'todas' || (filtro.value === 'activas' ? !cerrada(o) : cerrada(o))),
)

// Comprobante en PDF (orden entregada): descargar o enviar a su correo
const ocupado = ref(0)
const avisos = ref<Record<number, { texto: string; error: boolean }>>({})
async function descargar(o: MiOrden) {
  ocupado.value = o.ordenId
  avisos.value[o.ordenId] = { texto: '', error: false }
  try {
    await portalApi.descargarComprobante(o.ordenId, o.numeroOrden)
  } catch (e) {
    avisos.value[o.ordenId] = { texto: (e as Error).message, error: true }
  } finally {
    ocupado.value = 0
  }
}
async function enviar(o: MiOrden) {
  ocupado.value = o.ordenId
  try {
    const r = await portalApi.enviarComprobante(o.ordenId)
    avisos.value[o.ordenId] = { texto: r.mensaje, error: false }
  } catch (e) {
    avisos.value[o.ordenId] = { texto: (e as Error).message, error: true }
  } finally {
    ocupado.value = 0
  }
}

onMounted(async () => {
  try {
    ordenes.value = await portalApi.misOrdenes()
  } catch (e) {
    error.value = (e as Error).message
  } finally {
    cargando.value = false
  }
})
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <h1>Mis órdenes</h1>
      <p class="sub">Hola, {{ auth.nombreCompleto }}. Aquí puede ver el estado de los equipos que entregó a TechCare.</p>
    </header>

    <section class="resumen" aria-label="Resumen">
      <div><span>Órdenes</span><b>{{ ordenes.length }}</b></div>
      <div><span>En proceso</span><b>{{ activas }}</b></div>
      <div :class="{ alerta: saldoTotal > 0 }"><span>Saldo pendiente</span><b>{{ moneda(saldoTotal) }}</b></div>
    </section>

    <p v-if="cargando" class="nota">Cargando…</p>
    <p v-else-if="error" class="error" role="alert">{{ error }}</p>
    <p v-else-if="!ordenes.length" class="nota">Todavía no tiene órdenes registradas.</p>

    <div v-if="ordenes.length" class="filtro" role="group" aria-label="Filtrar órdenes">
      <button type="button" :class="{ activo: filtro === 'todas' }" @click="filtro = 'todas'">Todas</button>
      <button type="button" :class="{ activo: filtro === 'activas' }" @click="filtro = 'activas'">En proceso</button>
      <button type="button" :class="{ activo: filtro === 'historial' }" @click="filtro = 'historial'">Historial</button>
    </div>
    <p v-if="ordenes.length && !visibles.length" class="nota">No hay órdenes en esta vista.</p>

    <article v-for="o in visibles" :key="o.ordenId" class="orden">
      <div class="orden-cab">
        <h2>{{ o.numeroOrden }}</h2>
        <span class="chip" :class="o.estado.toLowerCase()">{{ textoEstado(o.estado) }}</span>
      </div>
      <p class="equipo">{{ o.tipoEquipo }} · {{ o.equipo }} · Serie {{ o.numeroSerie }}</p>

      <ol v-if="o.estado !== 'CANCELADO'" class="pasos" aria-label="Avance de la orden">
        <li v-for="(p, i) in PASOS" :key="p.codigo"
          :class="{ hecho: i < paso(o.estado) || o.estado === 'ENTREGADO', actual: i === paso(o.estado) && o.estado !== 'ENTREGADO' }">
          {{ p.texto }}
        </li>
      </ol>

      <!-- Avisos según el estado -->
      <div v-if="o.estado === 'CANCELADO'" class="aviso cancelado">
        <b>Orden cancelada el {{ fecha(o.ultimoCambio) }}.</b>
        <span v-if="o.motivoCancelacion"> Motivo: {{ conPunto(o.motivoCancelacion) }}</span>
        <span> Puede pasar a recoger su equipo a TechCare.</span>
      </div>
      <div v-else-if="o.estado === 'ESPERANDO_AUTORIZACION'" class="aviso espera">
        <b>Su equipo espera su autorización.</b>
        Costo estimado de mano de obra: <b>{{ moneda(o.costoEstimado) }}</b> (más repuestos, si se necesitan).
        Comuníquese con TechCare para autorizar la reparación.
      </div>
      <div v-else-if="o.estado === 'LISTO'" class="aviso listo">
        <b>¡Su equipo está listo!</b> Puede pasar a recogerlo<template v-if="(o.saldo ?? 0) > 0"> y cancelar el saldo de {{ moneda(o.saldo) }}</template>.
      </div>
      <div v-else-if="o.estado === 'ENTREGADO'" class="aviso listo">
        <b>Entregado el {{ fechaHora(o.fechaEntrega) }}</b><template v-if="o.nombreRecibe"> a {{ o.nombreRecibe }}</template>.
      </div>

      <dl class="datos">
        <div><dt>Ingreso</dt><dd>{{ fecha(o.fechaIngreso) }}</dd></div>
        <div><dt>Fecha estimada</dt><dd>{{ fecha(o.fechaEstimada) }}</dd></div>
        <div><dt>Última actualización</dt><dd>{{ fechaHora(o.ultimoCambio) }}</dd></div>
        <div class="ancho"><dt>Problema reportado</dt><dd>{{ o.problemaReportado }}</dd></div>
        <div v-if="o.diagnostico && o.estado !== 'CANCELADO'" class="ancho"><dt>Diagnóstico del técnico</dt><dd>{{ o.diagnostico }}</dd></div>
        <template v-if="o.estado !== 'CANCELADO' || o.numeroFactura">
          <div><dt>Factura</dt><dd>{{ o.numeroFactura ?? 'Aún no facturada' }}</dd></div>
          <div v-if="o.numeroFactura"><dt>Total</dt><dd>{{ moneda(o.total) }}</dd></div>
          <div v-if="o.numeroFactura"><dt>Pagado</dt><dd>{{ moneda(o.pagado) }}</dd></div>
          <div v-if="o.numeroFactura"><dt>Saldo</dt><dd :class="{ debe: (o.saldo ?? 0) > 0 }">{{ moneda(o.saldo) }}</dd></div>
        </template>
      </dl>

      <div v-if="o.estado === 'ENTREGADO' && o.numeroFactura" class="acciones">
        <button type="button" class="btn primario" :disabled="ocupado === o.ordenId" @click="descargar(o)">Descargar comprobante (PDF)</button>
        <button type="button" class="btn" :disabled="ocupado === o.ordenId" @click="enviar(o)">Enviar a mi correo</button>
        <span v-if="avisos[o.ordenId]?.texto" :class="avisos[o.ordenId]!.error ? 'error' : 'ok'" role="status">{{ avisos[o.ordenId]!.texto }}</span>
      </div>
    </article>
  </main>
</template>

<style scoped>
.pagina {
  --c-title: #17375e; --c-text: #222b38; --c-muted: #5a6472; --c-surface: #fff; --c-border: #d0d7e2; --c-row: #f4f6fa;
}
:root.dark .pagina {
  --c-title: #c7d2fe; --c-text: #e2e8f0; --c-muted: #a3b2c9; --c-surface: rgb(18 27 46); --c-border: rgb(43 56 78); --c-row: rgb(24 36 60);
}
.pagina { max-width: 960px; margin: 0 auto; padding: 32px 24px 64px; text-align: left; color: var(--c-text); }
.cabecera { border-bottom: 2px solid #c8962e; padding-bottom: 12px; margin-bottom: 18px; }
h1 { margin: 0; font: 700 28px/1.2 Georgia, 'Times New Roman', serif; color: var(--c-title); }
h2 { margin: 0; font: 700 20px/1.2 Georgia, serif; color: var(--c-title); }
.sub, .nota { margin: 4px 0 0; color: var(--c-muted); font-size: 15px; }
.error { color: #d9534f; }
.resumen { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-bottom: 18px; }
.resumen div { border: 1px solid var(--c-border); border-radius: 6px; padding: 12px 14px; background: var(--c-surface);
  display: flex; flex-direction: column; gap: 4px; }
.resumen span { font-size: 13px; color: var(--c-muted); }
.resumen b { font-size: 20px; color: var(--c-title); }
.resumen .alerta { border-left: 4px solid #c8962e; }
.orden { border: 1px solid var(--c-border); border-radius: 8px; padding: 18px 20px; margin-bottom: 14px; background: var(--c-surface); }
.orden-cab { display: flex; justify-content: space-between; align-items: center; gap: 10px; }
.equipo { margin: 6px 0 12px; color: var(--c-muted); }
.chip { padding: 3px 10px; border-radius: 999px; font-size: 13px; font-weight: 600; background: #e6f0fb; color: #1d4f8a; }
.chip.listo, .chip.entregado { background: #dff3e6; color: #1e6b3a; }
.chip.esperando_autorizacion { background: #fff2d6; color: #7a4c00; }
.chip.cancelado { background: #fde2e2; color: #8a1f1f; }
.pasos { list-style: none; display: grid; grid-template-columns: repeat(6, 1fr); gap: 4px; padding: 0; margin: 0 0 14px; }
.pasos li { font-size: 12px; text-align: center; padding: 8px 4px 0; border-top: 4px solid var(--c-border); color: var(--c-muted); }
.pasos li.hecho { border-top-color: #2e8b57; color: var(--c-text); }
.pasos li.actual { border-top-color: #c8962e; color: var(--c-title); font-weight: 700; }
.datos { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px 16px; margin: 0; }
.datos .ancho { grid-column: 1 / -1; }
dt { font-size: 12px; color: var(--c-muted); }
dd { margin: 2px 0 0; font-weight: 600; }
dd.debe { color: #c0392b; }
.filtro { display: flex; gap: 6px; margin-bottom: 12px; }
.filtro button { border: 1px solid var(--c-border); background: var(--c-surface); color: var(--c-text);
  padding: 6px 14px; border-radius: 999px; font-size: 14px; cursor: pointer; }
.filtro button.activo { background: #17375e; border-color: #17375e; color: #fff; }
.aviso { border-radius: 6px; padding: 10px 12px; margin: 0 0 12px; font-size: 14px; border-left: 4px solid; }
.aviso.cancelado { background: rgb(222 76 76 / 0.12); border-color: #c0392b; }
.aviso.espera { background: rgb(200 150 46 / 0.15); border-color: #c8962e; }
.aviso.listo { background: rgb(46 139 87 / 0.14); border-color: #2e8b57; }
.acciones { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; margin-top: 14px; }
.btn { border: 1px solid var(--c-border); background: var(--c-surface); color: var(--c-text);
  padding: 8px 14px; border-radius: 4px; font-size: 14px; font-weight: 600; cursor: pointer; }
.btn.primario { background: #17375e; border-color: #17375e; color: #fff; }
.btn:disabled { opacity: 0.6; cursor: default; }
.ok { color: #2e8b57; font-size: 14px; }
@media (max-width: 700px) {
  .resumen, .datos { grid-template-columns: 1fr 1fr; }
  .pasos { grid-template-columns: repeat(3, 1fr); }
}
</style>
