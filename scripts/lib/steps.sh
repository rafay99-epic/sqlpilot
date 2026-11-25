# shellcheck shell=bash
# The steps of a full setup, in order. run_setup in setup.sh calls them.
# They share the plan through globals: ARCH, MEM, CPUS, VM, ENGINE, PASSWORD, PORT.
# Sourced by setup.sh; defines functions only.

# Reads the Mac's RAM and CPUs and decides the limits (MEM, CPUS, VM).
check_mac() {
  step "Checking this Mac"
  local ram_gb ncpu
  ARCH=$(uname -m)
  ram_gb=$(($(sysctl -n hw.memsize) / 1073741824))
  ncpu=$(sysctl -n hw.ncpu)
  ok "macOS $(sw_vers -productVersion), $ARCH, ${ram_gb} GB RAM, $ncpu CPUs"
  ((ram_gb >= 8)) || warn "SQL Server needs about 3 GB free. Expect a slow Mac with ${ram_gb} GB."

  read -r MEM CPUS VM <<<"$(plan_resources "$ram_gb" "$ncpu")"
  MEM=${MSSQL_MEMORY_MB:-$MEM}
  CPUS=${MSSQL_CPUS:-$CPUS}
  ((MEM >= MIN_SQL_MB)) || die "MSSQL_MEMORY_MB must be at least $MIN_SQL_MB."
  ok "Plan: SQL Server gets ${MEM} MB and $CPUS CPUs"
}

# Double-clicking the app twice should not start two setups.
take_lock() {
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    # A lock left by a killed run is stale once its PID is gone.
    kill -0 "$(cat "$LOCK_DIR/pid" 2>/dev/null)" 2>/dev/null && die "Setup is already running in another window."
  fi
  echo $$ >"$LOCK_DIR/pid"
  trap 'rm -rf "$LOCK_DIR"' EXIT
}

# Starts Docker Desktop (or colima) and waits for the engine. Sets ENGINE.
start_docker() {
  step "Starting Docker"
  ENGINE=docker
  if docker_up; then
    ok "Docker is running"
  elif [ -d "$DOCKER_APP" ]; then
    # Size the VM before its first boot instead of Docker's default (half of RAM).
    if ((NEW_DOCKER)); then write_docker_settings "$VM" "$CPUS"; fi
    open -ga Docker
    say "Waiting for Docker Desktop (the first start takes a minute or two)..."
    wait_for 600 docker_up || die "Docker Desktop did not start. Open it from Applications, then run this again."
    ok "Docker is running"
  elif command -v colima >/dev/null; then
    colima start --vm-type vz --vz-rosetta --memory $(((VM + 1023) / 1024)) --cpu "$CPUS" \
      || die "colima failed to start."
    ENGINE=colima
    ok "colima is running"
  else
    die "Docker is not installed and could not be installed."
  fi
  if docker context show 2>/dev/null | grep -q colima; then ENGINE=colima; fi
}

# The container cannot use more than the VM has: shrink MEM to fit, or offer
# to grow Docker Desktop's VM.
fit_docker_vm() {
  local vm_mb
  vm_mb=$(($(docker info --format '{{.MemTotal}}') / 1048576))
  if ((vm_mb >= MEM + VM_OVERHEAD_MB)); then ok "Docker VM: ${vm_mb} MB"; return 0; fi
  if ((vm_mb - VM_OVERHEAD_MB >= MIN_SQL_MB)); then
    MEM=$((vm_mb - VM_OVERHEAD_MB))
    warn "Docker VM has ${vm_mb} MB, so SQL Server gets ${MEM} MB"
  elif [ "$ENGINE" = colima ]; then
    die "colima has ${vm_mb} MB. Run: colima stop && colima start --memory $(((VM + 1023) / 1024)), then run this again."
  else
    warn "Docker VM has ${vm_mb} MB; SQL Server needs ${VM} MB for the VM."
    confirm "Raise Docker Desktop to ${VM} MB and restart it? Running containers restart too." \
      || die "Raise Docker Desktop > Settings > Resources > Memory to ${VM} MB, then run this again."
    restart_docker_desktop_with "$VM" "$CPUS"
    ok "Docker VM resized"
  fi
}

