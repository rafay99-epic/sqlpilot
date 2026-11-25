#!/bin/bash
# SQLPilot's engine: a local SQL Server for .NET coursework on any Mac.
# Installs whatever is missing (Rosetta, Docker Desktop, .NET SDK, VS Code)
# behind one password prompt, runs SQL Server 2022 sized to this Mac's RAM and
# CPUs, connects VS Code's SQL Server extension, and installs the `sqlserver`
# helper. Safe to re-run: it reuses the container and password and fixes
# whatever is missing, which is what the app's Repair button does.
#
#   setup.sh [setup]   install or repair (default)
#   setup.sh status    read-only health report for the app
#   setup.sh start     turn the database on
#   setup.sh stop      turn it off
#
# Overrides: MSSQL_SA_PASSWORD, MSSQL_PORT, MSSQL_CONTAINER, MSSQL_IMAGE,
#            MSSQL_MEMORY_MB, MSSQL_CPUS (integer), SQLSETUP_SKIP_APPS=1,
#            SQLSETUP_UI=1 (app output mode, see lib/ui.sh)
#
# Logs: ~/Library/Logs/SQLPilot/YYYY-MM-DD.log (shared with the app, kept 14 days)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

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

for lib in "$SCRIPT_DIR"/lib/*.sh; do
  # shellcheck source=/dev/null
  . "$lib"
done

# Full install or repair.
run_setup() {
  check_mac
  take_lock
  step "Installing what's missing"
  NEW_DOCKER=0
  install_missing "$ARCH"
  start_docker
  fit_docker_vm
  start_sql_server
  setup_tools
  finish
}

# Sourcing (tests) loads the functions without running anything.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-setup}" in
    setup)  log_begin setup; run_setup ;;
    status) LOG_TAG=status; status_report ;;
    start)  log_begin start; server_start ;;
    stop)   log_begin stop; server_stop ;;
    *) echo "usage: setup.sh [setup|status|start|stop]" >&2; exit 2 ;;
  esac
fi
