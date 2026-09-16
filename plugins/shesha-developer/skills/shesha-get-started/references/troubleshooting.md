# Troubleshooting

Common first-time setup failures and fixes, grouped by stage.

## Locating the project

| Symptom | Cause | Fix |
|---|---|---|
| No `adminportal/`, `backend/` or `*.bacpac` anywhere | The download has not been expanded yet — shesha.io ships a `.zip` | Glob for `*.zip`, list its contents to confirm it is a Shesha starter, confirm with the user, then expand it beside the archive and re-glob (Step 0). |
| Pieces found, but under a plugin clone or unrelated folder | The skill was invoked from the wrong working directory | Re-pin `<project-root>` to the real project. Never write `appsettings.json` or `node_modules` outside it. |
| `Expand-Archive` fails with `DirectoryNotFoundException` | Destination path too long — Windows `MAX_PATH` (260 chars), hit easily under a deep temp or scratch directory | Expand somewhere short (beside the archive, e.g. `C:/Users/<user>/Downloads/<Project>`), not into a nested working directory. |
| `Expand-Archive -Force` errors repeatedly with `Remove-Item : Cannot find path` | `-Force` tries to clean a partially-populated destination | Expand into a new empty folder instead of forcing over an existing one; ask the user before touching a non-empty destination. |
| VS Code opens in Restricted Mode despite the `Unblock-File` sweep | Files were dragged out of Explorer's zip viewer, which re-applies the Mark of the Web per file | Re-run the sweep against the final `<project-root>`, or expand with `Expand-Archive` instead, which does not mark files. |

## Prerequisite installs (bare machine)

Full detail in [bare-machine-install.md](bare-machine-install.md).

| Symptom | Cause | Fix |
|---|---|---|
| `dotnet` / `node` / `code: command not found` right after installing it | `PATH` is stale — the shell inherited its environment before the install | Not a failed install; do **not** re-run the installer. Verify and keep using the absolute path (`/c/Program Files/dotnet/dotnet.exe`, `/c/Program Files/nodejs/node.exe`). |
| `winget install` hangs with no output | First-run source/package agreement prompt is waiting | Re-run with `--silent --accept-source-agreements --accept-package-agreements`. |
| `winget install` fails with access denied / `0x80070005` | Machine-scope install from a non-elevated shell | Warn the user a UAC dialog will appear and have them click **Yes**, use `--scope user` where supported, or have them run that one command in an elevated PowerShell. |
| `winget: command not found` (Windows) | App Installer not present, or not on `PATH` | Try `/c/Users/<user>/AppData/Local/Microsoft/WindowsApps/winget.exe`; otherwise install **App Installer** from the Microsoft Store or download each prerequisite directly. |
| `dotnet tool install` fails immediately after installing the SDK | `dotnet` not yet on `PATH` | Run it as `"/c/Program Files/dotnet/dotnet.exe" tool install -g microsoft.sqlpackage --version 162.4.92`. |
| `sqlcmd: command not found` on Windows | A winget SQL Server Express install does not add the command-line tools to `PATH` | Not required — use `<skill-base-dir>/scripts/sql-query.ps1` for every database check. |
| SQL Server unreachable just after installing Express | The service has not finished starting, or the instance is `localhost\SQLEXPRESS` | Retry `<skill-base-dir>/scripts/sql-query.ps1` (it tries the `SQLEXPRESS` instance automatically); confirm the SQL Server service is running. |

## Database & connection

| Symptom | Cause | Fix |
|---|---|---|
| `Login failed for user 'sa'` | SQL Server not running or wrong password | Windows: confirm the SQL Server service is started. Docker: `docker start SQL_Server_Docker` and verify the SA password. |
| `Cannot connect to localhost:1433` / connection refused | SQL Server not running or port in use | `docker ps` (Mac/Linux) or check the SQL Server service (Windows); ensure port 1433 is free. |
| `A connection was successfully established ... certificate chain` | Encryption/cert mismatch | Add `TrustServerCertificate=True;` to the connection string. |
| `sqlpackage: command not found` | Tool not installed or not on PATH | `dotnet tool install -g microsoft.sqlpackage --version 162.4.92`, then reopen the terminal. |
| SqlPackage import fails citing .NET 10 / framework | Newer SqlPackage pulled in | Reinstall pinned to `162.4.92`. |
| Database name mismatch at backend startup | Connection string ≠ restored DB name | Make `appsettings.json` `ConnectionStrings.Default` match the restored database exactly. |

## Backend (.NET)