# Reuses the saved password, or makes one for a brand-new server. Sets PASSWORD.
load_password() { # <container state>
  if [ -n "${MSSQL_SA_PASSWORD:-}" ]; then
    PASSWORD=$MSSQL_SA_PASSWORD
  elif [ -f "$PW_FILE" ]; then
    PASSWORD=$(<"$PW_FILE")
  elif [ "$1" != missing ] || docker volume inspect "$VOLUME" >/dev/null 2>&1; then
    die "Container or volume '$NAME' already exists but its password is unknown.
Re-run with MSSQL_SA_PASSWORD='...' or remove it: docker rm -f $NAME && docker volume rm $VOLUME"
  else
    # Random, plus a guaranteed upper/lower/digit/symbol to meet SQL Server policy.
    # Avoids ; ' " so it drops straight into connection strings.
    PASSWORD="Dev-$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | cut -c1-20)a1Z"
  fi
  printf '%s' "$PASSWORD" >"$PW_FILE"
  chmod 600 "$PW_FILE"
}

# Creates the container, or starts it and re-applies the limits. Sets PORT.
start_sql_server() {
  step "Starting SQL Server ($NAME)"
  local state
  state=$(docker container inspect -f '{{.State.Status}}' "$NAME" 2>/dev/null) || state=missing
  load_password "$state"

  local limits=(--memory "${MEM}m" --memory-swap "${MEM}m" --cpus "$CPUS")
  if [ "$state" = missing ]; then
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
  elif [ "$(docker container inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' "$NAME")" != "$((MEM * 1048576)) $((CPUS * 1000000000))" ]; then
    # SQL Server reads its memory limit at startup, so a change needs a restart.
    docker update "${limits[@]}" "$NAME" >/dev/null
    docker restart "$NAME" >/dev/null
    ok "Applied new limits and restarted"
  elif [ "$state" = running ]; then
    ok "Already running"
  else
    docker start "$NAME" >/dev/null
    ok "Container started"
  fi

  # The port of an existing container wins over MSSQL_PORT.
  PORT=$(docker port "$NAME" 1433/tcp | head -1 | awk -F: '{print $NF}')
  wait_until_ready
}

wait_until_ready() {
  say "Waiting for SQL Server to accept logins..."
  for ((i = 0; i < 90; i++)); do
    if [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" != true ]; then
      docker logs --tail 30 "$NAME" || true
      die "SQL Server exited. Logs above. In Docker Desktop, make sure Settings > General > 'Use Rosetta for x86_64/amd64 emulation' is on."
    fi
    if sql 'SELECT 1' >/dev/null 2>&1; then
      ok "$(sql "SELECT CAST(SERVERPROPERTY('ProductVersion') AS varchar) + ' ' + CAST(SERVERPROPERTY('Edition') AS varchar)" | head -1)"
      # SQL Server reports all host cores; Docker enforces the CPU limit as time quota.
      ok "Memory: SQL Server uses up to $(sql 'SELECT physical_memory_kb / 1024 FROM sys.dm_os_sys_info' | head -1) of ${MEM} MB, CPU limit: $CPUS"
      return 0
    fi
    sleep 2
  done
  die "SQL Server did not become ready. Check: docker logs $NAME"
}

# The sqlserver helper, dotnet-ef and VS Code.
setup_tools() {
  step "Tools"
  install_helper
  install_dotnet_ef
  local app
  if [ -z "${SQLSETUP_SKIP_APPS:-}" ] && app=$(vscode_app); then setup_vscode "$app"; fi
}

# Writes ~/.sqlserver-mac/connection.txt; in Terminal also prints a summary
# and opens VS Code. The app shows its own screen instead.
finish() {
  local conn="Server=localhost,$PORT;Database=YourDb;User Id=sa;Password=$PASSWORD;TrustServerCertificate=True;"
  cat >"$CONFIG_DIR/connection.txt" <<EOF
Server:   localhost,$PORT
User:     sa
Password: $PASSWORD

ConnectionString:
$conn

Limits: ${MEM} MB RAM, $CPUS CPUs (re-run setup with MSSQL_MEMORY_MB / MSSQL_CPUS to change)

VS Code (SSMS-style Object Explorer): run "sqlserver ui", or click the SQL
Server icon in VS Code's sidebar > "Local SQL Server".

Helper (new Terminal windows): sqlserver help
EOF
  chmod 600 "$CONFIG_DIR/connection.txt"

  step "Done. SQL Server is ready."
  [ -z "$UI" ] || return 0
  printf '%s' "$PASSWORD" | pbcopy
  cat <<EOF

    Server:    localhost,$PORT
    User:      sa
    Password:  $PASSWORD   (copied to clipboard)
    Limits:    ${MEM} MB RAM, $CPUS CPUs

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
  local app
  if [ -t 0 ] && [ -z "${SQLSETUP_SKIP_APPS:-}" ] && app=$(vscode_app); then open_sql_editor "$app"; fi
  # A clean exit lets Terminal close this window (its default for most profiles).
  if [ -t 0 ]; then read -r -t 60 -p $'\nThis window closes in 60 seconds. Press Return to close it now. ' _ || true; fi
}
