// Cuentas desde el login (AuthController): registro, recuperar y cambiar contraseña (script 14)
import { apiFetch } from '@/core/api/apiFetch'

export interface RegistroForm {
  tipoCliente: 'INDIVIDUAL' | 'EMPRESARIAL'
  nombreRazonSocial: string
  nit: string
  telefono: string
  correo: string
  direccion: string
  contrasena: string
}

export interface MiCuenta {
  usuarioId: number
  nombreUsuario: string
  nombreCompleto: string
  correo: string
  telefono: string | null
  clienteId: number | null
  tipoCliente: string | null
  nit: string | null
  direccion: string | null
}

const post = (path: string, body: unknown, method: 'POST' | 'PUT' = 'POST') =>
  apiFetch<{ mensaje: string }>(path, { method, body: JSON.stringify(body) })

export const cuentaApi = {
  registro: (f: RegistroForm) => post('/api/auth/registro', {
    ...f,
    nombreRazonSocial: f.nombreRazonSocial.trim(),
    nit: f.nit.trim().toUpperCase(),
    correo: f.correo.trim().toLowerCase(),
    direccion: f.direccion.trim(),
  }),
  recuperar: (correo: string) => post('/api/auth/recuperar', { correo: correo.trim().toLowerCase() }),
  miCuenta: () => apiFetch<MiCuenta>('/api/auth/mi-cuenta'),
  actualizarMiCuenta: (d: { nombreCompleto: string; telefono: string; direccion: string | null }) =>
    apiFetch<MiCuenta>('/api/auth/mi-cuenta', { method: 'PUT', body: JSON.stringify(d) }),
  cambiarContrasena: (actual: string, nueva: string) => post('/api/auth/mi-contrasena', { actual, nueva }, 'PUT'),
}
