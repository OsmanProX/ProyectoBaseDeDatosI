// Usuarios/empleados (UsuarioController): solo ADMINISTRADOR.
import { apiFetch } from '@/core/api/apiFetch'

export interface UsuarioFila {
  usuarioId: number
  nombreUsuario: string
  nombreCompleto: string
  correo: string
  telefono: string | null
  activo: boolean | number
  roles: string | null
  rolIds: string | null // ej. "2" o "2,5"
}

export interface Rol {
  rolId: number
  nombre: string
  descripcion: string | null
}

export interface UsuarioForm {
  nombreUsuario: string
  nombreCompleto: string
  correo: string
  telefono: string
  contrasena: string // solo al crear
  rolId: number
}

const json = (method: 'POST' | 'PUT', body: unknown): RequestInit => ({ method, body: JSON.stringify(body) })

export const usuariosApi = {
  lista: () => apiFetch<UsuarioFila[]>('/api/usuario'),
  roles: () => apiFetch<Rol[]>('/api/usuario/roles'),
  guardar: (id: number | null, f: UsuarioForm) => {
    const body = {
      nombreUsuario: f.nombreUsuario,
      nombreCompleto: f.nombreCompleto,
      correo: f.correo,
      telefono: f.telefono,
      contrasena: id ? null : f.contrasena,
      roles: [f.rolId],
    }
    return apiFetch<UsuarioFila>(id ? `/api/usuario/${id}` : '/api/usuario', json(id ? 'PUT' : 'POST', body))
  },
  estado: (id: number, activo: boolean) => apiFetch(`/api/usuario/${id}/estado`, json('PUT', { activo })),
  contrasena: (id: number, contrasena: string) =>
    apiFetch(`/api/usuario/${id}/contrasena`, json('PUT', { contrasena })),
}
