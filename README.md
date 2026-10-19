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
| Lógica de negocio | C# · ASP.NET Core 8 Web API · Dapper · Microsoft.Data.SqlClient · JWT · Swagger | `Backend_PFDB1/` |
| Datos | Microsoft SQL Server 2022 (Docker local / SmarterASP en la nube) | `BD/` y `database/` |

## Estructura del repositorio

```
├── BD/BD_Conetner_BD1/      docker-compose.yml del SQL Server local
├── database/                scripts SQL
│   ├── 00_script_maestro.sql     TODO en un solo archivo (01 al 12 en orden), con índice de objetos
│   ├── 01_tablas.sql             27 tablas con PK, FK, UNIQUE, DEFAULT y CHECK
│   ├── 02_datos_iniciales.sql    catálogos y usuarios base
│   ├── 03_procedimientos.sql     sp_RegistrarOrden, sp_CambiarEstadoOrden y sp_LoginUsuario
│   ├── 04_procesos.sql           diagnóstico, reparación, repuestos, compras, funciones y vistas
│   ├── 05_datos_prueba.sql       datos de prueba con los mínimos del enunciado (sección 7)
│   ├── 06_facturacion.sql        facturación, pagos y entrega
│   ├── 07_triggers_indices_reportes.sql  triggers, índices y reportes
│   ├── 08_permisos.sql           tabla Permiso (menú y acciones por rol) → tabla 28
│   ├── 09_clientes_equipos_ordenes.sql   vistas y SP para crear clientes y equipos
│   ├── 10_sp_orden_usuario.sql   listado de órdenes y de usuarios
│   ├── 11_sp_cliente_equipo.sql  listar, actualizar, desactivar y activar clientes y equipos
│   ├── 12_mantenimientos.sql     repuestos, proveedores, bodegas, categorías, tipos de equipo y usuarios
│   └── 0X_pruebas_*.sql          pruebas de cada script (opcionales)
├── Backend_PFDB1/           API en ASP.NET Core 8
├── Frontend_PFDB1/          interfaz en Vue 3
├── docs/                    ER, arquitectura, flujos, normalización y manuales
└── README.md
```

**Contenido final de la base:** 28 tablas · 155 restricciones · 14 índices · 20 vistas · 4 funciones · 39 procedimientos · 10 triggers.

## Requisitos (computadora limpia)

