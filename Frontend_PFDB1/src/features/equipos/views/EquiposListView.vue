<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { env } from '@/core/config/env'

interface EquipoFila {
  equipoId: number
  clienteId: number
  nombreCliente: string | null
  nombreTipoEquipo: string | null
  marca: string
  modelo: string
  numeroSerie: string
  estado: string
}

interface OpcionCliente {
  clienteId: number
  nombreRazonSocial: string
  estado: string
}

const BASE = env.VITE_API_BASE_URL

const equipos = ref<EquipoFila[]>([])
const clientes = ref<OpcionCliente[]>([])
const clienteId = ref('')
const cargando = ref(false)
const error = ref('')

async function cargarEquipos() {
  cargando.value = true
  error.value = ''
  try {
    const token = sessionStorage.getItem('token')
    const q = new URLSearchParams()
    if (clienteId.value) q.set('clienteId', clienteId.value)
    const res = await fetch(`${BASE}/api/Equipo?${q.toString()}`, {
      headers: { Authorization: `Bearer ${token}` },
    })
    const data = await res.json()
    if (data.codigo === 200) {
      equipos.value = data.data
    } else {
      error.value = data.mensaje ?? 'No se pudo cargar la lista de equipos.'
    }
  } catch {
    error.value = 'No se pudo conectar con el servidor. Verifique que la API esté en ejecución.'
  } finally {
    cargando.value = false
  }
}

async function cargarClientes() {
  try {
    const token = sessionStorage.getItem('token')
    const res = await fetch(`${BASE}/api/Cliente`, {
      headers: { Authorization: `Bearer ${token}` },
    })
    const data = await res.json()
    if (data.codigo === 200) {
      clientes.value = data.data.filter((c: OpcionCliente) => c.estado === 'ACTIVO')
    }
  } catch {
    clientes.value = []
  }
}

onMounted(() => {
  cargarClientes()
  cargarEquipos()
})
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <div>
        <h1>Equipos</h1>
        <p class="sub">Equipos registrados por cliente, con su tipo, marca y número de serie.</p>
      </div>
      <form class="filtros" @submit.prevent="cargarEquipos()">
        <select v-model="clienteId" aria-label="Filtrar por cliente" @change="cargarEquipos()">
          <option value="">Todos los clientes</option>
          <option v-for="c in clientes" :key="c.clienteId" :value="String(c.clienteId)">
            {{ c.nombreRazonSocial }}
          </option>
        </select>
        <button type="submit" :disabled="cargando">Actualizar</button>
      </form>
    </header>

    <p v-if="error" class="error" role="alert">{{ error }}</p>

    <div class="tabla-wrap">
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Cliente</th>
            <th>Tipo</th>
            <th>Marca</th>
            <th>Modelo</th>
            <th>N° serie</th>
            <th>Estado</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="cargando">
            <td colspan="7" class="vacio">Cargando equipos…</td>
          </tr>
          <tr v-else-if="!equipos.length">
            <td colspan="7" class="vacio">No hay equipos registrados.</td>
          </tr>
          <tr v-for="e in equipos" :key="e.equipoId">
            <td class="num">{{ e.equipoId }}</td>
            <td class="fuerte">{{ e.nombreCliente }}</td>
            <td><span class="chip-tipo">{{ e.nombreTipoEquipo ?? '—' }}</span></td>
            <td>{{ e.marca }}</td>
            <td>{{ e.modelo }}</td>
            <td class="num">{{ e.numeroSerie }}</td>
            <td>
              <span class="chip" :class="e.estado === 'ACTIVO' ? 'activo' : 'inactivo'">
                {{ e.estado === 'ACTIVO' ? 'Activo' : 'Inactivo' }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </main>
</template>

<style scoped>
.pagina {
  padding: 26px 30px;
}

.cabecera {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 16px;
  margin-bottom: 18px;
  flex-wrap: wrap;
}

.cabecera h1 {
  margin: 0;
  font-size: 24px;
  color: #1e2a4a;
}

.sub {
  margin: 4px 0 0;
  font-size: 13px;
  color: #7a809a;
}

.filtros {
  display: flex;
  gap: 8px;
}

.filtros select {
  border: 1px solid #d9def1;
  border-radius: 10px;
  padding: 8px 12px;
  font-size: 13.5px;
  min-width: 220px;
  background: #fff;
}

.filtros button {
  border: none;
  border-radius: 10px;
  background: #3d56a8;
  color: #fff;
  font-weight: 600;
  font-size: 13px;
  padding: 8px 16px;
  cursor: pointer;
}

.filtros button:disabled {
  opacity: 0.6;
  cursor: default;
}

.tabla-wrap {
  overflow-x: auto;
  background: #fff;
  border: 1px solid #e4e8f4;
  border-radius: 14px;
}

table {
  width: 100%;
  border-collapse: collapse;
}

th, td {
  padding: 12px 16px;
  text-align: left;
  font-size: 13.5px;
  border-bottom: 1px solid #eef0f7;
}

th {
  background: #f4f6fc;
  color: #3c4360;
  font-weight: 600;
}

tr:last-child td {
  border-bottom: none;
}

.fuerte {
  font-weight: 600;
  color: #2c3050;
}

.num {
  color: #7a809a;
}

.vacio {
  text-align: center;
  color: #7a809a;
  padding: 30px;
}

.error {
  background: #ffebee;
  color: #b1303a;
  border-radius: 8px;
  padding: 10px 14px;
  font-size: 13px;
  margin-bottom: 14px;
}

.chip-tipo {
  background: #eef2ff;
  color: #3d56a8;
  border-radius: 999px;
  padding: 3px 10px;
  font-size: 12px;
  font-weight: 600;
}

.chip {
  border-radius: 999px;
  padding: 3px 10px;
  font-size: 12px;
  font-weight: 600;
}

.activo {
  background: #e8f5e9;
  color: #1f6f3c;
}

.inactivo {
  background: #ffebee;
  color: #b1303a;
}
</style>
