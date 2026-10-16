# AGENTS.md

## Repo layout (monorepo, 3 independent parts)

- `Backend_PFDB1/Backend_API_Proyevto_Base_de_Datos_I/` — ASP.NET Core 8 Web API (C#, controller-based, no EF; ADO.NET `Microsoft.Data.SqlClient` + Dapper). Solution file is `.slnx`.
- `Frontend_PFDB1/` — Vue 3 + TS + Vite (package manager is **Bun** — `bun.lock`, no npm lockfile). Still template-level; Vite dev proxy `/api` → `http://localhost:5245`.
- `BD/BD_Conetner_BD1/docker-compose.yml` — SQL Server 2022 local: port **1441** (not 1433). SA password in `BD/BD_Conetner_BD1/.env` (copy from `.env.example`); never commit `.env`.
- `SCRIPT DE PROYECTO.sql` (root) — full schema, **27 tables** (taller de soporte: seguridad, clientes/equipos, órdenes, diagnóstico/reparación, inventario/compras, facturación/pagos). Already executed on Azure DB `db_acf53d_dbfinal2026`.

## Cloud DB facts (verified 2026-10-15)

- Server: `sql5113.site4now.net` (credentials in `appsettings.json` `DefaultConnection`).
- Seed users: `admin`, `recepcion1`, `tecnico1`, `tecnico2`, `bodega1`, `caja1` — password `TechCare2026!` for all; stored as SHA256 hex **uppercase** in `Usuario.ContrasenaHash`.
- Stored procedures exist **only in the DB** (no .sql file in repo): `sp_RegistrarOrden` (crea orden en RECIBIDO + primer historial; valida cliente/equipo/rol RECEPCION|ADMIN; número OS-AAAA-0001) and `sp_CambiarEstadoOrden` (transiciones 1→2/7, 2→3/7, 3→4/7, 4→5/7; permisos por rol; historial). Extract with `SELECT OBJECT_DEFINITION(OBJECT_ID('sp_...'))` via sqlcmd before using them locally.
- `EstadoOrden` ids: 1 RECIBIDO, 2 DIAGNOSTICO, 3 ESPERANDO_AUTORIZACION, 4 REPARACION, 5 LISTO, 6 ENTREGADO, 7 CANCELADO.

No CI, no tests, no lint. Verify backend with `dotnet build` (run in the backend folder).

## Commands

```bash
# Backend (must run from Backend_PFDB1/Backend_API_Proyevto_Base_de_Datos_I)
dotnet build
dotnet run   # profile "http": http://localhost:5245, Swagger at /swagger

# Frontend (from Frontend_PFDB1)
bun run dev      # Vite dev server (port 5173), proxies /api to the backend
bun run build    # vue-tsc + vite build

# Probe the cloud DB (password contains #, keep quotes)
sqlcmd -S sql5113.site4now.net -d db_acf53d_dbfinal2026 -U db_acf53d_dbfinal2026_admin -P "#Kfuentes21" -C -Q "SELECT 1"
```

## Backend conventions (match existing code)

- Structure mirrors a class-demo pattern: `BD/` (DBContext factory), `DTO/` (DTOs hold their own data access via `SetConexion(DBContext)` + Dapper; they return `ResponseDto { codigo, mensaje, data }`), `Models/`, `Services/` (JwtService), `Controllers/`.
- Controllers wrap every call in try/catch and return `ResponseDto`-shaped bodies; error codes live in the body (`codigo`), not only the HTTP status.
- Business endpoints (`/api/cliente`, `/api/equipo`, `/api/orden`) are `[Authorize]` — get a token first via `POST /api/auth/login`.
- Ordenes go through the stored procedures (`sp_RegistrarOrden`, `sp_CambiarEstadoOrden`) via Dapper `ExecuteAsync(..., CommandType.StoredProcedure)` with `DynamicParameters` OUTPUT params (`@OrdenId`, `@NumeroOrden`). Never re-implement that logic in C#.
- Always use Dapper parameters — never string-concatenate SQL (an older demo project this was based on had SQL injection; do not copy that pattern).
- Login compares SHA256 hex (uppercase) of the provided password with `ContrasenaHash` (also accepts plain match).
- JWT config lives in `appsettings.json` under `Jwt`. `Program.cs` requires `Jwt:Key` at startup — removing it breaks the app.
- Pipeline order in `Program.cs`: `UseSwagger` → `UseCors("Frontend")` → `UseAuthentication` → `UseAuthorization`.
- CORS policy `Frontend` allows origin `http://localhost:5173` only.

## Frontend integration status

- `vite.config.ts` proxies `/api` → `http://localhost:5245`; call the API with relative URLs (`fetch('/api/auth/login')`).
- No router/store/HTTP client/login page yet — any real integration starts from scratch.

## Gotchas

- `.gitignore` only covers `.vs/`, `*.vsidx`, `*.slnx` — `bin/` and `obj/` build output is still tracked in git; don't commit new build artifacts.
- `appsettings.json` contains real production DB credentials in plaintext — treat as sensitive; never log or expose them.
- Local Docker DB (port 1441) is NOT seeded and does NOT have the SPs; the cloud DB is the only complete one.
- `sp_CambiarEstadoOrden` rejects estado 6 (ENTREGADO — va por el proceso de entrega con factura/pagos) and estado 1 (no se vuelve a RECIBIDO).
