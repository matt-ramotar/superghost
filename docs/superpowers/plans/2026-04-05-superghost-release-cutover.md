# Superghost Release Cutover Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a clean-install `Superghost` Release artifact that installs side by side with `cmux`, using app name `Superghost.app`, executable `Superghost`, bundle identifier `sh.bionic.superghost`, a separate runtime state domain, and `superghost`-named release assets.

**Architecture:** Cut over the shipping Release lane in layers. Add artifact-level release identity tests first, then switch the Release app/build metadata, then isolate the Release runtime state from `cmux`, and finally rename the packaging and distribution surfaces that publish the shipped app. Keep the debug/dev lane on `cmux DEV` for this phase so local development stays stable while the shipped product cuts over.

**Tech Stack:** Swift/AppKit, Xcode project metadata, Info.plist localization, shell scripts, GitHub Actions, Homebrew cask automation, shell/Node verification.

---

## File Map

- Create: `cmuxTests/ReleaseIdentityTests.swift`
  Responsibility: focused unit tests for release-only identity constants, fallback feed URLs, and release runtime path derivation.
- Create: `tests/test_release_identity_artifact.sh`
  Responsibility: artifact-level verification of a built Release app bundle (`Superghost.app`, executable name, bundle identifier, bundled `superghost` CLI).
- Create: `tests/test_release_packaging_identity.sh`
  Responsibility: behavior-level verification of release packaging constants exposed to shell tooling.
- Create: `Sources/ReleaseIdentity.swift`
  Responsibility: single Swift source of truth for the clean-install Release product identity and release-only path/feed constants.
- Create: `scripts/release_identity.sh`
  Responsibility: single shell source of truth for release artifact names, bundle ID, executable name, DMG name, and appcast name.
- Delete: `Resources/cmux.sdef`
  Responsibility: retire the old AppleScript dictionary filename from the shipped app bundle.
- Create: `Resources/Superghost.sdef`
  Responsibility: shipped AppleScript dictionary resource branded as `Superghost`.
- Modify: `GhosttyTabs.xcodeproj/project.pbxproj`
  Responsibility: wire new Swift test/source files into targets and switch Release product settings to `Superghost`.
- Modify: `Resources/Info.plist`
  Responsibility: point Release metadata at `Superghost`, the renamed scripting definition, and the renamed release feed.
- Modify: `Resources/InfoPlist.xcstrings`
  Responsibility: rename shipped permission-prompt copy from `cmux` to `Superghost` across supported locales.
- Modify: `Resources/Localizable.xcstrings`
  Responsibility: rename remaining shipped release/update/install strings that still present the app as `cmux`.
- Modify: `Sources/SocketControlSettings.swift`
- Modify: `Sources/GhosttyConfig.swift`
  Responsibility: make the clean-install Release bundle use `sh.bionic.superghost` and `/tmp/superghost*` while leaving debug/dev bundle families alone.
- Modify: `Sources/SessionPersistence.swift`
  Responsibility: move Release persistence identity off `com.cmuxterm.app`.
- Modify: `Sources/GhosttyTerminalView.swift`
  Responsibility: switch release-only bundle and path assumptions away from `cmux`.
- Modify: `Sources/Panels/BrowserPanel.swift`
  Responsibility: keep release-only bundle-prefix normalization aligned with `sh.bionic.superghost`.
- Modify: `Sources/Update/UpdateDelegate.swift`
  Responsibility: use the `Superghost` fallback feed URL and release channel naming.
- Modify: `Sources/TerminalNotificationStore.swift`
  Responsibility: rename notification category identifiers away from `com.cmuxterm.app.*`.
- Modify: `Sources/AppDelegate.swift`
  Responsibility: rename release queue/label identifiers that still leak `com.cmuxterm.app`.
- Modify: `scripts/reloadp.sh`
  Responsibility: build, find, print, and launch `Superghost.app`/`Superghost` in Release mode.
- Modify: `scripts/build-sign-upload.sh`
  Responsibility: sign, notarize, package, and upload `Superghost`-named release assets instead of `cmux` assets.
