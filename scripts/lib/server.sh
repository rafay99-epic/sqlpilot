# shellcheck shell=bash
# Running SQL, starting and stopping the server (the app's switch).
# Sourced by setup.sh; defines functions only.

sql() { # sql <query>: runs as sa inside the container
  docker exec -e SQLCMDPASSWORD="$PASSWORD" "$NAME" "$SQLCMD" -C -S localhost -U sa -b -h -1 -W -Q "SET NOCOUNT ON; $1"
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

# Turns the database off. Docker Desktop keeps running (other work may use
# it); its Resource Saver hands the VM's RAM back once nothing is running.
server_stop() {
  docker_up || return 0
  docker stop "$NAME" >/dev/null 2>&1 || true
  say "Stopped"
}
