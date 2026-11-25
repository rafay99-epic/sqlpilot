import SwiftUI

/// How each health status and server phase looks. Shape plus color, never color alone.
extension HealthCheck.Status {
  var symbol: String {
    switch self {
    case .ok: "checkmark.circle.fill"
    case .bad: "xmark.circle.fill"
    case .off: "minus.circle.fill"
    case .info: "info.circle"
    }
  }

  var tint: Color {
    switch self {
    case .ok: .green
    case .bad: .red
    case .off, .info: .secondary
    }
  }
}

extension ServerPhase {
  var title: String {
    switch self {
    case .checking: "Checking…"
    case .notInstalled: "Not set up"
    case .installing: "Setting up…"
    case .off: "Stopped"
    case .starting: "Starting…"
    case .on: "Running"
    case .stopping: "Stopping…"
    case .broken: "Needs repair"
    }
  }

  var tint: Color {
    switch self {
    case .on: .green
    case .starting, .stopping, .installing: .orange
    case .broken: .red
    default: .secondary
    }
  }
}

/// Small colored dot plus the phase name, e.g. "● Running".
struct PhaseLabel: View {
  let phase: ServerPhase

  var body: some View {
    HStack(spacing: 6) {
      Circle().fill(phase.tint).frame(width: 8, height: 8)
      Text(phase.title)
    }
  }
}
