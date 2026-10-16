export interface ApiResponse<T> {
  codigo: number
  mensaje: string | null
  data: T
  data_rechazo?: unknown
}
export interface Entity {
  id: number
  active: boolean
  stateId: number | null
  notes: string
}
export interface BackendEntity {
  // TODO: validar contra Swagger/Oracle el ID inicial 0 y los indicadores 0/1.
  id: number
  activo: number | null
  id_estado: number | null
  observaciones: string | null
}
export interface DeleteInput {
  id: number
}
export type MutationOutput = number | null
export interface CrudService<T, Input> {
  list(signal?: AbortSignal): Promise<T[]>
  create(input: Input, signal?: AbortSignal): Promise<MutationOutput>
  update(input: Input, signal?: AbortSignal): Promise<MutationOutput>
  remove(id: number, signal?: AbortSignal): Promise<MutationOutput>
}
export interface Option {
  value: string | number
  label: string
}
export interface Column {
  key: string
  label: string
  sortable?: boolean
}
export interface DisplayRow {
  id: number
  active: boolean
  stateId: number | null
  [key: string]: unknown
}
