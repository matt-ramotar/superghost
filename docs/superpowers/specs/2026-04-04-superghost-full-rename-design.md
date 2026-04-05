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
- defaults domains / preferences plists
- keychain service names
- config-file and config-directory names such as `cmux.json` and `~/.config/cmux/`
- helper shims and symlink targets
- discovery marker files written by reload/test automation
- remote relay metadata and remote bootstrap paths
- `.cmuxterm` state used by Claude/OpenCode/tmux-compat helpers

### Hidden Runtime State Inventory

- local app support, cache, defaults domain, preferences-plist, and keychain service names, including `~/Library/Application Support/cmux`, `~/Library/Caches/cmux`, `com.cmuxterm.app`, `com.cmuxterm.app.debug`, `com.cmuxterm.app.staging`, tagged debug/staging descendants, and `com.cmuxterm.app.nightly`
- local config-file and config-directory identities such as `cmux.json` and `~/.config/cmux/cmux.json`
- local socket-password identities including keychain service family `com.cmuxterm.app.socket-control(.<scope>)`, keychain account `local-socket-password`, and file-backed password path `~/Library/Application Support/cmux/socket-control-password`
- local socket marker files and discovery marker files, including `last-socket-path`, `/tmp/cmux-last-socket-path`, `/tmp/cmux-last-debug-log-path`, and `/tmp/cmux-last-cli-path`
- local helper wrapper shims and symlink targets, including the reload-managed PATH shim target named `cmux`, `/tmp/cmux-cli`, `$HOME/.local/bin/cmux-dev`, and app-bundled helper wrapper launch paths
- remote-host state under `~/.cmux/*`, including `~/.cmux/socket_addr`, `~/.cmux/bin/cmux`, `~/.cmux/bin/cmuxd-remote-current`, `~/.cmux/relay/<port>.auth`, and `~/.cmux/relay/<port>.daemon_path`
- `.cmuxterm` helper state and shim directories, including `~/.cmuxterm/claude-hook-sessions.json`, `~/.cmuxterm/codex-hook-sessions.json`, `~/.cmuxterm/tmux-compat-store.json`, `~/.cmuxterm/claude-teams-bin/tmux`, `~/.cmuxterm/omo-bin/tmux`, `~/.cmuxterm/omo-bin/terminal-notifier`, and `~/.cmuxterm/omo-config`
- remote relay/auth files, relay bootstrap paths, remote daemon cache paths, and wrapper install paths, including `~/.cmuxterm/claude-teams-bin`, `~/.cmuxterm/omo-bin`, `~/.cmuxterm/omo-config`, `~/.cmux/bin/cmuxd-remote/<version>/<os-arch>/cmuxd-remote`, `~/Library/Application Support/cmux/remote-daemons/<version>/<os-arch>/cmuxd-remote`, `/tmp/cmux-remote-daemons/<version>/<os-arch>/cmuxd-remote`, and per-relay auth/daemon routing metadata under `~/.cmux/relay/`
- shell integration env vars and helper binary names that currently use `CMUX_SOCKET_PATH`, `CMUX_SOCKET`, `CMUX_SOCKET_PASSWORD`, `CMUX_SOCKET_ENABLE`, `CMUX_SOCKET_MODE`, `CMUXD_UNIX_PATH`, `CMUX_DEBUG_LOG`, `CMUX_BUNDLE_ID`, `CMUX_SHELL_INTEGRATION`, `CMUX_SHELL_INTEGRATION_DIR`, `CMUX_ZSH_ZDOTDIR`, `CMUX_LOAD_GHOSTTY_ZSH_INTEGRATION`, `CMUX_REMOTE_DAEMON_ALLOW_LOCAL_BUILD`, `CMUX_BUNDLED_CLI_PATH`, `CMUXTERM_REPO_ROOT`, `CMUX_PORT`, `CMUX_PORT_END`, `CMUX_PORT_RANGE`, `CMUX_TAG`, `CMUX_WORKSPACE_ID`, `CMUX_TAB_ID`, `CMUX_PANEL_ID`, `CMUX_SURFACE_ID`, `CMUX_PANE_ID`, `CMUX_CLAUDE_HOOKS_DISABLED`, `CMUX_CLAUDE_TEAMS_CMUX_BIN`, `CMUX_CLAUDE_TEAMS_TERM`, `CMUX_OMO_CMUX_BIN`, `CMUX_OMO_TERM`, `CMUX_CLAUDE_HOOK_STATE_PATH`, `cmux`, `cmuxd-remote-current`, or related helper wrapper names

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
- marker files and helper shims use `superghost` naming where they are part of shipped or supported automation
- remote bootstrap no longer installs `~/.cmux/bin/cmux` or `cmuxd-remote-current`
- defaults domains, keychain service names, and shell integration env vars no longer use `cmux` names unless explicitly carved out as historical/internal-only with rationale

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
