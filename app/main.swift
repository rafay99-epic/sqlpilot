// "SQL Server Setup.app": copies the bundled setup.sh to
// ~/.sqlserver-mac/setup.command (a fresh file, so no quarantine flag) and
// opens it in Terminal, where the user sees progress and answers prompts.
import Foundation

let fm = FileManager.default
let dir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".sqlserver-mac")
let script = dir.appendingPathComponent("setup.command")

do {
  try fm.createDirectory(at: dir, withIntermediateDirectories: true)
  guard let source = Bundle.main.url(forResource: "setup", withExtension: "sh") else {
    fatalError("setup.sh missing from the app bundle")
  }
  try? fm.removeItem(at: script)
  try Data(contentsOf: source).write(to: script)
  try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

  let open = Process()
  open.executableURL = URL(fileURLWithPath: "/usr/bin/open")
  open.arguments = ["-a", "Terminal", script.path]
  try open.run()
  open.waitUntilExit()
} catch {
  fatalError("Could not start setup: \(error)")
}
