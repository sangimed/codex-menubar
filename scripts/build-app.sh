#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="CodexMenuBar"
BUNDLE_ID="com.sangimed.codex-menubar"
PROJECT_VERSION="$(bash "$ROOT_DIR/scripts/read-version.sh")"
VERSION="${VERSION:-$PROJECT_VERSION}"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

ARCH_ARGS=()
if [[ "${UNIVERSAL_BINARY:-1}" == "1" ]]; then
  ARCH_ARGS=(--arch arm64 --arch x86_64)
fi

echo "Building release binary…"
swift build -c release "${ARCH_ARGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_ARGS[@]}" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

if [[ "${UNIVERSAL_BINARY:-1}" == "1" ]]; then
  BUILT_ARCHS="$(lipo -archs "$MACOS_DIR/$APP_NAME")"
  echo "Built architectures: $BUILT_ARCHS"

  [[ "$BUILT_ARCHS" == *"arm64"* ]] || {
    echo "error: release binary is missing arm64" >&2
    exit 1
  }

  [[ "$BUILT_ARCHS" == *"x86_64"* ]] || {
    echo "error: release binary is missing x86_64" >&2
    exit 1
  }
fi

ICON_FILE="$RESOURCES_DIR/CodexMenuBar.icns"
bash "$ROOT_DIR/scripts/generate-app-icon.sh" "$ICON_FILE"

if [[ -f "$ROOT_DIR/assets/codex-menubar-logo.svg" ]]; then
  cp "$ROOT_DIR/assets/codex-menubar-logo.svg" "$RESOURCES_DIR/"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>CodexMenuBar.icns</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER:-1}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  echo "Signing with: $CODESIGN_IDENTITY"
  codesign --force --deep --options runtime --sign "$CODESIGN_IDENTITY" "$APP_DIR"
else
  echo "Applying ad-hoc signature…"
  codesign --force --deep --sign - "$APP_DIR"
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "Built: $APP_DIR"