| Programa | Versión | Para qué |
|---|---|---|
| [Git](https://git-scm.com/) o GitHub Desktop | cualquiera | clonar el repositorio |
| [.NET SDK](https://dotnet.microsoft.com/download/dotnet/8.0) | 8.0 | backend |
| [Node.js](https://nodejs.org/) | 22.12 o superior | frontend |
| SQL Server Management Studio (SSMS) o VS Code con la extensión **SQL Server (mssql)** | 20 o superior | ejecutar los scripts |
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | cualquiera | **solo** si la base va en local |
| Visual Studio 2022 Community (opcional) | 17.8 o superior | abrir y correr el backend |

```bash
git clone <url-del-repositorio>
cd ProyectoBaseDeDatosI
```

## Paso 1 – Base de datos

La base se crea completa con **un solo script**: `database/00_script_maestro.sql`.
Ese archivo junta los scripts 01 al 12 en el orden correcto (incluye los datos de prueba del 05).

> ⚠️ El script **borra las tablas si ya existen**. Sobre una base con datos, sacar un respaldo antes.

### Opción A – SQL Server local con Docker

```bash
cd BD/BD_Conetner_BD1
cp .env.example .env        # en Windows: copy .env.example .env
# editar .env y poner una contraseña segura para el usuario sa
docker compose up -d
```

1. Conectarse en SSMS a `localhost,1441` con el usuario `sa` y la contraseña del `.env`.
2. Abrir `database/00_script_maestro.sql`.
3. Quitar el `--` de las 4 líneas que están después del encabezado (crean y seleccionan la base `TechCare`):
   ```sql
   IF DB_ID('TechCare') IS NULL CREATE DATABASE TechCare;
   GO
   USE TechCare;
   GO
   ```
4. Ejecutar todo (F5). Al final debe mostrar el mensaje de cada sección `>> 1/12` … `>> 12/12` sin errores.

### Opción B – SQL Server en la nube (SmarterASP)

1. Conectarse en SSMS al servidor de SmarterASP con el usuario de la base (los datos los tiene el grupo; **no están en el repositorio**).
2. Seleccionar la base del proyecto en la lista de bases.
3. Abrir `database/00_script_maestro.sql`, **dejar comentadas** las 4 líneas del `CREATE DATABASE` / `USE` y ejecutar todo.

### Verificar

```sql
SELECT type_desc, COUNT(*) AS Cantidad
FROM sys.objects
WHERE type IN ('U', 'V', 'P', 'FN', 'IF', 'TF', 'TR')
GROUP BY type_desc;
-- Debe dar: 28 tablas, 20 vistas, 39 procedimientos y 10 triggers; las funciones (FN, IF o TF) suman 4.
```

## Paso 2 – Backend (API)

Las credenciales **no están en `appsettings.json`** (ahí quedan vacías). Se guardan con los **secretos de usuario** de .NET, que viven en la computadora de cada integrante, fuera del repositorio:
`%APPDATA%\Microsoft\UserSecrets\techcare-backend-pfdb1\secrets.json`

El proyecto ya trae su `UserSecretsId`, así que **no** hace falta `dotnet user-secrets init`. En una terminal:

```powershell
cd Backend_PFDB1/Backend_API_Proyevto_Base_de_Datos_I

# 1) Cadena de conexión (usar comillas simples si la contraseña tiene símbolos)
#    Docker local:
dotnet user-secrets set 'ConnectionStrings:DefaultConnection' 'Server=localhost,1441;Database=TechCare;User Id=sa;Password=TU_PASSWORD;TrustServerCertificate=True;'
#    SmarterASP: la misma forma, con el servidor, la base, el usuario y la contraseña de la nube.

# 2) Clave para firmar los tokens JWT (mínimo 32 caracteres). Para generar una al azar en PowerShell:
#    $b = New-Object byte[] 48; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b); [Convert]::ToBase64String($b)
dotnet user-secrets set 'Jwt:Key' 'PEGUE_AQUI_LA_CLAVE_GENERADA'

# 3) Revisar que quedaron guardadas y ejecutar
dotnet user-secrets list
dotnet run
```

> Con Visual Studio: clic derecho al proyecto → **Administrar secretos de usuario** y pegar:
> ```json
> {
>   "Jwt": { "Key": "PEGUE_AQUI_LA_CLAVE_GENERADA" },
>   "ConnectionStrings": { "DefaultConnection": "Server=...;Database=...;User Id=...;Password=...;TrustServerCertificate=True;" }
> }
> ```

- Swagger: http://localhost:5247/swagger
- Prueba de conexión: `GET http://localhost:5247/api/test/conexion` → debe responder `"conectado": true`

**Cómo se leen:** ASP.NET Core carga `appsettings.json` → `appsettings.Development.json` → **secretos de usuario** (solo en modo Development) → variables de entorno. Cada fuente sobrescribe a la anterior, por eso los valores vacíos del `appsettings.json` se reemplazan por los de `secrets.json`. En un servidor de producción se usarían variables de entorno (`ConnectionStrings__DefaultConnection`, `Jwt__Key`) sin cambiar código.

## Paso 3 – Frontend

```bash
cd Frontend_PFDB1
cp .env.example .env   # en Windows: copy .env.example .env   (VITE_API_BASE_URL=http://localhost:5247)
npm install       # o: bun install
npm run dev       # o: bun run dev
```

Abrir http://127.0.0.1:5173 e iniciar sesión con un usuario de prueba.

> El backend tiene que estar corriendo antes de iniciar sesión; si no, la web muestra **Network Error**.

## Usuarios de prueba

Contraseña de todos: `TechCare2026!` (en la base se guarda solo el hash SHA-256, nunca el texto). Se inicia sesión con el **correo**.

| Correo | Rol | Creado por |
|---|---|---|
| `admin@techcare.com.gt` | ADMINISTRADOR | 02 |
| `recepcion1@techcare.com.gt` | RECEPCION | 02 |
| `tecnico1@techcare.com.gt`, `tecnico2@techcare.com.gt` | TECNICO | 02 |
| `bodega1@techcare.com.gt` | BODEGA | 02 |
| `caja1@techcare.com.gt` | CAJA | 02 |
| `recepcion2@techcare.com.gt` | RECEPCION y CAJA | 05 |
| `tecnico3@techcare.com.gt`, `tecnico4@techcare.com.gt` | TECNICO | 05 |
| `bodega2@techcare.com.gt` | BODEGA | 05 |
| `caja2@techcare.com.gt` | CAJA | 05 |

## Problemas comunes

| Mensaje | Causa | Solución |
|---|---|---|
| `Jwt:Key no está configurada…` o `No se encontró la cadena de conexión…` al iniciar el backend | faltan los secretos de usuario | hacer el **Paso 2** |
| `Network Error` en el login | el backend no está corriendo | ejecutar `dotnet run` (o ▶ en Visual Studio) |
| `Correo o contraseña incorrectos` | se escribió el usuario en vez del correo, o el usuario está inactivo | usar el correo completo, p. ej. `admin@techcare.com.gt` |
| `Login failed for user…` en la consola del backend | la contraseña de la cadena de conexión es incorrecta | corregirla en los secretos de usuario |
| `La base ya tiene órdenes o datos de prueba` al correr el 05 suelto | el 05 solo corre sobre una base recién creada | usar el `00_script_maestro.sql` completo |

## Forma de trabajo con ramas

1. Cada integrante trabaja en **su rama** (`rama_nombre`).
2. Al terminar una parte: commit → push a su rama.
3. Se une a `rama_Combinada` con *Merge into current branch* (en `rama_Combinada` solo entran merges).
4. Cuando todo funciona, se pasa a `main`.

**Nunca subir** contraseñas, archivos `.env`, `secrets.json`, respaldos `.bak`, `package-lock.json`, ni las carpetas `bin/`, `obj/` o `node_modules/`.

## Avance

- [x] **Semana 1 – Diseño:** caso y reglas de negocio, ER, modelo relacional, normalización 3FN, arquitectura, diagramas de flujo, repositorio inicial
- [x] **Semana 2 – Base + núcleo:** base v1 y datos iniciales, login y roles, clientes, equipos y órdenes
- [x] **Semana 3 – Procesos:** diagnóstico, reparación, inventario, compras, procedimientos, transacciones, funciones, primeros reportes
- [x] **Semana 4 – Integración:** facturación, pagos, entrega, vistas, triggers, índices, 12 reportes, mantenimientos y script maestro
- [ ] **Cierre:** pruebas T01–T14 con evidencia, manual técnico, manual de usuario y defensa
