#!/usr/bin/env bash
set -euo pipefail

TARGET_PATH="${1:?target path required}"
FALLBACK_BIN="${2:?fallback binary required}"
MODE="${3:-prefer-last-cli}"

case "$MODE" in
  prefer-last-cli|fallback-only) ;;
  *)
    echo "error: invalid superghost shim mode: $MODE" >&2
    exit 1
    ;;
esac

mkdir -p "$(dirname "$TARGET_PATH")"
cat > "$TARGET_PATH" <<EOF
#!/usr/bin/env bash
# superghost shim (managed by scripts/write-superghost-shim.sh)
set -euo pipefail

if [[ "\${1:-}" != "boo" ]]; then
  echo "error: only 'superghost boo' is supported." >&2
  exit 1
fi
shift

MODE="$MODE"
CLI_PATH_FILE="/tmp/cmux-last-cli-path"
if [[ "\$MODE" == "prefer-last-cli" ]]; then
  CLI_PATH_OWNER="\$(stat -f '%u' "\$CLI_PATH_FILE" 2>/dev/null || stat -c '%u' "\$CLI_PATH_FILE" 2>/dev/null || echo -1)"
  if [[ -r "\$CLI_PATH_FILE" ]] && [[ ! -L "\$CLI_PATH_FILE" ]] && [[ "\$CLI_PATH_OWNER" == "\$(id -u)" ]]; then
    CLI_PATH="\$(cat "\$CLI_PATH_FILE")"
    if [[ -x "\$CLI_PATH" ]]; then
      exec "\$CLI_PATH" welcome "\$@"
    fi
  fi
fi

if [[ -x "$FALLBACK_BIN" ]]; then
  exec "$FALLBACK_BIN" welcome "\$@"
fi

echo "error: no reload-selected dev cmux CLI found. Run ./scripts/reload.sh --tag <name> first." >&2
exit 1
EOF

chmod +x "$TARGET_PATH"