- Modify: `scripts/release_asset_guard.js`
  Responsibility: guard immutable release assets using the `Superghost` asset family.
- Modify: `scripts/release_asset_guard.test.js`
  Responsibility: verify the release asset guard accepts only the `Superghost` immutable asset set.
- Modify: `scripts/bump-version.sh`
  Responsibility: derive the monotonic build baseline from the renamed `Superghost` stable appcast.
- Modify: `scripts/sparkle_generate_appcast.sh`
  Responsibility: default to `superghost-appcast.xml` and stop emitting `cmux`-specific appcast messaging.
- Modify: `.github/workflows/release.yml`
  Responsibility: build, sign, notarize, and publish `Superghost` release artifacts and feed names.
- Modify: `.github/workflows/update-homebrew.yml`
  Responsibility: publish the renamed Homebrew cask metadata and renamed DMG URL.
- Delete: `homebrew-cmux/Casks/cmux.rb`
  Responsibility: retire the old stable cask file in the Homebrew submodule.
- Create: `homebrew-cmux/Casks/superghost.rb`
  Responsibility: ship the clean-install `superghost` cask in the Homebrew submodule.

### Submodule Safety Note

`homebrew-cmux` is a git submodule. If implementation reaches the cask task, the worker must not create an orphaned submodule commit. The cask change must be committed in `homebrew-cmux` first, pushed to its remote if policy allows, and only then should the parent repo record the updated submodule pointer. If pushing that submodule is not allowed for the execution session, stop and ask the human before doing the cask step.

### Task 1: Add Failing Release Identity Tests

**Files:**
- Create: `cmuxTests/ReleaseIdentityTests.swift`
- Create: `tests/test_release_identity_artifact.sh`
- Modify: `GhosttyTabs.xcodeproj/project.pbxproj`

- [ ] **Step 1: Inventory the current Release identity seams**

Run:
```bash
rg -n 'PRODUCT_NAME = cmux;|PRODUCT_BUNDLE_IDENTIFIER = com\\.cmuxterm\\.app;|cmux\\.app|Contents/MacOS/cmux|com\\.cmuxterm\\.app|SUFeedURL|appcast\\.xml' \
  GhosttyTabs.xcodeproj/project.pbxproj \
  Resources/Info.plist \
  Sources/SocketControlSettings.swift \
  Sources/Update/UpdateDelegate.swift \
  scripts/reloadp.sh \
  scripts/build-sign-upload.sh \
  .github/workflows/release.yml
```
Expected: the active Release lane still hard-codes `cmux`.

- [ ] **Step 2: Write a failing unit test file for release-only identity**

Add `cmuxTests/ReleaseIdentityTests.swift` with assertions that expect:
- `ReleaseIdentity.productName == "Superghost"`
- `ReleaseIdentity.bundleIdentifier == "sh.bionic.superghost"`
- `ReleaseIdentity.executableName == "Superghost"`
- `UpdateFeedResolver.fallbackFeedURL` ends with `/superghost-appcast.xml`
- `SocketControlSettings.defaultSocketPath(bundleIdentifier: "sh.bionic.superghost", isDebugBuild: false, probeStableDefaultPathEntry: { _ in .missing }) == "/tmp/superghost.sock"`

Wire the file into the `cmuxTests` target in `GhosttyTabs.xcodeproj/project.pbxproj`.

- [ ] **Step 3: Run the new unit test to verify it fails**

Run:
```bash
CMUX_SKIP_ZIG_BUILD=1 xcodebuild \
  -project GhosttyTabs.xcodeproj \
  -scheme cmux-unit \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:cmuxTests/ReleaseIdentityTests \
  test
```
Expected: FAIL because `ReleaseIdentity` does not exist yet and/or the old `cmux` constants are still present.

- [ ] **Step 4: Write a failing artifact-level Release bundle test**

Create `tests/test_release_identity_artifact.sh` that accepts `APP_PATH` and fails unless all of these are true:
- bundle basename is `Superghost.app`
- `Contents/MacOS/Superghost` exists and is executable
- `Contents/Resources/bin/superghost` exists and is executable
- `Contents/Resources/bin/cmux` does not exist
- `Info.plist` reports bundle identifier `sh.bionic.superghost`

