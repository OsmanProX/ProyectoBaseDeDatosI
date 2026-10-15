# TechCare Solutions – Sistema de Servicio Técnico

Proyecto Final de **Base de Datos I** – Universidad Mariano Gálvez de Guatemala (Sede La Florida, Zona 19).
Catedrático: Ing. Manuel Alejandro Díaz Barillas · Sección A · Octubre 2026.

Sistema para controlar el servicio técnico de equipos de cómputo: clientes, equipos, órdenes de servicio, diagnóstico, reparación, repuestos, inventario por bodega, compras, facturación, pagos y entrega.

## Integrantes

| Nombre | Rama |
|---|---|
| Kevin Josué Fuentes Vásquez | `rama_kevin` |
| Osman Javier Tobías Ramírez | `rama_osman` |
| Jeyling Juridia Ajcalon Méndez | `rama_jeyling` |
| Gerson Daniel Gabriel Huinac | `rama_gerson` |
| Antonio Alexander Rabinal Bos | `rama_antonio` |

## Arquitectura (3 capas)

```
Frontend (Vue 3)  →  HTTP / JSON  →  Backend API (ASP.NET Core 8)  →  SQL Server 2022
```
El frontend **nunca** se conecta directo a SQL Server; todo pasa por la API.

| Capa | Tecnología | Carpeta |
|---|---|---|
| Presentación | Vue 3 + Vite + TypeScript | `Frontend_PFDB1/` |
| Lógica de negocio | C# · ASP.NET Core 8 Web API · Microsoft.Data.SqlClient · Swagger | `Backend_PFDB1/` |
| Datos | Microsoft SQL Server 2022 (Docker local / SmarterASP en la nube) | `BD/` y `database/` |

## Estructura del repositorio

```
├── BD/BD_Conetner_BD1/      docker-compose.yml del SQL Server local
├── database/                scripts SQL (se ejecutan en orden)
│   ├── 01_tablas.sql             27 tablas con PK, FK, UNIQUE, DEFAULT y CHECK
│   ├── 02_datos_iniciales.sql    catálogos, usuarios y datos de prueba
│   ├── 03_procedimientos.sql     sp_RegistrarOrden y sp_CambiarEstadoOrden
│   └── 03_pruebas_procedimientos.sql  pruebas de los procedimientos
├── Backend_PFDB1/           API en ASP.NET Core
├── Frontend_PFDB1/          interfaz en Vue
├── docs/                    ER, arquitectura, flujos, normalización y manuales
└── README.md
```

## Requisitos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Node.js 20+](https://nodejs.org/) o [Bun](https://bun.sh/)
- SSMS, DBeaver o VS Code con la extensión **SQL Server (mssql)**

## Cómo levantar el proyecto

### 1. Base de datos (Docker)

```bash
cd BD/BD_Conetner_BD1
cp .env.example .env        # en Windows: copy .env.example .env
# editar .env y poner una contraseña segura para el usuario sa
docker compose up -d
```

Conectarse a `localhost,1441` con el usuario `sa` y ejecutar **en orden**:

1. `database/01_tablas.sql` → quitar el `--` de las líneas 8 a 11 (crean la base `TechCare`) y ejecutar todo. Debe mostrar **27 tablas**.
2. `database/02_datos_iniciales.sql` → quitar el `--` de `USE TechCare;` y ejecutar todo.
3. `database/03_procedimientos.sql` → igual que el anterior.
4. (Opcional) `database/03_pruebas_procedimientos.sql` → prueba los procedimientos.

> En SmarterASP (nube) se dejan esas líneas y el `USE` comentados: se selecciona la base `db_acf53d_dbfinal2026` y se ejecuta todo.

### 2. Backend (API)

La cadena de conexión **no se escribe en `appsettings.json`**; se guarda con *user-secrets* (queda solo en tu computadora):

```bash
cd Backend_PFDB1/Backend_API_Proyevto_Base_de_Datos_I
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Server=localhost,1441;Database=TechCare;User Id=sa;Password=TU_PASSWORD;TrustServerCertificate=True;"
dotnet run
```

- Swagger: http://localhost:5245/swagger
- Prueba de conexión: `GET http://localhost:5245/api/test/conexion` → debe responder `"conectado": true`

### 3. Frontend

```bash
cd Frontend_PFDB1
bun install        # o: npm install
bun run dev        # o: npm run dev
```

Abrir http://localhost:5173

## Usuarios de prueba

Creados por `02_datos_iniciales.sql`. Contraseña de todos: `TechCare2026!` (guardada como hash, solo para pruebas).

| Usuario | Rol |
|---|---|
| `admin` | ADMINISTRADOR |
| `recepcion1` | RECEPCION |
| `tecnico1`, `tecnico2` | TECNICO |
| `bodega1` | BODEGA |
| `caja1` | CAJA |

## Forma de trabajo con ramas

1. Cada integrante trabaja en **su rama** (`rama_nombre`).
2. Al terminar una parte: `git add` → `git commit` → `git push`.
3. Se abre un **Pull Request** hacia `rama_Combinada` para revisar e integrar.
4. Cuando todo funciona, se pasa a `main`.

**Nunca subir** contraseñas, archivos `.env`, ni las carpetas `bin/`, `obj/` o `node_modules/`.

## Avance

- [x] **Semana 1 – Diseño:** caso y reglas de negocio, ER, modelo relacional, normalización 3FN, arquitectura, diagramas de flujo, repositorio inicial
- [ ] **Semana 2 – Base + núcleo:** base v1 y datos iniciales (scripts listos), login y roles, clientes, equipos y órdenes
- [ ] **Semana 3 – Procesos:** diagnóstico, reparación, inventario, compras, procedimientos, transacciones, funciones, primeros reportes
- [ ] **Semana 4 – Integración:** facturación, pagos, entrega, vistas, triggers, índices, 12 reportes, pruebas y manuales
