# CodexMenuBar

A native macOS menu bar app for monitoring your OpenAI Codex usage limits at a glance.

> **Status:** Early development. The first release is not available yet.

## Why CodexMenuBar?

Codex exposes usage limits for both its rolling **5-hour window** and **weekly window**, but checking them manually interrupts your workflow.

CodexMenuBar aims to keep that information visible directly in the macOS menu bar, with a lightweight native UI and no separate backend.

## Planned features

- 5-hour Codex usage
- Weekly Codex usage
- Time remaining until each limit resets
- Remaining Codex credits, when available
- Compact menu bar indicator
- Detailed usage popover
- Automatic refresh
- Launch at login
- Native macOS experience built with Swift and SwiftUI

## How it works

CodexMenuBar talks to the locally installed Codex CLI through the Codex app server:

```bash
codex app-server --stdio
```

The app initializes the local JSON-RPC connection and reads the current rate limits using:

```text
account/rateLimits/read
```

A typical response contains usage information such as:

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

CodexMenuBar identifies the windows by their duration rather than assuming that `primary` or `secondary` always maps to a particular limit:

- `300` minutes → 5-hour window
- `10080` minutes → weekly window

## Privacy

CodexMenuBar is designed to run entirely on your Mac.

It does not require a separate API key or hosted backend. It uses your existing locally authenticated Codex CLI session and does not need to copy or expose your Codex authentication file.

## Requirements

Development is currently targeting:

- macOS
- Apple Silicon and Intel Macs
- Codex CLI installed and authenticated
- Swift / SwiftUI

Exact minimum macOS and Codex versions will be documented before the first release.

## Roadmap

### v0.1

- [ ] Native macOS menu bar app
- [ ] Connect to `codex app-server`
- [ ] Display 5-hour usage
- [ ] Display weekly usage
- [ ] Display reset countdowns
- [ ] Display available credits
- [ ] Manual and automatic refresh

### Later

- [ ] Configurable menu bar display
- [ ] Used vs. remaining percentage mode
- [ ] Usage threshold notifications
- [ ] Launch at login
- [ ] Usage history
- [ ] Model-specific limits when exposed by Codex

## Development

The project is being designed as a small native macOS application with a simple architecture:

```text
SwiftUI / MenuBarExtra
        │
        ▼
CodexUsageService
        │
        ▼
codex app-server --stdio
        │
        ▼
JSON-RPC rate limit data
```

More development and build instructions will be added as the initial implementation lands.

## Contributing

The project is in its early stages, but ideas, bug reports, and contributions are welcome.

## Disclaimer

CodexMenuBar is an independent open-source project and is not affiliated with or endorsed by OpenAI.

Codex and its local app-server protocol may evolve over time, so compatibility can change between Codex CLI releases.
