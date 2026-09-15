# Mac / Linux — Database Setup

Visual Studio and SSMS are not available on Mac/Linux, so SQL Server runs in **Docker** and the `.bacpac` is restored with the **SqlPackage** CLI.

## 1. Run SQL Server in Docker

Check for an existing container first (reuse it instead of creating duplicates):

```bash
docker ps -a --filter "name=SQL_Server_Docker" --format "{{.Names}} {{.Status}}"
```

- **Exists but stopped** → `docker start SQL_Server_Docker`
- **Does not exist** → create it:

```bash
docker pull --platform linux/amd64 mcr.microsoft.com/mssql/server:2022-latest
docker run --platform linux/amd64 -d \
  -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=@123Shesha" \
  -p 1433:1433 --name SQL_Server_Docker \
  mcr.microsoft.com/mssql/server:2022-latest
```

Default credentials: `sa` / `@123Shesha` on port `1433`. In Docker Desktop, enable **host networking** so the host can reach the container.

## 2. Install SqlPackage

Requires a .NET SDK able to build the project's `<TargetFramework>` (`dotnet --list-sdks`). Then:

```bash
dotnet tool install -g microsoft.sqlpackage --version 162.4.92
```

> Pin `162.4.92` unless the project needs otherwise — newer SqlPackage requires the .NET 10 runtime. SqlPackage is a standalone tool; its version is independent of the backend's target framework. Reopen the terminal after install so `sqlpackage` is on PATH.

## 3. Check whether the database already exists

```bash
docker exec SQL_Server_Docker /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P '@123Shesha' -C \
  -Q "SELECT name FROM sys.databases WHERE name NOT IN ('master','tempdb','model','msdb');"
```

If the target database is listed, skip the import.

## 4. Import the `.bacpac`

```bash
sqlpackage /Action:Import \
  /SourceFile:"<path-to>/<Project>.bacpac" \
  /TargetConnectionString:"Server=localhost,1433;Initial Catalog=<DbName>;Persist Security Info=False;User ID=sa;Password=@123Shesha;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
```

## 5. Verify the restore

Re-run the database list from step 3 and confirm `<DbName>` now appears.

## Connection string for the backend

The starter ships with a Windows-auth connection string. Replace it with SQL auth so it works against Docker:

```
Server=localhost,1433;Initial Catalog=<DbName>;Persist Security Info=False;User ID=sa;Password=@123Shesha;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;
```

If no local HTTPS dev certificate exists, run `dotnet dev-certs https --trust` before starting the backend.

Return to **Step 3** of SKILL.md to apply the connection string.
