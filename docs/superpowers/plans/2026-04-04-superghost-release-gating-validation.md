# Superghost Release Gating Validation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename stable/nightly release automation and define no-release gates so `Superghost` is not shipped until release assets, update feeds, Homebrew publication, and historical-reference boundaries all match the hardened design.

**Architecture:** Cut over stable release automation first, then nightly asset/feed automation, then Homebrew/publication verification, and finally explicit release-gating rules that prevent shipping while external dependencies or historical-reference boundaries are still mixed.

**Tech Stack:** GitHub Actions, shell release scripts, Sparkle appcasts, remote-daemon asset tooling, Homebrew checksum verification, markdown release policy.

## File Map

- Modify: `scripts/release_asset_guard.js`
  Responsibility: rename the guarded stable asset list and fail if old immutable asset names are still emitted.
- Modify: `scripts/sparkle_generate_appcast.sh`
  Responsibility: rename feed URL defaults and generated appcast expectations.
- Modify: `scripts/build-sign-upload.sh`
  Responsibility: rename stable DMG/appcast generation and Homebrew update flow.
- Modify: `scripts/build_remote_daemon_release_assets.sh`
  Responsibility: rename remote-daemon asset and manifest outputs for the released contract.
- Modify: `scripts/bump-version.sh`
  Responsibility: rename stable appcast lookup defaults used for build numbering.
- Modify: `.github/workflows/release.yml`
  Responsibility: rename stable release assets, feed URLs, remote-daemon publication, and repo/domain references.
- Modify: `.github/workflows/nightly.yml`
  Responsibility: rename nightly assets, appcasts, remote-daemon publication, and nightly release notes/download links.
- Modify: `.github/workflows/update-homebrew.yml`
  Responsibility: rename the cask rewrite and publication flow.
- Modify: `tests/test_homebrew_sha.sh`
  Responsibility: keep checksum verification aligned with renamed release assets.
- Modify: `tests/test_remote_daemon_release_assets.sh`
  Responsibility: keep remote-daemon release validation aligned with primary `superghostd-remote` outputs and any explicitly documented compatibility aliases.
- Modify: `tests/test_nightly_universal_build.sh`
  Responsibility: keep nightly build validation aligned with renamed bundle IDs, feed metadata, and asset names.
- Modify: `CHANGELOG.md`
  Responsibility: preserve historical references as historical while ensuring current release guidance uses the renamed contract.
- Modify: `README.md`
  Responsibility: keep current release/download guidance aligned with the final published contract.

### Task 1: Rename Stable Release Asset Generation And Guard Rails

**Files:**
- Modify: `scripts/release_asset_guard.js`
- Modify: `scripts/sparkle_generate_appcast.sh`
- Modify: `scripts/build-sign-upload.sh`
- Modify: `scripts/bump-version.sh`
- Modify: `.github/workflows/release.yml`

- [ ] **Step 1: Inventory stable release surfaces**

Run:
```bash
rg -n 'release_asset_guard|sparkle_generate_appcast|build-sign-upload|bump-version|cmux-macos|appcast\\.xml|manaflow-ai/cmux|cmuxd-remote' \
  scripts/release_asset_guard.js \
  scripts/sparkle_generate_appcast.sh \
  scripts/build-sign-upload.sh \
  scripts/bump-version.sh \
  .github/workflows/release.yml
```
Expected: stable release scripts and workflow still emit `cmux` asset names or old repo/feed URLs.

- [ ] **Step 2: Rename stable DMG, appcast, feed, and repo outputs**

Update the stable release path so guarded asset names, Sparkle feed defaults, build-sign-upload flow, and release workflow publication all use `superghost` names and the new repo/domain while preserving required feed compatibility outputs such as `appcast.xml` and any explicitly documented `cmuxd-remote-*` alias publication only where the hardened spec still requires them.

- [ ] **Step 3: Verify stable release automation**

Run:
```bash
! rg -n 'cmux-macos|manaflow-ai/cmux' \
  scripts/release_asset_guard.js \
  scripts/sparkle_generate_appcast.sh \
  scripts/build-sign-upload.sh \
  scripts/bump-version.sh \
  .github/workflows/release.yml
rg -n 'appcast\\.xml|superghostd-remote' \
  scripts/release_asset_guard.js \
  scripts/sparkle_generate_appcast.sh \
  scripts/build-sign-upload.sh \
  scripts/bump-version.sh \
  .github/workflows/release.yml
rg -n 'cmuxd-remote|compatibility alias|alias' \
  scripts/release_asset_guard.js \
  scripts/sparkle_generate_appcast.sh \
  scripts/build-sign-upload.sh \
  scripts/bump-version.sh \
  .github/workflows/release.yml
```
Expected: active stable release automation no longer publishes old stable DMG/repo identifiers, `appcast.xml` remains only where the hardened spec requires it, `superghostd-remote` is the primary daemon artifact/manifest name, and any remaining `cmuxd-remote` references are explicit compatibility-alias publication rather than the canonical shipped output.

- [ ] **Step 4: Commit**

```bash
git add scripts/release_asset_guard.js scripts/sparkle_generate_appcast.sh scripts/build-sign-upload.sh scripts/bump-version.sh .github/workflows/release.yml
git commit -m "release: rename stable asset and feed automation"
```

### Task 2: Rename Nightly And Remote-Daemon Publication Flows

**Files:**
- Modify: `scripts/build_remote_daemon_release_assets.sh`
- Modify: `.github/workflows/nightly.yml`
- Modify: `.github/workflows/release.yml`
- Modify: `tests/test_remote_daemon_release_assets.sh`
- Modify: `tests/test_nightly_universal_build.sh`

