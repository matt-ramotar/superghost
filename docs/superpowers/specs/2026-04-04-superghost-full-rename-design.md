# Superghost Full Rename Design

## Summary

This design defines a clean-break, end-to-end rename from `cmux` to `Superghost`.
The rename covers app identity, CLI/runtime identifiers, release assets, distribution surfaces, website/docs references, and supporting automation.

The goal is a repo and shipped product that no longer present or require `cmux` identifiers in normal operation.
No compatibility aliases or upgrade-in-place behavior are retained.

## Approved Decisions

- Canonical product brand: `Superghost`
- Canonical CLI command: `superghost`
- Canonical source repository: `matt-ramotar/superghost`
- Canonical website/docs domain: `https://superghost.bionic.sh`
- Compatibility policy: no shipped `cmux` aliases, env vars, sockets, or update paths
- Upgrade policy: clean break is acceptable; existing `cmux` installs do not need to update in place
- Delivery approach: structured cutover across a few tightly sequenced workstreams, with release held until all workstreams are complete

## Goals

1. Ship a product whose primary names, commands, and distribution surfaces are consistently `Superghost` or `superghost`.
2. Remove `cmux` from shipped runtime behavior, public install instructions, release packaging, and automation contracts.
3. Make `matt-ramotar/superghost` and `https://superghost.bionic.sh` the canonical public endpoints for code, docs, and downloads.

## Non-Goals

- Preserving updater continuity from existing `cmux` installations
- Shipping a temporary `cmux` compatibility layer
- Keeping old socket paths, env vars, or daemon names for one more release
- Limiting the rename to English marketing copy only

## Canonical Naming Matrix

### Product And App

- Product brand: `Superghost`
- Release app name: `Superghost.app`
- Debug app name: `Superghost DEV.app`
- Staging app name: `Superghost STAGING.app`
- Nightly app name: `Superghost NIGHTLY.app` where nightly-specific naming exists

### CLI And Runtime

- Primary CLI command: `superghost`
- Primary daemon family: `superghostd`
- Remote daemon binary family: `superghostd-remote`
- Environment variable prefix: `SUPERGHOST_`
- Default socket path family: `/tmp/superghost*`
- Application support directory family: `~/Library/Application Support/Superghost`
- Cache directory family: `~/Library/Caches/Superghost`

### Public Distribution

- Repo URLs: `https://github.com/matt-ramotar/superghost`
- Docs and website base URL: `https://superghost.bionic.sh`
- Stable macOS DMG asset: `superghost-macos.dmg`
- Nightly macOS DMG asset: `superghost-nightly-macos.dmg`
- Homebrew cask name: `superghost`
- Homebrew tap/repo naming should also move to `superghost` naming where a dedicated tap is still required

### Bundle Identity

Use `sh.bionic.superghost` as the canonical reverse-domain bundle prefix for app and test targets.

- Release app bundle ID: `sh.bionic.superghost.app`
- Debug app bundle ID: `sh.bionic.superghost.app.debug`
- UI test and unit test bundle IDs should move under the same prefix

### Build Graph Surfaces

- Root SwiftPM package, product, and target names in `Package.swift`; `SwiftPM` must stop emitting a `cmux` package/product/target.
- Xcode native target names, product names, and built app names in `GhosttyTabs.xcodeproj/project.pbxproj`.
- Shared scheme names such as `cmux`, `cmux-ci`, and `cmux-unit`, plus any renamed successors and their buildable references.
- Unit/UI test target names such as `cmuxTests` and `cmuxUITests`, including module imports, buildable references, and `TEST_HOST` / `BUNDLE_LOADER`.
- Workflow and script selectors that call schemes, `-only-testing`, or `-skip-testing` by name, including CI selectors, scheme-validation scripts, and artifact/process-name lookups used by local and CI test helpers.

### Channel Identity Matrix

