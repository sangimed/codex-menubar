# Contributing to CodexMenuBar

Thanks for wanting to contribute.

This guide starts from zero and assumes you may never have configured a Swift or macOS development environment before.

## 1. What you need

CodexMenuBar currently targets:

- macOS 13 Ventura or newer
- Xcode with Swift 5.9 or newer
- Git
- Codex CLI installed and authenticated
- A GitHub account if you want to contribute changes upstream

You do **not** need to install any third-party Swift packages. The project uses Swift Package Manager, which ships with Xcode.

## 2. Install Xcode

### Option A — Mac App Store

1. Open the **App Store** on your Mac.
2. Search for **Xcode**.
3. Install it.
4. Launch Xcode once after the installation.
5. Accept the license and let Xcode install any additional components it requests.

Xcode is a large download, so make sure you have enough free disk space.

### Select the Xcode developer tools

Open Terminal and run:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Then verify:

```bash
xcodebuild -version
swift --version
```

You should see an Xcode version followed by a Swift version.

If macOS asks you to accept the Xcode license, run:

```bash
sudo xcodebuild -license accept
```

## 3. Install Git

Recent Xcode installations normally provide Git through the Command Line Tools.

Verify it with:

```bash
git --version
```

If macOS says the developer tools are missing, run:

```bash
xcode-select --install
```

and follow the system dialog.

## 4. Install Codex CLI

CodexMenuBar reads the usage information from your locally authenticated Codex CLI. It does not use a separate OpenAI API key.

If Codex is already installed, verify it:

```bash
codex --version
```

If it is not installed, the current official Codex installer for macOS is:

```bash
curl -fsSL https://chatgpt.com/codex/install.sh | sh
```

Codex can also be installed with Homebrew:

```bash
brew install --cask codex
```

or npm:

```bash
npm install -g @openai/codex
```

After installation, run:

```bash
codex
```

and choose **Sign in with ChatGPT**.

You can verify the local app-server manually:

```bash
codex app-server --stdio
```

Then paste:

```json
{"method":"initialize","id":1,"params":{"clientInfo":{"name":"codex-menubar-dev","version":"0.1.0"}}}
```

After the initialize response, paste:

```json
{"method":"initialized"}
```

and then:

```json
{"method":"account/rateLimits/read","id":2}
```

A successful response contains `usedPercent`, `windowDurationMins`, and `resetsAt`.

Press **Control+C** to stop the app-server.

## 5. Clone CodexMenuBar

Choose a folder where you keep source code, then run:

```bash
git clone https://github.com/sangimed/codex-menubar.git
cd codex-menubar
```

If you use GitHub CLI:

```bash
gh repo clone sangimed/codex-menubar
cd codex-menubar
```

## 6. Check your environment

The repository includes a small diagnostic script:

```bash
make check
```

It checks that Xcode, Swift, Git, and Codex are available.

A healthy setup should end with:

```text
Environment looks ready.
```

## 7. Build the project

Run:

```bash
make build
```

This is equivalent to:

```bash
swift build
```

Swift Package Manager will create a local `.build` directory. It is ignored by Git.

## 8. Run CodexMenuBar

The quickest way is:

```bash
make run
```

or:

```bash
swift run CodexMenuBar
```

CodexMenuBar is a menu-bar-only application, so do not expect a normal application window or Dock icon.

Look at the right side of the macOS menu bar. You should see a gauge icon followed by the Codex usage percentages.

Click the item to open the usage popover.

Press **Control+C** in the Terminal where you launched it to stop the development build, or click **Quit** in the popover.

## 9. Open the project in Xcode

You can develop entirely from Xcode even though this repository does not contain an `.xcodeproj` file.

That is intentional: the project uses Swift Package Manager.

From Terminal:

```bash
xed .
```

If `xed` is not available, open Xcode and choose:

1. **File**
2. **Open…**
3. Select the `codex-menubar` folder
4. Wait for Xcode to resolve the Swift package

At the top of Xcode:

1. Select the **CodexMenuBar** scheme.
2. Select **My Mac** as the destination.
3. Click the Run button or press **Command+R**.

The app should appear in the macOS menu bar.

### Useful Xcode shortcuts

