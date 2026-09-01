# Changelog

All notable user-facing changes are documented here.

## 0.2.3

- Hardened the public repository for external contributors and community use.
- Added dedicated tests for Codex executable discovery and Finder/Spotlight-safe
  process environments.
- Refactored the app-server client and menu bar UI into smaller focused
  components without changing the user experience.
- Added release/version consistency checks, immutable GitHub Actions pins, and
  Homebrew Cask style validation.
- Added MIT licensing, security guidance, issue forms, release notes tooling,
  and improved project documentation.

## 0.2.2

- Fixed Codex connectivity when CodexMenuBar is launched from Finder or
  Spotlight instead of an interactive shell.
- Made the Codex child-process environment independent from the user's shell
  `PATH`.

## 0.2.1

- Added the proper macOS application icon generated from the project logo.
- Added a configurable background refresh interval from 15 to 300 seconds,
  with a 30-second default.
- Added an optional compact credit balance in the menu bar.
- Changed the footer to a static last-update timestamp with seconds.
- Improved Homebrew installation and Gatekeeper documentation.

## 0.2.0

- Added persistent `codex app-server --stdio` integration.
- Added live `account/rateLimits/updated` handling with fallback refreshes.
- Added 5-hour and weekly quota display, reset times, plan information, and
  credits.
- Added preferences, threshold notifications, launch at login, and seven-day
  local history.
- Added universal macOS packaging, GitHub Releases, and Homebrew Cask
  distribution.
