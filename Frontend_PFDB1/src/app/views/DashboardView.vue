<script setup lang="ts">
// Semana 4 — Pantalla de inicio: números del taller (vw_Dashboard) y actividad reciente (vw_ActividadReciente).
// Los datos se calculan en la base; cualquier usuario con sesión los puede ver.
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { useAuthStore } from '@/features/auth/stores/auth.store'
import { reportesApi, type Fila } from '@/features/reportes/api/reportes'

const auth = useAuthStore()
const resumen = ref<Fila | null>(null)
const actividad = ref<Fila[]>([])
const cargando = ref(true)
const error = ref('')

const n = (k: string) => Number(resumen.value?.[k] ?? 0)
const moneda = (v: number) => v.toLocaleString('es-GT', { style: 'currency', currency: 'GTQ' })
const fechaHora = (iso: unknown) =>
  typeof iso === 'string' ? new Date(iso).toLocaleString('es-GT', { dateStyle: 'short', timeStyle: 'short' }) : ''

const saludo = computed(() => {
  const h = new Date().getHours()
  return h < 12 ? 'Buenos días' : h < 18 ? 'Buenas tardes' : 'Buenas noches'
})

// Accesos según el rol (mismos roles que el menú)
const accesos = computed(() => {
  const r = auth.rol
  const lista = [
    { a: '/ordenes', t: 'Órdenes', d: 'Recibir equipos y ver su estado', roles: ['ADMINISTRADOR', 'RECEPCION', 'TECNICO', 'BODEGA', 'CAJA'] },
    { a: '/taller', t: 'Taller', d: 'Diagnóstico y reparación', roles: ['ADMINISTRADOR', 'TECNICO'] },
    { a: '/inventario', t: 'Inventario', d: 'Existencias y compras', roles: ['ADMINISTRADOR', 'BODEGA'] },
    { a: '/caja', t: 'Caja y entrega', d: 'Facturar, cobrar y entregar', roles: ['ADMINISTRADOR', 'CAJA', 'RECEPCION'] },
    { a: '/reportes', t: 'Reportes', d: 'Los 12 reportes del sistema', roles: ['ADMINISTRADOR'] },
    { a: '/mantenimientos', t: 'Mantenimientos', d: 'Repuestos, proveedores, bodegas y catálogos', roles: ['ADMINISTRADOR', 'BODEGA'] },
    { a: '/usuarios', t: 'Usuarios', d: 'Empleados, roles y contraseñas', roles: ['ADMINISTRADOR'] },
  ]
  return lista.filter((x) => x.roles.includes(r))
})

