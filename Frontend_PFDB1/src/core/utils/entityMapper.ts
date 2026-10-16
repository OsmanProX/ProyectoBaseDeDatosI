import type { BackendEntity, Entity } from '@/core/types/api.types'
export const fromBackendEntity = (raw: BackendEntity): Entity => ({
  id: raw.id,
  active: raw.activo === 1,
  stateId: raw.id_estado,
  notes: raw.observaciones ?? '',
})
export const toBackendEntity = (model: Entity): BackendEntity => ({
  id: model.id,
  activo: model.active ? 1 : 0,
  id_estado: model.stateId,
  observaciones: model.notes,
})
