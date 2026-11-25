# shellcheck shell=bash
# Docker Desktop settings (VM size, first-run screens) and restarts.
# Sourced by setup.sh; defines functions only.

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
