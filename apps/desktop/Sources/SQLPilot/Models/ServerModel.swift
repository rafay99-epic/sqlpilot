import Foundation
import Observation

/// App state and actions. Every decision about what's installed or broken is
/// made by setup.sh; this turns its output into a phase the views render.
@MainActor
@Observable
final class ServerModel {
  private(set) var phase: ServerPhase = .checking
  private(set) var report = StatusReport()
  private(set) var checkedAt: Date?

  private var refreshing = false
  private let script = SetupScript.bundled
  private let passwordFile = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".sqlserver-mac/sa_password")

  var isOn: Bool { phase == .on }
  var canToggle: Bool { phase == .on || phase == .off }

  // MARK: Checking

  /// For automatic triggers (window opens, app comes to the front): skips
  /// when an action is running or a check is already in flight.
  func refreshIfIdle() async {
    guard !refreshing, !phase.isBusy || phase == .checking else { return }
    await refresh()
  }

  /// Re-reads `setup.sh status`. While SQL Server is still starting it checks
  /// again every 3 s, for up to 2 minutes. With `keepPhase`, only the health
  /// list updates, so a failure message stays on screen.
  func refresh(keepPhase: Bool = false) async {
    refreshing = true
    defer { refreshing = false }
    for _ in 0..<40 {
      await readStatus()
      if keepPhase { return }
      guard report.state == .starting else { return applyState() }
      phase = .starting
      try? await Task.sleep(for: .seconds(3))
    }
    phase = .broken("SQL Server is taking too long to start.")
  }

  private func readStatus() async {
    var lines: [String] = []
    _ = await run(.status) { lines.append($0) }
    report = StatusReport(lines: lines)
    checkedAt = .now
  }

  private func applyState() {
    let before = phase
    defer { if phase != before { Log.info("State: \(phase.title)\(report.reason.map { " (\($0))" } ?? "")") } }
    switch report.state {
    case .notInstalled: phase = .notInstalled
    case .broken: phase = .broken(report.reason ?? "Something isn't set up.")
    case .on: phase = .on
    case .off: phase = .off
    case .starting: phase = .starting
    case nil: phase = .broken("Couldn't check the database.")
    }
  }

  // MARK: Actions

  /// First-time install, and the repair behind every "Repair" button:
  /// setup.sh is safe to re-run and fixes whatever is missing.
  func setup() async {
    guard !phase.isBusy || phase == .checking else { return }
    Log.info("Setup or repair started")
    var progress = SetupProgress()
    phase = .installing(progress)
    var failure: String?
    let status = await run(.setup) { raw in
      guard let line = ScriptLine(raw) else { return }
      switch line.kind {
      case "progress": progress = SetupProgress(step: Int(line.fields[0]) ?? progress.step)
      case "detail": progress.detail = line.text
      case "error": failure = line.text
      default: return
      }
      self.phase = .installing(progress)
    }
    if status == 0 {
      Log.info("Setup finished")
      await refresh()
      if phase == .on { SQLEditor.open(port: report.port) }
    } else {
      Log.error("Setup failed: \(failure ?? "exit \(status)")")
      phase = .broken(failure ?? "Setup stopped before it finished.")
      await refresh(keepPhase: true)
    }
  }

  func start() async {
    guard canToggle else { return }
    Log.info("Start pressed")
    phase = .starting
    var failure: String?
    let status = await run(.start) { raw in
      if let line = ScriptLine(raw), line.kind == "error" { failure = line.text }
    }
    if status == 0 {
      await refresh()
    } else {
      Log.error("Start failed: \(failure ?? "exit \(status)")")
      phase = .broken(failure ?? "The database didn't start.")
      await refresh(keepPhase: true)
    }
  }

  func stop() async {
    guard canToggle else { return }
    Log.info("Stop pressed")
    phase = .stopping
    _ = await run(.stop) { _ in }
    await refresh()
  }

  func setRunning(_ on: Bool) {
    Task { on ? await start() : await stop() }
  }

  func openEditor() {
    SQLEditor.open(port: report.port)
  }

  func copyConnectionString() {
    Clipboard.copy("Server=localhost,\(report.port);Database=YourDb;User Id=sa;Password=\(password);TrustServerCertificate=True;")
  }

  func copyProblemReport() {
    Clipboard.copy(ProblemReport.make(version: AppVersion.display, phase: phase, checks: report.checks, log: Log.tail(80), secret: password))
  }

  private var password: String {
    (try? String(contentsOf: passwordFile, encoding: .utf8)) ?? ""
  }

  // MARK: Script

  private func run(_ command: SetupScript.Command, onLine: (String) -> Void) async -> Int32 {
    let status = await script.run(command, onLine: onLine)
    if status != 0 { Log.error("setup.sh \(command.rawValue) exited with \(status)") }
    return status
  }
}