- [ ] **Step 1: Inventory nightly and remote-daemon outputs**

Run:
```bash
rg -n 'nightly\\.yml|build_remote_daemon_release_assets|appcast-universal\\.xml|cmuxd-remote|cmux-nightly-macos|manaflow-ai/cmux' \
  scripts/build_remote_daemon_release_assets.sh \
  .github/workflows/nightly.yml \
  .github/workflows/release.yml \
  tests/test_remote_daemon_release_assets.sh \
  tests/test_nightly_universal_build.sh
```
Expected: nightly feed/publication and remote-daemon assets still use `cmux` naming.

- [ ] **Step 2: Rename nightly feeds, notes, and remote-daemon assets**

Update nightly publication, compatibility feed generation, remote-daemon assets, manifests, and download/release-note text so the nightly channel is fully aligned with `Superghost` while preserving required feed compatibility outputs such as `appcast-universal.xml` and any explicitly documented `cmuxd-remote-*` alias publication only where the hardened spec still requires them.

- [ ] **Step 3: Verify nightly and remote-daemon publication**

Run:
```bash
! rg -n 'cmux-nightly-macos|manaflow-ai/cmux' \
  scripts/build_remote_daemon_release_assets.sh \
  .github/workflows/nightly.yml \
  .github/workflows/release.yml
rg -n 'appcast-universal\\.xml|superghostd-remote' \
  scripts/build_remote_daemon_release_assets.sh \
  .github/workflows/nightly.yml \
  .github/workflows/release.yml \
  tests/test_remote_daemon_release_assets.sh \
  tests/test_nightly_universal_build.sh
rg -n 'cmuxd-remote|compatibility alias|alias' \
  scripts/build_remote_daemon_release_assets.sh \
  .github/workflows/nightly.yml \
  .github/workflows/release.yml \
  tests/test_remote_daemon_release_assets.sh \
  tests/test_nightly_universal_build.sh
```
Expected: active nightly publication no longer depends on the old repo or nightly DMG names, `appcast-universal.xml` remains only where the hardened spec requires it, `superghostd-remote` is the primary daemon asset/manifest name, and any remaining `cmuxd-remote` references are explicit compatibility-alias publication rather than the canonical shipped output.

- [ ] **Step 4: Commit**

```bash
git add scripts/build_remote_daemon_release_assets.sh .github/workflows/nightly.yml .github/workflows/release.yml tests/test_remote_daemon_release_assets.sh tests/test_nightly_universal_build.sh
git commit -m "release: rename nightly and remote daemon publication flows"
```

### Task 3: Verify Homebrew Publication And No-Release External Blockers

**Files:**
- Modify: `.github/workflows/update-homebrew.yml`
- Modify: `.github/workflows/release.yml`
- Modify: `tests/test_homebrew_sha.sh`
- Modify: `README.md`

- [ ] **Step 1: Inventory Homebrew publication surfaces**

Run:
```bash
rg -n 'update-homebrew|homebrew-cmux|cmux-macos\\.dmg|manaflow-ai/cmux|brew install --cask cmux' \
  .github/workflows/release.yml \
  .github/workflows/update-homebrew.yml \
  tests/test_homebrew_sha.sh \
  README.md
```
Expected: publication workflow, checksum test, and public install docs still use the old cask/repo/DMG contract.

- [ ] **Step 2: Rename publication flow and define release blockers**

Update the Homebrew publication workflow and checksum verification to the new cask/DMG URL, and add explicit no-release conditions in release/publication automation for missing tap credentials, missing canonical-domain readiness, or missing renamed GitHub assets.

- [ ] **Step 3: Verify Homebrew/publication gating**

Run:
```bash
! rg -n 'homebrew-cmux|cmux-macos\\.dmg|manaflow-ai/cmux|brew install --cask cmux' \
  .github/workflows/release.yml \
  .github/workflows/update-homebrew.yml \
  tests/test_homebrew_sha.sh \
  README.md
rg -n 'no-release|block release|release-blocking|tap credential|canonical domain|renamed GitHub asset' \
  .github/workflows/release.yml \
  .github/workflows/update-homebrew.yml
```
Expected: active Homebrew publication and public install guidance use the renamed contract, and release/publication automation contains explicit no-release gates for missing tap credentials, canonical-domain readiness, and renamed GitHub assets.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml .github/workflows/update-homebrew.yml tests/test_homebrew_sha.sh README.md
git commit -m "release: rename homebrew publication and gating checks"
```

### Task 4: Enforce Historical-Reference Boundaries And Final No-Ship Validation

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `README.md`
- Modify: `docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md`

- [ ] **Step 1: Inventory current/historical reference boundaries**

Run:
```bash
rg -n 'cmux|manaflow-ai/cmux|cmux\\.com' CHANGELOG.md README.md docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
```
Expected: both historical and active references exist and must be separated intentionally.

- [ ] **Step 2: Preserve historical references only where they document past reality**

Keep changelog/history references only where they are clearly archival, and ensure current install/update/runtime instructions point only at the renamed `Superghost` contract.

- [ ] **Step 3: Verify no-ship gates**

Run:
```bash
rg -n 'no-release|block release|release-blocking|historical|archival' \
  docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md \
  CHANGELOG.md \
  README.md
```
Expected: the repo explicitly distinguishes archival references from current release guidance and blocks release if external dependencies are not ready.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md README.md docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
git commit -m "release: enforce no-ship gates and historical boundaries"
```
