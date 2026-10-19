<script setup lang="ts">
// Mantenimientos (enunciado 6.1): repuestos, proveedores, bodegas, categorías y tipos de equipo.
// BODEGA: repuestos (con su stock mínimo por bodega) y proveedores.
// ADMINISTRADOR: además bodegas, categorías y tipos de equipo.
// Nada se borra: se inactiva. Las reglas las valida la base (script 12).
import { computed, onMounted, reactive, ref, watch } from 'vue'
import { useAuthStore } from '@/features/auth/stores/auth.store'
import {
  mantenimientoApi,
  type Categoria, type TipoEquipo, type Repuesto, type RepuestoBodega, type Bodega, type Proveedor,
  type EstadoRegistro,
} from '../api/mantenimientos'

const auth = useAuthStore()
const esAdmin = computed(() => auth.rol === 'ADMINISTRADOR')

const moneda = (n: number | null | undefined) =>
  (n ?? 0).toLocaleString('es-GT', { style: 'currency', currency: 'GTQ' })

type Pestana = 'repuestos' | 'proveedores' | 'bodegas' | 'categorias' | 'tipos'
const todas: { id: Pestana; titulo: string; admin?: boolean }[] = [
  { id: 'repuestos', titulo: 'Repuestos' },
  { id: 'proveedores', titulo: 'Proveedores' },
  { id: 'bodegas', titulo: 'Bodegas', admin: true },
  { id: 'categorias', titulo: 'Categorías', admin: true },
  { id: 'tipos', titulo: 'Tipos de equipo', admin: true },
]
const pestanas = computed(() => todas.filter((p) => !p.admin || esAdmin.value))
const pestana = ref<Pestana>('repuestos')

const aviso = ref('')
function mostrarAviso(texto: string) {
  aviso.value = texto
  setTimeout(() => (aviso.value = ''), 4000)
}

// ---------- datos ----------
const categorias = ref<Categoria[]>([])
const bodegas = ref<Bodega[]>([])
const tipos = ref<TipoEquipo[]>([])
const repuestos = ref<Repuesto[]>([])
const proveedores = ref<Proveedor[]>([])
const cargando = reactive<Record<Pestana, boolean>>({ repuestos: false, proveedores: false, bodegas: false, categorias: false, tipos: false })
const errores = reactive<Record<Pestana, string>>({ repuestos: '', proveedores: '', bodegas: '', categorias: '', tipos: '' })

const fRep = reactive({ buscar: '', categoriaId: 0, estado: 'ACTIVO' })
const fProv = reactive({ buscar: '', estado: 'ACTIVO' })

const categoriasActivas = computed(() => categorias.value.filter((c) => c.activo))
const bodegasActivas = computed(() => bodegas.value.filter((b) => b.activo))

async function cargar(p: Pestana) {
  cargando[p] = true
  errores[p] = ''
  try {
    if (p === 'repuestos') repuestos.value = await mantenimientoApi.repuestos(fRep)
    else if (p === 'proveedores') proveedores.value = await mantenimientoApi.proveedores(fProv)
    else if (p === 'bodegas') bodegas.value = await mantenimientoApi.bodegas()
    else if (p === 'categorias') categorias.value = await mantenimientoApi.categorias()
    else tipos.value = await mantenimientoApi.tiposEquipo()
  } catch (e) {
    errores[p] = (e as Error).message
  } finally {
    cargando[p] = false
  }
}

// Repuestos y proveedores se filtran en la base; el buscador espera a que deje de escribir
let espera: ReturnType<typeof setTimeout> | undefined
function cargarLuego(p: Pestana) {
  clearTimeout(espera)
  espera = setTimeout(() => cargar(p), 300)
}
watch(() => [fRep.categoriaId, fRep.estado], () => cargar('repuestos'))
watch(() => fRep.buscar, () => cargarLuego('repuestos'))
watch(() => fProv.estado, () => cargar('proveedores'))
watch(() => fProv.buscar, () => cargarLuego('proveedores'))

const cargadas = new Set<Pestana>()
watch(pestana, (p) => {
  if (!cargadas.has(p)) {
    cargadas.add(p)
    cargar(p)
  }
})

onMounted(async () => {
  cargadas.add('repuestos')
  // Catálogos para los filtros y formularios (BODEGA también los puede consultar)
  await Promise.all([cargar('categorias'), cargar('bodegas'), cargar('repuestos')])
  cargadas.add('categorias').add('bodegas')
})

// ---------- formulario (crear / editar) ----------
const dlgForm = ref<HTMLDialogElement | null>(null)
const editando = ref<{ tipo: Pestana; id: number | null } | null>(null)
const errorForm = ref('')
const guardando = ref(false)

