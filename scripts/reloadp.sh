#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

xcodebuild -project GhosttyTabs.xcodeproj -scheme cmux -configuration Release -destination 'platform=macOS' build
pkill -x Superghost || true
sleep 0.2
APP_PATH="$(
  find "$HOME/Library/Developer/Xcode/DerivedData" -path "*/Build/Products/Release/Superghost.app" -print0 \
  | xargs -0 /usr/bin/stat -f "%m %N" 2>/dev/null \
  | sort -nr \
  | head -n 1 \
  | cut -d' ' -f2-
)"
if [[ -z "${APP_PATH}" ]]; then
  echo "Superghost.app not found in DerivedData" >&2
  exit 1
fi

CLI_PATH="${APP_PATH}/Contents/Resources/bin/superghost"
if [[ ! -x "$CLI_PATH" ]]; then
  echo "bundled superghost CLI not found at $CLI_PATH" >&2
  exit 1
fi

echo "Release app:"
echo "  ${APP_PATH}"

# Dev shells (including CI/Codex) often force-disable paging by exporting these.
# Don't leak that into cmux, otherwise `git diff` won't page even with PAGER=less.
APP_PROCESS_PATH="${APP_PATH}/Contents/MacOS/Superghost"
env -u GIT_PAGER -u GH_PAGER "$APP_PROCESS_PATH" >/dev/null 2>&1 &
ATTEMPT=0
MAX_ATTEMPTS=20
while [[ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]]; do
  if pgrep -f "$APP_PROCESS_PATH" >/dev/null 2>&1; then
    echo "Release launch status:"
    echo "  running: ${APP_PROCESS_PATH}"
    exit 0
  fi
  ATTEMPT=$((ATTEMPT + 1))
  sleep 0.25
done

echo "warning: Release app launch was requested, but no running process was observed for:" >&2
echo "  ${APP_PROCESS_PATH}" >&2
