#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

bash "$ROOT_DIR/scripts/build-app.sh"

mkdir -p dist
rm -f dist/CodexMenuBar-macOS.zip

ditto -c -k --sequesterRsrc --keepParent   dist/CodexMenuBar.app   dist/CodexMenuBar-macOS.zip

echo "Packaged: dist/CodexMenuBar-macOS.zip"
