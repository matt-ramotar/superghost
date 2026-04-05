#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ -n "${APP_PATH:-}" ]] || fail "APP_PATH must be set"
[[ -d "$APP_PATH" ]] || fail "app bundle not found at $APP_PATH"

APP_BASENAME="$(basename "$APP_PATH")"
[[ "$APP_BASENAME" == "Superghost.app" ]] || fail "expected bundle basename Superghost.app, got $APP_BASENAME"

APP_EXECUTABLE="$APP_PATH/Contents/MacOS/Superghost"
[[ -x "$APP_EXECUTABLE" ]] || fail "expected executable at $APP_EXECUTABLE"

LEGACY_APP_EXECUTABLE="$APP_PATH/Contents/MacOS/cmux"
[[ ! -e "$LEGACY_APP_EXECUTABLE" ]] || fail "legacy app executable should not exist at $LEGACY_APP_EXECUTABLE"

CLI_EXECUTABLE="$APP_PATH/Contents/Resources/bin/superghost"
[[ -x "$CLI_EXECUTABLE" ]] || fail "expected bundled CLI at $CLI_EXECUTABLE"

LEGACY_CLI="$APP_PATH/Contents/Resources/bin/cmux"
[[ ! -e "$LEGACY_CLI" ]] || fail "legacy bundled CLI should not exist at $LEGACY_CLI"

INFO_PLIST="$APP_PATH/Contents/Info.plist"
[[ -f "$INFO_PLIST" ]] || fail "missing Info.plist at $INFO_PLIST"

BUNDLE_IDENTIFIER="$(
  /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" 2>/dev/null || true
)"
[[ "$BUNDLE_IDENTIFIER" == "sh.bionic.superghost" ]] || fail "expected bundle identifier sh.bionic.superghost, got ${BUNDLE_IDENTIFIER:-<missing>}"

BUNDLE_EXECUTABLE="$(
  /usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO_PLIST" 2>/dev/null || true
)"
[[ "$BUNDLE_EXECUTABLE" == "Superghost" ]] || fail "expected CFBundleExecutable Superghost, got ${BUNDLE_EXECUTABLE:-<missing>}"

BUNDLE_NAME="$(
  /usr/libexec/PlistBuddy -c "Print :CFBundleName" "$INFO_PLIST" 2>/dev/null || true
)"
[[ "$BUNDLE_NAME" == "Superghost" ]] || fail "expected CFBundleName Superghost, got ${BUNDLE_NAME:-<missing>}"

DISPLAY_NAME="$(
  /usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$INFO_PLIST" 2>/dev/null || true
)"
[[ "$DISPLAY_NAME" == "Superghost" ]] || fail "expected CFBundleDisplayName Superghost, got ${DISPLAY_NAME:-<missing>}"

FEED_URL="$(
  /usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$INFO_PLIST" 2>/dev/null || true
)"
[[ "$FEED_URL" == *"/superghost-appcast.xml" ]] || fail "expected SUFeedURL to end with /superghost-appcast.xml, got ${FEED_URL:-<missing>}"

echo "PASS: release artifact identity matches Superghost"
