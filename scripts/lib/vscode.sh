# shellcheck shell=bash
# VS Code's SQL Server extension: the saved "Local SQL Server" connection.
# Sourced by setup.sh; defines functions only.

# Adds or updates the connection, password included so it connects with no
# prompt. Acceptable because the server only listens on 127.0.0.1 and the
# password is random. Prints "updated" or "unchanged".
add_vscode_connection() {
  local profile
  profile=$(printf '{"id":"sqlserver-mac-%s","groupId":"ROOT","profileName":"Local SQL Server","server":"localhost,%s","authenticationType":"SqlLogin","user":"sa","password":"%s","savePassword":true,"database":"master","encrypt":"Mandatory","trustServerCertificate":true,"containerName":"%s"}' "$NAME" "$PORT" "$PASSWORD" "$NAME")
  mkdir -p "$(dirname "$VSCODE_SETTINGS")"
  osascript -l JavaScript "$SCRIPT_DIR/lib/vscode-connection.js" "$VSCODE_SETTINGS" "$profile"
}

# Installs the SQL Server extension and C# Dev Kit, then saves the connection.
setup_vscode() { # <path to VS Code.app>
  local code="$1/Contents/Resources/app/bin/code"
  if "$code" --install-extension ms-mssql.mssql >/dev/null 2>&1; then ok "VS Code: SQL Server extension"
  else warn "Could not install the VS Code SQL Server extension. Install 'SQL Server (mssql)' from the Extensions view."; fi
  if "$code" --install-extension ms-dotnettools.csdevkit >/dev/null 2>&1; then ok "VS Code: C# Dev Kit"; fi
  if [ -n "$(add_vscode_connection 2>/dev/null)" ]; then ok "VS Code: saved connection \"Local SQL Server\""
  else warn "Could not add the VS Code connection; add it by hand with the details below."; fi
}

# Opens VS Code connected, on the SSMS-style Object Explorer.
open_sql_editor() { # <path to VS Code.app>
  "$1/Contents/Resources/app/bin/code" --open-url \
    "vscode://ms-mssql.mssql/connect?server=localhost%2C$PORT&database=master&user=sa&authenticationType=SqlLogin" >/dev/null 2>&1 || true
}
