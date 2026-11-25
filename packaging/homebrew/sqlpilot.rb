cask "sqlpilot" do
  version "0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/rafay99-epic/sqlpilot/releases/download/v#{version}/SQLPilot.dmg"
  name "SQLPilot"
  desc "Local SQL Server for .NET coursework, with an SSMS-style editor"
  homepage "https://github.com/rafay99-epic/sqlpilot"

  # Pinned version + checksum. SQLPilot's release CI rewrites both on every
  # release (.github/scripts/bump-cask.sh), so nobody hand-edits a sha256.
  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "SQLPilot.app"

  zap trash: [
    "~/Library/Logs/SQLPilot",
    "~/Library/Preferences/com.syntaxlabtechnology.sqlpilot.plist",
    "~/Library/Saved Application State/com.syntaxlabtechnology.sqlpilot.savedState",
  ]
end
