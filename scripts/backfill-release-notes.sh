#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v gh >/dev/null 2>&1; then
  echo "error: GitHub CLI (gh) is required" >&2
  exit 1
fi

gh auth status >/dev/null

RELEASE_TAG="${1:-$(git describe --tags --abbrev=0)}"
RELEASE_SHA="$(git rev-list -n 1 "$RELEASE_TAG")"

NOTES_FILE="$(mktemp)"
cleanup() {
  rm -f "$NOTES_FILE"
}
trap cleanup EXIT

bash scripts/generate-release-notes.sh   "$RELEASE_TAG"   "$RELEASE_SHA"   "$NOTES_FILE"

echo "Updating release notes for $RELEASE_TAG..."
cat "$NOTES_FILE"

gh release edit "$RELEASE_TAG"   --notes-file "$NOTES_FILE"

echo "Release notes updated."
