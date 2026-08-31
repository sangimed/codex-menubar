#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT_VERSION="$(bash "$ROOT_DIR/scripts/read-version.sh")"
VERSION="${VERSION:-$PROJECT_VERSION}"
ASSET_NAME="CodexMenuBar-v$VERSION-macOS.zip"
CHECKSUM_NAME="$ASSET_NAME.sha256"

VERSION="$VERSION" bash "$ROOT_DIR/scripts/build-app.sh"

mkdir -p dist
rm -f "dist/$ASSET_NAME" "dist/$CHECKSUM_NAME"

ditto -c -k --sequesterRsrc --keepParent   dist/CodexMenuBar.app   "dist/$ASSET_NAME"

(
  cd dist
  shasum -a 256 "$ASSET_NAME" > "$CHECKSUM_NAME"
)

echo "Packaged: dist/$ASSET_NAME"
echo "Checksum: dist/$CHECKSUM_NAME"
