#!/bin/bash
# Stress test for setup.sh. Runs in a sandbox (temp HOME, container
# "sqlstress" on port 14339), so the real "sqlserver" container and
# ~/.sqlserver-mac are never touched. Needs Docker running.
#
#   ./tests/stress.sh                    # everything, 90 s load phase
#   STRESS_SECONDS=300 ./tests/stress.sh # longer soak
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SETUP="$ROOT/setup.sh"
NAME=sqlstress
PORT=14339
SECS=${STRESS_SECONDS:-90}
SQLCMD=/opt/mssql-tools18/bin/sqlcmd
SANDBOX=$(mktemp -d)
LOGS="$SANDBOX/logs"
mkdir -p "$SANDBOX/home" "$LOGS"
# Pin the engine before HOME changes, since docker reads its context from HOME.
DOCKER_HOST=$(docker context inspect --format '{{.Endpoints.docker.Host}}') || exit 1
export DOCKER_HOST
CLIPBOARD=$(pbpaste)
fails=0

cleanup() {
  docker rm -f "$NAME" "${NAME}2" >/dev/null 2>&1
  docker volume rm "$NAME-data" "${NAME}2-data" >/dev/null 2>&1
  printf '%s' "$CLIPBOARD" | pbcopy
  rm -rf "$SANDBOX"
}
trap cleanup EXIT

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fails=$((fails + 1)); }
check() { local name=$1; shift; if "$@"; then pass "$name"; else fail "$name"; fi; }
now() { perl -MTime::HiRes=time -e 'printf "%.3f", time'; }

# setup <log name> [VAR=value...]: runs setup.sh in the sandbox, returns its exit code
setup() {
  local log=$1; shift
  env HOME="$SANDBOX/home" MSSQL_CONTAINER="$NAME" MSSQL_PORT="$PORT" SQLSETUP_SKIP_APPS=1 "$@" \
    /bin/bash "$SETUP" </dev/null >"$LOGS/$log" 2>&1
}
logged() { grep -q "$2" "$LOGS/$1"; }
limits_are() { # <MB> <cpus>
  [ "$(docker inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}}' "$NAME")" = "$(($1 * 1048576)) $(($2 * 1000000000))" ]
}
sql() {
  docker exec -e SQLCMDPASSWORD="$(cat "$SANDBOX/home/.sqlserver-mac/sa_password")" "$NAME" \
    "$SQLCMD" -C -S localhost -U sa -b -h -1 -W -Q "SET NOCOUNT ON; $1"
}

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

echo "Install scenarios"
t0=$(now)
setup fresh MSSQL_MEMORY_MB=2560 MSSQL_CPUS=2
check "fresh install on 8 GB tier" [ $? = 0 ]
echo "    took $(printf '%.0f' "$(echo "$(now) - $t0" | bc)")s (includes image pull if not cached)"
check "container limited to 2560 MB, 2 CPUs" limits_are 2560 2
cap=$(sql 'SELECT physical_memory_kb / 1024 FROM sys.dm_os_sys_info' | head -1)
check "SQL Server caps itself inside the container (${cap} MB of 2560)" [ "${cap:-0}" -le 2560 ]

t0=$(now)
setup rerun MSSQL_MEMORY_MB=2560 MSSQL_CPUS=2
rc=$?; dt=$(echo "$(now) - $t0" | bc)
check "re-run is a no-op (${dt}s)" eval "[ $rc = 0 ] && logged rerun 'Already running'"

docker stop "$NAME" >/dev/null
setup stopped MSSQL_MEMORY_MB=2560 MSSQL_CPUS=2
rc=$?; check "re-run starts a stopped container" eval "[ $rc = 0 ] && logged stopped 'Container started'"

setup resize MSSQL_MEMORY_MB=3072 MSSQL_CPUS=3
rc=$?; check "changed limits are applied on re-run" eval "[ $rc = 0 ] && limits_are 3072 3"
setup resize-back MSSQL_MEMORY_MB=2560 MSSQL_CPUS=2

