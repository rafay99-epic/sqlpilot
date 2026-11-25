import SwiftUI

/// Icon, name, status, and the on/off switch at the top of the window.
struct ServerHeader: View {
  @Environment(ServerModel.self) private var model

  var body: some View {
    HStack(spacing: 14) {
      AppIcon(size: 56)
      VStack(alignment: .leading, spacing: 3) {
        Text("SQL Server")
          .font(.title2.weight(.semibold))
        PhaseLabel(phase: model.phase)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Toggle("Database", isOn: Binding(
        get: { model.isOn || model.phase == .starting },
        set: { model.setRunning($0) }
      ))
      .toggleStyle(.switch)
      .controlSize(.large)
      .labelsHidden()
      .disabled(!model.canToggle)
      .help(model.isOn ? "Stop SQL Server" : "Start SQL Server")
    }
    .padding(.horizontal, 24)
    .padding(.top, 34)
    .padding(.bottom, 8)
  }
}
