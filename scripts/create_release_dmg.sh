#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/create_release_dmg.sh <app_path> <output_dmg> [create-dmg options...]

Creates a DMG via create-dmg, then moves the emitted DMG to <output_dmg>.
This avoids assuming create-dmg writes the final DMG name directly.
EOF
}

if [[ $# -lt 2 ]]; then
  usage >&2
  exit 1
fi

APP_PATH="$1"
OUTPUT_DMG="$2"
shift 2

if [[ ! -e "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH" >&2
  exit 1
fi

CREATE_DMG_HELP="$(create-dmg --help 2>&1 || true)"
if [[ "$CREATE_DMG_HELP" != *"<app> [destination]"* ]]; then
  echo "create-dmg with '<app> [destination]' syntax is required (expected create-dmg@8+)" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$(dirname "$OUTPUT_DMG")"
rm -f "$OUTPUT_DMG"

create-dmg "$@" "$APP_PATH" "$TMP_DIR"

CREATED_DMG="$(find "$TMP_DIR" -maxdepth 1 -name '*.dmg' -print -quit)"
if [[ -z "$CREATED_DMG" ]]; then
  echo "Failed to locate created DMG for $APP_PATH" >&2
  exit 1
fi

mv "$CREATED_DMG" "$OUTPUT_DMG"