const fRepuesto = reactive({ categoriaId: 0, codigo: '', nombre: '', descripcion: '', precioCompraReferencia: 0, precioVenta: 0, bodegaId: 0, stockMinimo: 0 })
const fProveedor = reactive({ nit: '', nombre: '', contacto: '', telefono: '', correo: '', direccion: '' })
const fBodega = reactive({ nombre: '', ubicacion: '' })
const fCategoria = reactive({ nombre: '', descripcion: '' })
const fTipo = reactive({ nombre: '' })

const NOMBRES: Record<Pestana, string> = {
  repuestos: 'repuesto', proveedores: 'proveedor', bodegas: 'bodega', categorias: 'categoría', tipos: 'tipo de equipo',
}
const tituloNuevo = (p: Pestana) =>
  `${p === 'bodegas' || p === 'categorias' ? 'Nueva' : 'Nuevo'} ${NOMBRES[p]}`
const tituloForm = computed(() => {
  if (!editando.value) return ''
  return editando.value.id ? `Editar ${NOMBRES[editando.value.tipo]}` : tituloNuevo(editando.value.tipo)
})

function abrir(tipo: Pestana, fila?: Repuesto | Proveedor | Bodega | Categoria | TipoEquipo) {
  errorForm.value = ''
  if (tipo === 'repuestos') {
    const r = fila as Repuesto | undefined
    Object.assign(fRepuesto, {
      categoriaId: r?.categoriaId ?? 0, codigo: r?.codigo ?? '', nombre: r?.nombre ?? '',
      descripcion: r?.descripcion ?? '', precioCompraReferencia: r?.precioCompraReferencia ?? 0,
      precioVenta: r?.precioVenta ?? 0, bodegaId: r ? 0 : (bodegasActivas.value[0]?.bodegaId ?? 0), stockMinimo: 0,
    })
    editando.value = { tipo, id: r?.repuestoId ?? null }
  } else if (tipo === 'proveedores') {
    const p = fila as Proveedor | undefined
    Object.assign(fProveedor, {
      nit: p?.nit ?? '', nombre: p?.nombre ?? '', contacto: p?.contacto ?? '',
      telefono: p?.telefono ?? '', correo: p?.correo ?? '', direccion: p?.direccion ?? '',
    })
    editando.value = { tipo, id: p?.proveedorId ?? null }
  } else if (tipo === 'bodegas') {
    const b = fila as Bodega | undefined
    Object.assign(fBodega, { nombre: b?.nombre ?? '', ubicacion: b?.ubicacion ?? '' })
    editando.value = { tipo, id: b?.bodegaId ?? null }
  } else if (tipo === 'categorias') {
    const c = fila as Categoria | undefined
    Object.assign(fCategoria, { nombre: c?.nombre ?? '', descripcion: c?.descripcion ?? '' })
    editando.value = { tipo, id: c?.categoriaId ?? null }
  } else {
    const t = fila as TipoEquipo | undefined
    fTipo.nombre = t?.nombre ?? ''
    editando.value = { tipo, id: t?.tipoEquipoId ?? null }
  }
  dlgForm.value?.showModal()
}

const RX_NIT = /^[0-9]+-?[0-9K]$/i
const RX_TEL = /^[0-9 +-]{8,15}$/
const RX_CORREO = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

// Mismas reglas que la base, para avisar antes de enviar
function validar(tipo: Pestana): string {
  if (tipo === 'repuestos') {
    const f = fRepuesto
    if (!f.categoriaId) return 'Seleccione la categoría.'
    if (!f.codigo.trim()) return 'El código es obligatorio.'
    if (!f.nombre.trim()) return 'El nombre es obligatorio.'
    if (!(Number(f.precioCompraReferencia) >= 0) || !(Number(f.precioVenta) >= 0)) return 'Los precios no pueden ser negativos.'
    if (Number(f.precioVenta) < Number(f.precioCompraReferencia)) return 'El precio de venta no puede ser menor al de compra.'
    if (!Number.isInteger(Number(f.stockMinimo)) || Number(f.stockMinimo) < 0) return 'El stock mínimo debe ser un entero de 0 en adelante.'
  } else if (tipo === 'proveedores') {
    const f = fProveedor
    if (!RX_NIT.test(f.nit.trim())) return 'NIT inválido. Ejemplo: 1234567-8.'
    if (!f.nombre.trim()) return 'El nombre es obligatorio.'
    if (!RX_TEL.test(f.telefono.trim())) return 'Teléfono inválido (8 a 15 dígitos).'
    if (f.correo.trim() && !RX_CORREO.test(f.correo.trim())) return 'Correo inválido.'
  } else if (tipo === 'bodegas') {
    if (!fBodega.nombre.trim()) return 'El nombre es obligatorio.'
  } else if (tipo === 'categorias') {
    if (!fCategoria.nombre.trim()) return 'El nombre es obligatorio.'
  } else if (!fTipo.nombre.trim()) return 'El nombre es obligatorio.'
  return ''
}

