import AppKit

/// VS Code's SQL Server extension, the Mac stand-in for SSMS.
enum SQLEditor {
  /// Opens VS Code, connects with the saved "Local SQL Server" profile and
  /// focuses its Object Explorer.
  static func open(port: String) {
    let link = "vscode://ms-mssql.mssql/connect?server=localhost%2C\(port)&database=master&user=sa&authenticationType=SqlLogin"
    if let url = URL(string: link) { NSWorkspace.shared.open(url) }
  }
}

enum Clipboard {
  static func copy(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
  }
}
