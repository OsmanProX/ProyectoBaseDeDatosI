import { describe, expect, it } from 'vitest'
import { buildTree, descendantIds } from './tree'

describe('árbol de menús', () => {
  const items = [
    { id: 1, parentId: null, name: 'Raíz', order: 2 },
    { id: 2, parentId: 1, name: 'Hijo', order: 1 },
    { id: 3, parentId: 999, name: 'Huérfano', order: 0 },
  ]
  it('ordena las raíces y conserva los hijos y los huérfanos', () => {
    const tree = buildTree(items)
    expect(tree.map((node) => node.item.id)).toEqual([3, 1])
    expect(tree[1]?.children[0]?.item.id).toBe(2)
  })
  it('termina aun cuando los datos contienen ciclos', () => {
    const cyclic = [
      { id: 1, parentId: 2, name: 'Uno', order: 0 },
      { id: 2, parentId: 1, name: 'Dos', order: 0 },
    ]
    expect(buildTree(cyclic)[0]?.children[0]?.item.id).toBe(2)
    expect(descendantIds(cyclic, 1)).toEqual(new Set([1, 2]))
  })
})
