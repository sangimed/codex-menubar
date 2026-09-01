# Security Policy

## Supported versions

Security fixes are provided for the latest stable release of CodexMenuBar.

## Reporting a vulnerability

Please do not open a public issue for a suspected security vulnerability.

Prefer GitHub's private vulnerability reporting flow from the repository's
**Security** tab when it is available. If that option is unavailable, contact
the maintainer through GitHub before sharing exploit details publicly.

When reporting a vulnerability, include:

- the affected CodexMenuBar version
- the macOS version
- the Codex CLI version and installation method
- clear reproduction steps
- the expected security impact

Do not include authentication tokens, cookies, or the contents of Codex
credential files.

CodexMenuBar intentionally delegates authentication to the locally installed
Codex CLI and does not read or copy `~/.codex/auth.json`.
