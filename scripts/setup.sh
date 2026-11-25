#!/bin/bash
# One-shot SQL Server for local .NET dev on Apple Silicon (works on Intel too).
# Installs whatever is missing (Rosetta, Docker Desktop, .NET SDK, VS Code)
# behind one password prompt, starts SQL Server 2022 sized to this Mac's RAM
# and CPUs, sets up VS Code's SQL Server extension with a saved connection,
# and installs a `sqlserver` helper (restore .bak, run .sql, start/stop).
# Safe to re-run: reuses the container and saved password, re-applies limits.
#
# Overrides: MSSQL_SA_PASSWORD, MSSQL_PORT, MSSQL_CONTAINER, MSSQL_IMAGE,
#            MSSQL_MEMORY_MB, MSSQL_CPUS (integer), SQLSETUP_SKIP_APPS=1
set -euo pipefail

IMAGE="${MSSQL_IMAGE:-mcr.microsoft.com/mssql/server:2022-latest}"
NAME="${MSSQL_CONTAINER:-sqlserver}"
PORT="${MSSQL_PORT:-1433}"
VOLUME="${NAME}-data"
CONFIG_DIR="$HOME/.sqlserver-mac"
PW_FILE="$CONFIG_DIR/sa_password"
LOCK_DIR="$CONFIG_DIR/.lock"
DOCKER_APP=/Applications/Docker.app
DOCKER_SETTINGS="$HOME/Library/Group Containers/group.com.docker/settings-store.json"
VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
SQLCMD=/opt/mssql-tools18/bin/sqlcmd
DOTNET_CHANNEL=10.0

# SQL Server refuses to start below 2 GB; it uses 80% of the container limit.
MIN_SQL_MB=2560
# Room the Docker VM needs on top of the container (kernel, dockerd).
VM_OVERHEAD_MB=768
# Docker Desktop + SQL Server image + .NET SDK + VS Code, with headroom.
MIN_FREE_GB=8

# Apps launched from Finder get a bare PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/local/share/dotnet:/Applications/Docker.app/Contents/Resources/bin:$HOME/.dotnet/tools:$CONFIG_DIR/bin:$PATH"

# SQLSETUP_UI=1 (set by the app) turns output into "kind|text" lines it parses:
# progress|n|total|label, detail|text, error|text.
UI=${SQLSETUP_UI:-}
STEP_NO=0
STEP_TOTAL=6
step() {
  STEP_NO=$((STEP_NO + 1))
  if [ -n "$UI" ]; then printf 'progress|%s|%s|%s\n' "$STEP_NO" "$STEP_TOTAL" "$*"; else printf '\n\033[1m==> %s\033[0m\n' "$*"; fi
}
ok()   { if [ -n "$UI" ]; then printf 'detail|%s\n' "$*"; else printf '    \033[32m%s\033[0m\n' "$*"; fi; }
warn() { if [ -n "$UI" ]; then printf 'detail|%s\n' "$*"; else printf '    \033[33m%s\033[0m\n' "$*"; fi; }
say()  { if [ -n "$UI" ]; then printf 'detail|%s\n' "$*"; else printf '    %s\n' "$*"; fi; }
die() {
  if [ -n "$UI" ]; then printf 'error|%s\n' "$(printf '%s' "$*" | tr '\n' ' ')"
  else printf '\n\033[31mError: %s\033[0m\n' "$*"; pause_if_interactive; fi
  exit 1
}
pause_if_interactive() { if [ -t 0 ]; then read -r -p $'\nPress Return to close. ' _ || true; fi; }
confirm() {
  if [ -n "$UI" ]; then
    osascript -e "button returned of (display dialog \"$1\" buttons {\"Not now\", \"OK\"} default button \"OK\" with title \"SQL Server\")" 2>/dev/null | grep -q OK
    return
  fi
  [ -t 0 ] || return 1
  local a; read -r -p "    $1 [Y/n] " a; [[ ! "$a" =~ ^[Nn] ]]
}

# Picks limits for a host with $1 GB RAM and $2 CPUs.
# Prints "<container MB> <container CPUs> <Docker VM MB>".
plan_resources() {
  local ram_gb=$1 ncpu=$2 mem cpus
  if   ((ram_gb <= 8));  then mem=$MIN_SQL_MB
  elif ((ram_gb <= 16)); then mem=4096
  elif ((ram_gb <= 32)); then mem=6144
  else                        mem=8192
  fi
  cpus=$((ncpu / 2))
  if ((cpus < 2)); then cpus=2; fi
  if ((cpus > 6)); then cpus=6; fi
  if ((ram_gb <= 8)); then cpus=2; fi
  echo "$mem $cpus $((mem + VM_OVERHEAD_MB + 256))"
}

