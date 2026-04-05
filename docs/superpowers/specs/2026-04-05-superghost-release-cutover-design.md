# Superghost Release Cutover Design

## Summary

This design defines a shipping-identity cutover for the Release lane from `cmux` to `Superghost`.
The goal is a clean-install `Superghost` release that can live side by side with an existing `cmux` install on the same machine.

The cutover applies to the Release app artifact, Release runtime identity, and release/distribution tooling that produces and publishes the shipped product.
Debug and dev workflows remain on the current `cmux DEV` lane for now to avoid mixing a product cutover with a full local-tooling rewrite.

## Approved Decisions

- Canonical shipped product name: `Superghost`
- Canonical clean-install Release bundle identifier: `sh.bionic.superghost`
- Release cutover policy: full shipped identity cutover, not just UI veneer
- Install policy: `Superghost` installs cleanly and separately from `cmux`
- Coexistence policy: `cmux` and `Superghost` must be able to live side by side without sharing runtime state
- Migration policy: no first-launch migration or upgrade-in-place behavior from `cmux`
- Scope policy: Release/product/distribution surfaces move now; debug/dev `cmux DEV` surfaces stay in place for this phase

## Goals

1. Ship `Superghost.app` instead of `cmux.app`.
2. Give the shipped app its own macOS install identity via `sh.bionic.superghost`.
3. Ensure the shipped Release artifact no longer presents `cmux` as its app name, executable name, bundle ID, packaged CLI name, or release asset family.
4. Keep existing `cmux` installs untouched and non-interfering.
5. Preserve a practical development lane by leaving debug/dev naming alone for now.

## Non-Goals

- Renaming the entire repo, target graph, module names, or test bundle names in one pass
- Reworking tagged debug/dev workflows away from `cmux DEV`
- Migrating `cmux` user defaults, app support, caches, sockets, or updater state into `Superghost`
- Preserving updater continuity from `cmux` to `Superghost`
- Adding release-time compatibility aliases such as a shipped `cmux` wrapper inside `Superghost.app`

## Scope

### Included

- Release `PRODUCT_NAME`, executable name, bundle identifier, and built app bundle name
- Release Info.plist metadata and user-facing shipped strings that derive from Release product identity
- Release-only runtime state derived from bundle/app identity
- Release app packaging names, DMG name, appcast/feed naming, and upload asset naming
- Release Homebrew cask/public install surfaces for the shipped app
- Release AppleScript dictionary branding and similar shipped metadata surfaces
- Release scripts that build, package, sign, notarize, and publish the shipped app

### Excluded

- Debug `PRODUCT_NAME = "cmux DEV"` and tagged debug naming
- Existing tagged reload workflows and dev socket/debug-log discovery markers
- Internal Swift target/module names where they do not leak into the shipped Release artifact
- Broad source-level rename of every internal `cmux` symbol in this phase

## Canonical Release Identity

### App And Bundle

- App name: `Superghost.app`
- Executable name: `Superghost`
- Bundle identifier: `sh.bionic.superghost`
- Release display name: `Superghost`
- Release service-menu copy and Info.plist-derived app naming use `Superghost`

### Release Runtime State

These paths must not collide with `cmux` paths.

- Application Support: `~/Library/Application Support/Superghost`
- Caches: `~/Library/Caches/Superghost`
- Preferences domain / plist family: `sh.bionic.superghost`
- Default stable socket family: `/tmp/superghost*`
- Release bundled CLI command: `superghost`

### Release Distribution Surfaces

- Stable DMG asset: `superghost-macos.dmg`
- Stable appcast/feed asset: `superghost-appcast.xml`
- Stable Homebrew cask name: `superghost`
- Stable installed app reference in packaging/cask metadata: `Superghost.app`
- Stable packaged binary reference in packaging/cask metadata: `superghost`

## Side-By-Side Install Contract

`cmux` and `Superghost` must not share the following:

- bundle identifier
- app support directory
- caches directory
- defaults domain / preferences plist
- socket path family
- update feed identity
- release asset names
- installed CLI path inside the app bundle

