#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <version> <sha256> [output]" >&2
  exit 1
fi

VERSION="$1"
SHA256="$2"
OUTPUT="${3:-/dev/stdout}"

cat > "$OUTPUT" <<RUBY
cask "codex-menubar" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/sangimed/codex-menubar/releases/download/v#{version}/CodexMenuBar-v#{version}-macOS.zip"
  name "CodexMenuBar"
  desc "Monitor Codex usage limits at a glance"
  homepage "https://github.com/sangimed/codex-menubar"

  depends_on macos: :ventura

  app "CodexMenuBar.app"

  zap trash: [
    "~/Library/Application Support/CodexMenuBar",
    "~/Library/Preferences/com.sangimed.codex-menubar.plist",
  ]

  caveats <<~EOS
    CodexMenuBar is ad-hoc signed and is not notarized by Apple.
    macOS may block the first launch.

    If that happens, try to open CodexMenuBar once, then go to:
      System Settings > Privacy & Security > Open Anyway
  EOS
end
RUBY
