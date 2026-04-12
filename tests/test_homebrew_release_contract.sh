#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck disable=SC1091
source "$PROJECT_ROOT/scripts/release_identity.sh"

README_FILE="$PROJECT_ROOT/README.md"
TAP_README_FILE="$PROJECT_ROOT/homebrew-cmux/README.md"
GETTING_STARTED_FILE="$PROJECT_ROOT/web/app/[locale]/docs/getting-started/page.tsx"

require_fixed_string() {
  local file="$1"
  local needle="$2"

  if ! grep -Fq "$needle" "$file"; then
    echo "FAIL: expected '$needle' in $file" >&2
    exit 1
  fi
}

forbid_fixed_string() {
  local file="$1"
  local needle="$2"

  if grep -Fq "$needle" "$file"; then
    echo "FAIL: unexpected legacy string '$needle' in $file" >&2
    exit 1
  fi
}

if [[ "${RELEASE_CASK_NAME}" != "superghost" ]]; then
  echo "FAIL: RELEASE_CASK_NAME must be 'superghost' (got '${RELEASE_CASK_NAME}')" >&2
  exit 1
fi

if [[ "${RELEASE_HOMEBREW_TAP_REPOSITORY}" != "matt-ramotar/homebrew-cmux" ]]; then
  echo "FAIL: RELEASE_HOMEBREW_TAP_REPOSITORY must be 'matt-ramotar/homebrew-cmux' (got '${RELEASE_HOMEBREW_TAP_REPOSITORY}')" >&2
  exit 1
fi

for file in "$README_FILE" "$TAP_README_FILE" "$GETTING_STARTED_FILE"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL: expected file to exist: $file" >&2
    exit 1
  fi
done

for file in "$README_FILE" "$TAP_README_FILE" "$GETTING_STARTED_FILE"; do
  require_fixed_string "$file" "brew tap matt-ramotar/homebrew-cmux"
  require_fixed_string "$file" "brew install --cask superghost"
  require_fixed_string "$file" "brew upgrade --cask superghost"
  forbid_fixed_string "$file" "brew tap manaflow-ai/cmux"
  forbid_fixed_string "$file" "brew install --cask cmux"
done

echo "PASS: canonical Homebrew install surfaces teach the Superghost contract"
