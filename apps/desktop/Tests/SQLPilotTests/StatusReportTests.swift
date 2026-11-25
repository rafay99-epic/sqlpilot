import XCTest
@testable import SQLPilot

final class StatusReportTests: XCTestCase {
  func testParsesChecksStateAndPort() {
    let report = StatusReport(lines: [
      "check|docker|ok|Docker|running",
      "check|server|bad|SQL Server|not set up",
      "some tool noise without separators",
      "state|broken",
      "reason|The database was removed.",
      "minor|The SQL editor isn't connected.",
      "port|14330",
    ])
    XCTAssertEqual(report.checks.count, 2)
    XCTAssertEqual(report.checks[1], HealthCheck(id: "server", status: .bad, label: "SQL Server", detail: "not set up"))
    XCTAssertEqual(report.state, .broken)
    XCTAssertEqual(report.reason, "The database was removed.")
    XCTAssertEqual(report.minor, "The SQL editor isn't connected.")
    XCTAssertEqual(report.port, "14330")
  }

  func testUnknownStatusFallsBackToInfoAndTextKeepsPipes() {
    let report = StatusReport(lines: ["check|x|weird|Label|a|b", "state|notinstalled"])
    XCTAssertEqual(report.checks.first?.status, .info)
    XCTAssertEqual(report.state, .notInstalled)
    XCTAssertEqual(ScriptLine("error|Docker | didn't start")?.text, "Docker | didn't start")
    XCTAssertNil(ScriptLine("plain line"))
  }

  func testProblemReportNeverContainsThePassword() {
    let text = ProblemReport.make(
      version: "2.0",
      phase: .broken("boom"),
      checks: [HealthCheck(id: "server", status: .bad, label: "SQL Server", detail: "stopped")],
      log: ["detail|Password: Dev-FakeTestValue0000000a1Z", "detail|custom My-Own-Pass1"],
      secret: "My-Own-Pass1"
    )
    XCTAssertFalse(text.contains("Dev-FakeTestValue0000000a1Z"))
    XCTAssertFalse(text.contains("My-Own-Pass1"))
    XCTAssertTrue(text.contains("BAD SQL Server: stopped"))
  }
}
