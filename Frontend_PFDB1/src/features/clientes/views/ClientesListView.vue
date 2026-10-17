<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { env } from '@/core/config/env'

interface ClienteFila {
  clienteId: number
  tipoCliente: string
  nombreRazonSocial: string
  nit: string
  telefono: string | null
  correo: string | null
  direccion: string | null
  estado: string
}

const BASE = env.VITE_API_BASE_URL

const clientes = ref<ClienteFila[]>([])
const cargando = ref(false)
const error = ref('')
const busqueda = ref('')

async function cargar() {
  cargando.value = true
  error.value = ''
  try {
    const token = sessionStorage.getItem('token')
    const q = new URLSearchParams()
    if (busqueda.value.trim()) q.set('busqueda', busqueda.value.trim())
    const res = await fetch(`${BASE}/api/Cliente?${q.toString()}`, {
      headers: { Authorization: `Bearer ${token}` },
    })
    const data = await res.json()
    if (data.codigo === 200) {
      clientes.value = data.data
    } else {
      error.value = data.mensaje ?? 'No se pudo cargar la lista de clientes.'
    }
  } catch {
    error.value = 'No se pudo conectar con el servidor. Verifique que la API esté en ejecución.'
  } finally {
    cargando.value = false
  }
}

onMounted(cargar)
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <div>
        <h1>Clientes</h1>
        <p class="sub">Clientes individuales y empresariales registrados en el sistema.</p>
      </div>
      <form class="buscador" @submit.prevent="cargar()">
        <input
          v-model="busqueda"
          type="search"
          placeholder="Buscar por nombre o NIT…"
          aria-label="Buscar cliente"
        />
        <button type="submit" :disabled="cargando">Buscar</button>
      </form>
    </header>

    <p v-if="error" class="error" role="alert">{{ error }}</p>

    <div class="tabla-wrap">
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Nombre / Razón social</th>
            <th>Tipo</th>
            <th>NIT</th>
            <th>Teléfono</th>
            <th>Correo</th>
            <th>Estado</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="cargando">
            <td colspan="7" class="vacio">Cargando clientes…</td>
          </tr>
          <tr v-else-if="!clientes.length">
            <td colspan="7" class="vacio">No hay clientes que coincidan con la búsqueda.</td>
          </tr>
          <tr v-for="c in clientes" :key="c.clienteId">
            <td class="num">{{ c.clienteId }}</td>
            <td class="fuerte">{{ c.nombreRazonSocial }}</td>
            <td><span class="chip-tipo">{{ c.tipoCliente }}</span></td>
            <td class="num">{{ c.nit }}</td>
            <td>{{ c.telefono ?? '—' }}</td>
            <td>{{ c.correo ?? '—' }}</td>
            <td>
              <span class="chip" :class="c.estado === 'ACTIVO' ? 'activo' : 'inactivo'">
                {{ c.estado === 'ACTIVO' ? 'Activo' : 'Inactivo' }}
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

.buscador {
  display: flex;
  gap: 8px;
}

.buscador input {
  border: 1px solid #d9def1;
  border-radius: 10px;
  padding: 8px 12px;
  font-size: 13.5px;
  min-width: 220px;
}

.buscador input:focus {
  outline: 2px solid #6d8bd8;
  outline-offset: 1px;
}

.buscador button {
  border: none;
  border-radius: 10px;
  background: #3d56a8;
  color: #fff;
  font-weight: 600;
  font-size: 13px;
  padding: 8px 16px;
  cursor: pointer;
}

.buscador button:disabled {
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