| Channel | App Name | Bundle ID | Executable Name | Socket Path Family | Notes |
| --- | --- | --- | --- | --- | --- |
| Stable | Superghost.app | sh.bionic.superghost.app | superghost | /tmp/superghost.sock with /tmp/superghost-<uid>.sock fallback | shipped release; Workstream 2 must explicitly reconcile the current Application Support-backed stable socket contract with this clean-break target |
| Debug | Superghost DEV.app | sh.bionic.superghost.app.debug | superghost | /tmp/superghost-debug.sock | local only |
| Tagged DEV | Superghost DEV <tag>.app | sh.bionic.superghost.app.debug.<sanitized-tag> | superghost | /tmp/superghost-debug-<sanitized-tag>.sock | required for parallel local builds |
| Staging | Superghost STAGING.app | sh.bionic.superghost.app.staging | superghost | /tmp/superghost-staging.sock | isolated from stable |
| Tagged STAGING | Superghost STAGING <tag>.app | sh.bionic.superghost.app.staging.<sanitized-tag> | superghost | /tmp/superghost-staging-<sanitized-tag>.sock | optional parallel staging builds |
| Nightly | Superghost NIGHTLY.app | sh.bionic.superghost.app.nightly | superghost | /tmp/superghost-nightly.sock | isolated update channel |

`<sanitized-tag>` means: lowercase, replace `.` and `_` with `-`, strip non-alphanumeric characters except `-`, collapse repeated separators, and trim leading/trailing `-`.

When `<sanitized-tag>` is rendered into bundle-ID suffixes, the same normalized tag components should be serialized with `.` separators; when it is rendered into socket/path slugs, keep `-` separators. The matrix uses one canonical normalization rule while still calling out the current helper split between `sanitize_bundle` and `sanitize_path`.

tagged DEV, tagged staging, and nightly channel behavior must be documented in the same build-contract source of truth that currently drives `scripts/reload.sh`, `scripts/reloads.sh`, and automation launch helpers.

## Scope

### Workstream 1: Identity And Build Foundation

This workstream renames the product and build graph so generated build artifacts and target metadata all align with `Superghost`.

It includes:

- Xcode product names and product references
- Bundle identifiers
- Scheme names and buildable references
- App/test host paths
- Info.plist display names and metadata
- Derived build product assumptions in repo scripts
- Debug/staging/nightly naming surfaces that currently derive from `cmux`

### Workstream 2: Runtime Contract Rename

This workstream renames the executable and automation contract so runtime behavior no longer depends on `cmux` names.

It includes:

- CLI binary names and install paths
- Shell integration wrappers and helper scripts
- Socket paths and socket discovery logic
- Environment variable names
- Support-directory and cache-directory paths
- Remote daemon names, manifests, release assets, and upload/download paths
- Test harness defaults and automation bootstrap scripts

### Workstream 3: Distribution And Public Surface Cutover

This workstream renames public endpoints and packaging so all user-facing install, update, and discovery paths point at `Superghost`.

It includes:

- GitHub release asset names and release workflow behavior
- Sparkle feed URLs and update metadata
- Website and docs base URLs
- Download links, nightly links, issue links, and repo links
- Homebrew cask/tap naming and install instructions
- README, site metadata, SEO, blog/docs examples, and localized docs strings where runtime identifiers appear

## Architecture And Migration Order

The rename should be executed as a structured cutover with one authoritative subsystem at a time.

1. **Identity source of truth first**
   - Update Xcode project settings, plist metadata, bundle IDs, scheme/build-product names, and release packaging expectations so the build graph produces `Superghost` artifacts.
2. **Runtime contract second**
   - Update CLI names, daemon names, env vars, socket paths, support directories, wrappers, and automation scripts so all runtime behavior agrees with the new identity.
3. **Distribution and docs third**
   - Update release asset names, update feeds, website/docs URLs, Homebrew naming, and public instructions after the build and runtime contracts are stable.
4. **Release gating**
   - Do not cut an official release until all three workstreams are complete.

This sequencing avoids a partially renamed state where docs or release tooling point at identifiers that the build no longer emits, or runtime paths diverge from published instructions.

## Detailed Rename Rules

### Remove `cmux` From Shipped Behavior

After the rename lands:

- Users launch `Superghost.app`
- Users run `superghost`
- Runtime env vars use `SUPERGHOST_*`
- Socket paths use `/tmp/superghost*`
- Shipped daemon binaries use `superghostd*`
- Public release downloads use `superghost*` asset names

### No Compatibility Parsing

The app, CLI, daemon, scripts, tests, and docs should not preserve parsing or fallback logic for old identifiers such as:

- `cmux`
- `cmuxd`
- `cmuxd-remote`
- `CMUX_*`
- `/tmp/cmux*`
- `~/Library/Application Support/cmux`
- `cmux-macos.dmg`
- `https://github.com/manaflow-ai/cmux`
- `https://cmux.com`

