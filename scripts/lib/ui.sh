# shellcheck shell=bash
# Output for Terminal or the app (SQLSETUP_UI=1), plus prompts.
# Sourced by setup.sh; defines functions only.

# SQLSETUP_UI=1 (set by the app) turns output into "kind|text" lines it parses:
# progress|n|total|label, detail|text, error|text.
UI=${SQLSETUP_UI:-}
STEP_NO=0
STEP_TOTAL=6
step() {
  STEP_NO=$((STEP_NO + 1))
  log_line "== $*"
  if [ -n "$UI" ]; then printf 'progress|%s|%s|%s\n' "$STEP_NO" "$STEP_TOTAL" "$*"; else printf '\n\033[1m==> %s\033[0m\n' "$*"; fi
}
ok()   { log_line "$*"; if [ -n "$UI" ]; then printf 'detail|%s\n' "$*"; else printf '    \033[32m%s\033[0m\n' "$*"; fi; }
warn() { log_line "WARN: $*"; if [ -n "$UI" ]; then printf 'detail|%s\n' "$*"; else printf '    \033[33m%s\033[0m\n' "$*"; fi; }
say()  { log_line "$*"; if [ -n "$UI" ]; then printf 'detail|%s\n' "$*"; else printf '    %s\n' "$*"; fi; }
die() {
  log_line "ERROR: $*"
  if [ -n "$UI" ]; then printf 'error|%s\n' "$(printf '%s' "$*" | tr '\n' ' ')"
  else printf '\n\033[31mError: %s\033[0m\n' "$*"; pause_if_interactive; fi
  exit 1
}
pause_if_interactive() { if [ -t 0 ]; then read -r -p $'\nPress Return to close. ' _ || true; fi; }
confirm() {
  if [ -n "$UI" ]; then
    osascript -e "button returned of (display dialog \"$1\" buttons {\"Not now\", \"OK\"} default button \"OK\" with title \"SQLPilot\")" 2>/dev/null | grep -q OK
    return
  fi
  [ -t 0 ] || return 1
  local a; read -r -p "    $1 [Y/n] " a; [[ ! "$a" =~ ^[Nn] ]]
}
