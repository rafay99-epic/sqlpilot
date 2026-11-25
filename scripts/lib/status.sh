# shellcheck shell=bash
# Read-only health report the app renders (setup.sh status).
# Sourced by setup.sh; defines functions only.

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
  log_line "$state${issues[0]:+: ${issues[0]}}"
  echo "state|$state"
  if ((${#issues[@]})); then echo "reason|${issues[0]}"; fi
  if ((${#minor[@]})); then echo "minor|${minor[0]}"; fi
  echo "port|$PORT"
}
