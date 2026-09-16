---
name: shesha-get-started
description: Gets a freshly downloaded Shesha starter project running locally for the first time, fully automatically and seamlessly. Expands the downloaded .zip if it has not been unzipped yet, detects the OS, reads the required .NET and Node versions from the project itself, and auto-installs any missing prerequisites (the Node version the frontend pins, the .NET SDK the backend targets, SQL Server or Docker, SqlPackage, HTTPS dev cert, VS Code, Visual Studio), restores the seeded database, configures the backend connection string, installs the frontend dependencies, opens the backend solution in Visual Studio and the frontend admin portal in VS Code — runs `npm install` and `npm run dev` in `adminportal/` so the admin portal starts automatically, and opens the app in the browser — the user presses Start/F5 in Visual Studio to run the backend API, and is otherwise left only to log in. Use when a user has downloaded a new Shesha project from shesha.io and wants it up and running, set up their local environment from scratch, or troubleshoot a first-time setup.
---

# Get a Shesha Starter Project Running

Take a freshly downloaded Shesha starter project from zero to a running **frontend admin portal** the user can log into — doing every step **for** the user. Auto-install anything missing, restore the seeded database, configure the backend, install the frontend dependencies, then open the **backend (`*.sln`) in Visual Studio** and the **frontend (`adminportal/`) in VS Code**.

**This split is the team standard and is not negotiable:** the backend API runs from **Visual Studio**, the frontend admin portal runs from **VS Code**. Do not collapse both into one IDE.

The user presses **Start/F5** in Visual Studio to run the backend — that is their **only** action before logging in. You run the frontend yourself (`npm install` then `npm run dev` in `adminportal/`), poll both servers, and open the app in the browser. **The skill is done once the frontend is up.**

**Do not write a VS Code `tasks.json` or use a `folderOpen` task.** Automatic tasks are gated behind Workspace Trust *and* a separate "Allow Automatic Tasks" setting, so on a fresh download they fail silently and the frontend never starts. A plain terminal command is visible, predictable, and leaves its log where the user can read it.

This is a first-time setup, and the user is watching a lot of machinery they did not set up. **Narrate it** — see the **Progress reporting** section below. Explain briefly what each step does as you go, but do the work yourself.

## Progress reporting

The user must always know which step is running, what just happened, and what (if anything) is expected of them. Several steps take minutes with no output, so silence reads as a hang.

The workflow has seven steps, numbered 0 to 6. Before starting each, print a heading line:

```
**Step <n> of 6 — <title>** <one clause on what it is about to do>
```

When the step finishes, print a short result line starting with `✓` (done), `→` (done, nothing needed), or `⚠` (worked around — say how). Keep each to one line, naming the concrete thing: the database restored, the version installed, the file written.

Four further rules:

- **Warn before anything slow**, with a rough duration: the `.bacpac` import, `npm install`, any `winget install`, and the first backend run (migrations and configuration-item bootstrap take a minute or more).
- **Warn before anything the user must do** — a UAC dialog, pressing Start/F5 in Visual Studio — *before* the moment it is needed, not after.
- **Report skips as clearly as actions.** "Connection string already correct — left unchanged" tells the user more than silence does.
- **Never report a step complete before it is verified.** If a fallback was used, say so on the `⚠` line.

At the end, give the Step 6 handoff report.

## Automation policy (read first)

The user should not have to install, add, or configure anything. Make it **seamless**. The split is fixed: the **backend (`*.sln`) runs in Visual Studio**, the **frontend (`adminportal/`) runs in VS Code**.

- If a prerequisite or dependency is **missing, install/add it yourself.** For system-level software (Node, the .NET SDK, SQL Server, VS Code, Visual Studio) **confirm once** before installing, then do it. For lightweight additions (global `dotnet` tools, the HTTPS dev cert) just do them.
- **Install the dependencies and open both IDEs yourself.** Run `npm install` in `adminportal/`, open the project root in VS Code, and open the backend `*.sln` in Visual Studio. Do **not** write a `.vscode/tasks.json`.
- **Run the frontend yourself — it is not a user gesture.** In `adminportal/`, run `npm install`, then start `npm run dev` as a background command. Do not ask the user to type either one. Open the project in VS Code for editing, but the dev server is yours to start and verify.
- **The backend's only action is pressing Start/F5 in Visual Studio.** Visual Studio does not auto-run a solution on open — an agent cannot press it. Open the `*.sln` yourself, then the user sets the `*.Web.Host` project as the startup project (usually already is) and presses the green **▶ Start** button (or **F5** / **Ctrl+F5**). That builds and runs the backend API.
- **The F5 gesture is expected, not a failure.** Tell the user about it *before* it is needed and treat the wait as normal — do not silently poll a port nobody has started yet. If it has not happened after a few minutes, prompt once rather than assuming a fault.
- **Be resilient.** If the user cannot or will not use Visual Studio (or is on Mac/Linux, where it does not exist), run `dotnet run …` yourself so the result is identical — say on a `⚠` line that you did, since a server started that way stops when the session ends. The same caveat applies to the frontend you start: mention that it stops with the session, and how to restart it in a VS Code terminal.
- Besides pressing Start/F5, the only things the user does are: a one-time yes/no if you ask before installing system software, and finally **log in** with `admin` / `123qwe`.

