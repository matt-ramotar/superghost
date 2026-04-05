# Superghost Identity And Build Cutover Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the build graph so SwiftPM, Xcode, schemes, test bundles, and channel-specific app identities all emit `Superghost` or `superghost` instead of `cmux`.

**Architecture:** Execute from the build graph outward. Rename SwiftPM package/product/target names first, then native Xcode target and scheme wiring, then test-host linkage, then channel-specific product/bundle/socket naming in reload helpers, and finally CI selectors that still hardcode `cmux` artifact or process names.

**Tech Stack:** SwiftPM, Xcode project metadata, shared schemes, shell scripts, GitHub Actions, markdown verification plans.

## File Map

- Modify: `Package.swift`
  Responsibility: rename the root SwiftPM package/product/target and any generated executable name assumptions.
- Modify: `scripts/rebuild.sh`
  Responsibility: rename SwiftPM debug-app wrapper assumptions that still expect `.build/debug/cmux` and `cmux.app`.
- Modify: `GhosttyTabs.xcodeproj/project.pbxproj`
  Responsibility: rename native app, CLI, and test targets, products, bundle IDs, product names, and test-host wiring.
- Modify: `Resources/Info.plist`
  Responsibility: rename Info.plist display names, feed metadata, and other build-graph metadata that still ship the old identity.
- Modify: `GhosttyTabs.xcodeproj/xcshareddata/xcschemes/cmux.xcscheme`
  Responsibility: rename the primary scheme or replace it with the `Superghost` successor while preserving intended build/test behavior.
- Modify: `GhosttyTabs.xcodeproj/xcshareddata/xcschemes/cmux-ci.xcscheme`
  Responsibility: keep CI build/test behavior aligned with the renamed scheme and test bundles.
- Modify: `GhosttyTabs.xcodeproj/xcshareddata/xcschemes/cmux-unit.xcscheme`
  Responsibility: keep unit-test scheme naming and buildable references aligned with renamed targets.
- Modify: `cmuxTests/**/*.swift`
  Responsibility: rename unit-test module imports and source-level references to renamed targets/products.
- Modify: `cmuxUITests/**/*.swift`
  Responsibility: rename UI-test module imports and source-level references to renamed targets/products.
- Modify: `scripts/reload.sh`
  Responsibility: implement tagged DEV identity changes for app name, bundle ID, derived data layout, process name, and socket/debug-log markers.
- Modify: `scripts/reloadp.sh`
  Responsibility: rename release-app lookup and launch assumptions that still expect `cmux` scheme, app, or binary names.
- Modify: `scripts/reload2.sh`
  Responsibility: keep the combined debug/release reload helper aligned with renamed build outputs and app identities.
- Modify: `scripts/reloads.sh`
  Responsibility: implement staging identity changes and any tagged staging naming.
- Modify: `scripts/launch-tagged-automation.sh`
  Responsibility: keep automation launch paths aligned with tagged DEV identity changes.
- Modify: `.github/workflows/nightly.yml`
  Responsibility: rename nightly app identity, bundle ID, plist mutation, workflow artifact labels, and release-note channel naming so Nightly is owned by the same channel matrix as DEV and STAGING.
- Modify: `.github/workflows/ci.yml`
  Responsibility: update scheme names, test selectors, artifact discovery, and process-name lookups.
- Modify: `.github/workflows/ci-macos-compat.yml`
  Responsibility: update scheme names and test selectors in the compatibility lane.
- Modify: `.github/workflows/test-depot.yml`
  Responsibility: update scheme names and UI-test selectors for depot coverage.
- Modify: `.github/workflows/test-e2e.yml`
  Responsibility: update scheme names and UI-test selectors for end-to-end coverage.
- Modify: `scripts/test-unit.sh`
  Responsibility: update local unit-test scheme selection.
- Modify: `tests/test_ci_scheme_testaction_debug.sh`
  Responsibility: keep scheme validation aligned with the renamed shared scheme file.
- Modify: `tests/test_bundled_ghostty_theme_picker_helper.sh`
  Responsibility: rename derived build-product assumptions in shell-based validation scripts that still hardcode the old scheme or app name.
- Modify: `scripts/smoke-test-ci.sh`
  Responsibility: rename smoke-test build-product, process-name, and socket assumptions used by local and CI validation.

### Task 1: Rename SwiftPM Package, Product, And Target Surfaces

**Files:**
- Modify: `Package.swift`
- Modify: `scripts/rebuild.sh`

- [ ] **Step 1: Inventory current SwiftPM `cmux` surfaces**

Run:
```bash
rg -n 'name: "cmux"|executable\\(name: "cmux"|executableTarget\\(|\\.build/debug/cmux|cmux\\.app' Package.swift scripts/rebuild.sh
```
Expected: the package, executable product, executable target, and SwiftPM wrapper assumptions still use `cmux`.

