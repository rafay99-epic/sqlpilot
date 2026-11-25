# shellcheck shell=bash
# Daily log shared with the app: ~/Library/Logs/SQLPilot/YYYY-MM-DD.log.
# Every step/ok/warn/say/die line lands here too (see lib/ui.sh), so a
# student's install, start, stop and errors can be read back later.
# Sourced by setup.sh; defines functions only.

LOG_DIR="$HOME/Library/Logs/SQLPilot"
LOG_KEEP_DAYS=14

# Appends one timestamped line. Never fails the caller.
log_line() { # <text>
  mkdir -p "$LOG_DIR" 2>/dev/null || return 0
  printf '%s [setup %s] %s\n' "$(date '+%H:%M:%S')" "${LOG_TAG:-?}" "$*" \
    >>"$LOG_DIR/$(date +%F).log" 2>/dev/null || true
}

# Starts a logged run: tags its lines, records start and exit code, releases
# the setup lock if this run holds it, and drops logs older than two weeks.
log_begin() { # <command>
  LOG_TAG=$1
  log_line "start (pid $$${UI:+, from the app})"
  find "$LOG_DIR" -name '*.log' -mtime +"$LOG_KEEP_DAYS" -delete 2>/dev/null || true
  trap on_exit EXIT
}

on_exit() {
  local rc=$?
  if [ -n "${LOCK_HELD:-}" ]; then rm -rf "$LOCK_DIR"; fi
  log_line "exit $rc"
}
