# shellcheck shell=bash
# Installs Rosetta, Docker Desktop, .NET SDK and VS Code when missing.
# Sourced by setup.sh; defines functions only.

# Downloads everything missing, then installs the parts that need root in a
# single password prompt. Sets NEW_DOCKER=1 when Docker Desktop was installed.
install_missing() { # <arch>
  local arch=$1 tmp admin=() names=() docker_mnt=""
  local need_rosetta=0 need_docker=0 need_dotnet=0 need_code=0
  if [ "$arch" = arm64 ] && [ ! -e /Library/Apple/usr/libexec/oah/libRosettaRuntime ]; then need_rosetta=1; names+=("Rosetta 2"); fi
  if ! docker_up && [ ! -d "$DOCKER_APP" ] && ! command -v colima >/dev/null; then need_docker=1; names+=("Docker Desktop"); fi
  if [ -z "${SQLSETUP_SKIP_APPS:-}" ]; then
    if ! command -v dotnet >/dev/null; then need_dotnet=1; names+=(".NET SDK $DOTNET_CHANNEL"); fi
    if ! vscode_app >/dev/null; then need_code=1; names+=("VS Code"); fi
  fi
  if ((${#names[@]} == 0)); then ok "Everything needed is already installed"; return 0; fi

  local free_gb
  free_gb=$(df -g "$HOME" | awk 'NR==2 {print $4}')
  ((free_gb >= MIN_FREE_GB)) || die "Only ${free_gb} GB free on disk; setup needs about ${MIN_FREE_GB} GB. Free some space and run this again."

  local list
  list=$(printf '%s, ' "${names[@]}")
  say "Installing: ${list%, }"
  tmp=$(mktemp -d)
  local rid=x64 docker_arch=amd64
  if [ "$arch" = arm64 ]; then rid=arm64; docker_arch=arm64; fi

  if ((need_rosetta)); then admin+=("softwareupdate --install-rosetta --agree-to-license"); fi
  if ((need_docker)); then
    download "https://desktop.docker.com/mac/main/$docker_arch/Docker.dmg" "$tmp/Docker.dmg" "Docker Desktop (~600 MB)"
    docker_mnt=$(hdiutil attach -nobrowse -noautoopen "$tmp/Docker.dmg" 2>/dev/null | awk -F'\t' '/\/Volumes\//{print $NF}')
    [ -n "$docker_mnt" ] || die "Could not open the Docker Desktop download. Run this again."
    # Docker's own CLI installer: copies the app, installs its helper and
    # accepts the license, so first launch needs no clicks.
    admin+=("$(printf '%q' "$docker_mnt/Docker.app/Contents/MacOS/install") --accept-license --user=$(printf '%q' "$USER")")
  fi
  if ((need_dotnet)); then
    download "https://aka.ms/dotnet/$DOTNET_CHANNEL/dotnet-sdk-osx-$rid.pkg" "$tmp/dotnet.pkg" ".NET SDK (~250 MB)"
    admin+=("installer -pkg $(printf '%q' "$tmp/dotnet.pkg") -target /")
  fi
  if ((need_code)); then
    download "https://update.code.visualstudio.com/latest/darwin-$([ "$arch" = arm64 ] && echo arm64 || echo x64)/stable" "$tmp/vscode.zip" "VS Code (~150 MB)"
  fi

  if ((${#admin[@]})); then
    say "macOS will ask for your password once."
    local joined
    joined=$(printf '%s && ' "${admin[@]}")
    if ! run_as_admin "${joined% && }"; then
      if [ -n "$docker_mnt" ]; then hdiutil detach -quiet "$docker_mnt" || true; fi
      die "Install was cancelled or failed. Run this again to retry."
    fi
  fi
  if [ -n "$docker_mnt" ]; then hdiutil detach -quiet "$docker_mnt" || true; NEW_DOCKER=1; ok "Docker Desktop installed"; fi
  if ((need_rosetta)); then ok "Rosetta 2 installed"; fi
  if ((need_dotnet)); then ok ".NET SDK $(dotnet --version 2>/dev/null) installed"; fi
  if ((need_code)); then
    local dest=/Applications
    if [ ! -w "$dest" ]; then dest="$HOME/Applications"; mkdir -p "$dest"; fi
    ditto -x -k "$tmp/vscode.zip" "$dest" || die "Could not unpack VS Code."
    ok "VS Code installed in $dest"
  fi
  rm -rf "$tmp"
}
