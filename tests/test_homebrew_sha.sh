#!/bin/bash
# Regression test: verify the homebrew cask SHA256 matches the actual release DMG.
# Catches issues like https://github.com/manaflow-ai/cmux/issues/110 where a race
# condition caused the cask to contain the SHA of a 404 page instead of the DMG.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$PROJECT_ROOT/scripts/release_identity.sh"

CASK_FILE="$PROJECT_ROOT/homebrew-cmux/Casks/${RELEASE_CASK_NAME}.rb"

if [ ! -f "$CASK_FILE" ]; then
  echo "SKIP: homebrew-cmux submodule not initialized"
  exit 0
fi

VERSION=$(grep 'version "' "$CASK_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')
CASK_SHA=$(grep 'sha256 "' "$CASK_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [ -z "$VERSION" ] || [ -z "$CASK_SHA" ]; then
  echo "FAIL: could not parse version/sha256 from $CASK_FILE"
  exit 1
fi

echo "Cask version: $VERSION"
echo "Cask SHA256:  $CASK_SHA"

URL="https://github.com/${RELEASE_GITHUB_REPOSITORY}/releases/download/v${VERSION}/${RELEASE_DMG_ASSET_NAME}"
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

HTTP_CODE=$(curl -sL -w '%{http_code}' "$URL" -o "$TMPFILE")
FILE_SIZE=$(stat -f%z "$TMPFILE" 2>/dev/null || stat --printf="%s" "$TMPFILE")

if [ "$HTTP_CODE" != "200" ]; then
  echo "FAIL: download returned HTTP $HTTP_CODE (expected 200)"
  exit 1
fi

if [ "$FILE_SIZE" -lt 1000000 ]; then
  echo "FAIL: downloaded file is only $FILE_SIZE bytes (expected >1MB for a DMG)"
  exit 1
fi

ACTUAL_SHA=$(shasum -a 256 "$TMPFILE" | cut -d' ' -f1)
echo "Actual SHA256: $ACTUAL_SHA"

if [ "$CASK_SHA" != "$ACTUAL_SHA" ]; then
  echo "FAIL: SHA256 mismatch!"
  echo "  Cask:   $CASK_SHA"
  echo "  Actual: $ACTUAL_SHA"
  exit 1
fi

echo "PASS: homebrew cask SHA256 matches release DMG"
