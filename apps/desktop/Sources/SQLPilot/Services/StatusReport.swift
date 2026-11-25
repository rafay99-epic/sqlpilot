/// The parsed output of `setup.sh status`. See status_report() in setup.sh
/// for the line format.
struct StatusReport: Equatable {
  enum State: String {
    case notInstalled = "notinstalled", broken, off, starting, on
  }

  var checks: [HealthCheck] = []
  var state: State?
  /// Why the database can't run (only when broken).
  var reason: String?
  /// A problem that doesn't stop the database, e.g. VS Code isn't connected.
  var minor: String?
  var port = "1433"

  init() {}

  init(lines: [String]) {
    for line in lines {
      guard let parsed = ScriptLine(line) else { continue }
      let f = parsed.fields
      switch parsed.kind {
      case "check" where f.count >= 4:
        checks.append(HealthCheck(id: f[0], status: .init(rawValue: f[1]) ?? .info, label: f[2], detail: f[3]))
      case "state": state = State(rawValue: parsed.text)
      case "reason": reason = parsed.text
      case "minor": minor = parsed.text
      case "port": port = parsed.text
      default: break
      }
    }
  }
}