async function guardar() {
  if (!editando.value) return
  const { tipo, id } = editando.value
  errorForm.value = validar(tipo)
  if (errorForm.value) return
  guardando.value = true
  try {
    if (tipo === 'repuestos') await mantenimientoApi.guardarRepuesto(id, { ...fRepuesto })
    else if (tipo === 'proveedores') await mantenimientoApi.guardarProveedor(id, { ...fProveedor })
    else if (tipo === 'bodegas') await mantenimientoApi.guardarBodega(id, { ...fBodega })
    else if (tipo === 'categorias') await mantenimientoApi.guardarCategoria(id, { ...fCategoria })
    else await mantenimientoApi.guardarTipoEquipo(id, { ...fTipo })
    dlgForm.value?.close()
    mostrarAviso(id ? 'Cambios guardados.' : 'Registro creado.')
    await cargar(tipo)
    if (tipo === 'categorias' || tipo === 'bodegas') cargar('repuestos')
  } catch (e) {
    errorForm.value = (e as Error).message
  } finally {
    guardando.value = false
  }
}

// ---------- activar / inactivar ----------
const dlgEstado = ref<HTMLDialogElement | null>(null)
const cambio = ref<{ tipo: Pestana; id: number; nombre: string; activar: boolean } | null>(null)
const errorEstado = ref('')
const procesando = ref(false)

function pedirEstado(tipo: Pestana, id: number, nombre: string, activar: boolean) {
  cambio.value = { tipo, id, nombre, activar }
  errorEstado.value = ''
  dlgEstado.value?.showModal()
}

async function confirmarEstado() {
  if (!cambio.value) return
  const { tipo, id, activar } = cambio.value
  const estado: EstadoRegistro = activar ? 'ACTIVO' : 'INACTIVO'
  procesando.value = true
  errorEstado.value = ''
  try {
    if (tipo === 'repuestos') await mantenimientoApi.estadoRepuesto(id, estado)
    else if (tipo === 'proveedores') await mantenimientoApi.estadoProveedor(id, estado)
    else if (tipo === 'bodegas') await mantenimientoApi.estadoBodega(id, activar)
    else await mantenimientoApi.estadoCategoria(id, activar)
    dlgEstado.value?.close()
    mostrarAviso(activar ? 'Registro activado.' : 'Registro inactivado.')
    await cargar(tipo)
  } catch (e) {
    errorEstado.value = (e as Error).message
  } finally {
    procesando.value = false
  }
}

// ---------- stock mínimo por bodega ----------
const dlgMinimos = ref<HTMLDialogElement | null>(null)
const repMinimos = ref<Repuesto | null>(null)
const filasMinimos = ref<(RepuestoBodega & { nuevo: number })[]>([])
const errorMinimos = ref('')
const guardandoMinimo = ref<number | null>(null)

async function abrirMinimos(r: Repuesto) {
  repMinimos.value = r
  filasMinimos.value = []
  errorMinimos.value = ''
  dlgMinimos.value?.showModal()
  try {
    const filas = await mantenimientoApi.inventarioRepuesto(r.repuestoId)
    filasMinimos.value = filas.map((f) => ({ ...f, nuevo: f.stockMinimo }))
  } catch (e) {
    errorMinimos.value = (e as Error).message
  }
}

async function guardarMinimo(f: RepuestoBodega & { nuevo: number }) {
  if (!repMinimos.value) return
  const valor = Number(f.nuevo)
  if (!Number.isInteger(valor) || valor < 0) {
    errorMinimos.value = 'El stock mínimo debe ser un entero de 0 en adelante.'
    return
  }
  errorMinimos.value = ''
  guardandoMinimo.value = f.bodegaId
  try {
    await mantenimientoApi.guardarMinimo(repMinimos.value.repuestoId, f.bodegaId, valor)
    f.stockMinimo = valor
    f.registrado = true
    mostrarAviso(`Mínimo de ${f.bodega} actualizado.`)
    cargar('repuestos')
  } catch (e) {
    errorMinimos.value = (e as Error).message
  } finally {
    guardandoMinimo.value = null
  }
}
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <div>
        <h1>Mantenimientos</h1>
        <p class="sub">Catálogos del taller. Los registros no se borran: se inactivan.</p>
      </div>
      <button class="btn primario" @click="abrir(pestana)">+ {{ tituloNuevo(pestana) }}</button>
    </header>

    <p v-if="aviso" class="aviso" role="status">{{ aviso }}</p>

    <nav class="pestanas" role="tablist" aria-label="Catálogos">
      <button
