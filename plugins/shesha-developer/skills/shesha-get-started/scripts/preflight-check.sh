#!/usr/bin/env bash
# Shesha get-started preflight check.
# Verifies the tools needed to run a Shesha starter project locally.
# Read-only: prints a PASS/WARN/FAIL report and changes nothing.
#
# Usage: bash preflight-check.sh [<project-root>]
#
# Pass the project root so the required .NET and Node versions are read FROM THE
# PROJECT (Web.Host csproj TargetFramework, global.json, engines.node, .nvmrc)
# rather than assumed. Without it the script still runs, but can only report what
# is installed — it cannot tell you whether it satisfies this project.

pass() { printf '  [PASS] %s\n' "$1"; }
warn() { printf '  [WARN] %s\n' "$1"; }
fail() { printf '  [FAIL] %s\n' "$1"; }
info() { printf '  [INFO] %s\n' "$1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "== Shesha environment preflight =="
echo

# --- Operating system -------------------------------------------------------
case "$(uname -s)" in
  Linux*)               OS=Linux ;;
  Darwin*)              OS=macOS ;;
  MINGW*|MSYS*|CYGWIN*) OS=Windows ;;
  *)                    OS="$(uname -s)" ;;
esac
echo "Operating system: $OS"
echo

# --- Required versions, read from the project -------------------------------
# Everything below degrades gracefully: an unset REQ_* means "unknown", and the
# corresponding check reports what is installed without passing judgement.
PROJECT_ROOT="${1:-}"
REQ_TFM=""; REQ_DOTNET_MAJOR=""; REQ_SDK_PIN=""; REQ_NODE_RANGE=""; REQ_NODE_MAJOR=""

if [ -n "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT" ]; then
  # .NET: TargetFramework from the Web.Host csproj (net8.0 / net9.0 / net10.0 …)
  HOST_CSPROJ="$(find "$PROJECT_ROOT" -name '*.Web.Host.csproj' -not -path '*/node_modules/*' 2>/dev/null | head -1)"
  if [ -n "$HOST_CSPROJ" ]; then
    REQ_TFM="$(grep -o '<TargetFrameworks\?>[^<]*' "$HOST_CSPROJ" 2>/dev/null | head -1 | sed 's/.*>//' | tr -d ' \r' | cut -d';' -f1)"
    case "$REQ_TFM" in net*) REQ_DOTNET_MAJOR="$(echo "$REQ_TFM" | sed 's/^net//' | cut -d. -f1)" ;; esac
  fi
  # An SDK pin in global.json overrides which SDK actually gets selected
  GLOBAL_JSON="$(find "$PROJECT_ROOT" -maxdepth 3 -name 'global.json' -not -path '*/node_modules/*' 2>/dev/null | head -1)"
  if [ -n "$GLOBAL_JSON" ]; then
    REQ_SDK_PIN="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$GLOBAL_JSON" 2>/dev/null | head -1 | sed 's/.*"\([0-9][^"]*\)"/\1/')"
  fi
  # Node: .nvmrc wins over engines.node; both are optional
  NVMRC="$PROJECT_ROOT/adminportal/.nvmrc"
  PKG_JSON="$PROJECT_ROOT/adminportal/package.json"
  if [ -f "$NVMRC" ]; then
    REQ_NODE_RANGE="$(tr -d ' \r\n' < "$NVMRC" | sed 's/^v//')"
  elif [ -f "$PKG_JSON" ]; then
    REQ_NODE_RANGE="$(grep -A3 '"engines"' "$PKG_JSON" 2>/dev/null | grep -o '"node"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
  fi
  [ -n "$REQ_NODE_RANGE" ] && REQ_NODE_MAJOR="$(echo "$REQ_NODE_RANGE" | grep -o '[0-9][0-9]*' | head -1)"

  echo "Project requirements (read from the project):"
  if [ -n "$REQ_TFM" ]; then
    pass "backend targets $REQ_TFM — needs the .NET $REQ_DOTNET_MAJOR runtime"
  else
    warn "could not read <TargetFramework> from a *.Web.Host.csproj — .NET check will be version-agnostic"
  fi
  [ -n "$REQ_SDK_PIN" ] && info "global.json pins the SDK to $REQ_SDK_PIN — that exact SDK must be installed"
  if [ -n "$REQ_NODE_RANGE" ]; then
    pass "frontend requires Node $REQ_NODE_RANGE"
  else
    info "no engines.node or .nvmrc in adminportal/ — the project does not pin a Node version"
  fi
  echo