### External Surface Rule

All canonical public references should move to the new repo/domain:

- Repo/discussions/issues/downloads point at `matt-ramotar/superghost`
- Website/docs/SEO metadata point at `https://superghost.bionic.sh`
- Install snippets teach `superghost`, not `cmux`

### Localized Content Rule

This rename is not limited to English strings.
Any localized string that teaches a live command, env var, socket path, repo URL, download URL, or product/runtime identifier must be updated to the new `Superghost` contract.

## Key Files And Systems Affected

At minimum, the implementation should expect to touch the following system groups:

- Xcode project and schemes under `GhosttyTabs.xcodeproj`
- `Resources/Info.plist`, localized plist strings, and app-facing localization catalogs
- Build/reload/release scripts under `scripts/`
- GitHub Actions under `.github/workflows/`
- Homebrew tap/cask files under `homebrew-cmux/` or its renamed successor
- Website/docs under `web/`, `README.md`, and related metadata/config files
- Python test harnesses in `tests/` and `tests_v2/`
- Remote daemon code under `daemon/remote/`

## Risks

### Build Graph Risk

Xcode schemes, product references, and test-host settings currently assume `cmux.app` and `cmux DEV.app`.
Renaming product names without updating those references can leave tests and scripts pointing at missing artifacts.

### Release Pipeline Risk

The release pipeline currently publishes `cmux-macos.dmg`, `appcast.xml`, and `cmuxd-remote-*` assets, and current update metadata points at legacy release endpoints.
These changes must be coordinated with the release workflow so a built app never publishes dead update/download paths.

### Runtime Contract Risk

Socket paths and env vars are deeply embedded in code, tests, shell scripts, and docs.
Because compatibility is intentionally removed, a partial rename would break automation immediately.

### Distribution Risk

Homebrew, docs, SEO metadata, nightly pages, and issue/discussion links currently point at the old ecosystem.
Missing even a single canonical link leaves a broken user path after release.

### External Dependency Risk

The code repo is already `matt-ramotar/superghost`, but website hosting, Homebrew naming, and any release-consumer expectations outside this repo must be updated before shipping.
Implementation should treat those as release-blocking dependencies where applicable.

## Verification Criteria

### Build Verification

- Release, Debug, and auxiliary app builds produce `Superghost`-named artifacts and test hosts
- Bundle IDs use the `sh.bionic.superghost` prefix
- Scripts that locate built apps no longer assume `cmux` names
- `swift build` no longer emits a `cmux` package/product/target
- Shared schemes, test targets, `TEST_HOST`, and `BUNDLE_LOADER` paths no longer point at `cmux`
- Tagged DEV, staging, and nightly builds have documented app-name, bundle-ID, and socket-path conventions

### Runtime Verification

- The shipped CLI path and executable name are `superghost`
- The default socket and support-directory paths are `superghost` paths
- Environment-variable contracts use `SUPERGHOST_*`
- Remote daemon artifacts and manifests use `superghostd-remote` naming

### Distribution Verification

- Stable and nightly release asset names use `superghost` naming
- Sparkle or equivalent update metadata points only at the new repo/domain
- Website/download/docs/install surfaces reference `matt-ramotar/superghost` and `https://superghost.bionic.sh`
- Homebrew install instructions and cask naming use `superghost`

### Boundary Verification

- No shipped path requires a user to invoke `cmux`
- No release or doc surface points at `manaflow-ai/cmux` or `cmux.com`
- No compatibility alias remains in normal runtime behavior

## Release Policy

- The rename ships as a clean-break release, not an in-place upgrade from `cmux`
- The first official release after the cutover should be published only after all three workstreams pass verification
- If an external dependency such as domain hosting, Homebrew publication, or release-consumer path migration is incomplete, the release should be blocked rather than silently shipping mixed identity

## Expected Outcome

After this project:

- The product is `Superghost` across app identity, CLI/runtime behavior, release packaging, docs, and public distribution
- Users install `Superghost`, run `superghost`, and interact with `SUPERGHOST_*` automation surfaces
- The canonical public home is `matt-ramotar/superghost` plus `https://superghost.bionic.sh`
- `cmux` is no longer the active shipped identity