docker_up() { docker info >/dev/null 2>&1; }
docker_down() { ! docker_up; }

wait_for() { # wait_for <seconds> <command...>
  local secs=$1; shift
  for ((i = 0; i < secs; i += 2)); do
    "$@" && return 0
    sleep 2
  done
  return 1
}

vscode_app() {
  local app
  for app in "/Applications/Visual Studio Code.app" "$HOME/Applications/Visual Studio Code.app"; do
    if [ -d "$app" ]; then echo "$app"; return 0; fi
  done
  return 1
}

download() { # download <url> <file> <label>
  say "Downloading $3..."
  curl -fL --retry 3 $([ -n "$UI" ] && echo -sS || echo --progress-bar) -o "$2" "$1" || die "Downloading $3 failed. Check your internet connection and run this again."
}

# Runs shell commands as root behind one macOS password dialog.
run_as_admin() { # <command string>
  osascript - "$1" <<'EOF' >/dev/null
on run argv
  do shell script (item 1 of argv) with administrator privileges
end run
EOF
}

# Writes Docker Desktop's VM size and skips its first-run screens. Docker
# Desktop must not be running, or it overwrites the file on quit.
write_docker_settings() { # <vm MB> <cpus>
  mkdir -p "$(dirname "$DOCKER_SETTINGS")"
  [ -s "$DOCKER_SETTINGS" ] || echo '{}' >"$DOCKER_SETTINGS"
  plutil -replace MemoryMiB -integer "$1" "$DOCKER_SETTINGS"
  plutil -replace Cpus -integer "$2" "$DOCKER_SETTINGS"
  plutil -replace SwapMiB -integer 1024 "$DOCKER_SETTINGS"
  # Pauses the VM after idle time with no containers running.
  plutil -replace UseResourceSaver -bool true "$DOCKER_SETTINGS"
  plutil -replace DisplayedOnboarding -bool true "$DOCKER_SETTINGS"
  plutil -replace ShowInstallScreen -bool false "$DOCKER_SETTINGS"
}

restart_docker_desktop_with() { # <vm MB> <cpus>
  osascript -e 'quit app "Docker"' >/dev/null 2>&1 || true
  wait_for 60 docker_down || die "Docker Desktop did not quit. Quit it from the menu bar and run this again."
  sleep 3
  write_docker_settings "$1" "$2"
  open -ga Docker
  wait_for 180 docker_up || die "Docker Desktop did not come back. Open it and run this again."
}