The script must exit non-zero with clear messages when any assertion is wrong.

- [ ] **Step 5: Run the artifact test against the current Release build and verify it fails**

Run:
```bash
RELOADP_LOG=/tmp/superghost-release-red.log
CMUX_SKIP_ZIG_BUILD=1 ./scripts/reloadp.sh | tee "$RELOADP_LOG"
APP_PATH="$(awk '/^Release app:/{getline; sub(/^  /, ""); print; exit}' "$RELOADP_LOG")"
APP_PATH="$APP_PATH" bash tests/test_release_identity_artifact.sh
```
Expected: FAIL because the current artifact is still `cmux.app` with executable `cmux` and still bundles a `cmux` CLI.

- [ ] **Step 6: Commit the failing tests**

```bash
git add cmuxTests/ReleaseIdentityTests.swift tests/test_release_identity_artifact.sh GhosttyTabs.xcodeproj/project.pbxproj
git commit -m "test: cover superghost release identity"
```

### Task 2: Cut Over The Release App Identity And Shipped Metadata

**Files:**
- Create: `Sources/ReleaseIdentity.swift`
- Delete: `Resources/cmux.sdef`
- Create: `Resources/Superghost.sdef`
- Modify: `GhosttyTabs.xcodeproj/project.pbxproj`
- Modify: `Resources/Info.plist`
- Modify: `Resources/InfoPlist.xcstrings`
- Modify: `scripts/reloadp.sh`

- [ ] **Step 1: Implement the shared Release identity constants**

Create `Sources/ReleaseIdentity.swift` with a focused API for the shipping Release lane:
- product name `Superghost`
- executable name `Superghost`
- bundle identifier `sh.bionic.superghost`
- app support directory name `Superghost`
- cache directory name `Superghost`
- stable socket path `/tmp/superghost.sock`
- user-scoped stable socket path `/tmp/superghost-<uid>.sock`
- stable appcast asset name `superghost-appcast.xml`
- stable DMG asset name `superghost-macos.dmg`

Do not move debug/dev identity into this type in this phase.

- [ ] **Step 2: Switch the Release target to `Superghost`**

In `GhosttyTabs.xcodeproj/project.pbxproj`, change the Release app settings so the built artifact becomes:
- `Superghost.app`
- executable `Superghost`
- bundle identifier `sh.bionic.superghost`
- build-phase output `Contents/Resources/bin/superghost` with no bundled `Contents/Resources/bin/cmux`

Keep Debug on `cmux DEV`.

- [ ] **Step 3: Rename the shipped scripting and Info.plist metadata**

Rename `Resources/cmux.sdef` to `Resources/Superghost.sdef`, update `Resources/Info.plist` `OSAScriptingDefinition`, and change `Resources/InfoPlist.xcstrings` camera/microphone strings from `cmux` to `Superghost`.

- [ ] **Step 4: Make `reloadp.sh` find and launch the renamed Release artifact**

Update `scripts/reloadp.sh` so it:
- finds `*/Build/Products/Release/Superghost.app`
- launches `Contents/MacOS/Superghost`
- still writes the bundled `superghost` shim after build

- [ ] **Step 5: Run the unit and artifact tests to verify they pass**

Run:
```bash
CMUX_SKIP_ZIG_BUILD=1 xcodebuild \
  -project GhosttyTabs.xcodeproj \
  -scheme cmux-unit \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:cmuxTests/ReleaseIdentityTests \
  test

RELOADP_LOG=/tmp/superghost-release-green.log
CMUX_SKIP_ZIG_BUILD=1 ./scripts/reloadp.sh | tee "$RELOADP_LOG"
APP_PATH="$(awk '/^Release app:/{getline; sub(/^  /, ""); print; exit}' "$RELOADP_LOG")"
APP_PATH="$APP_PATH" bash tests/test_release_identity_artifact.sh
```
Expected: both commands PASS, and the artifact test reports `Superghost.app` / `sh.bionic.superghost`.

- [ ] **Step 6: Commit**

