import Foundation

/// Plain-text report a student can paste to their teacher. Never contains the
/// database password.
enum ProblemReport {
  static func make(version: String, phase: ServerPhase, checks: [HealthCheck], log: [String]) -> String {
    var lines = [
      "SQL Server Setup \(version)",
      "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
      "State: \(phase)",
      "",
    ]
    lines += checks.map { "\(mark($0.status)) \($0.label): \($0.detail)" }
    lines += ["", "Recent log:"] + log.suffix(60)
    return mask(lines.joined(separator: "\n"))
  }

  /// setup.sh passwords look like Dev-<20 letters/digits>a1Z.
  static func mask(_ text: String) -> String {
    text.replacingOccurrences(of: #"Dev-[A-Za-z0-9]+"#, with: "<password>", options: .regularExpression)
  }

  private static func mark(_ status: HealthCheck.Status) -> String {
    switch status {
    case .ok: "OK "
    case .bad: "BAD"
    case .off, .info: "-  "
    }
  }
}
