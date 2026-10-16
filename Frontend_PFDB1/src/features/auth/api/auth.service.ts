import axios from 'axios'
import { env } from '@/core/config/env'
import { requestData } from '@/core/api/httpClient'
import type { FilaPermiso, ResultadoLogin } from '../types/auth.types'

// Axios propio sin los interceptores de httpClient: el login trae el token
// en la raíz de la respuesta (no dentro de data) y no debe desempaquetarse.
const apiAuth = axios.create({
  baseURL: env.VITE_API_BASE_URL,
  timeout: 15000,
  headers: { Accept: 'application/json' },
})

export const authService = {
  /**
   * Login contra sp_LoginUsuario vía POST /api/Auth/login.
   */
  async login(correo: string, password: string): Promise<ResultadoLogin> {
    try {
      const response = await apiAuth.post('/api/Auth/login', { correo, password })
      const body = response.data as {
        codigo?: number
        mensaje?: string
        token?: string
        expira?: string
        usuario?: ResultadoLogin['usuario']
      }
      if (body.codigo !== 200 || !body.token || !body.usuario) {
        throw new Error(body.mensaje ?? 'Correo o contraseña incorrectos.')
      }
      return { token: body.token, expira: body.expira ?? '', usuario: body.usuario }
    } catch (error) {
      // El login responde HTTP 401 con el mensaje en el cuerpo
      if (axios.isAxiosError(error) && error.response?.data) {
        const cuerpo = error.response.data as { mensaje?: string }
        if (cuerpo.mensaje) throw new Error(cuerpo.mensaje)
      }
      throw error
    }
  },

  /** Permisos activos del usuario autenticado (GET /api/Permiso con Bearer). */
  async fetchPermisos(): Promise<string[]> {
    const filas = await requestData<FilaPermiso[]>({ method: 'GET', url: '/api/Permiso' })
    const activos = (filas ?? []).filter((f) => f.activo === true || f.activo === 1)
    return [...new Set(activos.map((f) => f.permiso))]
  },
}