```bash
git add Sources/ReleaseIdentity.swift Resources/Superghost.sdef GhosttyTabs.xcodeproj/project.pbxproj Resources/Info.plist Resources/InfoPlist.xcstrings scripts/reloadp.sh
git commit -m "build: cut release app identity to superghost"
```

### Task 3: Isolate Release Runtime State From `cmux`

**Files:**
- Modify: `Sources/ReleaseIdentity.swift`
- Modify: `Sources/SocketControlSettings.swift`
- Modify: `Sources/GhosttyConfig.swift`
- Modify: `Sources/SessionPersistence.swift`
- Modify: `Sources/GhosttyTerminalView.swift`
- Modify: `Sources/Panels/BrowserPanel.swift`
- Modify: `Sources/Update/UpdateDelegate.swift`
- Modify: `Sources/TerminalNotificationStore.swift`
- Modify: `Sources/AppDelegate.swift`
- Modify: `Resources/Localizable.xcstrings`
- Modify: `cmuxTests/ReleaseIdentityTests.swift`
- Modify: `cmuxTests/GhosttyConfigTests.swift`
- Modify: `cmuxTests/SocketControlPasswordStoreTests.swift`

- [ ] **Step 1: Update the release-runtime tests to the `Superghost` contract**

Modify/add tests so they expect the clean-install Release lane to use:
- bundle identifier `sh.bionic.superghost`
- stable socket path `/tmp/superghost.sock`
- user-scoped stable socket path `/tmp/superghost-<uid>.sock`
- password file under `Application Support/Superghost/socket-control-password`
- fallback update feed ending in `/superghost-appcast.xml`

At minimum, update these existing tests:
- `cmuxTests/GhosttyConfigTests.swift`
  - `testStableReleaseIgnoresAmbientSocketOverrideByDefault`
  - `testDefaultSocketPathByChannel`
  - `testStableReleaseFallsBackToUserScopedSocketWhenStablePathOwnedByDifferentUser`
  - `testStableReleaseFallsBackToUserScopedSocketWhenStablePathIsBlockedByNonSocketEntry`
- `cmuxTests/SocketControlPasswordStoreTests.swift`
  - `testDefaultPasswordFileURLUsesCmuxAppSupportPath`

Keep debug/staging expectations on their current `cmux` bundle families for this phase.

- [ ] **Step 2: Run the focused runtime tests to verify they fail**

Run:
```bash
CMUX_SKIP_ZIG_BUILD=1 xcodebuild \
  -project GhosttyTabs.xcodeproj \
  -scheme cmux-unit \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:cmuxTests/ReleaseIdentityTests \
  -only-testing:cmuxTests/GhosttyConfigTests/testStableReleaseIgnoresAmbientSocketOverrideByDefault \
  -only-testing:cmuxTests/GhosttyConfigTests/testDefaultSocketPathByChannel \
  -only-testing:cmuxTests/GhosttyConfigTests/testStableReleaseFallsBackToUserScopedSocketWhenStablePathOwnedByDifferentUser \
  -only-testing:cmuxTests/GhosttyConfigTests/testStableReleaseFallsBackToUserScopedSocketWhenStablePathIsBlockedByNonSocketEntry \
  -only-testing:cmuxTests/SocketControlPasswordStoreTests/testDefaultPasswordFileURLUsesCmuxAppSupportPath \
  test
```
Expected: FAIL because the Release runtime still resolves to `cmux` state.

- [ ] **Step 3: Implement the release-only runtime isolation**

Use `ReleaseIdentity` to move only the clean-install Release lane off `cmux` in the Swift sources:
- `Sources/SocketControlSettings.swift`
- `Sources/GhosttyConfig.swift`
- `Sources/SessionPersistence.swift`
- `Sources/GhosttyTerminalView.swift`
- `Sources/Panels/BrowserPanel.swift`
- `Sources/Update/UpdateDelegate.swift`
- `Sources/TerminalNotificationStore.swift`
- `Sources/AppDelegate.swift`

Update `Resources/Localizable.xcstrings` for shipped release/update/install strings that still say `cmux` where they refer to the product, not a live compatibility command.

- [ ] **Step 4: Re-run the focused runtime tests and the Release artifact test**

