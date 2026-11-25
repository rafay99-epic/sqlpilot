import SwiftUI

/// First launch on a Mac without SQL Server: what gets installed, one button.
struct WelcomeView: View {
  @Environment(ServerModel.self) private var model

  var body: some View {
    VStack(spacing: 20) {
      Spacer(minLength: 24)
      AppIcon(size: 88)
      VStack(spacing: 6) {
        Text("Set Up SQL Server")
          .font(.title.weight(.semibold))
        Text("Everything you need for class, ready in about 10 minutes.")
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      VStack(alignment: .leading, spacing: 14) {
        FeatureRow(symbol: "shippingbox", title: "Docker Desktop", detail: "Runs the database quietly in the background")
        FeatureRow(symbol: "cylinder.split.1x2", title: "SQL Server 2022", detail: "Developer Edition, sized for this Mac")
        FeatureRow(symbol: "tablecells", title: "VS Code SQL Editor", detail: "Works like SSMS from class")
        FeatureRow(symbol: "hammer", title: ".NET SDK and EF Core tools", detail: "For ASP.NET projects")
      }
      .padding(.vertical, 4)
      Spacer(minLength: 12)
      VStack(spacing: 8) {
        Button { Task { await model.setup() } } label: {
          Text("Install").frame(maxWidth: 220)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        Text("Your Mac will ask for its password once.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(32)
  }
}

struct FeatureRow: View {
  let symbol: String
  let title: String
  let detail: String

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: symbol)
        .font(.title2)
        .foregroundStyle(.tint)
        .frame(width: 32)
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.headline)
        Text(detail).font(.callout).foregroundStyle(.secondary)
      }
    }
  }
}
