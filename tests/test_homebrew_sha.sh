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

LATEST_RELEASE_JSON="$(curl -fsSL -H 'Accept: application/vnd.github+json' "https://api.github.com/repos/${RELEASE_GITHUB_REPOSITORY}/releases/latest")"
LATEST_TAG="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])' <<<"$LATEST_RELEASE_JSON")"
LATEST_VERSION="${LATEST_TAG#v}"

if [ -z "$LATEST_VERSION" ]; then
  echo "FAIL: could not determine latest stable release version for ${RELEASE_GITHUB_REPOSITORY}"
  exit 1
fi

echo "Cask version: $VERSION"
echo "Latest release version: $LATEST_VERSION"
echo "Cask SHA256:  $CASK_SHA"

if [ "$VERSION" != "$LATEST_VERSION" ]; then
  echo "FAIL: cask version is stale"
  echo "  Cask:   $VERSION"
  echo "  Latest: $LATEST_VERSION"
  exit 1
fi

URL="https://github.com/${RELEASE_GITHUB_REPOSITORY}/releases/download/v${LATEST_VERSION}/${RELEASE_DMG_ASSET_NAME}"
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