v-for="p in pestanas" :key="p.id" role="tab" :aria-selected="pestana === p.id"
              :class="{ activa: pestana === p.id }" @click="pestana = p.id">{{ p.titulo }}</button>
    </nav>

    <!-- ===== Repuestos ===== -->
    <section v-show="pestana === 'repuestos'" role="tabpanel">
      <div class="filtros">
        <label class="campo grande">
          <span>Buscar</span>
          <input v-model="fRep.buscar" type="search" placeholder="Código o nombre" />
        </label>
        <label class="campo">
          <span>Categoría</span>
          <select v-model.number="fRep.categoriaId">
            <option :value="0">Todas</option>
            <option v-for="c in categorias" :key="c.categoriaId" :value="c.categoriaId">{{ c.nombre }}</option>
          </select>
        </label>
        <label class="campo">
          <span>Estado</span>
          <select v-model="fRep.estado">
            <option value="ACTIVO">Activos</option>
            <option value="INACTIVO">Inactivos</option>
            <option value="">Todos</option>
          </select>
        </label>
      </div>
      <p v-if="errores.repuestos" class="error" role="alert">{{ errores.repuestos }}</p>
      <div class="tabla-wrap">
        <table>
          <thead>
            <tr><th>Código</th><th>Repuesto</th><th>Categoría</th><th class="der">Precio compra</th><th class="der">Precio venta</th><th class="der">Existencia</th><th>Estado</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-if="cargando.repuestos"><td colspan="8" class="vacio">Cargando repuestos…</td></tr>
            <tr v-else-if="!repuestos.length"><td colspan="8" class="vacio">No hay repuestos con ese criterio.</td></tr>
            <template v-else>
              <tr v-for="r in repuestos" :key="r.repuestoId">
                <td class="num">{{ r.codigo }}</td>
                <td>{{ r.nombre }}<div v-if="r.descripcion" class="detalle">{{ r.descripcion }}</div></td>
                <td>{{ r.categoria }}</td>
                <td class="der">{{ moneda(r.precioCompraReferencia) }}</td>
                <td class="der">{{ moneda(r.precioVenta) }}</td>
                <td class="der fuerte">{{ r.existencia }}<div class="detalle">{{ r.bodegas }} bodega(s)</div></td>
                <td><span class="chip" :class="r.estado === 'ACTIVO' ? 'ok' : 'inactivo'">{{ r.estado === 'ACTIVO' ? 'Activo' : 'Inactivo' }}</span></td>
                <td class="acciones">
                  <button class="btn enlace" @click="abrir('repuestos', r)">Editar</button>
                  <button v-if="r.estado === 'ACTIVO'" class="btn enlace" @click="abrirMinimos(r)">Mínimos</button>
                  <button
class="btn enlace" :class="{ peligro: r.estado === 'ACTIVO' }"
                          @click="pedirEstado('repuestos', r.repuestoId, `${r.codigo} · ${r.nombre}`, r.estado !== 'ACTIVO')">
                    {{ r.estado === 'ACTIVO' ? 'Inactivar' : 'Activar' }}
                  </button>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
      <p class="nota pie">Cambiar un precio queda registrado en la auditoría de precios (AuditoriaPrecio).</p>
    </section>

    <!-- ===== Proveedores ===== -->
    <section v-show="pestana === 'proveedores'" role="tabpanel">
      <div class="filtros">
        <label class="campo grande">
          <span>Buscar</span>
          <input v-model="fProv.buscar" type="search" placeholder="Nombre, NIT o contacto" />
        </label>
        <label class="campo">
          <span>Estado</span>
          <select v-model="fProv.estado">
            <option value="ACTIVO">Activos</option>
            <option value="INACTIVO">Inactivos</option>
            <option value="">Todos</option>
          </select>
        </label>
      </div>
      <p v-if="errores.proveedores" class="error" role="alert">{{ errores.proveedores }}</p>
      <div class="tabla-wrap">
        <table>
          <thead>
            <tr><th>NIT</th><th>Proveedor</th><th>Contacto</th><th>Teléfono</th><th>Correo</th><th class="der">Compras</th><th>Estado</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-if="cargando.proveedores"><td colspan="8" class="vacio">Cargando proveedores…</td></tr>
            <tr v-else-if="!proveedores.length"><td colspan="8" class="vacio">No hay proveedores con ese criterio.</td></tr>
            <template v-else>
              <tr v-for="p in proveedores" :key="p.proveedorId">
                <td class="num">{{ p.nit }}</td>
                <td>{{ p.nombre }}<div v-if="p.direccion" class="detalle">{{ p.direccion }}</div></td>
                <td>{{ p.contacto ?? '—' }}</td>
                <td>{{ p.telefono }}</td>
                <td>{{ p.correo ?? '—' }}</td>
                <td class="der">{{ p.compras }}<div v-if="p.comprasPendientes" class="detalle">{{ p.comprasPendientes }} pendiente(s)</div></td>
                <td><span class="chip" :class="p.estado === 'ACTIVO' ? 'ok' : 'inactivo'">{{ p.estado === 'ACTIVO' ? 'Activo' : 'Inactivo' }}</span></td>
                <td class="acciones">
                  <button class="btn enlace" @click="abrir('proveedores', p)">Editar</button>
                  <button
