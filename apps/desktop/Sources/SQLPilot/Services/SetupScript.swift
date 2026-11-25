import Foundation

/// One line of setup.sh app output: `kind|field|field`.
struct ScriptLine: Equatable {
  let kind: String
  let fields: [String]

  /// Nil for plain lines (stderr noise, tool output) that carry no `|`.
  init?(_ raw: String) {
    let parts = raw.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    guard parts.count > 1 else { return nil }
    kind = parts[0]
    fields = Array(parts.dropFirst())
  }

  /// All fields joined back, for free text that may itself contain `|`.
  var text: String { fields.joined(separator: "|") }
}

/// Runs the bundled scripts/setup.sh in app mode (SQLSETUP_UI=1), which
/// prints `kind|...` lines instead of Terminal output.
struct SetupScript: Sendable {
  enum Command: String {
    case status, start, stop, setup
  }

  let url: URL

  static let bundled = SetupScript(url: Bundle.main.url(forResource: "setup", withExtension: "sh")!)

  /// Runs `command`, handing every output line to `onLine` as it arrives.
  /// Returns the exit status (-1 if the script couldn't start).
  @MainActor
  func run(_ command: Command, onLine: (String) -> Void) async -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [url.path, command.rawValue]
    process.environment = ProcessInfo.processInfo.environment.merging(["SQLSETUP_UI": "1"]) { $1 }
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    process.standardInput = FileHandle.nullDevice
    do {
      try process.run()
    } catch {
      onLine("error|Couldn't run setup: \(error.localizedDescription)")
      return -1
    }
    do {
      for try await line in pipe.fileHandleForReading.bytes.lines { onLine(line) }
    } catch {
      onLine("Lost setup output: \(error.localizedDescription)")
    }
    while process.isRunning { try? await Task.sleep(for: .milliseconds(50)) }
    return process.terminationStatus
  }
}
