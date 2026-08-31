#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <release-tag> <commit-sha> [output]" >&2
  exit 1
fi

RELEASE_TAG="$1"
RELEASE_SHA="$2"
OUTPUT="${3:-/dev/stdout}"
REPOSITORY="${GITHUB_REPOSITORY:-sangimed/codex-menubar}"

PREVIOUS_TAG="$(
  git describe     --tags     --match 'v[0-9]*'     --abbrev=0     "${RELEASE_SHA}^"     2>/dev/null     || true
)"

{
  echo "## What's changed"
  echo

  if [[ -n "$PREVIOUS_TAG" ]]; then
    CHANGES="$(
      git log         --no-merges         --pretty='- %s (`%h`)'         "$PREVIOUS_TAG..$RELEASE_SHA"
    )"
  else
    CHANGES="$(
      git log         --no-merges         --max-count=20         --pretty='- %s (`%h`)'         "$RELEASE_SHA"
    )"
  fi

  if [[ -n "$CHANGES" ]]; then
    printf '%s\n' "$CHANGES"
  else
    echo "- Maintenance release"
  fi

  if [[ -n "$PREVIOUS_TAG" ]]; then
    echo
    echo "**Full Changelog**: https://github.com/$REPOSITORY/compare/$PREVIOUS_TAG...$RELEASE_TAG"
  fi
} > "$OUTPUT"