class="btn enlace" :class="{ peligro: p.estado === 'ACTIVO' }"
                          @click="pedirEstado('proveedores', p.proveedorId, p.nombre, p.estado !== 'ACTIVO')">
                    {{ p.estado === 'ACTIVO' ? 'Inactivar' : 'Activar' }}
                  </button>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </section>

    <!-- ===== Bodegas ===== -->
    <section v-if="esAdmin" v-show="pestana === 'bodegas'" role="tabpanel">
      <p v-if="errores.bodegas" class="error" role="alert">{{ errores.bodegas }}</p>
      <div class="tabla-wrap">
        <table>
          <thead>
            <tr><th>Bodega</th><th>Ubicación</th><th class="der">Repuestos con existencia</th><th class="der">Unidades</th><th class="der">Valor</th><th>Estado</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-if="cargando.bodegas"><td colspan="7" class="vacio">Cargando bodegas…</td></tr>
            <tr v-else-if="!bodegas.length"><td colspan="7" class="vacio">No hay bodegas.</td></tr>
            <template v-else>
              <tr v-for="b in bodegas" :key="b.bodegaId">
                <td class="fuerte">{{ b.nombre }}</td>
                <td>{{ b.ubicacion ?? '—' }}</td>
                <td class="der">{{ b.repuestosConExistencia }}</td>
                <td class="der">{{ b.unidades }}</td>
                <td class="der">{{ moneda(b.valorInventario) }}</td>
                <td><span class="chip" :class="b.activo ? 'ok' : 'inactivo'">{{ b.activo ? 'Activa' : 'Inactiva' }}</span></td>
                <td class="acciones">
                  <button class="btn enlace" @click="abrir('bodegas', b)">Editar</button>
                  <button
class="btn enlace" :class="{ peligro: b.activo }"
                          @click="pedirEstado('bodegas', b.bodegaId, b.nombre, !b.activo)">
                    {{ b.activo ? 'Inactivar' : 'Activar' }}
                  </button>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
      <p class="nota pie">Una bodega con existencias o compras pendientes no se puede inactivar.</p>
    </section>

    <!-- ===== Categorías ===== -->
    <section v-if="esAdmin" v-show="pestana === 'categorias'" role="tabpanel">
      <p v-if="errores.categorias" class="error" role="alert">{{ errores.categorias }}</p>
      <div class="tabla-wrap">
        <table>
          <thead>
            <tr><th>Categoría</th><th>Descripción</th><th class="der">Repuestos activos</th><th>Estado</th><th></th></tr>
          </thead>
          <tbody>
            <tr v-if="cargando.categorias"><td colspan="5" class="vacio">Cargando categorías…</td></tr>
            <tr v-else-if="!categorias.length"><td colspan="5" class="vacio">No hay categorías.</td></tr>
            <template v-else>
              <tr v-for="c in categorias" :key="c.categoriaId">
                <td class="fuerte">{{ c.nombre }}</td>
                <td>{{ c.descripcion ?? '—' }}</td>
                <td class="der">{{ c.repuestos }}</td>
                <td><span class="chip" :class="c.activo ? 'ok' : 'inactivo'">{{ c.activo ? 'Activa' : 'Inactiva' }}</span></td>
                <td class="acciones">
                  <button class="btn enlace" @click="abrir('categorias', c)">Editar</button>
                  <button