else
  info "no project root passed — reporting installed versions only, without checking them against a project"
  echo
fi

# --- Package manager (needed to install everything below) -------------------
echo "Package manager:"
case "$OS" in
  Windows)
    if command -v winget >/dev/null 2>&1; then
      pass "winget $(winget --version 2>/dev/null | tr -d '\r')"
    elif [ -x "$LOCALAPPDATA/Microsoft/WindowsApps/winget.exe" ]; then
      warn "winget installed but not on PATH — use the absolute path"
    else
      fail "winget not found — install 'App Installer' from the Microsoft Store, or download each prerequisite directly"
    fi
    ;;
  macOS)
    if command -v brew >/dev/null 2>&1; then
      pass "$(brew --version 2>/dev/null | head -1)"
    else
      fail "brew not found — install Homebrew, or use vendor .pkg installers"
    fi
    ;;
  *)
    if command -v apt >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
      pass "distro package manager available"
    else
      warn "no apt/dnf found — install prerequisites per distro"
    fi
    ;;
esac

# --- Elevation (machine-scope installs raise UAC) ---------------------------
echo "Elevation:"
case "$OS" in
  Windows)
    if net session >/dev/null 2>&1; then
      pass "shell is elevated — machine-scope installs will not prompt"
    else
      warn "shell is NOT elevated — winget installs of Node, the .NET SDK, SQL Server Express and Visual Studio will raise a UAC prompt the user must click Yes on"
    fi
    ;;
  *)
    if [ "$(id -u)" -eq 0 ]; then
      pass "running as root"
    else
      info "not root — brew needs no sudo; apt/dnf installs will prompt for a password"
    fi
    ;;
esac

# --- Node.js ----------------------------------------------------------------
echo "Node.js:"
if command -v node >/dev/null 2>&1; then
  NODE_V="$(node -v)"
  NODE_MAJOR="$(echo "$NODE_V" | sed 's/^v//' | cut -d. -f1)"
  if [ -z "$REQ_NODE_MAJOR" ]; then
    pass "node $NODE_V  (project pins no version — nothing to check against)"
  elif [ "$NODE_MAJOR" -eq "$REQ_NODE_MAJOR" ] 2>/dev/null; then
    pass "node $NODE_V satisfies the project's Node $REQ_NODE_RANGE"
  elif [ "$NODE_MAJOR" -gt "$REQ_NODE_MAJOR" ] 2>/dev/null; then
    case "$REQ_NODE_RANGE" in
      *">="*|*"^"*|*">"*) pass "node $NODE_V is newer than the project's minimum ($REQ_NODE_RANGE) — acceptable" ;;
      *) warn "node $NODE_V is NEWER than the project's Node $REQ_NODE_RANGE — switch with 'nvm use $REQ_NODE_MAJOR' if the build misbehaves" ;;
    esac
  else
    fail "node $NODE_V is OLDER than the project's Node $REQ_NODE_RANGE — install/switch to $REQ_NODE_MAJOR.x"
  fi
else
  fail "node not found — install Node.js${REQ_NODE_RANGE:+ $REQ_NODE_RANGE}"
fi

# --- npm --------------------------------------------------------------------
echo "npm:"
if command -v npm >/dev/null 2>&1; then
  pass "npm $(npm -v)"
else
  fail "npm not found"
fi

# --- .NET SDK ---------------------------------------------------------------
echo ".NET SDK:"
if command -v dotnet >/dev/null 2>&1; then
  DOTNET_V="$(dotnet --version)"
  DOTNET_MAJOR="$(echo "$DOTNET_V" | cut -d. -f1)"
  if [ -z "$REQ_DOTNET_MAJOR" ]; then
    pass "dotnet $DOTNET_V  (target framework unknown — could not check it against the project)"
  elif [ "$DOTNET_MAJOR" = "$REQ_DOTNET_MAJOR" ]; then
    pass "dotnet $DOTNET_V matches the project's $REQ_TFM"
  elif dotnet --list-runtimes 2>/dev/null | grep -q "Microsoft.AspNetCore.App $REQ_DOTNET_MAJOR\."; then
    pass "dotnet $DOTNET_V with the .NET $REQ_DOTNET_MAJOR runtime present — can build and run $REQ_TFM"
  else
    fail "dotnet $DOTNET_V and no $REQ_DOTNET_MAJOR.x runtime — the project targets $REQ_TFM; install the .NET $REQ_DOTNET_MAJOR SDK"
  fi
  # A global.json pin selects the SDK regardless of what else is installed
  if [ -n "$REQ_SDK_PIN" ] && ! dotnet --list-sdks 2>/dev/null | grep -q "^$REQ_SDK_PIN "; then
    warn "global.json pins SDK $REQ_SDK_PIN, which is not in 'dotnet --list-sdks' — builds will fail until it is installed"
  fi
