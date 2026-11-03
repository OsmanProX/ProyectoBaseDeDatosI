export interface UsuarioSesion {
  usuarioId: number
  nombreUsuario: string
  nombreCompleto: string
  correo: string
  telefono?: string | null
  roles: string
  /** true = entró con contraseña temporal: debe cambiarla antes de continuar */
  debeCambiarContrasena?: boolean
}

export interface ResultadoLogin {
  token: string
  expira: string
  usuario: UsuarioSesion
}
