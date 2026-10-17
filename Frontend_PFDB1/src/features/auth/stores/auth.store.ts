import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { authService } from '../api/auth.service'
import type { UsuarioSesion } from '../types/auth.types'

const TOKEN_KEY = 'token'
const USER_KEY = 'usuario'
const PERMISOS_KEY = 'permisos'

function readJson<T>(key: string, fallback: T): T {
  try {
    const raw = sessionStorage.getItem(key)
    return raw ? (JSON.parse(raw) as T) : fallback
  } catch {
    return fallback
  }
}

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(sessionStorage.getItem(TOKEN_KEY))
  const usuario = ref<UsuarioSesion | null>(readJson<UsuarioSesion | null>(USER_KEY, null))
  const permisos = ref<string[]>(readJson<string[]>(PERMISOS_KEY, []))

  const isAuthenticated = computed(() => !!token.value)
  const rol = computed(() => (usuario.value?.roles ?? '').toUpperCase())
  const nombreCompleto = computed(() => usuario.value?.nombreCompleto ?? '')

  function tienePermiso(codigo: string): boolean {
    return permisos.value.includes(codigo)
  }

  /** Login: guarda el JWT y carga los permisos del usuario (cada inicio de sesión).
   * La sesión vive en sessionStorage: al cerrar la pestaña se cierra la sesión. */
  async function login(correo: string, password: string): Promise<void> {
    const resultado = await authService.login(correo, password)
    token.value = resultado.token
    usuario.value = resultado.usuario
    sessionStorage.setItem(TOKEN_KEY, resultado.token)
    sessionStorage.setItem(USER_KEY, JSON.stringify(resultado.usuario))

    const permisosUsuario = await authService.fetchPermisos()
    permisos.value = permisosUsuario
    sessionStorage.setItem(PERMISOS_KEY, JSON.stringify(permisosUsuario))
  }

  function logout(): void {
    token.value = null
    usuario.value = null
    permisos.value = []
    sessionStorage.removeItem(TOKEN_KEY)
    sessionStorage.removeItem(USER_KEY)
    sessionStorage.removeItem(PERMISOS_KEY)
  }

  return { token, usuario, permisos, isAuthenticated, rol, nombreCompleto, tienePermiso, login, logout }
})