## The end state

When finished, the user has:

- The **backend API** built and run from **Visual Studio** (IIS Express / Kestrel profile, typically `http://localhost:21021`), reachable at `http://localhost:21021/swagger`.
- The **frontend admin portal** started by you with `npm run dev` (default `http://localhost:3000`) and **opened in the browser**.
- The backend solution **open in Visual Studio** and the project **open in VS Code** for editing.
- Nothing left to install, configure or start except the backend (**F5 in Visual Studio**) — then **log in** with `admin` / `123qwe`.

The frontend cannot log in unless the backend is running and connected to a restored database, so all three must be working.

## Workflow

Run these steps in order. Do not skip ahead — each step depends on the previous one succeeding.

### Step 0 — Locate the project pieces

Expect the working directory to be the unzipped project, or a folder containing it. It may also be somewhere else entirely — a developer who has cloned `shesha-plugins` may well invoke this skill from that clone. Resolve the Shesha project explicitly and **pin its absolute path as `<project-root>`**; every project path below is relative to `<project-root>`, never to the working directory.

Never write `appsettings.json` or `node_modules` into a plugin clone or any other non-project folder.

**If none of the pieces are found, look for the download itself before asking.** What shesha.io hands the user is a `.zip`, so an unexpanded archive is a normal starting state, not an error:

- Glob for `*.zip` in the working directory (and one level down). A Shesha starter archive is tens of MB and its name usually carries the `Organisation.Project` namespace.
- List the archive's contents before expanding — `Expand-Archive -Path "<zip>" -DestinationPath "<dest>" -WhatIf` on Windows, `unzip -l "<zip>"` elsewhere — and confirm it holds `adminportal/` and `backend/`. Do not expand an archive that is not a Shesha starter.
- Confirm with the user, then expand it: `Expand-Archive -Path "<zip>" -DestinationPath "<dest>"` (Windows) or `unzip -q "<zip>" -d "<dest>"`. Expand **beside** the archive, never over an existing folder — if the destination exists and is non-empty, ask.
- Expanding this way also avoids the Mark of the Web that a drag-out from Explorer leaves on every file, which is what puts VS Code into Restricted Mode and makes PowerShell refuse the project's scripts. Still run the `Unblock-File` sweep in Step 1; it is cheap and covers the case where the user expanded it themselves.
- Re-glob for the pieces afterwards, and pin `<project-root>` to the expanded folder.

If there is no archive and no project pieces, ask the user where they unzipped the download rather than guessing.

