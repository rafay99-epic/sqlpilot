# shellcheck shell=bash
# Small helpers: Docker checks, waiting, downloads, admin prompts, VS Code lookup.
# Sourced by setup.sh; defines functions only.

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
