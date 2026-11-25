/// One part of the setup and how it's doing, from a `check|...` line.
struct HealthCheck: Identifiable, Hashable {
  enum Status: String {
    case ok, bad, off, info
  }

  let id: String
  let status: Status
  let label: String
  let detail: String
}
