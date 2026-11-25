<img src="assets/icon-install.png" width="96" align="right" alt="">

# SQLPilot

SQLPilot is a small Mac app (Apple Silicon or Intel) that gives students a local SQL Server for .NET coursework, plus an SSMS-style editor.

Open `dist/SQLPilot.dmg` and drag **SQLPilot** to Applications (or just open it; it offers to move itself). The app:

- installs whatever is missing (Rosetta, Docker Desktop, .NET SDK, VS Code) behind one password prompt, with no Terminal
- runs SQL Server 2022 Developer Edition in Docker, sized to the Mac's RAM and CPUs
- has a switch to start and stop the server, a health check of every part, and one Repair button
- opens VS Code's SQL Server extension connected, on its Object Explorer (like SSMS)
- lives in the menu bar too, with Start, Stop and Open SQL Editor

Signed with the Syntax Labs Developer ID and notarized, so Gatekeeper opens it without warnings.

## Layout

```
apps/desktop/      SwiftUI app (XcodeGen project)
  Sources/SQLPilot/
    App/           entry point, menus, move-to-Applications
    Models/        ServerModel (state + actions), phases, health checks
    Services/      runs setup.sh, parses its output, problem report, VS Code link
    Views/         screens and small components
  Tests/           unit tests (status parsing, report masking)
  dev.sh           debug build / unit tests
  make-dmg.sh      signed, notarized DMG into dist/
scripts/           the engine, bundled into the app
  setup.sh         entry point: setup (install or repair), status, start, stop
  lib/             one file per job: ui, plan, system, docker, install, steps,
                   server, status, vscode, helper
  sqlserver        the Terminal helper setup installs
tests/stress.sh    sandboxed tests for setup.sh, including a load test
assets/            icon drawing code and previews
```

The app holds no install logic. It runs the bundled `scripts/setup.sh` with `SQLSETUP_UI=1`, which prints `kind|...` lines (`progress`, `detail`, `error`, `check`, `state`) that the app renders.

## Sizing

| Mac RAM | SQL Server gets | CPUs |
|---|---|---|
| 8 GB | 2.5 GB (SQL Server's minimum) | 2 |
| 16 GB | 4 GB | half the cores |
| 24 to 32 GB | 6 GB | half, max 6 |
| 36 GB+ | 8 GB | max 6 |

Override with `MSSQL_MEMORY_MB` and `MSSQL_CPUS`. The server listens on `127.0.0.1` only.

## Terminal use

`scripts/setup.sh` also works on its own (`setup`, `status`, `start`, `stop`), and setup installs a `sqlserver` helper:

```
sqlserver ui                         open VS Code connected, Object Explorer like SSMS
sqlserver restore ~/Downloads/X.bak  restore a backup (Windows .bak files work)
sqlserver run script.sql             run a script
sqlserver info | stop | start        details, or control the server
```

## Development

```
apps/desktop/dev.sh           build and open a debug build
apps/desktop/dev.sh test      unit tests
tests/stress.sh               setup.sh tests in a sandbox (container sqlstress, port 14339)
apps/desktop/make-dmg.sh      build, sign and notarize (uses the Apple account signed in to Xcode)
```

Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

Made by Syntax Lab Technology. Developer: Abdul Rafay ([rafay99.com](https://rafay99.com)).
