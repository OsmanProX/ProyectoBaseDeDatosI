<script setup lang="ts">
import { onMounted, ref } from 'vue'

interface UsuarioFila {
  usuarioId: number
  nombreUsuario: string
  nombreCompleto: string
  correo: string
  telefono: string | null
  activo: boolean | number
  roles: string | null
}

const BASE = import.meta.env.VITE_API_URL ?? 'http://localhost:5245'

const usuarios = ref<UsuarioFila[]>([])
const cargando = ref(false)
const error = ref('')

onMounted(async () => {
  cargando.value = true
  try {
    const token = sessionStorage.getItem('token')
    const res = await fetch(`${BASE}/api/usuario`, {
      headers: { Authorization: `Bearer ${token}` },
    })
    const data = await res.json()
    if (data.codigo === 200) {
      usuarios.value = data.data
    } else {
      error.value = data.mensaje ?? 'No se pudo cargar la lista de usuarios.'
    }
  } catch {
    error.value = 'No se pudo conectar con el servidor. Verifique que la API est├® en ejecuci├│n.'
  } finally {
    cargando.value = false
  }
})

const esActivo = (u: UsuarioFila) => u.activo === true || u.activo === 1
</script>

<template>
  <main class="pagina">
    <header class="cabecera">
      <div>
        <h1>Usuarios</h1>
        <p class="sub">Usuarios registrados en el sistema y sus roles.</p>
      </div>
    </header>

    <p v-if="error" class="error" role="alert">{{ error }}</p>

    <div class="tabla-wrap">
      <table>
        <thead>
          <tr>
            <th>ID</th>
            <th>Nombre completo</th>
            <th>Nickname</th>
            <th>Correo</th>
            <th>Tel├®fono</th>
            <th>Roles</th>
            <th>Estado</th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="cargando">
            <td colspan="7" class="vacio">Cargando usuariosÔÇª</td>
          </tr>
          <tr v-else-if="!usuarios.length">
            <td colspan="7" class="vacio">No hay usuarios registrados.</td>
          </tr>
          <tr v-for="u in usuarios" :key="u.usuarioId">
            <td class="num">{{ u.usuarioId }}</td>
            <td class="fuerte">{{ u.nombreCompleto }}</td>
            <td>@{{ u.nombreUsuario }}</td>
            <td>{{ u.correo }}</td>
            <td>{{ u.telefono ?? 'ÔÇö' }}</td>
            <td><span class="chip-rol">{{ u.roles ?? 'SIN ROL' }}</span></td>
            <td>
              <span class="chip" :class="esActivo(u) ? 'activo' : 'inactivo'">
                {{ esActivo(u) ? 'Activo' : 'Inactivo' }}
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
  margin-bottom: 18px;
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
}

.chip-rol {
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
