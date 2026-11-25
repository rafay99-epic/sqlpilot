import Darwin
import Foundation

/// Puts crashes in the daily log: uncaught exceptions and fatal signals as they
/// happen, and an unclean exit (force quit, kill, power loss) on the next launch.
enum CrashReporter {
  private static let marker = Log.folder.appendingPathComponent(".running")
  /// Opened up front: a signal handler may only make async-signal-safe calls.
  nonisolated(unsafe) private static var crashFD: Int32 = -1

  static func install() {
    let fm = FileManager.default
    if fm.fileExists(atPath: marker.path) {
      Log.error("The previous run ended unexpectedly (crash or force quit).")
    }
    try? fm.createDirectory(at: Log.folder, withIntermediateDirectories: true)
    fm.createFile(atPath: marker.path, contents: nil)
    crashFD = open(Log.file(for: .now).path, O_WRONLY | O_APPEND | O_CREAT, 0o644)

    NSSetUncaughtExceptionHandler { exception in
      Log.writeNow("CRASH: \(exception.name.rawValue): \(exception.reason ?? "")\n\(exception.callStackSymbols.joined(separator: "\n"))")
    }
    for sig in [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP] {
      signal(sig, crashSignalHandler)
    }
  }

  /// Called on a normal quit, so the next launch doesn't report a crash.
  static func markCleanExit() {
    try? FileManager.default.removeItem(at: marker)
  }

  fileprivate static func writeCrash(_ message: StaticString) {
    guard crashFD >= 0 else { return }
    message.withUTF8Buffer { buffer in _ = write(crashFD, buffer.baseAddress, buffer.count) }
  }
}

/// Writes a fixed line, then lets the default handler produce the system crash
/// report. StaticString and write(2) keep this async-signal-safe.
private func crashSignalHandler(_ sig: Int32) {
  switch sig {
  case SIGABRT: CrashReporter.writeCrash("CRASH: SIGABRT (abort)\n")
  case SIGSEGV: CrashReporter.writeCrash("CRASH: SIGSEGV (bad memory access)\n")
  case SIGBUS: CrashReporter.writeCrash("CRASH: SIGBUS (bad memory access)\n")
  case SIGILL: CrashReporter.writeCrash("CRASH: SIGILL (illegal instruction)\n")
  case SIGFPE: CrashReporter.writeCrash("CRASH: SIGFPE (arithmetic error)\n")
  default: CrashReporter.writeCrash("CRASH: SIGTRAP (Swift runtime error)\n")
  }
  signal(sig, SIG_DFL)
  raise(sig)
}
