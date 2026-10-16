export interface UsuarioSesion {
  usuarioId: number
  nombreUsuario: string
  nombreCompleto: string
  correo: string
  telefono?: string | null
  roles: string
}

export interface ResultadoLogin {
  token: string
  expira: string
  usuario: UsuarioSesion
}

export interface FilaPermiso {
  permisoId: number
  rolId: number
  rol: string
  permiso: string
  activo: boolean | number
}
