import SwiftUI

/// The menu under the cylinder icon in the menu bar.
struct MenuBarMenu: View {
  @Environment(ServerModel.self) private var model
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    Text("SQL Server: \(model.phase.title)")
    Divider()
    if model.isOn {
      Button("Stop Server") { model.setRunning(false) }
    } else {
      Button("Start Server") { model.setRunning(true) }
        .disabled(model.phase != .off)
    }
    Button("Open SQL Editor") { model.openEditor() }
      .disabled(!model.isOn)
    Button("Copy Connection String") { model.copyConnectionString() }
    Divider()
    Button("Show Window") {
      openWindow(id: "main")
      NSApp.activate(ignoringOtherApps: true)
    }
    Button("Quit SQLPilot") { NSApp.terminate(nil) }
      .keyboardShortcut("q")
  }
}
