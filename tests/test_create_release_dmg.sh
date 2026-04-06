#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

APP_PATH="$TMP_DIR/Superghost.app"
OUTPUT_DMG="$TMP_DIR/output/superghost-macos.dmg"
STUB_DIR="$TMP_DIR/bin"
mkdir -p "$APP_PATH" "$STUB_DIR"

cat > "$STUB_DIR/create-dmg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage
  $ create-dmg <app> [destination]
HELP
  exit 0
fi

app_path="${@: -2:1}"
output_dir="${@: -1}"
mkdir -p "$output_dir"
printf '%s\n' "fake dmg for $app_path" > "$output_dir/Generated Superghost Installer.dmg"
EOF
chmod +x "$STUB_DIR/create-dmg"

PATH="$STUB_DIR:$PATH" \
  "$PROJECT_ROOT/scripts/create_release_dmg.sh" \
  "$APP_PATH" \
  "$OUTPUT_DMG" \
  --identity="Developer ID Application: Example"

[[ -f "$OUTPUT_DMG" ]]
[[ "$(cat "$OUTPUT_DMG")" == "fake dmg for $APP_PATH" ]]

echo "PASS: create_release_dmg relocates emitted DMG to requested output path"
