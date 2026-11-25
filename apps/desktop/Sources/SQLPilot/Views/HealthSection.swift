import SwiftUI

/// Every part of the setup with a pass/fail mark, plus Check Again.
struct HealthSection: View {
  @Environment(ServerModel.self) private var model

  var body: some View {
    Section {
      if model.report.checks.isEmpty {
        Text("Checking…").foregroundStyle(.secondary)
      }
      ForEach(model.report.checks) { HealthRow(check: $0) }
    } header: {
      HStack {
        Text("Health")
        Spacer()
        Button("Check Again") { Task { await model.refresh() } }
          .buttonStyle(.link)
          .font(.callout)
          .disabled(model.phase.isBusy)
      }
    } footer: {
      if let checkedAt = model.checkedAt {
        Text("Checked \(checkedAt.formatted(date: .omitted, time: .shortened))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

struct HealthRow: View {
  let check: HealthCheck

  var body: some View {
    LabeledContent {
      Text(check.detail)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .lineLimit(1)
    } label: {
      Label {
        Text(check.label)
      } icon: {
        Image(systemName: check.status.symbol).foregroundStyle(check.status.tint)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
