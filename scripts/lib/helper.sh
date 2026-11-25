# shellcheck shell=bash
# The `sqlserver` command and dotnet-ef, for students who use Terminal.
# Sourced by setup.sh; defines functions only.

# Installs scripts/sqlserver to ~/.sqlserver-mac/bin and puts it on PATH.
install_helper() {
  mkdir -p "$CONFIG_DIR/bin"
  sed "s/__NAME__/$NAME/" "$SCRIPT_DIR/sqlserver" >"$CONFIG_DIR/bin/sqlserver"
  chmod +x "$CONFIG_DIR/bin/sqlserver"
  add_to_path '.sqlserver-mac/bin'
  ok "sqlserver helper (type: sqlserver)"
}

# Installs the EF Core CLI matching the installed .NET SDK's major version.
install_dotnet_ef() {
  if ! command -v dotnet >/dev/null; then warn ".NET SDK not installed."; return 0; fi
  if dotnet tool list --global | grep -q '^dotnet-ef '; then
    ok "dotnet-ef $(dotnet tool list --global | awk '$1 == "dotnet-ef" {print $2}')"
  elif dotnet tool install --global dotnet-ef --version "$(dotnet --version | cut -d. -f1).*" >/dev/null 2>&1; then
    ok "dotnet-ef $(dotnet tool list --global | awk '$1 == "dotnet-ef" {print $2}') installed"
  else
    warn "Could not install dotnet-ef. Try: dotnet tool install --global dotnet-ef"
  fi
  # ~/.dotnet/tools must be on PATH for `dotnet ef` in new shells.
  add_to_path '.dotnet/tools'
}

# Appends $HOME/<dir> to PATH in ~/.zprofile unless a profile already has it.
add_to_path() { # <dir relative to $HOME>
  if ! grep -qs "$1" "$HOME/.zprofile" "$HOME/.zshrc"; then
    printf '\nexport PATH="$PATH:$HOME/%s"\n' "$1" >>"$HOME/.zprofile"
  fi
}
