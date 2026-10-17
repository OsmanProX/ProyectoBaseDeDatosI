export interface TreeItem {
  id: number
  parentId: number | null
  name: string
  order: number
}
export interface TreeNode<T extends TreeItem = TreeItem> {
  item: T
  children: TreeNode<T>[]
}
export function buildTree<T extends TreeItem>(items: T[]): TreeNode<T>[] {
  const ids = new Set(items.map((item) => item.id))
  const visited = new Set<number>()
  function branch(parentId: number | null): TreeNode<T>[] {
    return items
      .filter(
        (item) =>
          (parentId === null
            ? !item.parentId || !ids.has(item.parentId)
            : item.parentId === parentId) && !visited.has(item.id),
      )
      .sort((a, b) => a.order - b.order || a.name.localeCompare(b.name, 'es'))
      .map((item) => {
        visited.add(item.id)
        return { item, children: branch(item.id) }
      })
  }
  const roots = branch(null)
  // Los ciclos en datos externos no deben ocultar registros ni bloquear la navegación.
  for (const item of items)
    if (!visited.has(item.id)) {
      visited.add(item.id)
      roots.push({ item, children: branch(item.id) })
    }
  return roots
}
export function descendantIds(items: TreeItem[], id: number): Set<number> {
  const result = new Set<number>([id])
  let changed = true
  while (changed) {
    changed = false
    for (const item of items)
      if (item.parentId !== null && result.has(item.parentId) && !result.has(item.id)) {
        result.add(item.id)
        changed = true
      }
  }
  return result
}
