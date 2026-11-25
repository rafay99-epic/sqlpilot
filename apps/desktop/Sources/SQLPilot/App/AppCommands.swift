import SwiftUI

/// Menu bar menus: About, a Server menu with every action, and Help.
struct AppCommands: Commands {
  let model: ServerModel
  @Environment(\.openWindow) private var openWindow

  private static let developerURL = URL(string: "https://rafay99.com")!

  var body: some Commands {
    CommandGroup(replacing: .appInfo) {
      Button("About SQLPilot") { openWindow(id: "about") }
    }
    CommandGroup(replacing: .newItem) {}

    CommandMenu("Server") {
      Button("Start Server") { model.setRunning(true) }
        .keyboardShortcut("s", modifiers: [.command, .shift])
        .disabled(model.phase != .off)
      Button("Stop Server") { model.setRunning(false) }
        .keyboardShortcut("x", modifiers: [.command, .shift])
        .disabled(!model.isOn)
      Divider()
      Button("Open SQL Editor") { model.openEditor() }
        .keyboardShortcut("o")
        .disabled(!model.isOn)
      Button("Copy Connection String") { model.copyConnectionString() }
        .keyboardShortcut("c", modifiers: [.command, .shift])
      Divider()
      Button("Check Again") { Task { await model.refresh() } }
        .keyboardShortcut("r")
        .disabled(model.phase.isBusy)
      Button("Repair") { Task { await model.setup() } }
        .disabled(model.phase.isBusy)
    }

    CommandGroup(replacing: .help) {
      Button("Copy Problem Report") { model.copyProblemReport() }
      Button("Show Today's Log") { NSWorkspace.shared.open(Log.file(for: .now)) }
      Button("Open Logs Folder") { NSWorkspace.shared.open(Log.folder) }
      Divider()
      Link("Developer Website", destination: Self.developerURL)
    }
  }
}
