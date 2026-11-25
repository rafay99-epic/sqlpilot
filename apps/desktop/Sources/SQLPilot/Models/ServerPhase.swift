/// What the app is showing. Most phases come from `setup.sh status`; the
/// in-between ones (installing, starting, stopping) the app drives itself.
enum ServerPhase: Equatable {
  case checking
  case notInstalled
  case installing(SetupProgress)
  case off
  case starting
  case on
  case stopping
  case broken(String)

  var isBusy: Bool {
    switch self {
    case .checking, .installing, .starting, .stopping: true
    default: false
    }
  }
}

/// Where a first-time setup or repair is up to.
struct SetupProgress: Equatable {
  var step = 0
  var detail = ""
  var total: Int { Self.steps.count }

  /// Step titles in student words, in the order setup.sh runs them.
  static let steps = [
    "Checking your Mac",
    "Installing apps",
    "Starting Docker",
    "Setting up the database",
    "Setting up the SQL editor",
    "Finishing",
  ]
}