- **Command+R** — build and run
- **Command+B** — build
- **Command+U** — run tests
- **Command+.** — stop the running app

## 10. Run the tests

From Terminal:

```bash
make test
```

or:

```bash
swift test
```

The test suite covers rate-limit decoding and classification, Codex executable discovery, GUI-safe process environment construction, and preference validation.

Before opening a pull request, run both:

```bash
make build
make test
```

## 11. Project structure

```text
.
├── VERSION
├── Package.swift
├── README.md
├── CONTRIBUTING.md
├── RELEASING.md
├── CHANGELOG.md
├── LICENSE
├── SECURITY.md
├── Makefile
├── assets/
│   └── codex-menubar-logo.svg
├── docs/
│   ├── REPOSITORY_SETTINGS.md
│   └── screenshots/
├── scripts/
│   ├── build-app.sh
│   ├── check-environment.sh
│   ├── configure-main-protection.sh
│   ├── generate-app-icon.sh
│   ├── generate-app-icon.swift
│   ├── generate-release-notes.sh
│   ├── package-app.sh
│   ├── read-version.sh
│   └── render-homebrew-cask.sh
├── Sources/
│   ├── CodexMenuBar/
│   │   ├── CodexMenuBarApp.swift
│   │   ├── MenuBarView.swift
│   │   ├── PreferencesSection.swift
│   │   ├── UsageHistorySection.swift
│   │   ├── AdditionalLimitsSection.swift
│   │   ├── UsageComponents.swift
│   │   └── ...
│   └── CodexMenuBarCore/
│       ├── CodexAppServerClient.swift
│       ├── CodexAppServerError.swift
│       ├── CodexExecutableResolver.swift
│       ├── CodexRPCModels.swift
│       ├── POSIXLineReader.swift
│       ├── RateLimitModels.swift
│       └── ...
└── Tests/
    ├── CodexMenuBarCoreTests/
    └── CodexMenuBarTests/
```

### `CodexMenuBarCore`

Contains code that does not depend on SwiftUI:

- Codex app-server process management
- JSON-RPC requests
- response models
- rate-limit classification

Keeping this logic separate makes it easier to test.

### `CodexMenuBar`

Contains the macOS UI and application state:

- `MenuBarExtra`
- menu bar label
- popover
- persistent app-server lifecycle
- live notification updates
- fallback and manual refresh

## 12. How the Codex integration works

CodexMenuBar uses one persistent local app-server session:

1. Finds the local `codex` executable.
2. Starts `codex app-server --stdio` once.
3. Sends the JSON-RPC `initialize` request.
4. Sends the `initialized` notification.
5. Calls `account/rateLimits/read` for the initial snapshot.
6. Keeps reading JSONL messages from the same stdout pipe.
7. Applies `account/rateLimits/updated` notifications immediately.
8. Reuses the same connection for manual refreshes.
9. Sends a fallback `account/rateLimits/read` at the configured 15–300 second interval (30 seconds by default).
10. Restarts the app-server with exponential backoff if it exits.

This avoids repeatedly spawning Codex processes while keeping the menu bar fresher than fixed-interval polling.

The response can contain several buckets. CodexMenuBar prefers:

```text
rateLimitsByLimitId.codex
```

when it exists, and falls back to:

```text
rateLimits
```

The five-hour and weekly limits are detected by duration:

```text
300 minutes   → 5-hour window
10080 minutes → weekly window
```

The code intentionally does not assume that `primary` and `secondary` always have fixed meanings.

CodexMenuBar also inspects `rateLimitsByLimitId`. The `codex` entry remains the main quota, while any additional explicitly reported bucket is surfaced in the popover. The app uses `limitName` when Codex provides one and never guesses a model mapping.

### Local preferences, history, and notifications

CodexMenuBar stores display, refresh, and notification preferences in `UserDefaults`. Usage history is stored in the user's Application Support directory for seven days. Notification alerts are only emitted when a remaining quota crosses the configured threshold.

Launch at login uses `SMAppService.mainApp` and is intended to be tested from a packaged `.app`, not from `swift run`.

### Build a local app bundle

```bash
make app
```

This creates:

```text
dist/CodexMenuBar.app
```

The packaged app icon is generated from `assets/codex-menubar-logo.svg` as a
macOS `.icns` file and embedded in `Contents/Resources`. To generate the
icon by itself:

