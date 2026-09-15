# Windows — Database Setup

Restore the seeded starter database into a local SQL Server on Windows. Two paths: the SSMS GUI (the user does it) or the SqlPackage CLI (you can automate it).

## Prerequisites

- **SQL Server** running locally (Developer/Express/full). Confirm a server you can reach, usually `localhost` or `localhost\SQLEXPRESS`.
- **SQL Server Management Studio (SSMS)** — only for the GUI path.
- The starter `*.bacpac` file (from Step 0).

## Check whether the database already exists

If a previous setup already restored it, skip the import. Test connectivity and list databases with `sqlcmd` (ships with SQL Server / SSMS):

```bash
sqlcmd -S localhost -E -Q "SELECT name FROM sys.databases WHERE database_id > 4;"
```

`-E` uses Windows authentication. **`sqlcmd` is not guaranteed** — a winget-installed SQL Server Express does not put it on `PATH`. Use the bundled script instead, which needs no extra tooling and retries the `SQLEXPRESS` instance automatically:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-base-dir>/scripts/sql-query.ps1" -Query "SELECT name FROM sys.databases WHERE database_id > 4;"
```

Failing both, the user can check in SSMS by expanding the **Databases** node.

## Path A — SqlPackage CLI (automatable)

Install once if not present:

```bash
dotnet tool install -g microsoft.sqlpackage --version 162.4.92
```

> Pin `162.4.92` unless the project needs otherwise — newer SqlPackage requires the .NET 10 runtime. SqlPackage is a standalone tool; its version is independent of the backend's target framework. Reopen the terminal after install so `sqlpackage` is on PATH.

Import the `.bacpac` (Windows auth):

```bash
sqlpackage /Action:Import \
  /SourceFile:"<path-to>/<Project>.bacpac" \
  /TargetConnectionString:"Server=localhost;Initial Catalog=<DbName>;Integrated Security=True;TrustServerCertificate=True;"
```

Use SQL auth instead if Windows auth is not configured:

```bash
/TargetConnectionString:"Server=localhost;Initial Catalog=<DbName>;User ID=sa;Password=<password>;TrustServerCertificate=True;"
```

## Path B — SSMS GUI (user performs)

Walk the user through this when SqlPackage is unavailable or they prefer the GUI:

1. Open **SQL Server Management Studio** and connect to the local server (e.g. `localhost`).
2. Right-click **Databases** → **Import Data-tier Application...** → **Next**.
3. **Browse** to the `*.bacpac` file → **Next**.
4. Set **New database name** (e.g. `Membership`) → **Next**.
5. **Finish**.

## Verify the restore

Confirm seeded data exists — the `dbo.Core_Persons` table should be present and populated:

```bash
sqlcmd -S localhost -E -d <DbName> -Q "SELECT TOP 5 * FROM dbo.Core_Persons;"
```

Without `sqlcmd`:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-base-dir>/scripts/sql-query.ps1" -Database <DbName> -Query "SELECT TOP 5 * FROM dbo.Core_Persons;"
```

In SSMS: expand the database → **Tables** → right-click `dbo.Core_Persons` → **Select Top 1000 Rows**.

## Connection string for the backend

- **Windows auth:** `Server=localhost;Database=<DbName>;Trusted_Connection=True;TrustServerCertificate=True;`
- **SQL auth:** `Server=localhost;Database=<DbName>;User ID=sa;Password=<password>;TrustServerCertificate=True;`

If you used a database name other than the default, the connection string in `appsettings.json` must match it exactly.

Return to **Step 3** of SKILL.md to apply the connection string.
