#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <cask-file>" >&2
  exit 1
fi

CASK_FILE="$1"

if [[ ! -f "$CASK_FILE" ]]; then
  echo "error: cask file not found: $CASK_FILE" >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "error: Homebrew is required to validate the cask" >&2
  exit 1
fi

TAP="codex-menubar/ci"

cleanup() {
  brew untap --force "$TAP" >/dev/null 2>&1 || true
}
trap cleanup EXIT

cleanup
brew tap-new --no-git "$TAP" >/dev/null

TAP_DIR="$(brew --repository "$TAP")"
TARGET="$TAP_DIR/Casks/codex-menubar.rb"

mkdir -p "$(dirname "$TARGET")"
cp "$CASK_FILE" "$TARGET"

brew style --cask "$TARGET"
