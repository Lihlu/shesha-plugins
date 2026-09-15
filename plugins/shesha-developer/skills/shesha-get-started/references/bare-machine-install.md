# Bare-Machine Prerequisite Install

What actually goes wrong when the target machine has **none** of the prerequisites — no .NET, no Node, no SQL Server, no IDE. Read this before running any installer in Step 1.

## Contents

- [1. Confirm a package manager exists](#1-confirm-a-package-manager-exists)
- [2. Elevation and interactive prompts](#2-elevation-and-interactive-prompts)
- [3. PATH is stale after every install](#3-path-is-stale-after-every-install)
- [4. Install order](#4-install-order)
- [5. Query SQL Server without sqlcmd](#5-query-sql-server-without-sqlcmd)

## 1. Confirm a package manager exists

Every install command in Step 1 assumes one is present. Check first — do not discover it is missing halfway through.

| OS | Check | If missing |
|---|---|---|
| Windows | `winget --version` | Ships with Windows 11 and current Windows 10 as **App Installer**. If absent, ask the user to install App Installer from the Microsoft Store, or download each prerequisite's installer directly from its vendor page. |
| Mac | `brew --version` | Install Homebrew: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` — it asks for the user's password, so have them run it (see §2). Otherwise use vendor `.pkg` installers. |
| Linux | `apt --version` or `dnf --version` | Use the distro package manager. Installing Node via `nvm` avoids needing root at all. |

If `winget` is installed but not resolving, it is at `/c/Users/<user>/AppData/Local/Microsoft/WindowsApps/winget.exe`.

## 2. Elevation and interactive prompts

Two separate things block an unattended `winget install`:

**Agreement prompts.** On a machine that has never run `winget`, the first install stops on a source-agreement prompt and waits forever. Always pass:

```bash
winget install --id <Package.Id> --silent --accept-source-agreements --accept-package-agreements
```

**UAC.** Machine-scope installs (Node LTS, the .NET SDK, SQL Server Express, Visual Studio) raise a UAC dialog. An agent cannot click it, but the user can — the dialog appears on their desktop.

- Check elevation first: `net session >/dev/null 2>&1` succeeds only when elevated.
- If **not** elevated: tell the user *before* running the command that a UAC prompt will appear and they must click **Yes**, then run the install with a generous timeout (Visual Studio and SQL Server take many minutes).
- Prefer user-scope where the package supports it, which skips UAC entirely — VS Code does: `winget install --id Microsoft.VisualStudioCode --scope user --silent --accept-source-agreements --accept-package-agreements`.
- If the install still fails with an access-denied or `0x80070005` style error, ask the user to run that one command in an **elevated** PowerShell (Start ▸ *PowerShell* ▸ Run as administrator), then continue.

On Mac, `brew install` needs no `sudo`, but the Homebrew *installer* and some casks prompt for the user's password — have the user run those themselves by typing `! <command>` in the prompt.

## 3. PATH is stale after every install

**This is the most common false failure.** A tool installed during this session is not on `PATH` in your shell — the shell inherited its environment before the install happened. `dotnet: command not found` immediately after installing the .NET SDK means the `PATH` is stale, **not** that the install failed.

Never re-run the installer on this symptom. Verify with the absolute path instead, and keep using the absolute path for the rest of the session:

| Tool | Absolute path after a default install (Windows) |
|---|---|
| `dotnet` | `/c/Program Files/dotnet/dotnet.exe` |
| `node` | `/c/Program Files/nodejs/node.exe` |
| `npm` | `/c/Program Files/nodejs/npm.cmd` |
| `code` | `/c/Users/<user>/AppData/Local/Programs/Microsoft VS Code/bin/code` (user scope) or `/c/Program Files/Microsoft VS Code/bin/code` (machine scope) |
| `sqlpackage` | `~/.dotnet/tools/sqlpackage.exe` |
| `devenv` | resolve via `"/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe" -latest -property productPath` |
| `winget` | `/c/Users/<user>/AppData/Local/Microsoft/WindowsApps/winget.exe` |

Mac/Linux equivalents: Homebrew installs to `/opt/homebrew/bin` (Apple silicon) or `/usr/local/bin` (Intel); `dotnet` global tools land in `~/.dotnet/tools`.

To refresh `PATH` for subsequent PowerShell calls in this session:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
```

Bash tool calls start a fresh shell but still inherit the parent process environment, so this does **not** reliably fix `PATH` there — use the absolute paths above.

## 4. Install order

Dependencies between the installs matter on a bare machine:

1. **Package manager** (§1) — everything else depends on it.
2. **The .NET SDK the project targets** (read `<TargetFramework>` from the `*.Web.Host.csproj`) — must come before `dotnet tool install -g microsoft.sqlpackage`, which otherwise fails with `dotnet: command not found`. After installing, invoke it as `"/c/Program Files/dotnet/dotnet.exe" tool install -g microsoft.sqlpackage --version 162.4.92`.
3. **SQL Server** — must be running before the `.bacpac` import, and a fresh Express install can take a minute to start its service.
4. **Node** — needed before `npm install`.
5. **VS Code / Visual Studio** — needed only at Step 4, so install them last if time is short.

## 5. Query SQL Server without sqlcmd

`sqlcmd` is **not** guaranteed on a bare Windows machine — a `winget`-installed SQL Server Express does not put the command-line tools on `PATH`. Do not let the "does the database already exist?" check fail for that reason.

Use the bundled script instead, which talks to SQL Server directly through .NET and needs nothing beyond Windows PowerShell:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-base-dir>/scripts/sql-query.ps1" -Query "SELECT name FROM sys.databases WHERE database_id > 4;"
```

It defaults to `localhost` with Windows authentication and automatically retries `localhost\SQLEXPRESS`, which is what a `winget` SQL Server Express install actually creates. Useful options:

- `-Database <DbName>` — run against a specific database (verifying the restore).
- `-Server <server>` — target a non-default instance.
- `-User sa -Password '<pwd>'` — SQL authentication instead of Windows authentication.

Exit code `0` means the query ran; non-zero prints the connection error, which is also how to prove SQL Server is reachable at all.

On Mac/Linux there is no gap — `sqlcmd` ships inside the SQL Server container, so keep using `docker exec ... /opt/mssql-tools18/bin/sqlcmd` as in [mac-linux-setup.md](mac-linux-setup.md).