No `Superghost` first-launch step should read, rewrite, import, or delete `cmux` state.
No release script should overwrite `cmux` release assets or reuse `cmux` artifact names as aliases.

## Build Graph Strategy

This phase intentionally separates shipping identity from internal project churn.

### Release Lane Changes

- Release build settings move from `cmux` to `Superghost`
- Release bundle identifier moves from `com.cmuxterm.app` to `sh.bionic.superghost`
- Release app/executable paths in scripts must point to `Superghost.app` and `Contents/MacOS/Superghost`
- Release bundle-local helper generation must target the shipped `superghost` CLI rather than `cmux`

### Debug Lane Stability

- Debug remains `cmux DEV`
- Tagged debug builds remain `cmux DEV <tag>`
- Existing debug-only discovery files and local convenience shims remain unchanged in this phase

This keeps the shipping cutover bounded while preserving a known-good local development contract.

## Release Surface Inventory

The following release surfaces must be updated together so the shipping lane stays internally consistent:

- `GhosttyTabs.xcodeproj/project.pbxproj` Release `PRODUCT_NAME`, Release bundle identifier, and any Release-only executable/app assumptions
- `Resources/Info.plist` and shipped metadata that derive from Release product identity
- `Resources/cmux.sdef` and any other shipped dictionary/metadata files that still present the app as `cmux`
- `scripts/reloadp.sh`
- `scripts/build-sign-upload.sh`
- any Release-only notarization, DMG creation, appcast generation, upload, or Homebrew publication logic
- any release asset guard logic that hard-codes `cmux-macos.dmg`, `appcast.xml`, or `cmux.app`

## Implementation Sequence

1. Add failing artifact-level tests for the Release identity.
   These tests should inspect the built Release bundle and verify the shipped app name, executable name, bundle identifier, and bundled CLI surfaces.
2. Switch Release build settings and shipped bundle metadata.
   This establishes `Superghost.app`, executable `Superghost`, and bundle identifier `sh.bionic.superghost`.
3. Switch Release runtime state and packaged CLI surfaces.
   The shipped app bundle and runtime domains move to `Superghost` names without touching debug/dev paths.
4. Switch release packaging and distribution names.
   DMG, appcast, upload, notarization, and Homebrew/update references move to `superghost`.
5. Build and inspect a real Release artifact.
   Completion is based on the produced artifact, not on project-file text alone.

## Verification Criteria

### Artifact Verification

After the change, a Release build must produce a bundle whose observable identity is:

- app bundle name `Superghost.app`
- executable `Contents/MacOS/Superghost`
- bundle identifier `sh.bionic.superghost`
- bundled CLI at `Contents/Resources/bin/superghost`

The resulting Release artifact must not require `cmux` as its visible shipped app name or bundled CLI entrypoint.

### Isolation Verification

The shipped Release app must use `Superghost` runtime domains rather than `cmux` domains for:

- app support
- cache paths
- defaults / preferences domain
- socket path family

### Packaging Verification

The release pipeline must emit `Superghost`-named assets and must not reuse `cmux` asset names for the new shipped product.

### Clean-Install Verification

The implementation must not add migration code, compatibility aliases, or side effects that mutate an existing `cmux` install.

## Risks

- Release scripts currently hard-code `cmux.app`, `cmux-macos.dmg`, and `cmux` binary paths; partial edits will break signing, notarization, or upload.
- Some shipped metadata surfaces are easy to miss because they are not Swift source, such as AppleScript dictionaries and cask metadata.
- Leaving debug/dev as `cmux DEV` while Release becomes `Superghost` is intentional, but it increases the chance of accidental cross-lane assumptions in scripts if Release and Debug path logic are not separated carefully.
- The known `macOS 26.x + zig 0.15.2` Ghostty helper build issue can still block Release packaging unless the existing skip/stub workaround is handled consistently in the Release lane.

## Follow-On Work

After the shipping cutover is stable, a later phase can rename the remaining internal/development surfaces:

- debug/dev app names
- internal target and scheme names
- repo-wide `cmux` source identifiers
- test target/module naming
- local convenience scripts and historical automation names