setup concurrent-a MSSQL_MEMORY_MB=2560 MSSQL_CPUS=2 & a=$!
setup concurrent-b MSSQL_MEMORY_MB=2560 MSSQL_CPUS=2 & b=$!
wait $a; ra=$?; wait $b; rb=$?
busy=$(grep -l "already running in another window" "$LOGS"/concurrent-* | wc -l | tr -d ' ')
check "double launch: one runs, one stops cleanly (exit $ra/$rb)" eval "[ $((ra + rb)) -le 1 ] && [ $busy -le 1 ]"

mkdir -p "$SANDBOX/home/.sqlserver-mac/.lock" && echo 999999 >"$SANDBOX/home/.sqlserver-mac/.lock/pid"
setup stale-lock MSSQL_MEMORY_MB=2560 MSSQL_CPUS=2
check "stale lock from a killed run is ignored" [ $? = 0 ]

setup port-taken MSSQL_CONTAINER="${NAME}2"
rc=$?; check "busy port fails with a clear message" eval "[ $rc != 0 ] && logged port-taken 'already in use'"

env HOME="$(mktemp -d)" MSSQL_CONTAINER="$NAME" SQLSETUP_SKIP_APPS=1 /bin/bash "$SETUP" </dev/null >"$LOGS/no-pw" 2>&1
rc=$?; check "existing container with unknown password fails clearly" eval "[ $rc != 0 ] && logged no-pw 'password is unknown'"

setup too-small MSSQL_MEMORY_MB=1024
rc=$?; check "memory below SQL Server's floor is rejected" eval "[ $rc != 0 ] && logged too-small 'at least 2560'"

check "server only reachable from this Mac (127.0.0.1)" eval '[ "$(docker port "$NAME" 1433/tcp)" = "127.0.0.1:$PORT" ]'

echo "Helper: sqlserver run / restore"
helper() { HOME="$SANDBOX/home" "$SANDBOX/home/.sqlserver-mac/bin/sqlserver" "$@"; }
printf 'CREATE DATABASE ClassDb;\nGO\nUSE ClassDb;\nCREATE TABLE Students (Id int PRIMARY KEY, Name nvarchar(50));\nINSERT Students VALUES (1, N%sAda%s), (2, N%sGrace%s);\nGO\n' "'" "'" "'" "'" >"$SANDBOX/class.sql"
helper run "$SANDBOX/class.sql" >"$LOGS/helper-run" 2>&1
check "sqlserver run executes a professor's .sql file" [ "$(sql 'SELECT COUNT(*) FROM ClassDb.dbo.Students' | head -1)" = 2 ]
sql "BACKUP DATABASE ClassDb TO DISK = N'/var/opt/mssql/data/ClassDb.bak' WITH INIT" >/dev/null
docker cp "$NAME:/var/opt/mssql/data/ClassDb.bak" "$SANDBOX/ClassDb.bak" >/dev/null
helper restore "$SANDBOX/ClassDb.bak" "Restored O'Brien" >"$LOGS/helper-restore" 2>&1
check "sqlserver restore loads a .bak under a new name (quotes too)" eval "[ \"\$(sql \"SELECT COUNT(*) FROM [Restored O'Brien].dbo.Students\" | head -1)\" = 2 ]"
helper restore "$SANDBOX/ClassDb.bak" >"$LOGS/helper-restore2" 2>&1
check "sqlserver restore over an existing database replaces it" [ $? = 0 ]

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

echo "Load: 8 sessions for ${SECS}s on 2560 MB / 2 CPUs"
sql "CREATE DATABASE StressDb; ALTER DATABASE StressDb SET RECOVERY SIMPLE; ALTER DATABASE StressDb SET READ_COMMITTED_SNAPSHOT ON;" >/dev/null
t0=$(now)
sql "USE StressDb;
  CREATE TABLE t (id int IDENTITY PRIMARY KEY, k int NOT NULL, g uniqueidentifier NOT NULL DEFAULT NEWID(), pad char(1000) NOT NULL DEFAULT 'x');
  INSERT t (k) SELECT TOP (1000000) ABS(CHECKSUM(NEWID())) % 10000 FROM sys.all_objects a CROSS JOIN sys.all_objects b;" >/dev/null
