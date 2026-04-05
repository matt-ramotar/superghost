#!/usr/bin/env bash

# Shared release identity constants for the shipped Superghost lane.

export RELEASE_PRODUCT_NAME="Superghost"
export RELEASE_APP_BUNDLE_NAME="Superghost.app"
export RELEASE_EXECUTABLE_NAME="Superghost"
export RELEASE_BUNDLE_IDENTIFIER="sh.bionic.superghost"
export RELEASE_BUNDLED_CLI_NAME="superghost"
export RELEASE_APP_SUPPORT_DIR_NAME="Superghost"
export RELEASE_CACHE_DIR_NAME="Superghost"
export RELEASE_SOCKET_PATH="/tmp/superghost.sock"
export RELEASE_LAST_SOCKET_PATH_FALLBACK="/tmp/superghost-last-socket-path"
export RELEASE_DMG_ASSET_NAME="superghost-macos.dmg"
export RELEASE_APPCAST_ASSET_NAME="superghost-appcast.xml"
export RELEASE_CASK_NAME="superghost"
export RELEASE_LEGACY_CASK_NAME="cmux"
export RELEASE_WEBSITE_URL="https://superghost.bionic.sh"
export RELEASE_GITHUB_REPOSITORY="matt-ramotar/superghost"
export RELEASE_HOMEBREW_TAP_REPOSITORY="matt-ramotar/homebrew-cmux"
export RELEASE_GITHUB_BASE_URL="https://github.com/${RELEASE_GITHUB_REPOSITORY}"
export RELEASE_RELEASES_BASE_URL="${RELEASE_GITHUB_BASE_URL}/releases"
export RELEASE_DOWNLOAD_BASE_URL="${RELEASE_RELEASES_BASE_URL}/latest/download"
export RELEASE_STABLE_APPCAST_URL="${RELEASE_DOWNLOAD_BASE_URL}/${RELEASE_APPCAST_ASSET_NAME}"