```bash
make icon
```

To also create a versioned ZIP and SHA-256 checksum:

```bash
make package
```

The root `VERSION` file is the source of truth for local package versions. Release automation verifies that the requested release version matches it.

Release builds are universal macOS binaries by default and contain both `arm64` and `x86_64`. See **[RELEASING.md](RELEASING.md)** for tagged GitHub Releases and Homebrew distribution.

For local development the bundle receives an ad-hoc signature. To sign with a Developer ID:

```bash
CODESIGN_IDENTITY="Developer ID Application: Your Name (...)" make app
```

## 13. Codex executable discovery

A GUI app does not always inherit the same `PATH` as your interactive Terminal.

CodexMenuBar therefore checks:

- `CODEX_EXECUTABLE`
- the current `PATH`
- Homebrew locations on Apple Silicon and Intel Macs
- the official standalone installer under `~/.codex/packages/standalone`
- common local npm locations
- Volta, asdf, and mise shims
- installed Node versions under `~/.nvm/versions/node`

When launching the child process, CodexMenuBar also constructs a GUI-safe
`PATH` so Finder/Spotlight launches do not depend on an interactive shell.

If CodexMenuBar still cannot find Codex, get its path:

```bash
which codex
```

For a Terminal development run:

```bash
CODEX_EXECUTABLE="$(which codex)" swift run CodexMenuBar
```

For Xcode:

1. Open **Product → Scheme → Edit Scheme…**
2. Select **Run → Arguments**
3. Under **Environment Variables**, add `CODEX_EXECUTABLE`
4. Set its value to the output of `which codex`

## 14. Troubleshooting

### `swift: command not found`

Make sure Xcode is installed and selected:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Xcode says the license has not been accepted

Run:

```bash
sudo xcodebuild -license accept
```

### The app runs but no menu bar item appears

Make sure you are running on macOS 13 or later.

Also stop any previous development instance before launching another one.

### Codex CLI was not found

Run:

```bash
which codex
```

Then use the `CODEX_EXECUTABLE` override described above.

### Codex returns an authentication error

Run:

```bash
codex
```

and sign in with ChatGPT again.

### The five-hour window says "Not currently reported by Codex"

That does not necessarily mean CodexMenuBar is broken. The app-server can sometimes return only one active quota window for an account.

CodexMenuBar deliberately displays missing windows as unavailable instead of inventing a value.

### The usage value is briefly stale

The app normally updates from `account/rateLimits/updated` notifications and performs a configurable fallback resync. If the persistent app-server disconnects, the last successful usage snapshot remains visible while CodexMenuBar reconnects automatically.

## 15. Make a contribution

Create a branch:

```bash
git switch -c feat/my-change
```

Make your changes, then run:

```bash
make build
make test
```

Commit:

```bash
git add .
git commit -m "feat: describe your change"
```

Push the branch:

```bash
git push -u origin feat/my-change
```

Then open a pull request on GitHub.

Useful branch prefixes:

- `feat/` — new feature
- `fix/` — bug fix
- `docs/` — documentation
- `refactor/` — internal cleanup
- `test/` — tests

## 16. Coding guidelines

Keep the project lightweight and native:

- Prefer Foundation, AppKit, and SwiftUI over third-party dependencies.
- Keep Codex protocol handling in `CodexMenuBarCore`.
- Keep UI code in the `CodexMenuBar` target.
- Add or update tests when changing response parsing or quota classification.
- Handle missing or new Codex fields gracefully.
- Avoid reading `~/.codex/auth.json` directly.
- Never log or commit authentication tokens.

## 17. Continuous integration

GitHub Actions runs on pushes to `main` and on pull requests.

CI builds and tests the Swift package, creates the universal app bundle,
verifies both architectures and the ad-hoc signature, checks the generated
application icon and bundle version, and validates the generated Homebrew Cask.

A pull request should be green before it is merged.

## 18. Useful references

- Codex repository: https://github.com/openai/codex
- Swift: https://www.swift.org/documentation/
- SwiftUI: https://developer.apple.com/xcode/swiftui/
- Swift Package Manager: https://www.swift.org/package-manager/
- Xcode: https://developer.apple.com/xcode/
