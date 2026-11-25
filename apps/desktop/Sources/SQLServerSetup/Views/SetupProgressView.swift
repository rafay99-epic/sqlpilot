import SwiftUI

/// Install or repair in progress: a progress bar and the step list.
struct SetupProgressView: View {
  let progress: SetupProgress

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack(spacing: 14) {
        AppIcon(size: 56)
        VStack(alignment: .leading, spacing: 3) {
          Text("Setting Up SQL Server")
            .font(.title2.weight(.semibold))
          Text("About 10 minutes. You can keep using your Mac.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
      ProgressView(value: Double(progress.step), total: Double(progress.total))
      VStack(alignment: .leading, spacing: 12) {
        ForEach(Array(SetupProgress.steps.enumerated()), id: \.offset) { index, title in
          StepRow(title: title, state: state(of: index + 1), detail: index + 1 == progress.step ? progress.detail : "")
        }
      }
      Spacer()
    }
    .padding(.horizontal, 32)
    .padding(.top, 40)
    .padding(.bottom, 24)
  }

  private func state(of step: Int) -> StepRow.State {
    step < progress.step ? .done : step == progress.step ? .current : .pending
  }
}

struct StepRow: View {
  enum State { case done, current, pending }

  let title: String
  let state: State
  let detail: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: symbol)
        .foregroundStyle(tint)
        .frame(width: 18)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .fontWeight(state == .current ? .semibold : .regular)
          .foregroundStyle(state == .pending ? .secondary : .primary)
        if !detail.isEmpty {
          Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
      }
    }
  }

  private var symbol: String {
    switch state {
    case .done: "checkmark.circle.fill"
    case .current: "arrow.right.circle.fill"
    case .pending: "circle"
    }
  }

  private var tint: Color {
    switch state {
    case .done: .green
    case .current: .accentColor
    case .pending: .secondary
    }
  }
}