class="btn enlace" :class="{ peligro: c.activo }"
                          @click="pedirEstado('categorias', c.categoriaId, c.nombre, !c.activo)">
                    {{ c.activo ? 'Inactivar' : 'Activar' }}
                  </button>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </section>

    <!-- ===== Tipos de equipo ===== -->
    <section v-if="esAdmin" v-show="pestana === 'tipos'" role="tabpanel">
      <p v-if="errores.tipos" class="error" role="alert">{{ errores.tipos }}</p>
      <div class="tabla-wrap angosta">
        <table>
          <thead><tr><th>Tipo de equipo</th><th class="der">Equipos registrados</th><th></th></tr></thead>
          <tbody>
            <tr v-if="cargando.tipos"><td colspan="3" class="vacio">Cargando tipos…</td></tr>
            <tr v-else-if="!tipos.length"><td colspan="3" class="vacio">No hay tipos de equipo.</td></tr>
            <template v-else>
              <tr v-for="t in tipos" :key="t.tipoEquipoId">
                <td class="fuerte">{{ t.nombre }}</td>
                <td class="der">{{ t.equipos }}</td>
                <td class="acciones"><button class="btn enlace" @click="abrir('tipos', t)">Editar</button></td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>
    </section>

    <!-- Crear / editar -->
    <dialog ref="dlgForm" class="modal">
      <form v-if="editando" novalidate @submit.prevent="guardar">
        <h2>{{ tituloForm }}</h2>

        <template v-if="editando.tipo === 'repuestos'">
          <div class="fila">
            <label class="campo">
              <span>Código</span>
              <input v-model="fRepuesto.codigo" maxlength="20" placeholder="REP-0031" />
            </label>
            <label class="campo">
              <span>Categoría</span>
              <select v-model.number="fRepuesto.categoriaId">
                <option :value="0" disabled>Seleccione…</option>
                <option v-for="c in categoriasActivas" :key="c.categoriaId" :value="c.categoriaId">{{ c.nombre }}</option>
              </select>
            </label>
          </div>
          <label class="campo">
            <span>Nombre</span>
            <input v-model="fRepuesto.nombre" maxlength="100" />
          </label>
          <label class="campo">
            <span>Descripción (opcional)</span>
            <input v-model="fRepuesto.descripcion" maxlength="200" />
          </label>
          <div class="fila">
            <label class="campo">
              <span>Precio de compra (Q)</span>
              <input v-model.number="fRepuesto.precioCompraReferencia" type="number" min="0" step="0.01" />
            </label>
            <label class="campo">
              <span>Precio de venta (Q)</span>
              <input v-model.number="fRepuesto.precioVenta" type="number" min="0" step="0.01" />
            </label>
          </div>
          <div v-if="!editando.id" class="fila">
            <label class="campo">
              <span>Bodega donde se guarda</span>
              <select v-model.number="fRepuesto.bodegaId">
                <option :value="0">Ninguna por ahora</option>
                <option v-for="b in bodegasActivas" :key="b.bodegaId" :value="b.bodegaId">{{ b.nombre }}</option>
              </select>
            </label>
            <label class="campo">
              <span>Stock mínimo</span>
              <input v-model.number="fRepuesto.stockMinimo" type="number" min="0" step="1" :disabled="!fRepuesto.bodegaId" />
            </label>
          </div>
          <p v-if="!editando.id" class="nota">Empieza con existencia 0; sube cuando se reciba una compra.</p>
        </template>

        <template v-else-if="editando.tipo === 'proveedores'">
          <div class="fila">
            <label class="campo">
              <span>NIT</span>
              <input v-model="fProveedor.nit" maxlength="15" placeholder="1234567-8" />
            </label>
            <label class="campo">
              <span>Teléfono</span>
              <input v-model="fProveedor.telefono" maxlength="15" inputmode="tel" />
            </label>
          </div>
          <label class="campo">
            <span>Nombre o razón social</span>
            <input v-model="fProveedor.nombre" maxlength="150" />
          </label>
          <div class="fila">
            <label class="campo">
              <span>Contacto (opcional)</span>
              <input v-model="fProveedor.contacto" maxlength="100" />
            </label>
            <label class="campo">
              <span>Correo (opcional)</span>
              <input v-model="fProveedor.correo" maxlength="100" type="email" />
            </label>
          </div>
          <label class="campo">
            <span>Dirección (opcional)</span>
            <input v-model="fProveedor.direccion" maxlength="200" />
          </label>
        </template>

        <template v-else-if="editando.tipo === 'bodegas'">
          <label class="campo">
            <span>Nombre</span>
            <input v-model="fBodega.nombre" maxlength="50" />
          </label>
          <label class="campo">
            <span>Ubicación (opcional)</span>
            <input v-model="fBodega.ubicacion" maxlength="150" />
          </label>
        </template>

        <template v-else-if="editando.tipo === 'categorias'">
          <label class="campo">
            <span>Nombre</span>
            <input v-model="fCategoria.nombre" maxlength="50" />
          </label>
          <label class="campo">
            <span>Descripción (opcional)</span>
            <input v-model="fCategoria.descripcion" maxlength="150" />
          </label>
        </template>

        <template v-else>
          <label class="campo">
            <span>Nombre</span>
            <input v-model="fTipo.nombre" maxlength="50" placeholder="Ej. Consola de videojuegos" />
          </label>
        </template>

        <p v-if="errorForm" class="error" role="alert">{{ errorForm }}</p>
        <div class="botones">
          <button type="button" class="btn" @click="dlgForm?.close()">Cancelar</button>
          <button type="submit" class="btn primario" :disabled="guardando">{{ guardando ? 'Guardando…' : 'Guardar' }}</button>
        </div>
      </form>
    </dialog>

    <!-- Activar / inactivar -->
    <dialog ref="dlgEstado" class="modal">
      <form v-if="cambio" novalidate @submit.prevent="confirmarEstado">
        <h2>{{ cambio.activar ? 'Activar' : 'Inactivar' }}</h2>
        <p>¿{{ cambio.activar ? 'Activar' : 'Inactivar' }} <b>{{ cambio.nombre }}</b>?</p>
        <p v-if="!cambio.activar" class="nota">No se borra: deja de aparecer en las listas para nuevas operaciones y su historial se conserva.</p>
        <p v-if="errorEstado" class="error" role="alert">{{ errorEstado }}</p>
        <div class="botones">
          <button type="button" class="btn" @click="dlgEstado?.close()">Cancelar</button>
          <button type="submit" class="btn" :class="cambio.activar ? 'primario' : 'peligro-lleno'" :disabled="procesando">
            {{ procesando ? 'Procesando…' : cambio.activar ? 'Activar' : 'Inactivar' }}
          </button>
        </div>
      </form>
    </dialog>

    <!-- Stock mínimo por bodega -->
    <dialog ref="dlgMinimos" class="modal">
      <div v-if="repMinimos" class="contenido">
        <h2>Stock mínimo</h2>
        <p class="nota"><b>{{ repMinimos.codigo }}</b> · {{ repMinimos.nombre }}. Cuando la existencia llega al mínimo aparece en «Bajo mínimo».</p>
        <div class="tabla-wrap">
          <table>
            <thead><tr><th>Bodega</th><th class="der">Existencia</th><th class="der">Mínimo</th><th></th></tr></thead>
            <tbody>
              <tr v-if="!filasMinimos.length && !errorMinimos"><td colspan="4" class="vacio">Cargando…</td></tr>
              <tr v-for="f in filasMinimos" :key="f.bodegaId">
                <td>{{ f.bodega }}<div v-if="!f.registrado" class="detalle">Sin registro en esta bodega</div></td>
                <td class="der">{{ f.existencia }}</td>
                <td class="der"><input v-model.number="f.nuevo" class="corto" type="number" min="0" step="1" :aria-label="`Mínimo en ${f.bodega}`" /></td>
                <td class="acciones">
                  <button