- [ ] **Step 2: Rename the SwiftPM package, executable product, and executable target to `superghost`**

This step must leave the root package buildable through `swift build` without producing a `.build/**/cmux` executable or a wrapper script that still expects `cmux.app`.

- [ ] **Step 3: Verify SwiftPM emits only the renamed executable**

Run:
```bash
swift build
! rg -n 'name: "cmux"|executable\\(name: "cmux"|\\.build/debug/cmux|cmux\\.app' Package.swift scripts/rebuild.sh
test -x .build/debug/superghost
test ! -e .build/debug/cmux
```
Expected: `swift build` succeeds, no `cmux` package/product or wrapper assumption remains in `Package.swift` or `scripts/rebuild.sh`, `superghost` exists, and `cmux` does not.

- [ ] **Step 4: Commit**

```bash
git add Package.swift scripts/rebuild.sh
git commit -m "build: rename SwiftPM cmux executable to superghost"
```

### Task 2: Rename Xcode Targets, Schemes, And Test Host Wiring

**Files:**
- Modify: `GhosttyTabs.xcodeproj/project.pbxproj`
- Modify: `Resources/Info.plist`
- Modify: `GhosttyTabs.xcodeproj/xcshareddata/xcschemes/cmux.xcscheme`
- Modify: `GhosttyTabs.xcodeproj/xcshareddata/xcschemes/cmux-ci.xcscheme`
- Modify: `GhosttyTabs.xcodeproj/xcshareddata/xcschemes/cmux-unit.xcscheme`
- Modify: `cmuxTests/**/*.swift`
- Modify: `cmuxUITests/**/*.swift`

- [ ] **Step 1: Inventory current Xcode target and scheme identities**

Run:
```bash
rg -n 'cmux-cli|cmuxTests|cmuxUITests|cmux-unit|cmux-ci|TEST_HOST|BUNDLE_LOADER|cmux DEV|cmux.app' \
  GhosttyTabs.xcodeproj/project.pbxproj \
  Resources/Info.plist \
  GhosttyTabs.xcodeproj/xcshareddata/xcschemes/cmux.xcscheme \
  GhosttyTabs.xcodeproj/xcshareddata/xcschemes/cmux-ci.xcscheme \
  GhosttyTabs.xcodeproj/xcshareddata/xcschemes/cmux-unit.xcscheme
rg -n '^(@testable )?import (cmux|cmux_DEV)$' cmuxTests cmuxUITests
```
Expected: native CLI/test target names, test bundles, schemes, `TEST_HOST`, `BUNDLE_LOADER`, and test-source imports still point at `cmux`.

- [ ] **Step 2: Rename primary app, CLI, test targets, shared schemes, and test-source imports**

Rename the app/CLI/test bundle outputs, Info.plist display names and feed metadata, shared schemes, and unit/UI test module imports to the `Superghost` successors while preserving Debug/TestAction behavior and bundle-prefix expectations under `sh.bionic.superghost`.

- [ ] **Step 3: Update `TEST_HOST` and `BUNDLE_LOADER`**

Change unit/UI test host wiring so Debug and Release test bundles point at the renamed app binary rather than `cmux` or `cmux DEV`.

- [ ] **Step 4: Verify the project graph is consistent**

Run:
```bash
! rg -n 'cmux-cli|cmuxTests|cmuxUITests|cmux-unit|cmux-ci|TEST_HOST = "\\$\\(BUILT_PRODUCTS_DIR\\)/cmux' \
  GhosttyTabs.xcodeproj/project.pbxproj \
  Resources/Info.plist \
  GhosttyTabs.xcodeproj/xcshareddata/xcschemes
! rg -n '^(@testable )?import (cmux|cmux_DEV)$' cmuxTests cmuxUITests
rg -n 'BUNDLE_LOADER = "\\$\\(TEST_HOST\\)"' GhosttyTabs.xcodeproj/project.pbxproj
```
Expected: old CLI/test/scheme/test-host names and test-source imports are removed from the active Xcode build graph, and `BUNDLE_LOADER` still resolves through `$(TEST_HOST)` after the rename.

- [ ] **Step 5: Commit**

```bash
git add GhosttyTabs.xcodeproj/project.pbxproj Resources/Info.plist GhosttyTabs.xcodeproj/xcshareddata/xcschemes cmuxTests cmuxUITests
git commit -m "build: rename Xcode targets schemes and test hosts"
```

### Task 3: Implement The Tagged DEV, Staging, And Nightly Identity Matrix

**Files:**
- Modify: `scripts/reload.sh`
- Modify: `scripts/reloadp.sh`
- Modify: `scripts/reload2.sh`
- Modify: `scripts/reloads.sh`
- Modify: `scripts/launch-tagged-automation.sh`
- Modify: `.github/workflows/nightly.yml`

- [ ] **Step 1: Inventory current tagged DEV and staging identities**

