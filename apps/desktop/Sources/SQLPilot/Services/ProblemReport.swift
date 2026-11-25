import Foundation

/// Plain-text report a student can paste to their teacher. Never contains the
/// database password.
enum ProblemReport {
  static func make(version: String, phase: ServerPhase, checks: [HealthCheck], log: [String], secret: String) -> String {
    var lines = [
      "SQLPilot \(version)",
      "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
      "State: \(phase)",
      "",
    ]
    lines += checks.map { "\(mark($0.status)) \($0.label): \($0.detail)" }
    lines += ["", "Recent log:"] + log.suffix(60)
    return mask(lines.joined(separator: "\n"), secret: secret)
  }

  /// Hides the saved password, plus anything shaped like a setup.sh password
  /// (Dev-<letters/digits>) in case it differs.
  static func mask(_ text: String, secret: String) -> String {
    var masked = text
    if !secret.isEmpty { masked = masked.replacingOccurrences(of: secret, with: "<password>") }
    return masked.replacingOccurrences(of: #"Dev-[A-Za-z0-9]+"#, with: "<password>", options: .regularExpression)
  }

  private static func mark(_ status: HealthCheck.Status) -> String {
    switch status {
    case .ok: "OK "
    case .bad: "BAD"
    case .off, .info: "-  "
    }
  }
}