class="btn enlace" :disabled="guardandoMinimo === f.bodegaId || (f.registrado && f.nuevo === f.stockMinimo)"
                          @click="guardarMinimo(f)">{{ guardandoMinimo === f.bodegaId ? 'Guardando…' : 'Guardar' }}</button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <p v-if="errorMinimos" class="error" role="alert">{{ errorMinimos }}</p>
        <div class="botones">
          <button type="button" class="btn" @click="dlgMinimos?.close()">Cerrar</button>
        </div>
      </div>
    </dialog>
  </main>
</template>

<style scoped>
/* Colores que cambian con el tema (modo claro / oscuro de la plantilla) */
.pagina {
  --c-title: #17375e; --c-text: #222b38; --c-muted: #5a6472; --c-surface: #fff;
  --c-row: #f4f6fa; --c-border: #d0d7e2; --c-input: #b9c2d0; --c-disabled: #f1f3f7;
  --c-danger: #8a1f1f;
}
:root.dark .pagina {
  --c-title: #c7d2fe; --c-text: #e2e8f0; --c-muted: #a3b2c9; --c-surface: rgb(18 27 46);
  --c-row: rgb(24 36 60); --c-border: rgb(43 56 78); --c-input: rgb(71 85 105); --c-disabled: rgb(30 41 59);
  --c-danger: #f87171;
}
.modal { background: var(--c-surface); color: var(--c-text); margin: auto; }
.pagina { max-width: 1280px; margin: 0 auto; padding: 32px 24px 64px; text-align: left; color: var(--c-text); }
.cabecera { display: flex; justify-content: space-between; align-items: flex-end; gap: 16px; flex-wrap: wrap;
  border-bottom: 3px solid #c8962e; padding-bottom: 16px; margin-bottom: 20px; }
h1 { margin: 0; font: 700 28px/1.2 Georgia, 'Times New Roman', serif; color: var(--c-title); }
h2 { margin: 0; font: 700 22px/1.2 Georgia, serif; color: var(--c-title); }
.sub { margin: 4px 0 0; color: var(--c-muted); font-size: 15px; }

.pestanas { display: flex; gap: 4px; border-bottom: 1px solid var(--c-border); margin-bottom: 18px; overflow-x: auto; overflow-y: hidden; }
.pestanas button { font: inherit; font-size: 15px; padding: 10px 18px; border: none; background: none; color: var(--c-muted);
  border-bottom: 3px solid transparent; margin-bottom: -1px; cursor: pointer; white-space: nowrap; }
.pestanas button.activa { color: var(--c-title); font-weight: 700; border-bottom-color: #c8962e; }
.pestanas button:focus-visible { outline: 3px solid #c8962e; }

.filtros { display: flex; gap: 16px; margin-bottom: 16px; flex-wrap: wrap; align-items: flex-end; }
.campo { display: flex; flex-direction: column; gap: 4px; font-size: 14px; min-width: 180px; }
.campo span { font-weight: 600; color: var(--c-title); }
.campo.grande { flex: 1; min-width: 240px; }
input, select { font: inherit; font-size: 15px; padding: 9px 10px; border: 1px solid var(--c-input); border-radius: 4px;
  background: var(--c-surface); color: var(--c-text); box-sizing: border-box; width: 100%; }
input:disabled { background: var(--c-disabled); }
input.corto { width: 90px; text-align: right; }
input:focus-visible, select:focus-visible, .btn:focus-visible { outline: 3px solid #c8962e; outline-offset: 1px; }

.tabla-wrap { overflow-x: auto; border: 1px solid var(--c-border); border-radius: 4px; }
.tabla-wrap.angosta { max-width: 640px; }
table { width: 100%; border-collapse: collapse; font-size: 15px; }
th { background: #17375e; color: #fff; text-align: left; padding: 10px 12px; font-weight: 600; white-space: nowrap; }
td { padding: 10px 12px; border-top: 1px solid var(--c-border); vertical-align: middle; }
tbody tr:nth-child(even) { background: var(--c-row); }
.der { text-align: right; }
.fuerte { font-weight: 700; }
.num { font-variant-numeric: tabular-nums; white-space: nowrap; font-weight: 600; color: var(--c-title); }
.detalle { font-size: 13px; color: var(--c-muted); font-weight: 400; }
.vacio { text-align: center; color: var(--c-muted); padding: 28px 12px; }
.acciones { text-align: right; white-space: nowrap; }

.chip { padding: 2px 10px; border-radius: 999px; font-size: 13px; font-weight: 600; white-space: nowrap; }
.chip.ok { background: #dff3e4; color: #1d6b34; }
.chip.inactivo { background: #ececec; color: #3c4450; }

.btn { font: inherit; font-size: 15px; padding: 9px 16px; border-radius: 4px; border: 1px solid var(--c-input);
  background: var(--c-surface); color: var(--c-title); cursor: pointer; }
.btn.primario { background: #17375e; border-color: var(--c-title); color: #fff; font-weight: 600; }
.btn.primario:hover:not(:disabled) { background: #0f2a4a; }
.btn:disabled { opacity: 0.6; cursor: not-allowed; }
.btn.enlace { border: none; background: none; padding: 4px 8px; text-decoration: underline; }
.btn.enlace.peligro { color: var(--c-danger); }
.btn.peligro-lleno { background: #a32a2a; border-color: #a32a2a; color: #fff; font-weight: 600; }

.aviso { background: #dff3e4; color: #1d6b34; padding: 10px 14px; border-radius: 4px; margin: 0 0 16px; }
.error { background: #fbe4e4; color: #8a1f1f; padding: 10px 14px; border-radius: 4px; margin: 0 0 16px; }
.modal .error { margin: 0; }
.nota { margin: 0; color: var(--c-muted); font-size: 14px; }
.nota.pie { margin-top: 10px; }

.modal { border: none; border-radius: 6px; padding: 28px; width: min(600px, 92vw);
  box-shadow: 0 20px 50px rgba(15, 42, 74, 0.35); }
.modal::backdrop { background: rgba(15, 42, 74, 0.5); }
.modal form, .modal .contenido { display: flex; flex-direction: column; gap: 14px; text-align: left; }
.modal form > p { margin: 0; }
.modal td { padding: 6px 10px; }
.fila { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
.fila .campo { min-width: 0; }
.botones { display: flex; justify-content: flex-end; gap: 10px; }

@media (max-width: 700px) {
  .pagina { padding: 24px 16px 48px; }
  .pestanas button { padding: 10px 12px; }
  .fila { grid-template-columns: 1fr; }
  .cabecera { flex-direction: column; align-items: stretch; }
  .campo { min-width: 0; flex: 1 1 100%; }
}
</style>
