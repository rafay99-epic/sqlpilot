import AppKit
import SwiftUI

@main
struct SQLPilotApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  // SwiftUI creates the App once, so the model lives for the process.
  @State private var model = ServerModel()

  var body: some Scene {
    // Window, not WindowGroup: one main window, no ⌘N duplicates.
    Window("SQLPilot", id: "main") {
      ContentView()
        .environment(model)
        .task { await model.refreshIfIdle() }
        // Re-check whenever the student comes back to the app.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
          Task { await model.refreshIfIdle() }
        }
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
    .commands { AppCommands(model: model) }

    Window("About SQLPilot", id: "about") {
      AboutView()
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)

    // Static icon per state; it only changes when the server does.
    MenuBarExtra {
      MenuBarMenu().environment(model)
    } label: {
      Image(systemName: model.isOn ? "cylinder.fill" : "cylinder")
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    MoveToApplications.offerIfNeeded()
  }

  /// Closing the window leaves the menu bar item running.
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
