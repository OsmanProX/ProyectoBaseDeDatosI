# AGENTS.md

## Repo layout (monorepo, 3 independent parts)

- `Backend_PFDB1/Backend_API_Proyevto_Base_de_Datos_I/` — ASP.NET Core 8 Web API (C#, controller-based, no EF; ADO.NET `Microsoft.Data.SqlClient` + Dapper). Solution file is `.slnx`.
- `Frontend_PFDB1/` — Vue 3 + TS + Vite (template-level; package manager is **Bun** — `bun.lock`, no npm lockfile).
- `BD/BD_Conetner_BD1/docker-compose.yml` — SQL Server 2022 local: port **1441** (not 1433), SA password `Grupo1BD1`.
- `SCRIPT DE PROYECTO.sql` (root) — schema source of truth; targets the Azure DB `db_acf53d_dbfinal2026`. Tables: Rol, Usuario, UsuarioRol, Cliente, TipoEquipo, Equipo. Usuario stores `ContrasenaHash` (SHA256 hex).

No CI, no tests, no lint/typecheck scripts exist. Verify backend with `dotnet build` (run in the backend folder).

## Commands

```bash
# Backend (must run from Backend_PFDB1/Backend_API_Proyevto_Base_de_Datos_I)
dotnet build
dotnet run   # profile "http": http://localhost:5245, Swagger at /swagger

# Frontend (from Frontend_PFDB1)
bun run dev      # Vite dev server (default port 5173)
bun run build    # vue-tsc + vite build
```

## Backend conventions (match existing code)

- Structure mirrors a class-demo pattern: `BD/` (DBContext factory), `DTO/` (DTOs hold their own data access via `SetConexion(DBContext)` + Dapper; they return `ResponseDto { codigo, mensaje, data }`), `Models/`, `Services/` (JwtService), `Controllers/`.
- Controllers wrap every call in try/catch and return `ResponseDto`-shaped bodies; error codes live in the body (`codigo`), not only the HTTP status.
- Connection string: `DefaultConnection` in `appsettings.json` points to the **Azure SQL** DB (`sql5113.site4now.net`), not the local Docker one. Do not switch it to localhost:1441 without asking.
- JWT config lives in `appsettings.json` under `Jwt` (Key/Issuer/Audience/ExpirationMinutes). `Program.cs` requires `Jwt:Key` at startup — removing it breaks the app.
- Login (`POST /api/auth/login`) validates against table `Usuario`: compares SHA256 hex of the provided password with `ContrasenaHash` (also accepts plain match). Always use Dapper parameters — never string-concatenate SQL (an older demo project this was based on had SQL injection; do not copy that pattern).
- `GET /api/auth/token-demo` issues a test JWT without DB; `GET /api/auth/perfil` is `[Authorize]` and validates tokens.
- Pipeline order in `Program.cs`: `UseSwagger` → `UseAuthentication` → `UseAuthorization` (authentication middleware must stay before authorization).

## Gotchas

- No CORS configured: the Vue frontend cannot call the API until `AddCors`/`UseCors` is added.
- `.gitignore` only covers `.vs/`, `*.vsidx`, `*.slnx` — `bin/`, `obj/`, and `.vsconfig`-style artifacts may be tracked; don't commit build output.
- `appsettings.json` contains real production DB credentials in plaintext — treat as sensitive; never log or expose them.
- Frontend has no router/store/HTTP client yet; any API integration starts from scratch (use fetch or add axios).
