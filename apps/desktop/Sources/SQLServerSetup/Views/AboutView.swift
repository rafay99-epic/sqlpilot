import SwiftUI

/// About window: version and credits.
struct AboutView: View {
  private static let developerURL = URL(string: "https://rafay99.com")!

  private var version: String {
    let info = Bundle.main.infoDictionary
    let short = info?["CFBundleShortVersionString"] as? String ?? "?"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    return "Version \(short) (\(build))"
  }

  var body: some View {
    VStack(spacing: 14) {
      AppIcon(size: 88)
      VStack(spacing: 3) {
        Text("SQL Server Setup").font(.title2.weight(.semibold))
        Text(version).font(.callout).foregroundStyle(.secondary).monospacedDigit()
        Text("A local SQL Server for class, on any Mac.").font(.caption).foregroundStyle(.secondary)
      }
      Divider()
      Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
        GridRow {
          Text("Made by").foregroundStyle(.secondary)
          Text("Syntax Lab Technology")
        }
        GridRow {
          Text("Developer").foregroundStyle(.secondary)
          Link("Abdul Rafay · rafay99.com", destination: Self.developerURL)
        }
      }
      .font(.callout)
      Divider()
      VStack(spacing: 6) {
        Text("Credits").font(.headline)
        Text("Installs Microsoft SQL Server 2022 Developer Edition, Docker Desktop, the .NET SDK and Visual Studio Code from their official sources. SQL Server, .NET and Visual Studio Code are trademarks of Microsoft. Docker is a trademark of Docker, Inc. This app is not affiliated with either company.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      Text("© 2026 Syntax Lab Technology")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 28)
    .padding(.top, 36)
    .padding(.bottom, 24)
    .frame(width: 360)
  }
}