# Downloads everything missing, then installs the parts that need root in a
# single password prompt. Sets NEW_DOCKER=1 when Docker Desktop was installed.
install_missing() { # <arch>
  local arch=$1 tmp admin=() names=() docker_mnt=""
  local need_rosetta=0 need_docker=0 need_dotnet=0 need_code=0
  if [ "$arch" = arm64 ] && [ ! -e /Library/Apple/usr/libexec/oah/libRosettaRuntime ]; then need_rosetta=1; names+=("Rosetta 2"); fi
  if ! docker_up && [ ! -d "$DOCKER_APP" ] && ! command -v colima >/dev/null; then need_docker=1; names+=("Docker Desktop"); fi
  if [ -z "${SQLSETUP_SKIP_APPS:-}" ]; then
    if ! command -v dotnet >/dev/null; then need_dotnet=1; names+=(".NET SDK $DOTNET_CHANNEL"); fi
    if ! vscode_app >/dev/null; then need_code=1; names+=("VS Code"); fi
  fi
  if ((${#names[@]} == 0)); then ok "Everything needed is already installed"; return 0; fi

  local free_gb
  free_gb=$(df -g "$HOME" | awk 'NR==2 {print $4}')
  ((free_gb >= MIN_FREE_GB)) || die "Only ${free_gb} GB free on disk; setup needs about ${MIN_FREE_GB} GB. Free some space and run this again."

  local list
  list=$(printf '%s, ' "${names[@]}")
  say "Installing: ${list%, }"
  tmp=$(mktemp -d)
  local rid=x64 docker_arch=amd64
  if [ "$arch" = arm64 ]; then rid=arm64; docker_arch=arm64; fi

  if ((need_rosetta)); then admin+=("softwareupdate --install-rosetta --agree-to-license"); fi
  if ((need_docker)); then
    download "https://desktop.docker.com/mac/main/$docker_arch/Docker.dmg" "$tmp/Docker.dmg" "Docker Desktop (~600 MB)"
    docker_mnt=$(hdiutil attach -nobrowse -noautoopen "$tmp/Docker.dmg" 2>/dev/null | awk -F'\t' '/\/Volumes\//{print $NF}')
    [ -n "$docker_mnt" ] || die "Could not open the Docker Desktop download. Run this again."
    # Docker's own CLI installer: copies the app, installs its helper and
    # accepts the license, so first launch needs no clicks.
    admin+=("$(printf '%q' "$docker_mnt/Docker.app/Contents/MacOS/install") --accept-license --user=$(printf '%q' "$USER")")
  fi
  if ((need_dotnet)); then
    download "https://aka.ms/dotnet/$DOTNET_CHANNEL/dotnet-sdk-osx-$rid.pkg" "$tmp/dotnet.pkg" ".NET SDK (~250 MB)"
    admin+=("installer -pkg $(printf '%q' "$tmp/dotnet.pkg") -target /")
  fi
  if ((need_code)); then
    download "https://update.code.visualstudio.com/latest/darwin-$([ "$arch" = arm64 ] && echo arm64 || echo x64)/stable" "$tmp/vscode.zip" "VS Code (~150 MB)"
  fi

  if ((${#admin[@]})); then
    say "macOS will ask for your password once."
    local joined
    joined=$(printf '%s && ' "${admin[@]}")
    if ! run_as_admin "${joined% && }"; then
      if [ -n "$docker_mnt" ]; then hdiutil detach -quiet "$docker_mnt" || true; fi
      die "Install was cancelled or failed. Run this again to retry."
    fi
  fi
  if [ -n "$docker_mnt" ]; then hdiutil detach -quiet "$docker_mnt" || true; NEW_DOCKER=1; ok "Docker Desktop installed"; fi
  if ((need_rosetta)); then ok "Rosetta 2 installed"; fi
  if ((need_dotnet)); then ok ".NET SDK $(dotnet --version 2>/dev/null) installed"; fi
  if ((need_code)); then
    local dest=/Applications
    if [ ! -w "$dest" ]; then dest="$HOME/Applications"; mkdir -p "$dest"; fi
    ditto -x -k "$tmp/vscode.zip" "$dest" || die "Could not unpack VS Code."
    ok "VS Code installed in $dest"
  fi
  rm -rf "$tmp"
}

sql() { # sql <query>: runs as sa inside the container
  docker exec -e SQLCMDPASSWORD="$PASSWORD" "$NAME" "$SQLCMD" -C -S localhost -U sa -b -h -1 -W -Q "SET NOCOUNT ON; $1"
}

# Adds or updates the "Local SQL Server" connection in VS Code's SQL Server
# extension, password included so it connects with no prompt. Acceptable
# because the server only listens on 127.0.0.1 and the password is random.
# Prints "updated" or "unchanged".
add_vscode_connection() {
  local profile
  profile=$(printf '{"id":"sqlserver-mac-%s","groupId":"ROOT","profileName":"Local SQL Server","server":"localhost,%s","authenticationType":"SqlLogin","user":"sa","password":"%s","savePassword":true,"database":"master","encrypt":"Mandatory","trustServerCertificate":true,"containerName":"%s"}' "$NAME" "$PORT" "$PASSWORD" "$NAME")
  mkdir -p "$(dirname "$VSCODE_SETTINGS")"
  osascript -l JavaScript - "$VSCODE_SETTINGS" "$profile" <<'EOF'
ObjC.import('Foundation')
function run(argv) {
  const [path, profileJson] = argv
  const profile = JSON.parse(profileJson)
  const fm = $.NSFileManager.defaultManager
  const text = fm.fileExistsAtPath(path)
    ? $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null).js : ''
  // settings.json is JSONC (comments, trailing commas); a JS object literal accepts both.
  const settings = text.trim() ? Function('return (' + text + '\n)')() : {}
  const list = settings['mssql.connections'] || []
  const current = list.find(c => c.profileName === profile.profileName)
  if (current && JSON.stringify(current) === JSON.stringify(profile)) return 'unchanged'
  // Back up the original once; later runs must not overwrite it with our own edits.
  if (text.trim() && !fm.fileExistsAtPath(path + '.bak-sqlserver-setup')) $(text).writeToFileAtomicallyEncodingError(path + '.bak-sqlserver-setup', true, $.NSUTF8StringEncoding, null)
  settings['mssql.connections'] = [...list.filter(c => c.profileName !== profile.profileName), profile]
  // The extension drops connections whose groupId names no existing group.
  const groups = settings['mssql.connectionGroups'] || []
  if (!groups.some(g => g.id === 'ROOT')) settings['mssql.connectionGroups'] = [...groups, { name: 'ROOT', id: 'ROOT' }]
  $(JSON.stringify(settings, null, 2) + '\n').writeToFileAtomicallyEncodingError(path, true, $.NSUTF8StringEncoding, null)
  return 'updated'
}
EOF
}

# Installs ~/.sqlserver-mac/bin/sqlserver, the everyday helper.
install_helper() {
  mkdir -p "$CONFIG_DIR/bin"
  sed "s/__NAME__/$NAME/" >"$CONFIG_DIR/bin/sqlserver" <<'EOF'
#!/bin/bash
# sqlserver: everyday commands for the local SQL Server container.
set -euo pipefail
NAME=__NAME__
DIR="$HOME/.sqlserver-mac"
export PATH="/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin:$PATH"
die() { echo "sqlserver: $*" >&2; exit 1; }
pw() { cat "$DIR/sa_password"; }
sqlcmd() { docker exec -i -e SQLCMDPASSWORD="$(pw)" "$NAME" /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa "$@"; }
quote() { local q="'"; printf "%s" "${1//$q/$q$q}"; } # escape for a T-SQL N'...' literal (bash 3.2 safe)

case "${1:-help}" in
  start)    docker start "$NAME" >/dev/null && echo "Started." ;;
  stop)     docker stop "$NAME" >/dev/null && echo "Stopped. RAM is free again." ;;
  status)   docker ps -a --filter "name=^/$NAME$" --format '{{.Names}}: {{.Status}}' ;;
  info)     cat "$DIR/connection.txt" ;;
  password) pw | pbcopy; echo "Password copied to the clipboard." ;;
  shell)    docker exec -it -e SQLCMDPASSWORD="$(pw)" "$NAME" /opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa ;;
  run)      # run <file.sql> [database]
    [ -f "${2:-}" ] || die "usage: sqlserver run <file.sql> [database]"
    sqlcmd -b -d "${3:-master}" <"$2" ;;
  restore)  # restore <file.bak> [database name]
    [ -f "${2:-}" ] || die "usage: sqlserver restore <file.bak> [database name]"
    bak=$(basename "$2"); db=${3:-${bak%.*}}
    docker exec "$NAME" mkdir -p /var/opt/mssql/backup
    # Streamed in (not docker cp) so the file belongs to SQL Server's own user.
    docker exec -i "$NAME" sh -c 'cat >"$1"' _ "/var/opt/mssql/backup/$bak" <"$2"
    # Backups made on Windows point at C:\ paths, so every file is moved
    # into the container's data folder.
    sqlcmd -b -Q "
      SET NOCOUNT ON;
      DECLARE @db sysname = N'$(quote "$db")', @path nvarchar(260) = N'/var/opt/mssql/backup/$(quote "$bak")';
      DECLARE @files TABLE (LogicalName nvarchar(128), PhysicalName nvarchar(260), Type char(1), FileGroupName nvarchar(128), Size numeric(20,0), MaxSize numeric(20,0), FileId bigint, CreateLSN numeric(25,0), DropLSN numeric(25,0), UniqueId uniqueidentifier, ReadOnlyLSN numeric(25,0), ReadWriteLSN numeric(25,0), BackupSizeInBytes bigint, SourceBlockSize int, FileGroupId int, LogGroupGUID uniqueidentifier, DifferentialBaseLSN numeric(25,0), DifferentialBaseGUID uniqueidentifier, IsReadOnly bit, IsPresent bit, TDEThumbprint varbinary(32), SnapshotUrl nvarchar(360));
      DECLARE @esc nvarchar(520) = REPLACE(@path, '''', ''''''); -- EXEC() accepts only variables and literals
      INSERT @files EXEC (N'RESTORE FILELISTONLY FROM DISK = N''' + @esc + N'''');
      DECLARE @sql nvarchar(max) = N'RESTORE DATABASE ' + QUOTENAME(@db) + N' FROM DISK = N''' + @esc + N''' WITH REPLACE, STATS = 25';
      SELECT @sql += N', MOVE N''' + REPLACE(LogicalName, '''', '''''') + N''' TO N''/var/opt/mssql/data/'
        + REPLACE(@db + N'_' + LogicalName, '''', '''''')
        + CASE Type WHEN 'L' THEN N'.ldf' WHEN 'D' THEN N'.mdf' ELSE N'' END + N'''' FROM @files;
      EXEC (@sql);"
    docker exec "$NAME" rm -f "/var/opt/mssql/backup/$bak"
    echo "Restored $bak as database [$db]." ;;
  ui)       # Opens VS Code connected, on the SSMS-style Object Explorer.
    port=$(docker port "$NAME" 1433/tcp | head -1 | awk -F: '{print $NF}')
    open "vscode://ms-mssql.mssql/connect?server=localhost%2C$port&database=master&user=sa&authenticationType=SqlLogin" ;;
  *) cat <<'USAGE'
sqlserver start | stop | status     control the server (stop frees its RAM)
sqlserver info                      server, login and connection string
sqlserver password                  copy the sa password
sqlserver ui                        open VS Code connected, Object Explorer like SSMS
sqlserver shell                     interactive sqlcmd prompt
sqlserver run <file.sql> [db]       run a script, e.g. one your professor shares
sqlserver restore <file.bak> [name] restore a backup (works with Windows .bak files)
USAGE
  ;;
esac
EOF
  chmod +x "$CONFIG_DIR/bin/sqlserver"
  if ! grep -qs '.sqlserver-mac/bin' "$HOME/.zprofile" "$HOME/.zshrc"; then
    printf '\nexport PATH="$PATH:$HOME/.sqlserver-mac/bin"\n' >>"$HOME/.zprofile"
  fi
}