elif [ -x "/c/Program Files/dotnet/dotnet.exe" ]; then
  warn "dotnet installed but not on PATH — use /c/Program Files/dotnet/dotnet.exe"
else
  fail "dotnet not found — install the .NET SDK${REQ_DOTNET_MAJOR:+ $REQ_DOTNET_MAJOR}"
fi

# --- Git --------------------------------------------------------------------
echo "Git:"
if command -v git >/dev/null 2>&1; then
  pass "$(git --version)"
else
  warn "git not found (only needed if cloning rather than downloading the zip)"
fi

# --- VS Code (runs the frontend) --------------------------------------------
echo "VS Code (runs the frontend):"
if command -v code >/dev/null 2>&1; then
  pass "code CLI available"
elif [ -x "$LOCALAPPDATA/Programs/Microsoft VS Code/bin/code" ] || [ -x "/c/Program Files/Microsoft VS Code/bin/code" ]; then
  warn "VS Code installed but the code CLI is not on PATH — use its absolute path"
else
  fail "VS Code not found — install it (the frontend runs from VS Code)"
fi

# --- Visual Studio (runs the backend, Windows only) -------------------------
echo "Visual Studio (runs the backend):"
if [ "$OS" = "Windows" ]; then
  VSWHERE="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
  if [ -x "$VSWHERE" ] && [ -n "$("$VSWHERE" -latest -property productPath 2>/dev/null)" ]; then
    pass "Visual Studio found: $("$VSWHERE" -latest -property displayName 2>/dev/null | tr -d '\r')"
  else
    warn "Visual Studio not found — install it, or run the backend with 'dotnet run' instead"
  fi
else
  info "not applicable on $OS — run the backend with 'dotnet run'"
fi

# --- Docker (Mac/Linux SQL Server) ------------------------------------------
echo "Docker (SQL Server host on Mac/Linux):"
if command -v docker >/dev/null 2>&1; then
  pass "$(docker --version)"
else
  warn "docker not found — required only on Mac/Linux to run SQL Server"
fi

# --- SQL Server reachability ------------------------------------------------
echo "SQL Server:"
case "$OS" in
  Windows)
    PS_SCRIPT="$SCRIPT_DIR/sql-query.ps1"
    if command -v cygpath >/dev/null 2>&1; then PS_SCRIPT="$(cygpath -w "$PS_SCRIPT")"; fi
    if powershell -NoProfile -ExecutionPolicy Bypass -File "$PS_SCRIPT" -Query "SELECT 1" >/dev/null 2>&1; then
      pass "a local SQL Server instance is reachable"
    else
      fail "no reachable local SQL Server — install SQL Server Express (or use Docker) and confirm the service is started"
    fi
    ;;
  *)
    if command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' 2>/dev/null | grep -qi 'sql'; then
      pass "a SQL Server container appears to be running"
    else
      warn "no running SQL Server container detected — start one (see references/mac-linux-setup.md)"
    fi
    ;;
esac

# --- sqlcmd (optional on Windows; bundled script covers the gap) ------------
echo "sqlcmd (optional):"
if command -v sqlcmd >/dev/null 2>&1; then
  pass "sqlcmd available on PATH"
elif [ "$OS" = "Windows" ]; then
  info "sqlcmd not on PATH — not required: use scripts/sql-query.ps1 for database checks"
else
  info "sqlcmd not on PATH — not required: the SQL Server container ships its own"
fi

# --- SqlPackage (database import) -------------------------------------------
echo "SqlPackage (.bacpac import):"
if command -v sqlpackage >/dev/null 2>&1; then
  pass "sqlpackage available on PATH"
elif [ -x "$HOME/.dotnet/tools/sqlpackage" ] || [ -x "$HOME/.dotnet/tools/sqlpackage.exe" ]; then
  warn "sqlpackage installed but not on PATH — use ~/.dotnet/tools/sqlpackage"
else
  warn "sqlpackage not found — install it to import the .bacpac (needs the .NET SDK first)"
fi

echo
echo "Preflight complete. Resolve every [FAIL] before continuing; review each [WARN]."
echo "On a machine missing several of these, read references/bare-machine-install.md before installing."