check "loaded 1M rows (~1 GB) in $(printf '%.0f' "$(echo "$(now) - $t0" | bc)")s" [ "$(sql 'SELECT COUNT(*) FROM StressDb.dbo.t' | head -1)" = 1000000 ]

work="USE StressDb;
  DECLARE @end datetime2 = DATEADD(second, $SECS, SYSDATETIME()), @x bigint;
  WHILE SYSDATETIME() < @end BEGIN
    BEGIN TRY
    SELECT @x = COUNT(*) FROM (SELECT TOP 200000 * FROM t ORDER BY g) s;
    SELECT @x = COUNT(*) FROM (SELECT k, COUNT(*) c, MAX(pad) p FROM t GROUP BY k) s;
    SELECT @x = COUNT(*) FROM t a JOIN t b ON a.k = b.k WHERE a.id % 97 = 0 AND b.id % 89 = 0;
    UPDATE TOP (5000) t SET g = NEWID() WHERE id % 50 = ABS(CHECKSUM(NEWID())) % 50;
    END TRY
    BEGIN CATCH
      -- Deadlock victims retry, like an app would. Anything else fails the worker.
      IF ERROR_NUMBER() <> 1205 THROW;
      PRINT 'deadlock';
    END CATCH
  END"
pids=()
for n in 1 2 3 4 5 6 7 8; do
  sql "$work" >"$LOGS/worker-$n" 2>&1 & pids+=($!)
done

peak_mb=0 max_lat=0 min_free=100 samples=0
end=$(($(date +%s) + SECS))
while (($(date +%s) < end)); do
  mem=$(docker stats --no-stream --format '{{.MemUsage}}' "$NAME" | awk '{v=$1; u=v; gsub(/[0-9.]/,"",u); gsub(/[A-Za-z]/,"",v); print (u=="GiB") ? int(v*1024) : int(v)}')
  ((mem > peak_mb)) && peak_mb=$mem
  t0=$(now); sql 'SELECT 1' >/dev/null; lat=$(echo "$(now) - $t0" | bc)
  (($(echo "$lat > $max_lat" | bc))) && max_lat=$lat
  free=$(memory_pressure -Q 2>/dev/null | awk -F': ' '/percentage/{gsub(/%/,"",$2); print $2}')
  ((${free:-100} < min_free)) && min_free=$free
  samples=$((samples + 1))
done
worker_fail=0
for p in "${pids[@]}"; do wait "$p" || worker_fail=$((worker_fail + 1)); done

echo "    samples=$samples peak container RAM=${peak_mb} MB, slowest SELECT 1=${max_lat}s, lowest host free memory=${min_free}%"
deadlocks=$(cat "$LOGS"/worker-* | grep -c deadlock)
echo "    deadlocks retried: $deadlocks"
check "all 8 workers finished without errors ($worker_fail failed)" [ $worker_fail = 0 ]
check "container RAM stayed under its 2560 MB cap" [ "$peak_mb" -le 2560 ]
check "not OOM-killed, no restarts" [ "$(docker inspect -f '{{.State.OOMKilled}} {{.RestartCount}} {{.State.Running}}' "$NAME")" = "false 0 true" ]
check "stayed responsive under load (slowest SELECT 1 under 5s)" [ "$(echo "$max_lat < 5" | bc)" = 1 ]
check "still accepting queries after load" [ "$(sql 'SELECT 1' | head -1)" = 1 ]

if ((fails)); then
  kept=$(mktemp -d /tmp/sqlstress-logs.XXXX)
  cp -R "$LOGS/." "$kept/"
  echo "$fails check(s) failed. Logs: $kept"
  exit 1
fi
echo "All checks passed."