main() {
  step "Checking this Mac"
  local arch ram_gb ncpu
  arch=$(uname -m)
  ram_gb=$(($(sysctl -n hw.memsize) / 1073741824))
  ncpu=$(sysctl -n hw.ncpu)
  ok "macOS $(sw_vers -productVersion), $arch, ${ram_gb} GB RAM, $ncpu CPUs"
  ((ram_gb >= 8)) || warn "SQL Server needs about 3 GB free. Expect a slow Mac with ${ram_gb} GB."

  local mem cpus vm
  read -r mem cpus vm <<<"$(plan_resources "$ram_gb" "$ncpu")"
  mem=${MSSQL_MEMORY_MB:-$mem}
  cpus=${MSSQL_CPUS:-$cpus}
  ((mem >= MIN_SQL_MB)) || die "MSSQL_MEMORY_MB must be at least $MIN_SQL_MB."
  ok "Plan: SQL Server gets ${mem} MB and $cpus CPUs"

  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  # Double-clicking the app twice should not start two setups.
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    # A lock left by a killed run is stale once its PID is gone.
    kill -0 "$(cat "$LOCK_DIR/pid" 2>/dev/null)" 2>/dev/null && die "Setup is already running in another window."
  fi
  echo $$ >"$LOCK_DIR/pid"
  trap 'rm -rf "$LOCK_DIR"' EXIT

  # SQL Server only ships amd64 images, so Apple Silicon needs Rosetta;
  # without it Docker falls back to QEMU, where SQL Server crashes.
  step "Installing what's missing"
  NEW_DOCKER=0
  install_missing "$arch"

  step "Starting Docker"
  local engine=docker
  if docker_up; then
    ok "Docker is running"
  elif [ -d "$DOCKER_APP" ]; then
    # Size the VM before its first boot instead of Docker's default (half of RAM).
    if ((NEW_DOCKER)); then write_docker_settings "$vm" "$cpus"; fi
    open -ga Docker
    say "Waiting for Docker Desktop (the first start takes a minute or two)..."
    wait_for 600 docker_up || die "Docker Desktop did not start. Open it from Applications, then run this again."
    ok "Docker is running"
  elif command -v colima >/dev/null; then
    colima start --vm-type vz --vz-rosetta --memory $(((vm + 1023) / 1024)) --cpu "$cpus" \
      || die "colima failed to start."
    engine=colima
    ok "colima is running"
  else
    die "Docker is not installed and could not be installed."
  fi
  if docker context show 2>/dev/null | grep -q colima; then engine=colima; fi

  # The container cannot use more than the VM has.
  local vm_mb
  vm_mb=$(($(docker info --format '{{.MemTotal}}') / 1048576))
  if ((vm_mb < mem + VM_OVERHEAD_MB)); then
    if ((vm_mb - VM_OVERHEAD_MB >= MIN_SQL_MB)); then
      mem=$((vm_mb - VM_OVERHEAD_MB))
      warn "Docker VM has ${vm_mb} MB, so SQL Server gets ${mem} MB"
    elif [ "$engine" = colima ]; then
      die "colima has ${vm_mb} MB. Run: colima stop && colima start --memory $(((vm + 1023) / 1024)), then run this again."
    else
      warn "Docker VM has ${vm_mb} MB; SQL Server needs ${vm} MB for the VM."
      confirm "Raise Docker Desktop to ${vm} MB and restart it? Running containers restart too." \
        || die "Raise Docker Desktop > Settings > Resources > Memory to ${vm} MB, then run this again."
      restart_docker_desktop_with "$vm" "$cpus"
      ok "Docker VM resized"
    fi
  else
    ok "Docker VM: ${vm_mb} MB"
  fi

  step "Starting SQL Server ($NAME)"
  local state
  state=$(docker container inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null) || state=missing

  if [ -n "${MSSQL_SA_PASSWORD:-}" ]; then
    PASSWORD=$MSSQL_SA_PASSWORD
  elif [ -f "$PW_FILE" ]; then
    PASSWORD=$(<"$PW_FILE")
  elif [ "$state" != missing ] || docker volume inspect "$VOLUME" >/dev/null 2>&1; then
    die "Container or volume '$NAME' already exists but its password is unknown.
Re-run with MSSQL_SA_PASSWORD='...' or remove it: docker rm -f $NAME && docker volume rm $VOLUME"
  else
    # Random, plus a guaranteed upper/lower/digit/symbol to meet SQL Server policy.
    # Avoids ; ' " so it drops straight into connection strings.
    PASSWORD="Dev-$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | cut -c1-20)a1Z"
  fi
  printf '%s' "$PASSWORD" >"$PW_FILE"
  chmod 600 "$PW_FILE"

  local limits=(--memory "${mem}m" --memory-swap "${mem}m" --cpus "$cpus")
  case "$state" in
    missing)
      if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
        die "Port $PORT is already in use. Re-run with MSSQL_PORT=14330 (or any free port)."
      fi
      say "Downloading SQL Server (about 1.5 GB the first time)..."
      docker pull --platform linux/amd64 "$IMAGE" >/dev/null || die "SQL Server download failed. Check your internet connection."
      # Bound to 127.0.0.1: reachable from this Mac only, not the Wi-Fi.
      docker run -d --name "$NAME" --platform linux/amd64 \
        -e ACCEPT_EULA=Y -e MSSQL_PID=Developer -e MSSQL_SA_PASSWORD="$PASSWORD" \
        -p "127.0.0.1:$PORT:1433" -v "$VOLUME:/var/opt/mssql" "${limits[@]}" \
        --restart unless-stopped "$IMAGE" >/dev/null
      ok "Container created"
      ;;
    *)
      # SQL Server reads its memory limit at startup, so a change needs a restart.
      local current
      current=$(docker container inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' "$NAME")
      if [ "$current" != "$((mem * 1048576)) $((cpus * 1000000000))" ]; then
        docker update "${limits[@]}" "$NAME" >/dev/null
        docker restart "$NAME" >/dev/null
        ok "Applied new limits and restarted"
      elif [ "$state" = running ]; then
        ok "Already running"
      else
        docker start "$NAME" >/dev/null
        ok "Container started"
      fi
      ;;
  esac

  # The port of an existing container wins over MSSQL_PORT.
  PORT=$(docker port "$NAME" 1433/tcp | head -1 | awk -F: '{print $NF}')

  say "Waiting for SQL Server to accept logins..."
  local ready=0
  for ((i = 0; i < 90; i++)); do
    if [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" != true ]; then
      docker logs --tail 30 "$NAME" || true
      die "SQL Server exited. Logs above. In Docker Desktop, make sure Settings > General > 'Use Rosetta for x86_64/amd64 emulation' is on."
    fi
    if sql 'SELECT 1' >/dev/null 2>&1; then ready=1; break; fi
    sleep 2
  done
  [ "$ready" = 1 ] || die "SQL Server did not become ready. Check: docker logs $NAME"
  ok "$(sql "SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar) + ' ' + CAST(SERVERPROPERTY('Edition') AS varchar)" | head -1)"
  # SQL Server reports all host cores; Docker enforces the CPU limit as time quota.
  ok "Memory: SQL Server uses up to $(sql 'SELECT physical_memory_kb / 1024 FROM sys.dm_os_sys_info' | head -1) of ${mem} MB, CPU limit: $cpus"

  step "Tools"
  install_helper
  ok "sqlserver helper (type: sqlserver)"
  if command -v dotnet >/dev/null; then
    if dotnet tool list --global | grep -q '^dotnet-ef '; then
      ok "dotnet-ef $(dotnet tool list --global | awk '$1 == "dotnet-ef" {print $2}')"
    elif dotnet tool install --global dotnet-ef --version "$(dotnet --version | cut -d. -f1).*" >/dev/null 2>&1; then
      ok "dotnet-ef $(dotnet tool list --global | awk '$1 == "dotnet-ef" {print $2}') installed"
    else
      warn "Could not install dotnet-ef. Try: dotnet tool install --global dotnet-ef"
    fi
    # ~/.dotnet/tools must be on PATH for `dotnet ef` in new shells.
    if ! grep -qs '.dotnet/tools' "$HOME/.zprofile" "$HOME/.zshrc"; then
      printf '\nexport PATH="$PATH:$HOME/.dotnet/tools"\n' >>"$HOME/.zprofile"
    fi
  else
    warn ".NET SDK not installed."
  fi
  local app code=""
  if [ -z "${SQLSETUP_SKIP_APPS:-}" ] && app=$(vscode_app); then
    code="$app/Contents/Resources/app/bin/code"
    if "$code" --install-extension ms-mssql.mssql >/dev/null 2>&1; then ok "VS Code: SQL Server extension"
    else warn "Could not install the VS Code SQL Server extension. Install 'SQL Server (mssql)' from the Extensions view."; fi
    if "$code" --install-extension ms-dotnettools.csdevkit >/dev/null 2>&1; then ok "VS Code: C# Dev Kit"; fi
    if [ -n "$(add_vscode_connection 2>/dev/null)" ]; then ok "VS Code: saved connection \"Local SQL Server\""
    else warn "Could not add the VS Code connection; add it by hand with the details below."; fi
  fi

  local conn="Server=localhost,$PORT;Database=YourDb;User Id=sa;Password=$PASSWORD;TrustServerCertificate=True;"
  cat >"$CONFIG_DIR/connection.txt" <<EOF
Server:   localhost,$PORT
User:     sa
Password: $PASSWORD

ConnectionString:
$conn

Limits: ${mem} MB RAM, $cpus CPUs (re-run setup with MSSQL_MEMORY_MB / MSSQL_CPUS to change)

VS Code (SSMS-style Object Explorer): run "sqlserver ui", or click the SQL
Server icon in VS Code's sidebar > "Local SQL Server".

Helper (new Terminal windows): sqlserver help
EOF
  chmod 600 "$CONFIG_DIR/connection.txt"

  step "Done. SQL Server is ready."
  # The app shows its own screen; the summary below is for Terminal runs.
  [ -z "$UI" ] || return 0
  printf '%s' "$PASSWORD" | pbcopy
  cat <<EOF

    Server:    localhost,$PORT
    User:      sa
    Password:  $PASSWORD   (copied to clipboard)
    Limits:    ${mem} MB RAM, $cpus CPUs

    VS Code is opening, connected, on the Object Explorer (like SSMS):
      Databases, Security, Server Objects in the tree on the left
      Right-click the server > New Query, type SQL, click Run
      Later, reopen it with: sqlserver ui

    Professor shared a file? In a new Terminal window:
      sqlserver restore ~/Downloads/SchoolDb.bak
      sqlserver run ~/Downloads/script.sql

    For your ASP.NET app (keeps the password out of git):
      dotnet user-secrets init
      dotnet user-secrets set "ConnectionStrings:DefaultConnection" "$conn"
      dotnet ef database update

    Saved to ~/.sqlserver-mac/connection.txt. Not using it? sqlserver stop
EOF

  if [ -t 0 ] && [ -n "$code" ]; then
    # Opens VS Code, connects with the saved profile and focuses Object Explorer.
    "$code" --open-url "vscode://ms-mssql.mssql/connect?server=localhost%2C$PORT&database=master&user=sa&authenticationType=SqlLogin" >/dev/null 2>&1 || true
  fi
  # A clean exit lets Terminal close this window (its default for most profiles).
  if [ -t 0 ]; then read -r -t 60 -p $'\nThis window closes in 60 seconds. Press Return to close it now. ' _ || true; fi
}

