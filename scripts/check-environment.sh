#!/usr/bin/env bash
set -euo pipefail

failures=0

ok() {
  printf "✓ %s\n" "$1"
}

fail() {
  printf "✗ %s\n" "$1"
  failures=$((failures + 1))
}

echo "Checking CodexMenuBar development environment..."
echo

if command -v xcodebuild >/dev/null 2>&1; then
  ok "$(xcodebuild -version | head -n 1)"
else
  fail "Xcode is not available. Install Xcode from the Mac App Store and launch it once."
fi

if command -v swift >/dev/null 2>&1; then
  ok "$(swift --version | head -n 1)"
else
  fail "Swift is not available. Install/select Xcode Command Line Tools."
fi

if command -v codex >/dev/null 2>&1; then
  ok "$(codex --version 2>/dev/null || echo "Codex CLI found")"
else
  fail "Codex CLI is not on PATH. Install Codex and authenticate with ChatGPT."
fi

if command -v git >/dev/null 2>&1; then
  ok "$(git --version)"
else
  fail "Git is not available."
fi

echo

if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed. See CONTRIBUTING.md for setup instructions."
  exit 1
fi

echo "Environment looks ready."