Run:
```bash
CMUX_SKIP_ZIG_BUILD=1 xcodebuild \
  -project GhosttyTabs.xcodeproj \
  -scheme cmux-unit \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:cmuxTests/ReleaseIdentityTests \
  -only-testing:cmuxTests/GhosttyConfigTests/testStableReleaseIgnoresAmbientSocketOverrideByDefault \
  -only-testing:cmuxTests/GhosttyConfigTests/testDefaultSocketPathByChannel \
  -only-testing:cmuxTests/GhosttyConfigTests/testStableReleaseFallsBackToUserScopedSocketWhenStablePathOwnedByDifferentUser \
  -only-testing:cmuxTests/GhosttyConfigTests/testStableReleaseFallsBackToUserScopedSocketWhenStablePathIsBlockedByNonSocketEntry \
  -only-testing:cmuxTests/SocketControlPasswordStoreTests/testDefaultPasswordFileURLUsesCmuxAppSupportPath \
  test

RELOADP_LOG=/tmp/superghost-release-runtime.log
CMUX_SKIP_ZIG_BUILD=1 ./scripts/reloadp.sh | tee "$RELOADP_LOG"
APP_PATH="$(awk '/^Release app:/{getline; sub(/^  /, ""); print; exit}' "$RELOADP_LOG")"
APP_PATH="$APP_PATH" bash tests/test_release_identity_artifact.sh
```
Expected: PASS. Release path resolution and update fallback now use the `Superghost` contract while the artifact test still passes.

- [ ] **Step 5: Commit**

```bash
git add Sources/ReleaseIdentity.swift Sources/SocketControlSettings.swift Sources/GhosttyConfig.swift Sources/SessionPersistence.swift Sources/GhosttyTerminalView.swift Sources/Panels/BrowserPanel.swift Sources/Update/UpdateDelegate.swift Sources/TerminalNotificationStore.swift Sources/AppDelegate.swift Resources/Localizable.xcstrings cmuxTests/ReleaseIdentityTests.swift cmuxTests/GhosttyConfigTests.swift cmuxTests/SocketControlPasswordStoreTests.swift
git commit -m "runtime: isolate release superghost state"
```

### Task 4: Rename Release Packaging, Feed, And Homebrew Surfaces

**Files:**
- Create: `scripts/release_identity.sh`
- Create: `tests/test_release_packaging_identity.sh`
- Modify: `scripts/build-sign-upload.sh`
- Modify: `scripts/release_asset_guard.js`
- Modify: `scripts/release_asset_guard.test.js`
- Modify: `scripts/bump-version.sh`
- Modify: `scripts/sparkle_generate_appcast.sh`
- Modify: `.github/workflows/release.yml`
- Modify: `.github/workflows/update-homebrew.yml`
- Delete: `homebrew-cmux/Casks/cmux.rb`
- Create: `homebrew-cmux/Casks/superghost.rb`

- [ ] **Step 1: Add a failing packaging-identity test seam**

Use `scripts/release_identity.sh` as the planned shell source of truth for:
- app name `Superghost.app`
- executable `Superghost`
- bundle identifier `sh.bionic.superghost`
- DMG asset `superghost-macos.dmg`
- appcast asset `superghost-appcast.xml`
- cask name `superghost`

Before implementing the helper, create `tests/test_release_packaging_identity.sh` that sources `scripts/release_identity.sh` and fails unless those exact values are exported.

- [ ] **Step 2: Run the packaging tests to verify they fail**

Run:
```bash
bash tests/test_release_packaging_identity.sh
node scripts/release_asset_guard.test.js
```
Expected: FAIL because the helper does not exist yet and the guard test still expects `cmux` assets.

- [ ] **Step 3: Implement the packaging cutover**

Update the release tooling to consume `scripts/release_identity.sh` and emit only `Superghost` release assets:
- `scripts/build-sign-upload.sh`
- `scripts/release_asset_guard.js`
- `scripts/release_asset_guard.test.js`
- `scripts/bump-version.sh`
- `scripts/sparkle_generate_appcast.sh`
- `.github/workflows/release.yml`
- `.github/workflows/update-homebrew.yml`

