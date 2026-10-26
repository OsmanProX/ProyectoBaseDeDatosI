// fetch para las pantallas que necesitan el mensaje exacto de la API (Clientes, Equipos).
// Usa la misma URL y el mismo token que httpClient, y lee { codigo, mensaje, data }.
import { env } from '@/core/config/env'

export class ApiFetchError extends Error {
  constructor(
    message: string,
    public readonly status: number,
  ) {
    super(message)
    this.name = 'ApiFetchError'
  }
}

interface RespuestaApi<T> {
  codigo?: number
  mensaje?: string
  data?: T
  errors?: Record<string, string[]> // validación automática de ASP.NET
}

// Quita el prefijo técnico que agrega el backend ("Crear(): ", "Actualizar(): ", ...)
const sinPrefijo = (texto: string) => texto.replace(/^\w+\(\):\s*/, '')

export async function apiFetch<T>(
  path: string,
  init?: RequestInit,
  traducir: (mensaje: string) => string = (m) => m,
): Promise<T> {
  let res: Response
  const token = sessionStorage.getItem('token')
  try {
    res = await fetch(`${env.VITE_API_BASE_URL}${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
    })
  } catch {
    throw new ApiFetchError('No se pudo conectar con el servidor. Verifique que la API esté en ejecución.', 0)
  }
  if (res.status === 401) {
    // Igual que httpClient: sesión vencida → limpiar y volver al login
    sessionStorage.removeItem('token')
    sessionStorage.removeItem('usuario')
    sessionStorage.removeItem('permisos')
    window.location.href = '/login'
    throw new ApiFetchError('Su sesión venció. Vuelva a iniciar sesión.', 401)
  }
  const body = (await res.json().catch(() => ({}))) as RespuestaApi<T>
  if (!res.ok || (body.codigo !== undefined && body.codigo >= 400)) {
    const validacion = body.errors ? Object.values(body.errors).flat().join(' ') : ''
    const sinPermiso = res.status === 403 ? 'Su usuario no tiene permiso para realizar esta acción.' : ''
    const mensaje = validacion || body.mensaje || sinPermiso || 'Ocurrió un error inesperado.'
    throw new ApiFetchError(traducir(sinPrefijo(mensaje)), res.status)
  }
  return body.data as T
}
