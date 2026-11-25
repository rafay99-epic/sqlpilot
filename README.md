<img src="assets/icon-install.png" width="96" align="right" alt="">

# SQLPilot

[![CI](https://github.com/rafay99-epic/sqlpilot/actions/workflows/ci.yml/badge.svg)](https://github.com/rafay99-epic/sqlpilot/actions/workflows/ci.yml)

SQLPilot is a small Mac app (Apple Silicon or Intel) that gives students a local SQL Server for .NET coursework, plus an SSMS-style editor.

- installs whatever is missing (Rosetta, Docker Desktop, .NET SDK, VS Code) behind one password prompt, with no Terminal
- runs SQL Server 2022 Developer Edition in Docker, sized to the Mac's RAM and CPUs
- has a switch to start and stop the server, a health check of every part, and one Repair button
- opens VS Code's SQL Server extension connected, on its Object Explorer (like SSMS)
- lives in the menu bar too, with Start, Stop and Open SQL Editor
- keeps a daily log of everything it does, including crashes

## Install

With Homebrew:

```
brew install --cask rafay99-epic/apps/sqlpilot
```

Or download it from **[rafay99-epic.github.io/sqlpilot](https://rafay99-epic.github.io/sqlpilot/)** (the button always serves the [latest release](https://github.com/rafay99-epic/sqlpilot/releases/latest)), open the DMG and drag SQLPilot to Applications. Needs macOS 14 or later. Every build is signed with the Syntax Labs Developer ID and notarized by Apple.

Open SQLPilot and press **Install**. Your Mac asks for its password once; setup takes about 10 minutes.

## Logs

Everything SQLPilot and its setup script do lands in one file per day:

```
~/Library/Logs/SQLPilot/2026-11-25.log
```

Launches, installs and repairs, start and stop, state changes, errors with their exit codes, and crashes (uncaught exceptions, fatal signals, and an unclean exit noticed on the next launch). Logs older than 14 days are deleted. In the app: **Help > Show Today's Log**, **Open Logs Folder**, or **Copy Problem Report** (log tail plus health checks, password masked) to send to a teacher. App lines also show in Console.app under `com.syntaxlabtechnology.sqlpilot`.

## Versions

Every build is `0.<number of commits>`, like Vitals: the 42nd commit on `main` ships as `0.42`. CI computes it from the git history; `dev.sh` and `make-dmg.sh` do the same locally.

## Layout

```
apps/website/      landing page (Vite, React, Tailwind), deployed to GitHub Pages
apps/desktop/      SwiftUI app (XcodeGen project)
  Sources/SQLPilot/
    App/           entry point, menus, version, move-to-Applications
    Models/        ServerModel (state + actions), phases, health checks
    Services/      runs setup.sh, parses its output, logging, crash reporting
    Views/         screens and small components
  Tests/           unit tests (status parsing, report masking)
  dev.sh           debug build / unit tests
  make-dmg.sh      signed, notarized DMG into dist/
scripts/           the engine, bundled into the app
  setup.sh         entry point: setup (install or repair), status, start, stop
  lib/             one file per job: ui, log, plan, system, docker, install,
                   steps, server, status, vscode, helper
  sqlserver        the Terminal helper setup installs
tests/
  unit.sh          fast setup.sh tests, no Docker (CI runs these)
  stress.sh        everything, in a sandboxed container, plus a load test
packaging/homebrew the cask template the release CI pushes to the tap
.github/           CI workflow and its signing and cask scripts
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
tests/unit.sh                 setup.sh tests without Docker
tests/stress.sh               all setup.sh tests in a sandbox (container sqlstress, port 14339)
apps/desktop/make-dmg.sh      build, sign and notarize (uses the Apple account signed in to Xcode)
```

Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Releases

`main` is protected: changes land through pull requests once the **Scripts** and **App** checks pass. Each merge to `main` runs [CI](.github/workflows/ci.yml), which tests, builds, signs, notarizes, publishes release `v0.<commits>` with `SQLPilot.dmg`, and bumps the cask in [rafay99-epic/homebrew-apps](https://github.com/rafay99-epic/homebrew-apps).

Repo secrets the release job needs. There are no ad-hoc builds: if a signing secret is missing the release fails before anything is published.

| Secret | What |
|---|---|
| `MACOS_DEVELOPER_ID_P12` | base64 of the Developer ID Application certificate (.p12) |
| `MACOS_DEVELOPER_ID_PASSWORD` | its export password |
| `APPLE_API_KEY` | contents of the App Store Connect API key (`AuthKey_XXXX.p8`) |
| `APPLE_API_KEY_ID`, `APPLE_API_ISSUER` | the key's ID and issuer ID |
| `TAP_TOKEN` | fine-grained token with Contents read/write on `homebrew-apps` (the shared tap token; without it the cask bump is skipped) |

The website deploys from [`website.yml`](.github/workflows/website.yml) whenever `apps/website` changes on `main`.

Made by Syntax Lab Technology. Developer: Abdul Rafay ([rafay99.com](https://rafay99.com)).