# Prints one "check|id|ok/bad/off/info|label|detail" line per part, then
# "state|notinstalled/broken/off/starting/on", plus "reason|..." when broken,
# "minor|..." for problems that don't stop the server, and "port|...".
# Read-only: never installs or changes anything.
status_report() {
  local issues=() minor=() state docker_ok=0 container=unknown
  emit_check() { printf 'check|%s|%s|%s|%s\n' "$@"; }

  if [ "$(uname -m)" = arm64 ]; then
    if [ -e /Library/Apple/usr/libexec/oah/libRosettaRuntime ]; then emit_check rosetta ok "Rosetta 2" "installed"
    else emit_check rosetta bad "Rosetta 2" "missing"; issues+=("Rosetta isn't installed."); fi
  fi

  if docker_up; then
    docker_ok=1
    emit_check docker ok "Docker" "running"
  elif [ -d "$DOCKER_APP" ] || command -v colima >/dev/null; then
    emit_check docker off "Docker" "not running"
  else
    emit_check docker bad "Docker" "not installed"; issues+=("Docker isn't installed.")
  fi

  if ((docker_ok)); then
    container=$(docker container inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null) || container=missing
  fi
  case "$container" in
    running)
      PASSWORD=$(cat "$PW_FILE" 2>/dev/null || true)
      local version
      if [ -n "$PASSWORD" ] && version=$(sql "SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar)" 2>/dev/null | head -1); then
        emit_check server ok "SQL Server" "$version"
        container=ready
      else
        emit_check server off "SQL Server" "starting"
      fi ;;
    missing)
      emit_check server bad "SQL Server" "not set up"
      if [ -f "$PW_FILE" ]; then issues+=("The database was removed."); fi ;;
    unknown) emit_check server off "SQL Server" "off" ;;
    *) emit_check server off "SQL Server" "off" ;;
  esac
  if ((docker_ok)) && [ "$container" != missing ]; then
    local limits
    limits=$(docker container inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' "$NAME" 2>/dev/null) || limits="0 0"
    emit_check limits info "Memory and CPU" "$(( ${limits% *} / 1048576 )) MB, $(( ${limits#* } / 1000000000 )) CPUs"
    local port
    port=$(docker port "$NAME" 1433/tcp 2>/dev/null | head -1) || true
    [ -n "$port" ] && PORT=${port##*:}
  fi

  if command -v dotnet >/dev/null; then emit_check dotnet ok ".NET SDK" "$(dotnet --version 2>/dev/null)"
  else emit_check dotnet bad ".NET SDK" "missing"; minor+=(".NET isn't installed."); fi
  if [ -n "$(ls -d "$HOME"/.dotnet/tools/dotnet-ef 2>/dev/null)" ]; then emit_check ef ok "dotnet-ef" "installed"
  else emit_check ef bad "dotnet-ef" "missing"; minor+=("dotnet-ef isn't installed."); fi
  if vscode_app >/dev/null; then
    emit_check vscode ok "VS Code" "installed"
    if ls -d "$HOME"/.vscode/extensions/ms-mssql.mssql-* >/dev/null 2>&1; then emit_check mssql ok "SQL Server extension" "installed"
    else emit_check mssql bad "SQL Server extension" "missing"; minor+=("The SQL editor isn't set up."); fi
    if grep -qs "sqlserver-mac-$NAME" "$VSCODE_SETTINGS"; then emit_check connection ok "Saved connection" "Local SQL Server"
    else emit_check connection bad "Saved connection" "missing"; minor+=("The SQL editor isn't connected."); fi
  else
    emit_check vscode bad "VS Code" "missing"; minor+=("The SQL editor isn't installed.")
  fi
  if [ -x "$CONFIG_DIR/bin/sqlserver" ]; then emit_check helper ok "sqlserver command" "installed"
  else emit_check helper bad "sqlserver command" "missing"; minor+=("The sqlserver command is missing."); fi

  if [ ! -f "$PW_FILE" ] && { [ "$container" = missing ] || [ "$container" = unknown ]; }; then state=notinstalled
  elif ((${#issues[@]})); then state=broken
  elif [ "$container" = ready ]; then state=on
  elif [ "$container" = running ]; then state=starting
  else state=off
  fi
  echo "state|$state"
  if ((${#issues[@]})); then echo "reason|${issues[0]}"; fi
  if ((${#minor[@]})); then echo "minor|${minor[0]}"; fi
  echo "port|$PORT"
}

# Turns the database on: starts Docker if needed, then the container, then
# waits until SQL Server accepts logins.
server_start() {
  PASSWORD=$(cat "$PW_FILE" 2>/dev/null) || die "The database isn't set up yet."
  if ! docker_up; then
    say "Starting Docker"
    if [ -d "$DOCKER_APP" ]; then open -ga Docker
    elif command -v colima >/dev/null; then colima start >/dev/null 2>&1 || true
    else die "Docker isn't installed."; fi
    wait_for 180 docker_up || die "Docker didn't start."
  fi
  say "Starting SQL Server"
  docker start "$NAME" >/dev/null 2>&1 || die "The database is missing. Use Fix it to set it up again."
  for ((i = 0; i < 90; i++)); do
    if sql 'SELECT 1' >/dev/null 2>&1; then say "Ready"; return 0; fi
    [ "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null)" = true ] || die "SQL Server stopped while starting."
    sleep 2
  done
  die "SQL Server is taking too long to start."
}

# Turns the database off. Also stops Docker Desktop when nothing else is
# running in it, so its VM gives the RAM back.
server_stop() {
  docker_up || return 0
  docker stop "$NAME" >/dev/null 2>&1 || true
  if [ -z "${SQLSETUP_KEEP_DOCKER:-}" ] && [ -z "$(docker ps -q)" ] && docker desktop version >/dev/null 2>&1; then
    docker desktop stop >/dev/null 2>&1 || true
  fi
  say "Stopped"
}

# Sourcing (tests) loads the functions without running anything.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-setup}" in
    status) status_report ;;
    start)  server_start ;;
    stop)   server_stop ;;
    setup)  main ;;
    *) echo "usage: setup.sh [setup|status|start|stop]" >&2; exit 2 ;;
  esac
fi
