import {
  ClipboardList,
  Contact,
  Laptop,
  LayoutDashboard,
  Users,
  ShieldCheck,
  PanelsTopLeft,
  Link2,
  Folder,
  FileText,
  Settings,
  Home,
  BookOpen,
  Wrench,
  Package,
} from 'lucide-vue-next'
export const iconRegistry = {
  ClipboardList,
  Contact,
  Laptop,
  LayoutDashboard,
  Users,
  ShieldCheck,
  PanelsTopLeft,
  Link2,
  Folder,
  FileText,
  Settings,
  Home,
  BookOpen,
  Wrench,
  Package,
}
export type IconName = keyof typeof iconRegistry

const iconLabels: Record<IconName, string> = {
  ClipboardList: 'Órdenes',
  Contact: 'Clientes',
  Laptop: 'Equipos',
  LayoutDashboard: 'Panel',
  Users: 'Usuarios',
  ShieldCheck: 'Seguridad',
  PanelsTopLeft: 'Módulos',
  Link2: 'Enlace',
  Folder: 'Carpeta',
  FileText: 'Documento',
  Settings: 'Ajustes',
  Home: 'Inicio',
  BookOpen: 'Biblioteca',
  Wrench: 'Taller',
  Package: 'Inventario',
}

export const iconCatalog = (Object.keys(iconRegistry) as IconName[]).map((name) => ({
  name,
  label: iconLabels[name],
  component: iconRegistry[name],
}))

export function resolveIcon(name: string) {
  return name in iconRegistry ? iconRegistry[name as IconName] : Folder
}
export const iconOptions = iconCatalog.map(({ name, label }) => ({ value: name, label }))
