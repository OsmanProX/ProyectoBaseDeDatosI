import { ApiError } from './apiError'
// El contrato del proyecto usa 200 en el cuerpo, incluso cuando HTTP responde 200 con un rechazo.
export const API_CODES = { success: [200] as readonly number[] } as const
export function unwrapResponse<T = unknown>(body: unknown): T {
  if (
    !body ||
    typeof body !== 'object' ||
    !('codigo' in body) ||
    typeof body.codigo !== 'number' ||
    !('data' in body)
  ) {
    throw new ApiError('La API devolvió una respuesta con formato inesperado.')
  }
  if (!API_CODES.success.includes(body.codigo)) {
    const message =
      'mensaje' in body && typeof body.mensaje === 'string'
        ? body.mensaje
        : 'La operación fue rechazada.'
    throw new ApiError(
      message,
      'business',
      body.codigo,
      'data_rechazo' in body ? body.data_rechazo : undefined,
    )
  }
  return body.data as T
}
