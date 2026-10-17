import axios from 'axios'
import type { AxiosRequestConfig, AxiosResponse } from 'axios'
import { env } from '@/core/config/env'
import { unwrapResponse } from './apiResponse'
import { isCancellation, normalizeApiError } from './apiError'

export const httpClient = axios.create({
  baseURL: env.VITE_API_BASE_URL,
  timeout: 15000,
  headers: { Accept: 'application/json' },
})
httpClient.interceptors.request.use((config) => {
  // El token lo guarda el auth store en sessionStorage al iniciar sesión
  const token = sessionStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})
httpClient.interceptors.response.use(
  (response: AxiosResponse<unknown>) => {
    // Conservamos AxiosResponse para que el tipo de Axios siga siendo veraz; data ya queda desenvuelto.
    response.data = unwrapResponse(response.data)
    return response
  },
  (error: unknown) => {
    // HTTP 401: sesión vencida o inválida → limpiar y volver al login
    if (axios.isAxiosError(error) && error.response?.status === 401) {
      sessionStorage.removeItem('token')
      sessionStorage.removeItem('usuario')
      sessionStorage.removeItem('permisos')
      if (!window.location.pathname.startsWith('/login')) {
        window.location.href = '/login'
      }
    }
    return Promise.reject(isCancellation(error) ? error : normalizeApiError(error))
  },
)
export async function requestData<T>(config: AxiosRequestConfig): Promise<T> {
  const response = await httpClient.request<T>(config)
  return response.data
}