onMounted(async () => {
  try {
    const d = await reportesApi.dashboard()
    resumen.value = d.resumen
    actividad.value = d.actividad
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
      <h1>{{ saludo }}, {{ auth.nombreCompleto || 'bienvenido' }}</h1>
      <p class="sub">TechCare Solutions · resumen del taller en este momento.</p>
    </header>

    <p v-if="error" class="error" role="alert">{{ error }}</p>

    <section class="kpis" aria-label="Resumen" :aria-busy="cargando">
      <article class="kpi principal">
        <span>Órdenes abiertas</span><b>{{ cargando ? '…' : n('ordenesAbiertas') }}</b>
      </article>
      <article class="kpi"><span>Recibidas</span><b>{{ cargando ? '…' : n('recibidas') }}</b></article>
      <article class="kpi"><span>En diagnóstico</span><b>{{ cargando ? '…' : n('enDiagnostico') }}</b></article>
      <article class="kpi"><span>Esperando autorización</span><b>{{ cargando ? '…' : n('esperandoAutorizacion') }}</b></article>
      <article class="kpi"><span>En reparación</span><b>{{ cargando ? '…' : n('enReparacion') }}</b></article>
      <article class="kpi listo"><span>Listas para entregar</span><b>{{ cargando ? '…' : n('listasParaEntregar') }}</b></article>
      <article class="kpi" :class="{ alerta: n('facturasConSaldo') > 0 }">
        <span>Facturas con saldo</span><b>{{ cargando ? '…' : n('facturasConSaldo') }}</b>
      </article>
      <article class="kpi" :class="{ alerta: n('saldoPorCobrar') > 0 }">
        <span>Saldo por cobrar</span><b>{{ cargando ? '…' : moneda(n('saldoPorCobrar')) }}</b>
      </article>
      <article class="kpi" :class="{ alerta: n('repuestosBajoMinimo') > 0 }">
        <span>Repuestos bajo mínimo</span><b>{{ cargando ? '…' : n('repuestosBajoMinimo') }}</b>
      </article>
    </section>

    <div class="dos">
      <section class="caja">
        <h2>Actividad reciente</h2>
        <p v-if="!cargando && !actividad.length" class="vacio">Todavía no hay movimientos.</p>
        <ol class="actividad">
          <li v-for="(a, i) in actividad" :key="i">
            <span class="chip" :class="String(a.tipo).toLowerCase()">{{ a.tipo }}</span>
            <div>
              <p>{{ a.detalle }}</p>
              <small>{{ fechaHora(a.fecha) }} · {{ a.usuario }}</small>
            </div>
          </li>
        </ol>
      </section>

      <section class="caja">
        <h2>Accesos</h2>
        <ul class="accesos">
          <li v-for="x in accesos" :key="x.a">
            <RouterLink :to="x.a"><b>{{ x.t }}</b><span>{{ x.d }}</span></RouterLink>
          </li>
        </ul>
      </section>
    </div>
  </main>
</template>

<style scoped>
.pagina {
  --c-title: #17375e; --c-text: #222b38; --c-muted: #5a6472; --c-surface: #fff;
  --c-row: #f4f6fa; --c-border: #d0d7e2;
}
:root.dark .pagina {
  --c-title: #c7d2fe; --c-text: #e2e8f0; --c-muted: #a3b2c9; --c-surface: rgb(18 27 46);
  --c-row: rgb(24 36 60); --c-border: rgb(43 56 78);
}
.pagina { max-width: 1180px; margin: 0 auto; padding: 32px 24px 64px; text-align: left; color: var(--c-text); }
.cabecera { border-bottom: 3px solid #c8962e; padding-bottom: 16px; margin-bottom: 24px; }
h1 { margin: 0; font: 700 28px/1.2 Georgia, 'Times New Roman', serif; color: var(--c-title); }
h2 { margin: 0 0 12px; font: 700 19px/1.2 Georgia, serif; color: var(--c-title); }
.sub { margin: 4px 0 0; color: var(--c-muted); font-size: 15px; }

.kpis { display: grid; grid-template-columns: repeat(auto-fill, minmax(170px, 1fr)); gap: 12px; margin-bottom: 24px; }
.kpi { border: 1px solid var(--c-border); border-left: 4px solid #17375e; border-radius: 4px; padding: 12px 14px;
  background: var(--c-surface); display: flex; flex-direction: column; gap: 4px; }
.kpi span { font-size: 13px; color: var(--c-muted); }
.kpi b { font-size: 24px; color: var(--c-title); font-variant-numeric: tabular-nums; }
.kpi.principal { border-left-color: #c8962e; }
.kpi.listo { border-left-color: #2f8a4c; }
.kpi.alerta { border-left-color: #c8962e; }
.kpi.alerta b { color: #b26b00; }
:root.dark .kpi.alerta b { color: #f2b84b; }

.dos { display: grid; grid-template-columns: 2fr 1fr; gap: 20px; align-items: start; }
.caja { border: 1px solid var(--c-border); border-radius: 6px; padding: 18px; background: var(--c-surface); min-width: 0; }
.actividad { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; }
.actividad li { display: flex; gap: 12px; align-items: flex-start; padding: 10px 0; border-top: 1px solid var(--c-border); }
.actividad li:first-child { border-top: none; }
.actividad p { margin: 0; font-size: 14.5px; overflow-wrap: anywhere; }
.actividad small { color: var(--c-muted); font-size: 12.5px; }
.chip { padding: 2px 8px; border-radius: 999px; font-size: 11px; font-weight: 700; white-space: nowrap; margin-top: 2px;
  background: #e6f0fb; color: #1d4f8a; min-width: 82px; text-align: center; }
.chip.inventario { background: #fff2d6; color: #7a4c00; }
.chip.pago { background: #dff3e4; color: #1d6b34; }
.vacio { color: var(--c-muted); margin: 0; }

.accesos { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 8px; }
.accesos a { display: flex; flex-direction: column; gap: 2px; padding: 10px 12px; border: 1px solid var(--c-border);
  border-radius: 4px; text-decoration: none; color: var(--c-text); }
.accesos a:hover { background: var(--c-row); border-color: #c8962e; }
.accesos a:focus-visible { outline: 3px solid #c8962e; outline-offset: 1px; }
.accesos b { color: var(--c-title); }
.accesos span { font-size: 13px; color: var(--c-muted); }
.error { background: #fbe4e4; color: #8a1f1f; padding: 10px 14px; border-radius: 4px; margin: 0 0 16px; }

@media (max-width: 900px) { .dos { grid-template-columns: 1fr; } }
@media (max-width: 600px) { .pagina { padding: 24px 16px 48px; } .kpis { grid-template-columns: 1fr 1fr; } }
</style>
