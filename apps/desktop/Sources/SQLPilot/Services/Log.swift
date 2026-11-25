import Foundation
import os

/// One log file per day at ~/Library/Logs/SQLPilot/YYYY-MM-DD.log, shared with
/// setup.sh (which writes its own `[setup …]` lines there). Lines also go to the
/// unified log, so they show in Console.app under the app's subsystem.
enum Log {
  static let folder = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/SQLPilot", isDirectory: true)
  private static let keepDays = 14
  private static let system = Logger(subsystem: "com.syntaxlabtechnology.sqlpilot", category: "app")
  private static let queue = DispatchQueue(label: "com.syntaxlabtechnology.sqlpilot.log")

  static func info(_ message: String) {
    system.info("\(message, privacy: .public)")
    append(message, at: .now)
  }

  static func error(_ message: String) {
    system.error("\(message, privacy: .public)")
    append("ERROR: \(message)", at: .now)
  }

  /// Writes immediately on the calling thread. For crash paths, where the
  /// process may die before the queue runs.
  static func writeNow(_ message: String) {
    write(line(message, at: .now), to: file(for: .now))
  }

  static func file(for date: Date) -> URL {
    folder.appendingPathComponent("\(format(date, "yyyy-MM-dd")).log")
  }

  /// The last `count` lines of today's log, for problem reports.
  static func tail(_ count: Int) -> [String] {
    queue.sync {}  // let pending writes land first
    guard let text = try? String(contentsOf: file(for: .now), encoding: .utf8) else { return [] }
    return Array(text.split(separator: "\n", omittingEmptySubsequences: true).suffix(count).map(String.init))
  }

  /// Drops log files older than two weeks. setup.sh prunes the same way.
  static func pruneOld() {
    queue.async {
      let fm = FileManager.default
      let cutoff = Date.now.addingTimeInterval(-Double(keepDays) * 86_400)
      let files = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
      for url in files where url.pathExtension == "log" {
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        if let modified, modified < cutoff { try? fm.removeItem(at: url) }
      }
    }
  }

  private static func append(_ message: String, at date: Date) {
    queue.async { write(line(message, at: date), to: file(for: date)) }
  }

  private static func line(_ message: String, at date: Date) -> String {
    "\(format(date, "HH:mm:ss")) [app] \(message)\n"
  }

  private static func write(_ line: String, to url: URL) {
    let data = Data(line.utf8)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    if let handle = try? FileHandle(forWritingTo: url) {
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: data)
    } else {
      try? data.write(to: url)
    }
  }

  private static func format(_ date: Date, _ pattern: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = pattern
    return formatter.string(from: date)
  }
}
