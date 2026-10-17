import axios from 'axios'
export type ApiErrorKind = 'network' | 'timeout' | 'http' | 'business' | 'unexpected'
export class ApiError extends Error {
  constructor(
    message: string,
    public readonly kind: ApiErrorKind = 'unexpected',
    public readonly status?: number,
    public readonly rejection?: unknown,
  ) {
    super(message)
    this.name = 'ApiError'
  }
}
export function normalizeApiError(error: unknown): ApiError {
  if (error instanceof ApiError) return error
  if (axios.isAxiosError(error)) {
    if (error.code === 'ECONNABORTED')
      return new ApiError('La solicitud tardó demasiado. Intenta nuevamente.', 'timeout')
    if (!error.response)
      return new ApiError(
        'No se pudo conectar con la API. Comprueba tu conexión y que el servidor esté iniciado.',
        'network',
      )
    const status = error.response.status
    const message =
      status >= 500
        ? 'El servidor no pudo completar la operación.'
        : status === 401
          ? 'La API requiere autorización.'
          : status === 404
            ? 'No se encontró el recurso solicitado.'
            : 'Revisa los datos enviados. La API rechazó la solicitud.'
    return new ApiError(message, 'http', status, error.response.data)
  }
  return new ApiError(error instanceof Error ? error.message : 'Ocurrió un error inesperado.')
}
export function isCancellation(error: unknown): boolean {
  return axios.isCancel(error) || (error instanceof DOMException && error.name === 'AbortError')
}