Run:
```bash
rg -n 'cmux DEV|cmux STAGING|com\\.cmuxterm\\.app|cmux-debug|cmux-staging|sanitize_bundle|sanitize_path|CMUX_TAG' \
  scripts/reload.sh scripts/reloadp.sh scripts/reload2.sh scripts/reloads.sh scripts/launch-tagged-automation.sh .github/workflows/nightly.yml
```
Expected: app names, bundle IDs, socket names, and sanitization helpers still use `cmux`.

- [ ] **Step 2: Apply the `Superghost` channel identity matrix**

Implement the renamed app names, bundle IDs, executable names, plist mutation targets, release-app lookup behavior, workflow artifact labels, release-note channel labels, and socket/debug-log marker names for Debug, tagged DEV, Staging, tagged STAGING, Nightly, and release reload surfaces documented in the hardened spec.

- [ ] **Step 3: Verify channel naming is internally consistent**

Run:
```bash
rg -n 'Superghost DEV|Superghost STAGING|Superghost NIGHTLY|superghost-debug|superghost-staging|superghost-nightly|sh\\.bionic\\.superghost' \
  scripts/reload.sh scripts/reloadp.sh scripts/reload2.sh scripts/reloads.sh scripts/launch-tagged-automation.sh .github/workflows/nightly.yml
rg -n 'cmux DEV|cmux STAGING|com\\.cmuxterm\\.app\\.debug|com\\.cmuxterm\\.app\\.staging' \
  scripts/reload.sh scripts/reloadp.sh scripts/reload2.sh scripts/reloads.sh scripts/launch-tagged-automation.sh .github/workflows/nightly.yml
```
Expected: renamed identities are present and old `cmux` channel identities are removed from supported launch flows.

- [ ] **Step 4: Commit**

```bash
git add scripts/reload.sh scripts/reloadp.sh scripts/reload2.sh scripts/reloads.sh scripts/launch-tagged-automation.sh .github/workflows/nightly.yml
git commit -m "build: rename tagged staging and nightly app identities"
```

### Task 4: Update CI Selectors, Validation Scripts, And Artifact Discovery

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `.github/workflows/ci-macos-compat.yml`
- Modify: `.github/workflows/test-depot.yml`
- Modify: `.github/workflows/test-e2e.yml`
- Modify: `scripts/test-unit.sh`
- Modify: `scripts/smoke-test-ci.sh`
- Modify: `tests/test_ci_scheme_testaction_debug.sh`
- Modify: `tests/test_bundled_ghostty_theme_picker_helper.sh`

- [ ] **Step 1: Inventory CI selectors that still hardcode `cmux`**

Run:
```bash
rg -n 'cmux-unit|cmuxTests|cmuxUITests|cmux DEV|cmux\\.xcscheme|Build/Products/Debug/cmux|pkill -x "cmux DEV"|MacOS/cmux DEV' \
  .github/workflows/ci.yml \
  .github/workflows/ci-macos-compat.yml \
  .github/workflows/test-depot.yml \
  .github/workflows/test-e2e.yml \
  scripts/test-unit.sh \
  scripts/smoke-test-ci.sh \
  tests/test_ci_scheme_testaction_debug.sh \
  tests/test_bundled_ghostty_theme_picker_helper.sh
```
Expected: schemes, selectors, artifact discovery, and process-name lookups still point at `cmux`.

- [ ] **Step 2: Rename schemes, test selectors, artifact lookups, and process names**

Update `-only-testing`, `-skip-testing`, scheme references, shared-scheme validation, DerivedData artifact discovery, kill/start commands, smoke-test helpers, and shell-based build-product validation scripts so CI and repo validation track the renamed outputs instead of `cmux`.

- [ ] **Step 3: Verify CI selectors are aligned with the renamed graph**

Run:
```bash
rg -n 'cmux-unit|cmuxTests|cmuxUITests|cmux DEV|cmux\\.xcscheme|Build/Products/Debug/cmux|MacOS/cmux DEV' \
  .github/workflows/ci.yml \
  .github/workflows/ci-macos-compat.yml \
  .github/workflows/test-depot.yml \
  .github/workflows/test-e2e.yml \
  scripts/test-unit.sh \
  scripts/smoke-test-ci.sh \
  tests/test_ci_scheme_testaction_debug.sh \
  tests/test_bundled_ghostty_theme_picker_helper.sh
```
Expected: active CI selectors no longer point at `cmux` build outputs or test bundles.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml .github/workflows/ci-macos-compat.yml .github/workflows/test-depot.yml .github/workflows/test-e2e.yml scripts/test-unit.sh scripts/smoke-test-ci.sh tests/test_ci_scheme_testaction_debug.sh tests/test_bundled_ghostty_theme_picker_helper.sh
git commit -m "ci: rename build and test selectors for superghost"
```
