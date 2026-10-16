import {
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
} from 'lucide-vue-next'
export const iconRegistry = {
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
}
export type IconName = keyof typeof iconRegistry

const iconLabels: Record<IconName, string> = {
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
