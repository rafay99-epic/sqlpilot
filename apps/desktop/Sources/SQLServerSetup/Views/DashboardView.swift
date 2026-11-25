import SwiftUI

/// The everyday screen once SQL Server is installed.
struct DashboardView: View {
  @Environment(ServerModel.self) private var model

  var body: some View {
    VStack(spacing: 0) {
      ServerHeader()
      Form {
        if case let .broken(reason) = model.phase {
          ProblemSection(title: "SQL Server can't start", message: reason, severity: .red)
        } else if let minor = model.report.minor, !model.phase.isBusy {
          ProblemSection(title: "Something needs fixing", message: minor, severity: .orange)
        }
        ConnectSection()
        HealthSection()
      }
      .formStyle(.grouped)
    }
  }
}

/// A problem plus the one button that fixes it.
struct ProblemSection: View {
  @Environment(ServerModel.self) private var model
  let title: String
  let message: String
  let severity: Color

  var body: some View {
    Section {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(severity)
          .imageScale(.large)
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.headline)
          Text(message).foregroundStyle(.secondary)
        }
        Spacer()
        Button("Repair") { Task { await model.setup() } }
          .buttonStyle(.borderedProminent)
          .disabled(model.phase.isBusy)
      }
      .padding(.vertical, 2)
    }
  }
}

/// How students reach the database: the SQL editor and the connection string.
struct ConnectSection: View {
  @Environment(ServerModel.self) private var model

  var body: some View {
    Section("Connect") {
      LabeledContent {
        Button("Open") { model.openEditor() }
          .buttonStyle(.borderedProminent)
          .disabled(!model.isOn)
      } label: {
        Label {
          VStack(alignment: .leading, spacing: 1) {
            Text("SQL Editor")
            Text("VS Code, set up like SSMS").font(.caption).foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: "tablecells")
        }
      }
      LabeledContent {
        Text("localhost,\(model.report.port)")
          .font(.body.monospaced())
          .textSelection(.enabled)
      } label: {
        Label("Server", systemImage: "network")
      }
      LabeledContent {
        CopyButton(title: "Copy") { model.copyConnectionString() }
      } label: {
        Label {
          VStack(alignment: .leading, spacing: 1) {
            Text("Connection String")
            Text("For appsettings or user-secrets").font(.caption).foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: "link")
        }
      }
    }
  }
}
