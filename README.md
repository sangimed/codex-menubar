<p align="center">
  <img src="assets/codex-menubar-logo.svg" alt="CodexMenuBar logo" width="240" />
</p>

# CodexMenuBar

A native macOS menu bar app for monitoring your OpenAI Codex usage limits at a glance.

> **Status:** v0.2 development branch. Run it from source or build a local `.app` bundle.

## Why CodexMenuBar?

Codex exposes usage limits for its rolling **5-hour window** and **weekly window**, but checking them manually interrupts your workflow.

CodexMenuBar keeps that information directly in the macOS menu bar with a lightweight native UI and no separate backend.

The menu bar shows a compact summary such as:

```text
13% · W73%
```

The percentages represent **quota remaining**, matching the Codex UI. Click the item to see detailed five-hour and weekly usage, reset times, plan, credits, and refresh status.

## Features

- [x] Native macOS menu bar app
- [x] Connect to `codex app-server --stdio`
- [x] Display 5-hour usage
- [x] Display weekly usage
- [x] Display reset countdowns
- [x] Display available credits when reported by Codex
- [x] Manual refresh
- [x] Live updates from `account/rateLimits/updated`
- [x] Persistent local app-server session
- [x] Five-minute fallback resync
- [x] Preserve the last successful snapshot when a refresh fails
- [x] Handle missing quota windows gracefully
- [x] Apple Silicon and Intel-compatible Swift source
- [x] Core response-model tests
- [x] macOS GitHub Actions build and test workflow

## Requirements

- macOS 13 Ventura or newer
- Codex CLI installed and authenticated
- Xcode / Swift 5.9 or newer for development

## Quick start

If you already have Xcode and Codex installed:

```bash
git clone https://github.com/sangimed/codex-menubar.git
cd codex-menubar
make check
make run

# Build an ad-hoc signed local app bundle
make app

# Build the app and a distributable ZIP
make package
```

CodexMenuBar has no normal application window and no Dock icon. Look for it on the right side of your macOS menu bar.

If this is your first Swift project, follow the complete setup guide in **[CONTRIBUTING.md](CONTRIBUTING.md)**. It covers installing Xcode, Swift, Codex, cloning the project, running it from Terminal or Xcode, tests, debugging, and common setup issues.

## How it works

CodexMenuBar talks to the locally installed Codex CLI through the Codex app server:

```bash
codex app-server --stdio
```

The app performs the JSON-RPC initialization handshake once, keeps that local process alive, and requests an initial snapshot with:

```text
account/rateLimits/read
```

A typical response contains:

```json
{
  "primary": {
    "usedPercent": 82,
    "windowDurationMins": 300,
    "resetsAt": 1788125155
  },
  "secondary": {
    "usedPercent": 26,
    "windowDurationMins": 10080,
    "resetsAt": 1788693894
  }
}
```

CodexMenuBar prefers the `rateLimitsByLimitId.codex` bucket when Codex exposes it, then falls back to the top-level `rateLimits` snapshot.

It identifies quota windows by duration instead of assuming that `primary` or `secondary` has a fixed meaning:

- `300` minutes → 5-hour window
- `10080` minutes → weekly window

If Codex does not report one of those windows, the popover shows it as unavailable rather than fabricating a value.

If Codex exposes additional entries in `rateLimitsByLimitId`, v0.2 surfaces them under **Additional Codex limits** using the server-provided `limitName` when available. CodexMenuBar does not guess which model a limit belongs to.

After the initial snapshot, CodexMenuBar listens for `account/rateLimits/updated` notifications and updates the UI immediately. Manual refreshes reuse the same connection, and a lightweight `account/rateLimits/read` runs every five minutes as a fallback resync. If the app-server exits, CodexMenuBar restarts it with exponential backoff.

## v0.2 local state

Preferences use macOS `UserDefaults`. Usage history is stored locally under Application Support and retained for seven days. Threshold notifications use the macOS notification center. No history is uploaded by CodexMenuBar.

## Packaging

```bash
make app
make package
```

`make app` creates an ad-hoc signed `dist/CodexMenuBar.app`. Set `CODESIGN_IDENTITY` to use a Developer ID identity instead. `make package` additionally creates `dist/CodexMenuBar-macOS.zip`.

Launch at login is intended for a packaged app build; `swift run` remains the development path.

## Privacy

CodexMenuBar runs locally on your Mac.

It does not require a separate API key or hosted backend. It uses the locally authenticated Codex CLI session and does **not** read or copy `~/.codex/auth.json`.

## Architecture

```text
SwiftUI / MenuBarExtra
        │
        ▼
UsageStore
        │
        ▼
CodexAppServerClient
        │
        ▼
codex app-server --stdio
        │
        ├── account/rateLimits/read
        └── account/rateLimits/updated
```

The repository is split into two Swift targets:

- **CodexMenuBar** — SwiftUI/AppKit menu bar UI and application state
- **CodexMenuBarCore** — Codex process management, JSON-RPC integration, models, and quota classification

Keeping protocol code outside the UI makes it testable without launching the menu bar app.

## Development

Common commands:

```bash
make check
make build
make test
make run
```

The project intentionally uses Swift Package Manager instead of committing an Xcode project file. Xcode can open the repository directly:

```bash
xed .
```

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for the complete beginner-friendly development setup and contribution workflow.

## v0.2

The v0.2 branch adds:

- [x] Configurable menu bar display: both windows, 5-hour only, weekly only, or icon only
- [x] Used vs. remaining percentage mode
- [x] Configurable low-quota notifications
- [x] Launch at login for packaged app builds
- [x] Local `.app` and ZIP packaging scripts
- [x] Seven-day local usage history
- [x] Additional named/model-specific limit buckets when Codex exposes them through `rateLimitsByLimitId`

## Known limitations

- v0.1 is currently a source/development build rather than a signed packaged release.
- CodexMenuBar keeps one local `codex app-server` process alive while the app is running and reconnects automatically if it exits.
- The Codex app-server protocol can evolve between Codex CLI releases.
- Some accounts may temporarily receive only one quota window from Codex.

## Contributing

Contributions are welcome. Start with **[CONTRIBUTING.md](CONTRIBUTING.md)**, especially if you have never configured Swift development on macOS before.

## Disclaimer

CodexMenuBar is an independent community project and is not affiliated with or endorsed by OpenAI.

Codex and the Codex app-server protocol may evolve over time, so compatibility can change between Codex CLI releases.