A downloaded Shesha starter unzips to several pieces (names follow the user's `Organisation.Project` namespace):

| Piece | Look for | Purpose |
|---|---|---|
| Frontend | `adminportal/` (contains `package.json`, Next.js) | The admin portal VS Code will run |
| Backend | `backend/` containing `*.sln` and a `*.Web.Host` project | The ASP.NET Core API Visual Studio will run |
| Database | a `*.bacpac` file | The seeded SQL Server database to restore |

Use `Glob` to find `**/package.json`, `**/*.sln`, `**/*.Web.Host.csproj`, and `**/*.bacpac`. Confirm the project root with the user only if the layout is ambiguous. Note the `Organisation.Project` namespace (referred to below as `<Org.Project>`) — the `*.Web.Host` project is the backend startup project Visual Studio runs.

**Different Shesha versions ship different toolchains.** Do not carry version assumptions between projects: a v45 starter targeting `net8.0` and a v46 one targeting something newer are both normal. Step 1's preflight reads the required .NET and Node versions out of this project and reports them — treat that report, not prior experience, as the source of truth.

### Step 1 — Preflight, then auto-install whatever is missing

Run the preflight script via the Bash tool (it is read-only). The working directory is the user's **project**, while this skill's files live in the plugin cache — so always invoke bundled scripts through `<skill-base-dir>`, the absolute path announced as "Base directory for this skill" when the skill loads. Never copy them into the project.

```bash
bash "<skill-base-dir>/scripts/preflight-check.sh" "<project-root>"
```

**Always pass `<project-root>`.** With it, the script reads the required versions *from the project* — the `<TargetFramework>` in the `*.Web.Host.csproj`, an SDK pin in `global.json`, and `engines.node` / `.nvmrc` in `adminportal/` — and checks the installed toolchain against them. Without it, it can only report what is installed, which is how a project targeting a newer framework gets a misleading PASS.

It reports the OS, whether a package manager and an elevated shell are available, and the presence/version of Node, npm, .NET SDK, Git, VS Code, Visual Studio, Docker, SQL Server, `sqlcmd` and SqlPackage. For **every** gap, resolve it **yourself** (confirm before installing system software). Do not ask the user to install anything.

On a machine missing several of these, read [references/bare-machine-install.md](references/bare-machine-install.md) **before** running any installer. It covers the package-manager check, the agreement and UAC prompts that block an unattended install, the stale `PATH` that makes a fresh install look like a failed one, install order, and querying SQL Server without `sqlcmd`. Never re-run an installer because a just-installed tool is "missing" — check its absolute path there first.

Then close each gap individually (append `--silent --accept-source-agreements --accept-package-agreements` to every `winget install`):

- **Remove the "Mark of the Web"** so VS Code does not nag about Restricted Mode and PowerShell does not refuse the project's scripts (Windows): `powershell -Command "Get-ChildItem -Path '<project-root>' -Recurse | Unblock-File"`. The integrated terminal works in Restricted Mode either way, so this no longer gates the frontend — it is just housekeeping.
- **VS Code** (runs the frontend): the `code` CLI must be available. If missing, confirm and install (Windows `winget install --id Microsoft.VisualStudioCode --scope user` — user scope avoids the UAC prompt; Mac `brew install --cask visual-studio-code`, Linux per distro).
- **Visual Studio** (runs the backend): detect it (Windows — `"/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe" -latest -property productPath`, or check for `devenv.exe` under `"C:/Program Files/Microsoft Visual Studio/<year>/*/Common7/IDE/"`). If missing, confirm and install — **do not hardcode the release year**: run `winget search Microsoft.VisualStudio` and pick the newest `Microsoft.VisualStudio.<year>.Community` id it lists (`…2022.Community` is the floor, not the answer). Warn that it is a large download and takes many minutes. On Mac/Linux there is no Visual Studio: run the backend with `dotnet run` instead (see the fallback in Step 5).
- **Node**: the project decides. `.nvmrc` wins over `engines.node` in `adminportal/package.json`; the preflight report states which it found. If neither exists the project pins nothing — use the installed Node and say so, rather than assuming a version. If the installed version is **older** than required: `nvm install <version> && nvm use <version>` where `nvm` exists, otherwise install Node (Windows `winget install OpenJS.NodeJS.LTS`, Mac `brew install node@<major>`, Linux via nvm/apt) — confirm first. A **newer** Node than an exact pin is usually fine; treat it as a warning, not a blocker.
- **.NET**: the required version is the `<TargetFramework>` of the `*.Web.Host.csproj` — `net8.0`, `net9.0`, `net10.0`, whatever the Shesha version ships. **Never assume it.** A newer SDK **can build and run** an older target as long as that target's runtime is present (`dotnet --list-runtimes` shows `Microsoft.NETCore.App <major>.x` and `Microsoft.AspNetCore.App <major>.x`) — accept that, do not treat it as a failure. Install the matching SDK only when neither that SDK nor its runtime is available (Windows `winget install Microsoft.DotNet.SDK.<major>`) — confirm first.
- **`global.json`**: if the project pins an SDK version, that exact SDK must be installed or every `dotnet` command in the project fails, regardless of what else is present. The preflight report flags a pin that is missing from `dotnet --list-sdks`.
- **SQL Server**: must be reachable. Windows — if no local instance is running, confirm and install SQL Server Express (`winget search Microsoft.SQLServer` and take the newest `Microsoft.SQLServer.<year>.Express`; 2022 is a safe floor) or use Docker. Mac/Linux — start SQL Server in Docker yourself (see the reference file). A fresh Express install needs a moment before its service accepts connections — confirm with `<skill-base-dir>/scripts/sql-query.ps1` before continuing.
- **SqlPackage**: install automatically if missing — `dotnet tool install -g microsoft.sqlpackage --version 162.4.92` (pinned — newer SqlPackage requires the .NET 10 runtime; the pin is independent of the backend's target framework). Use the full path `~/.dotnet/tools/sqlpackage` so it resolves without reopening the shell. If the .NET SDK was installed moments ago, `dotnet` is not on `PATH` yet either — run it as `"/c/Program Files/dotnet/dotnet.exe" tool install ...`.
- **HTTPS dev cert**: run `dotnet dev-certs https --trust` automatically.

Continue only once each gap is closed **by your action**, not the user's — the one exception is a UAC or password dialog, which only a human can accept.

### Step 2 — Restore the database (automatically)

Restore the seeded `.bacpac` yourself using the **automatable CLI path** (SqlPackage). Follow the matching reference for exact commands:

- **Windows** → [references/windows-setup.md](references/windows-setup.md) (local SQL Server; SqlPackage CLI).
- **Mac / Linux** → [references/mac-linux-setup.md](references/mac-linux-setup.md) (SQL Server in Docker; SqlPackage).

First check whether the database already exists; if it does, skip the import. Otherwise import the `.bacpac`.

**Verify the restore against the configuration tables, not the person tables.** A correctly restored starter `.bacpac` has **empty** `dbo.Core_Persons` and `dbo.AbpUsers` — the `admin` user and its person record are seeded by the backend on its first run, not by the import. Treating those as evidence of a bad restore will fail a perfectly good one. Check instead that the configuration data arrived:

```sql
SELECT TOP 10 t.name AS TableName, SUM(p.rows) AS Rws
FROM sys.tables t JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1)
GROUP BY t.name HAVING SUM(p.rows) > 0 ORDER BY SUM(p.rows) DESC;
```

Expect populated `configuration_items`, `entity_properties`, `entity_configs`, `reference_list_items` and `permissioned_objects`. An import that reports success but leaves these empty is the real failure.

**Watch for a name collision.** The database is named from the `.bacpac`, so re-downloading a project with a name used before silently skips the import and leaves the *old* database against the *new* code — which presents later as inexplicable runtime errors. If a database of that name already exists, say so and confirm with the user before reusing it.

On **Windows do not depend on `sqlcmd`** — a freshly installed SQL Server Express does not put it on `PATH`. Use the bundled script for both the existence check and the verification; it reaches SQL Server through .NET, needs no extra tooling, and retries the `SQLEXPRESS` instance automatically:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-base-dir>/scripts/sql-query.ps1" -Query "SELECT name FROM sys.databases WHERE database_id > 4;"
```

On Mac/Linux `sqlcmd` ships inside the SQL Server container, so use `docker exec ... sqlcmd` as in the reference.

### Step 3 — Configure the backend connection string

Edit `appsettings.json` in the `*.Web.Host` project (e.g. `<project-root>/backend/src/<Org.Project>.Web.Host/appsettings.json`). Set `ConnectionStrings.Default` to match how the database is hosted:

- **Windows, local SQL Server (Windows auth):**
  ```json
  "Default": "Server=localhost;Database=<DbName>;Trusted_Connection=True;TrustServerCertificate=True;"
  ```
- **Mac/Linux/Docker, or SQL auth:**
  ```json
  "Default": "Server=localhost,1433;Initial Catalog=<DbName>;Persist Security Info=False;User ID=sa;Password=@123Shesha;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
  ```

Rules:
- Replace `<DbName>` with the database name you restored. If the file is already correct, leave it.
- Change **only** `ConnectionStrings.Default` (and, if needed, `App.CorsOrigins` to include the frontend origin). Leave `Authentication` and other settings as-is.
- Do **not** switch `DbmsType` to PostgreSQL — Shesha's base schema migrations are SQL Server only.

### Step 4 — Open the backend in Visual Studio and the frontend in VS Code

Start the frontend yourself and open both IDEs. Do all of this yourself — the user's only action is F5 in Visual Studio:

1. **Install frontend dependencies:** `cd "<project-root>/adminportal" && npm install`. Warn the user this takes a few minutes. Run it even if `node_modules` already exists unless you installed it yourself this session — a half-finished install from an earlier attempt is a common cause of a dev server that will not start.
2. **Start the dev server:** `cd "<project-root>/adminportal" && npm run dev`, as a **background** command whose output goes to a log file you can read. Do not run it in the foreground — it never exits. Read the bound URL out of that log (`Local: http://localhost:<port>`) rather than assuming `3000`; Next.js silently falls back to `3001`/`3002` when the port is taken.
3. **Open the frontend in VS Code:** `code <project-root>`, for editing. Do **not** write a `.vscode/tasks.json` — you start the dev server yourself.
4. **Open the backend solution in Visual Studio:** launch `devenv "<project-root>/backend/<Org.Project>.sln"`, or `start "" "<sln>"` since `.sln` is associated with Visual Studio. Warn the user that a first load of a large solution takes a while.
5. **Tell the user the one start gesture**, before it is needed: in **Visual Studio**, once the solution finishes loading, ensure **`<Org.Project>.Web.Host`** is the startup project (it usually already is) and press the green **▶ Start** button (or **F5** / **Ctrl+F5**) to build and run the backend API.

### Step 5 — Verify the servers came up, then open the browser

The frontend is already starting from the background command you launched in Step 4; the backend runs once the user presses Start/F5 in Visual Studio. Confirm both are up — do not block on the Visual Studio terminal:

- **Backend:** read the URL from `*.Web.Host/Properties/launchSettings.json` (the IIS Express profile's `applicationUrl`, typically `http://localhost:21021`) and poll `<that>/swagger` with a generous timeout. The first run applies migrations and bootstraps configuration items, so it can take a minute or more — tell the user that before you start polling, so a slow first build does not look like a hang. If HTTPS errors block startup, run `dotnet dev-certs https --trust`.
- **Frontend:** read the bound port from your `npm run dev` log, then poll it. **Check whether the default port is already held before you poll** — an unrelated dev server left running from earlier work is common, and Next.js then falls back to `3001`/`3002`. Use a generous timeout: Next.js compiles on first request and binds IPv6, so a short probe may falsely read as down (a first compile of 12k+ modules can take two minutes).
- **A port that is already answering may not be this project.** If the default port responds before you started the dev server, it belongs to something else. Do not report it as the portal, and do not kill it — it is not yours. Note it, expect the fallback port, and make sure `App.CorsOrigins` covers that port (see Step 3), or the portal will load but fail every API call with a CORS error.
- **The backend port not answering usually means F5 is still pending, not a fault.** Check before diagnosing: no backend process means Start/F5 has not been pressed. On Windows, `Get-Process node,devenv,Code,iisexpress,dotnet -ErrorAction SilentlyContinue` distinguishes these in one call. Prompt the user once, naming F5 as outstanding, rather than polling in silence. If the **frontend** port is silent, that is yours to diagnose — read your dev-server log for the error.
- **Do not poll in a tight loop.** Start one background wait that exits when the port answers, then let it notify you. Repeatedly re-checking a port the user has not started yet wastes the session and tells them nothing new.
- **If the backend cannot be started in Visual Studio** (or on Mac/Linux where it does not exist), run `cd "<project-root>/backend" && dotnet run --project src/<Org.Project>.Web.Host --urls http://localhost:21021` yourself — the outcome is identical. Say on a `⚠` line that it is running from your terminal rather than the IDE, since it stops when the session ends.

Once the frontend responds, **open the browser** to the detected URL:

- **Windows:** `start http://localhost:<port>`
- **Mac:** `open http://localhost:<port>`
- **Linux:** `xdg-open http://localhost:<port>`

### Step 6 — Verify and hand off

1. Confirm the backend (Swagger at the `applicationUrl` read in Step 5, typically `http://localhost:21021/swagger`) and the frontend both respond, and the browser opened to the app.
2. Tell the user the **only** remaining action: log in at the admin portal with `admin` / `123qwe`.
3. Give a concise final report:
   - OS detected, and anything you installed/added (with what you confirmed first).
   - Database name restored and connection string applied.
   - That the backend solution is open in Visual Studio (run with F5) and the frontend is running from the `npm run dev` you started — with the Swagger and frontend URLs. Note that the dev server stops when the session ends, and that `npm run dev` in a VS Code terminal restarts it.
   - The reminder to change the default `admin` / `123qwe` credentials before any shared/deployed environment.

## Notes

- Never invent versions or ports: read them from the project (`package.json`, `launchSettings.json`, `appsettings.json`) and from the IDE terminal output.
- For any error, consult [references/troubleshooting.md](references/troubleshooting.md) and fix it yourself before involving the user.
