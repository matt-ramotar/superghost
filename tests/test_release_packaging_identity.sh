#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# shellcheck disable=SC1091
source "$PROJECT_ROOT/scripts/release_identity.sh"

[[ "${RELEASE_PRODUCT_NAME}" == "Superghost" ]]
[[ "${RELEASE_APP_BUNDLE_NAME}" == "Superghost.app" ]]
[[ "${RELEASE_EXECUTABLE_NAME}" == "Superghost" ]]
[[ "${RELEASE_BUNDLE_IDENTIFIER}" == "sh.bionic.superghost" ]]
[[ "${RELEASE_BUNDLED_CLI_NAME}" == "superghost" ]]
[[ "${RELEASE_DMG_ASSET_NAME}" == "superghost-macos.dmg" ]]
[[ "${RELEASE_APPCAST_ASSET_NAME}" == "superghost-appcast.xml" ]]
[[ "${RELEASE_CASK_NAME}" == "superghost" ]]
[[ "${RELEASE_WEBSITE_URL}" == "https://superghost.bionic.sh" ]]
[[ "${RELEASE_STABLE_APPCAST_URL}" == "https://github.com/manaflow-ai/cmux/releases/latest/download/superghost-appcast.xml" ]]

echo "PASS: release packaging identity matches Superghost"
