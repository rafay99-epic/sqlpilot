#!/bin/bash
# Fast tests for scripts/setup.sh that need no Docker: sizing, the fresh-Mac
# install plan, the VS Code settings merge, status on a fresh Mac, and logging.
# CI runs these on every PR; tests/stress.sh runs them first, then the Docker parts.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SETUP="$ROOT/scripts/setup.sh"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
# Sourced setup.sh functions log to $HOME; keep that out of the real log.
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
fails=0

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fails=$((fails + 1)); }
check() { local name=$1; shift; if "$@"; then pass "$name"; else fail "$name"; fi; }

echo "Sizing plan per Mac (RAM GB, CPUs -> container MB, CPUs, Docker VM MB)"
plan() { (source "$SETUP" && plan_resources "$1" "$2"); }
for spec in "8 8" "16 10" "18 12" "24 8" "36 14" "64 16" "128 24"; do
  printf '    %-7s -> %s\n' "$spec" "$(plan $spec)"
done
check "8 GB Mac stays at the 2.5 GB SQL Server floor" [ "$(plan 8 8)" = "2560 2 3584" ]
check "16 GB / 10 CPU gets 4 GB, 5 CPUs" [ "$(plan 16 10)" = "4096 5 5120" ]
check "CPUs capped at 6" [ "$(plan 128 24)" = "8192 6 9216" ]

echo "Fresh Mac: what gets installed (downloads and password prompt stubbed)"
fresh_plan() {
  (
    source "$SETUP"
    DOCKER_APP=/nonexistent NEW_DOCKER=0
    docker_up() { return 1; }
    vscode_app() { return 1; }
    command() { if [ "$1" = -v ] && { [ "$2" = colima ] || [ "$2" = dotnet ]; }; then return 1; fi; builtin command "$@"; }
    download() { echo "download: $3"; : >"$2"; }
    hdiutil() { if [ "$1" = attach ]; then printf '/dev/disk9s1\tApple_HFS\t/Volumes/Docker\n'; fi; }
    run_as_admin() { echo "admin: $1"; }
    ditto() { :; }
    install_missing arm64
    echo "NEW_DOCKER=$NEW_DOCKER"
  ) 2>&1
}
plan_out=$(fresh_plan)
echo "$plan_out" | sed 's/^/    /'
check "downloads Docker Desktop, .NET SDK and VS Code" eval '[ "$(echo "$plan_out" | grep -c "^download:")" = 3 ]'
check "one password prompt for every root step" eval '[ "$(echo "$plan_out" | grep -c "^admin:")" = 1 ]'
check "Docker installed with its license pre-accepted" eval 'echo "$plan_out" | grep -q "/Volumes/Docker/Docker.app/Contents/MacOS/install --accept-license --user=$USER && installer -pkg"'
check "fresh Docker gets VM sizing before first launch" eval 'echo "$plan_out" | grep -q "NEW_DOCKER=1"'

echo "VS Code connection"
vs="$SANDBOX/vscode-settings.json"
cat >"$vs" <<'JSONC'
{
  // my editor setup
  "editor.fontSize": 14,
  "mssql.connections": [
    { "profileName": "Work", "server": "db.example.com", "user": "me", },
  ],
}
JSONC
vsc() { (source "$SETUP"; VSCODE_SETTINGS="$vs"; PORT=1433; NAME=sqlserver; PASSWORD=Test-pw1; add_vscode_connection); }
r1=$(vsc); r2=$(vsc)
names=$(osascript -l JavaScript -e "JSON.parse(\$.NSString.stringWithContentsOfFileEncodingError('$vs', 4, null).js)['mssql.connections'].map(c => c.profileName).join(',')")
check "adds Local SQL Server to a JSONC settings file, keeps other settings" eval "[ '$r1' = updated ] && grep -q '\"editor.fontSize\": 14' '$vs' && [ '$names' = 'Work,Local SQL Server' ]"
check "second run leaves settings untouched" [ "$r2" = unchanged ]
check "original settings backed up" grep -q 'my editor setup' "$vs.bak-sqlserver-setup"

echo "Status and logs"
fresh_home=$(mktemp -d)
check "status says not installed on a fresh Mac" eval '[ "$(env HOME="$fresh_home" MSSQL_CONTAINER=sqlunit-none SQLSETUP_UI=1 /bin/bash "$SETUP" status | sed -n "s/^state|//p")" = notinstalled ]'
env HOME="$fresh_home" MSSQL_CONTAINER=sqlunit-none SQLSETUP_UI=1 /bin/bash "$SETUP" start >/dev/null 2>&1
today="$fresh_home/Library/Logs/SQLPilot/$(date +%F).log"
check "each run lands in today's log with its error and exit code" eval "grep -q '\[setup start\] start' '$today' && grep -q 'ERROR: The database isn.t set up yet.' '$today' && grep -q '\[setup start\] exit 1' '$today'"
check "status adds one state line to the log" grep -q '\[setup status\] notinstalled' "$today"
rm -rf "$fresh_home"

if ((fails)); then echo "$fails unit check(s) failed."; exit 1; fi
echo "All unit checks passed."
