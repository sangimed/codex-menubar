#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_SVG="$ROOT_DIR/assets/codex-menubar-logo.svg"
OUTPUT_ICNS="${1:-$ROOT_DIR/dist/CodexMenuBar.icns}"

if [[ ! -f "$SOURCE_SVG" ]]; then
  echo "error: missing icon source: $SOURCE_SVG" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_ICNS")"

WORK_DIR="$(mktemp -d)"
ICONSET_DIR="$WORK_DIR/CodexMenuBar.iconset"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

swift "$ROOT_DIR/scripts/generate-app-icon.swift"   "$SOURCE_SVG"   "$ICONSET_DIR"

iconutil -c icns   "$ICONSET_DIR"   -o "$OUTPUT_ICNS"

echo "Generated: $OUTPUT_ICNS"
