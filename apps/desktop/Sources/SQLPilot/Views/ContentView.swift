import SwiftUI

/// Picks the screen for the current phase.
struct ContentView: View {
  @Environment(ServerModel.self) private var model

  var body: some View {
    Group {
      switch model.phase {
      case .notInstalled: WelcomeView()
      case let .installing(progress): SetupProgressView(progress: progress)
      default: DashboardView()
      }
    }
    .frame(width: 460, height: 600)
  }
}
