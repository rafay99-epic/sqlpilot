import AppKit

/// Students open the app from the DMG and then can't find it again. On a
/// launch outside Applications, offer to copy it there and relaunch from it.
enum MoveToApplications {
  @MainActor
  static func offerIfNeeded() {
    #if !DEBUG
    let bundle = Bundle.main.bundleURL
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    guard !bundle.path.hasPrefix("/Applications/"), !bundle.path.hasPrefix(home + "/Applications/") else { return }

    let alert = NSAlert()
    alert.messageText = "Move to Applications?"
    alert.informativeText = "So you can open it again from Launchpad next time."
    alert.addButton(withTitle: "Move")
    alert.addButton(withTitle: "Not Now")
    guard alert.runModal() == .alertFirstButtonReturn else { return }

    let fm = FileManager.default
    let folder = fm.isWritableFile(atPath: "/Applications") ? "/Applications" : home + "/Applications"
    let target = URL(fileURLWithPath: folder).appendingPathComponent(bundle.lastPathComponent)
    do {
      try fm.createDirectory(atPath: folder, withIntermediateDirectories: true)
      if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
      try fm.copyItem(at: bundle, to: target)
    } catch {
      NSAlert(error: error).runModal()
      return
    }
    NSWorkspace.shared.openApplication(at: target, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
      DispatchQueue.main.async { NSApp.terminate(nil) }
    }
    #endif
  }
}