| Symptom | Cause | Fix |
|---|---|---|
| `relation "Frwk_ConfigurationItems" does not exist` / `citext does not exist` | Pointed at PostgreSQL | Shesha base migrations are SQL Server only. Use SQL Server; do not change `DbmsType`. |
| HTTPS / dev cert errors on startup | No trusted local cert | `dotnet dev-certs https --trust`. |
| Wrong .NET SDK selected | Multiple SDKs installed, or a `global.json` pin that is not installed | Compare `dotnet --list-sdks` against the project's `<TargetFramework>`; if `global.json` pins an SDK, that exact version must be present. |
| Build fails with a target-framework error after a Shesha upgrade | The new version targets a different `net<major>.0` than the machine has | Read `<TargetFramework>` from the `*.Web.Host.csproj` and install that SDK — do not assume the previous project's version. |
| First run hangs for a while | Migrations + config bootstrap on first start | Expected. Wait for `Application started`; subsequent runs are fast. |
| Port 21021 already in use | Another instance running | Stop the other process or pass a different `--urls` port (and update frontend/CORS accordingly). |

## Frontend (Node / npm)

| Symptom | Cause | Fix |
|---|---|---|
| `npm install` fails on engine/version | Node version ≠ project requirement | Match the project pin — `.nvmrc` if present, else `engines.node` in `adminportal/package.json` (nvm: `nvm install <v> && nvm use <v>`). A project with neither pins nothing. |
| Login fails / network errors in the portal | Backend not running or wrong API URL | Confirm Swagger at `http://localhost:21021/swagger`; check the frontend's API base URL config. |
| CORS errors in browser console | Frontend origin not allowed | Add the frontend origin (e.g. `http://localhost:3000`) to `App.CorsOrigins` in backend `appsettings.json` and restart. |
| Dev server starts on an unexpected port | Port 3000 taken, often by an unrelated dev server left running | Read the actual port from the dev-server log and use that URL — and add that origin to `App.CorsOrigins`. |

## Frontend dev server (you start it)

You run `npm install` and then `npm run dev` in `adminportal/` yourself, as a background command logging to a file. There is no task, no Workspace Trust gate, and no user gesture — if the portal is not up, it is yours to diagnose from that log.

| Symptom | Cause | Fix |
|---|---|---|
| Dev server log is empty and the port is silent | `npm run dev` was run in the foreground, or its output was not redirected | Run it as a background command redirecting to a log file. It never exits, so a foreground run blocks the session. |
| `npm run dev` fails with a missing module | `npm install` did not complete, or a previous attempt left `node_modules` half-written | Re-run `npm install` in `adminportal/` and confirm it exits 0 before starting the dev server. |
| `next` is not recognised | The command ran at the project root, not `adminportal/` | `cd` into `adminportal/` first — the `dev` script only exists in that `package.json`. |
| Port answers before you started anything | An unrelated dev server from earlier work | Do not report it as the portal and do not kill it. Expect Next.js to fall back to `3001`/`3002`, and cover that origin in `App.CorsOrigins`. |
| Dev server starts on 3001/3002 instead of 3000 | Another process already holds 3000 | Normal. Read the bound port from your log rather than assuming, and make sure that origin is in `App.CorsOrigins`. |
| Portal loads but every API call fails | The bound port is not in `App.CorsOrigins` | Add the actual frontend origin to `App.CorsOrigins` in backend `appsettings.json` and restart the backend. |
| Port silent for ~2 minutes after "Ready" | Next.js compiles on first request (12k+ modules) and binds IPv6 | Not a fault. Poll with a generous per-request timeout; a short probe falsely reads as down. |
| Server stops when the session ends | You started it, so it is tied to the session | Expected — say so on a `⚠` line in the handoff, and tell the user to re-run `npm run dev` in a VS Code terminal to have it outlive the session. |

## Backend in Visual Studio

| Symptom | Cause | Fix |
|---|---|---|
| Nothing runs after opening the solution | Visual Studio does not auto-run on open | Set the `*.Web.Host` project as the startup project and press **▶ Start** / **F5** / **Ctrl+F5**. This gesture is expected — not a fault. |
| Wrong project starts | A different project is set as startup | Right-click the `*.Web.Host` project ▸ **Set as Startup Project**. |
| Backend starts on an unexpected port | Visual Studio uses the `launchSettings.json` profile `applicationUrl`, not `--urls` | Read the IIS Express profile's `applicationUrl` (typically `http://localhost:21021`) and use that port consistently for polling, the frontend API URL, and `App.CorsOrigins`. |
| Build errors on first run | Packages not restored | Restore NuGet (`dotnet restore <sln>` or **Build ▸ Restore NuGet Packages**), then rebuild. |
| First run takes minutes with no output | Migrations and configuration-item bootstrap | Expected on a fresh database — poll with a generous timeout rather than restarting it. |
| Can't / won't use Visual Studio (or Mac/Linux) | No Visual Studio available | Run the backend with `dotnet run --project src/<Org.Project>.Web.Host --urls http://localhost:21021` from a terminal — identical result, but it stops when that terminal closes. |

## General

- Resolve failures in order: database → backend → frontend. A frontend login failure is almost always a backend or connection-string problem upstream.
- Read real values (ports, versions, DB name) from the project files rather than assuming defaults.