Rename the Homebrew cask in the `homebrew-cmux` submodule from `cmux.rb` to `superghost.rb`, and update its installed app/binary/zap paths to `Superghost`.

- [ ] **Step 4: Handle the Homebrew submodule safely**

If the execution session allows pushing the submodule remote:
```bash
git -C homebrew-cmux checkout -b superghost-cask
git -C homebrew-cmux add Casks/superghost.rb Casks/cmux.rb
git -C homebrew-cmux commit -m "Add Superghost cask"
git -C homebrew-cmux push origin HEAD
git add homebrew-cmux
```
If pushing is not allowed, stop here and ask the human before recording the parent pointer update.

- [ ] **Step 5: Re-run the packaging tests**

Run:
```bash
bash tests/test_release_packaging_identity.sh
node scripts/release_asset_guard.test.js
```
Expected: PASS. The helper, guard logic, and release asset family all agree on `Superghost`.

- [ ] **Step 6: Commit**

```bash
git add scripts/release_identity.sh tests/test_release_packaging_identity.sh scripts/build-sign-upload.sh scripts/release_asset_guard.js scripts/release_asset_guard.test.js scripts/bump-version.sh scripts/sparkle_generate_appcast.sh .github/workflows/release.yml .github/workflows/update-homebrew.yml homebrew-cmux
git commit -m "release: rename packaging and cask surfaces to superghost"
```

### Task 5: Final Verification And Handoff

**Files:**
- Verify only; no new files unless a previous task revealed a missing seam.

- [ ] **Step 1: Run the focused unit-test slice**

Run:
```bash
CMUX_SKIP_ZIG_BUILD=1 xcodebuild \
  -project GhosttyTabs.xcodeproj \
  -scheme cmux-unit \
  -configuration Debug \
  -destination 'platform=macOS' \
  -only-testing:cmuxTests/ReleaseIdentityTests \
  -only-testing:cmuxTests/GhosttyConfigTests/testStableReleaseIgnoresAmbientSocketOverrideByDefault \
  -only-testing:cmuxTests/GhosttyConfigTests/testDefaultSocketPathByChannel \
  -only-testing:cmuxTests/GhosttyConfigTests/testStableReleaseFallsBackToUserScopedSocketWhenStablePathOwnedByDifferentUser \
  -only-testing:cmuxTests/GhosttyConfigTests/testStableReleaseFallsBackToUserScopedSocketWhenStablePathIsBlockedByNonSocketEntry \
  -only-testing:cmuxTests/SocketControlPasswordStoreTests/testDefaultPasswordFileURLUsesCmuxAppSupportPath \
  test
```
Expected: PASS.

- [ ] **Step 2: Run the shell/Node packaging checks**

Run:
```bash
bash tests/test_release_packaging_identity.sh
node scripts/release_asset_guard.test.js
```
Expected: PASS.

- [ ] **Step 3: Build and launch the Release app**

Run:
```bash
RELOADP_LOG=/tmp/superghost-release-final.log
CMUX_SKIP_ZIG_BUILD=1 ./scripts/reloadp.sh | tee "$RELOADP_LOG"
```
Expected: `** BUILD SUCCEEDED **`, a printed `Release app:` path ending in `Superghost.app`, and `Release launch status:` pointing at `Contents/MacOS/Superghost`.

- [ ] **Step 4: Verify the built artifact and bundled CLI**

Run:
```bash
APP_PATH="$(awk '/^Release app:/{getline; sub(/^  /, ""); print; exit}' "$RELOADP_LOG")"
APP_PATH="$APP_PATH" bash tests/test_release_identity_artifact.sh
"$APP_PATH/Contents/Resources/bin/superghost" boo --help
```
Expected: the artifact test PASSes and the bundled CLI prints `Usage: superghost boo`.

- [ ] **Step 5: Confirm the tree is in the expected final state**

Run:
```bash
git status --short
```
Expected: only the intended implementation changes remain; no surprise build byproducts are left checked in. If `homebrew-cmux` could not be pushed, stop and surface that blocker instead of claiming the plan complete.
