# Superghost Full Rename Design Remediation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revise the full rename design so it explicitly covers every build, runtime, release, localization, and archival surface required for a safe `cmux` to `Superghost` cutover, then split the work into bounded follow-on execution plans.

**Architecture:** Treat this as a doc-first hardening pass. First patch the authoritative design doc with concrete matrices for build products, channel identities, runtime state, release automation, localization, and historical-reference policy. Then create four smaller implementation plans so engineers can execute the rename in independent, testable workstreams instead of one monolithic pass.

**Tech Stack:** Markdown specs/plans, `rg`, Xcode project metadata, SwiftPM, GitHub Actions, Homebrew cask repo, Next.js website/docs, app localization catalogs.

---

## File Map

- Modify: `docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md`
  Responsibility: authoritative rename design; add the missing build graph, runtime-state, distribution, localization, and archival requirements uncovered in review.
- Create: `docs/superpowers/plans/2026-04-04-superghost-identity-build-cutover.md`
  Responsibility: executable plan for Xcode products, SwiftPM, schemes, test hosts, test targets, and channel naming.
- Create: `docs/superpowers/plans/2026-04-04-superghost-runtime-contract-cutover.md`
  Responsibility: executable plan for CLI naming, env vars, sockets, defaults domains, helper wrappers, remote daemon state, and automation markers.
- Create: `docs/superpowers/plans/2026-04-04-superghost-distribution-localization-cutover.md`
  Responsibility: executable plan for website/docs, release assets, Homebrew, public URLs, localized strings, and README translations.
- Create: `docs/superpowers/plans/2026-04-04-superghost-release-gating-validation.md`
  Responsibility: executable plan for release blockers, verification commands, historical-reference boundaries, and publish/no-publish gates.

This rename spans multiple independent subsystems. Do not jump straight into implementation from the current spec; first harden the design, then execute the smaller plans above.

### Task 1: Harden Build Graph And Channel Identity Requirements

**Files:**
- Modify: `docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md`
- Reference: `Package.swift`
- Reference: `GhosttyTabs.xcodeproj/project.pbxproj`
- Reference: `GhosttyTabs.xcodeproj/xcshareddata/xcschemes/cmux.xcscheme`
- Reference: `GhosttyTabs.xcodeproj/xcshareddata/xcschemes/cmux-ci.xcscheme`
- Reference: `GhosttyTabs.xcodeproj/xcshareddata/xcschemes/cmux-unit.xcscheme`
- Reference: `cmuxTests/SidebarWidthPolicyTests.swift`
- Reference: `.github/workflows/ci.yml`
- Reference: `.github/workflows/ci-macos-compat.yml`
- Reference: `.github/workflows/test-depot.yml`
- Reference: `.github/workflows/test-e2e.yml`
- Reference: `scripts/test-unit.sh`

- [ ] **Step 1: Confirm the current spec is missing build-graph coverage**

Run:
```bash
rg -n "Package.swift|SwiftPM|cmux-unit|cmuxTests|cmuxUITests|tagged DEV|Channel Identity Matrix|Superghost STAGING|Superghost NIGHTLY" docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
```
Expected: missing matches for at least the SwiftPM package, test target names, and tagged DEV channel behavior.

- [ ] **Step 2: Add a `Build Graph Surfaces` subsection to the spec**

Insert a markdown block that explicitly names:
```md
### Build Graph Surfaces

- Root SwiftPM package/product/target names in `Package.swift`
- Xcode native target names, product names, and built app names
- Shared scheme names (`cmux`, `cmux-ci`, `cmux-unit`) and any renamed successors
- Unit/UI test target names, module imports, buildable references, and `TEST_HOST` / `BUNDLE_LOADER`
- Workflow and script selectors that call schemes or `-only-testing` by name
```

- [ ] **Step 3: Add a `Channel Identity Matrix` to the spec**

Add a table covering at least these rows:
```md
| Channel | App Name | Bundle ID | Executable Name | Socket Path Family | Notes |
| --- | --- | --- | --- | --- | --- |
| Stable | Superghost.app | sh.bionic.superghost.app | superghost | /tmp/superghost.sock with /tmp/superghost-<uid>.sock fallback | shipped release |
| Debug | Superghost DEV.app | sh.bionic.superghost.app.debug | superghost | /tmp/superghost-debug.sock | local only |
| Tagged DEV | Superghost DEV <tag>.app | sh.bionic.superghost.app.debug.<sanitized-tag> | superghost | /tmp/superghost-debug-<sanitized-tag>.sock | required for parallel local builds |
| Staging | Superghost STAGING.app | sh.bionic.superghost.app.staging | superghost | /tmp/superghost-staging.sock | isolated from stable |
| Tagged STAGING | Superghost STAGING <tag>.app | sh.bionic.superghost.app.staging.<sanitized-tag> | superghost | /tmp/superghost-staging-<sanitized-tag>.sock | optional parallel staging builds |
| Nightly | Superghost NIGHTLY.app | sh.bionic.superghost.app.nightly | superghost | /tmp/superghost-nightly.sock | isolated update channel |
```

Also add a sanitization rule immediately below the table:
```md
`<sanitized-tag>` means: lowercase, replace `.` and `_` with `-`, strip non-alphanumeric characters except `-`, collapse repeated separators, and trim leading/trailing `-`.
```

- [ ] **Step 4: Add build verification bullets that cover these exact surfaces**

Extend `Build Verification` so it explicitly requires:
```md
- `swift build` no longer emits a `cmux` package/product/target
- Shared schemes, test targets, and `TEST_HOST` paths no longer point at `cmux`
- Tagged DEV, staging, and nightly builds have documented app-name, bundle-ID, and socket-path conventions
```

- [ ] **Step 5: Re-run the coverage check**

Run:
```bash
rg -n "Package.swift|SwiftPM|cmux-unit|cmuxTests|cmuxUITests|tagged DEV|Channel Identity Matrix|Superghost STAGING|Superghost NIGHTLY" docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
```
Expected: every token above appears in the spec.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
git commit -m "docs: harden rename design build graph and channel identity"
```

### Task 2: Harden Runtime State And Automation Requirements

**Files:**
- Modify: `docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md`
- Reference: `CLI/cmux.swift`
- Reference: `Sources/SocketControlSettings.swift`
- Reference: `daemon/remote/README.md`
- Reference: `daemon/remote/cmd/cmuxd-remote/agent_launch.go`
- Reference: `daemon/remote/cmd/cmuxd-remote/tmux_compat.go`
- Reference: `scripts/reload.sh`
- Reference: `scripts/reloads.sh`
- Reference: `scripts/launch-tagged-automation.sh`
- Reference: `Resources/shell-integration/cmux-bash-integration.bash`
- Reference: `Resources/shell-integration/.zshrc`
- Reference: `tests/cmux.py`
- Reference: `tests_v2/cmux.py`

- [ ] **Step 1: Confirm the current spec is missing hidden runtime-state surfaces**

Run:
```bash
rg -n "\\.cmux|\\.cmuxterm|defaults domain|keychain|socket marker|last-socket-path|relay|shell integration|helper wrapper" docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
```
Expected: missing matches for `.cmux`, `.cmuxterm`, defaults domains, keychain services, and discovery marker files.

- [ ] **Step 2: Add a `Hidden Runtime State Inventory` section**

Add a table or bullet inventory that names:
```md
- local app support, cache, defaults-domain, and keychain-service names
- local config-file and config-directory identities such as `cmux.json` and `~/.config/cmux/cmux.json`
- local marker files (`last-socket-path`, debug-log path, selected CLI path, helper symlinks)
- remote-host state under `~/.cmux/*` and `~/.cmuxterm/*`
- remote relay/auth files, remote daemon cache paths, and wrapper install paths
- shell integration env vars and helper binary names
```

- [ ] **Step 3: Expand `Workstream 2` to include non-obvious runtime contracts**

Append concrete bullets under runtime scope for:
```md
- defaults domains / preferences plists
- keychain service names
- config-file and config-directory names (`cmux.json`, `~/.config/cmux/`)
- helper shims and symlink targets
- discovery marker files written by reload/test automation
- remote relay metadata and remote bootstrap paths
- `.cmuxterm` state used by Claude/OpenCode/tmux-compat helpers
```

- [ ] **Step 4: Strengthen runtime verification**

Update `Runtime Verification` so it requires all of the following:
```md
- marker files and helper shims use `superghost` naming where they are part of shipped or supported automation
- remote bootstrap no longer installs `~/.cmux/bin/cmux` or `cmuxd-remote-current`
- defaults domains, keychain service names, and shell integration env vars no longer use `cmux` names unless explicitly carved out as historical/internal-only with rationale
```

- [ ] **Step 5: Re-run the coverage check**

Run:
```bash
rg -n "\\.cmux|\\.cmuxterm|defaults domain|keychain|socket marker|last-socket-path|relay|shell integration|helper wrapper" docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
```
Expected: the spec now mentions each hidden runtime-state family above.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
git commit -m "docs: harden rename design runtime contract surfaces"
```

### Task 3: Harden Release, Update, Homebrew, And Public URL Requirements

**Files:**
- Modify: `docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md`
- Reference: `scripts/release_asset_guard.js`
- Reference: `scripts/sparkle_generate_appcast.sh`
- Reference: `scripts/build-sign-upload.sh`
- Reference: `scripts/build_remote_daemon_release_assets.sh`
- Reference: `scripts/bump-version.sh`
- Reference: `.github/workflows/nightly.yml`
- Reference: `.github/workflows/release.yml`
- Reference: `.github/workflows/update-homebrew.yml`
- Reference: `homebrew-cmux/Casks/cmux.rb`
- Reference: `homebrew-cmux/README.md`
- Reference: `tests/test_homebrew_sha.sh`
- Reference: `README.md`
- Reference: `web/i18n/seo.ts`
- Reference: `web/app/robots.ts`
- Reference: `web/app/sitemap.ts`
- Reference: `web/proxy.ts`

- [ ] **Step 1: Confirm the current spec is missing explicit release blockers**

Run:
```bash
rg -n "release_asset_guard|sparkle_generate_appcast|build-sign-upload|bump-version|update-homebrew|nightly.yml|robots.ts|sitemap.ts|seo.ts|proxy.ts|external dependency checklist" docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
```
Expected: missing matches for most script/workflow names and no explicit external dependency checklist.

- [ ] **Step 2: Add a `Release Automation Surfaces` section**

Insert a concrete list like:
```md
### Release Automation Surfaces

- scripts that generate DMGs, appcasts, and remote-daemon manifests
- stable/nightly compatibility outputs such as `appcast.xml`, `appcast-universal.xml`, and aliased `cmuxd-remote-*` assets
- scripts/workflows that guard immutable asset names
- nightly/stable workflows that rewrite bundle IDs, feed URLs, and app names
- Homebrew publication automation, tap checkout path, and cask rewrite logic
```

- [ ] **Step 3: Add a `Release-Blocking External Dependencies` checklist**

Add a checklist that requires:
```md
- new GitHub release asset names are produced by CI
- Homebrew tap/repo/name/credentials exist and `brew install` works against the new cask name
- canonical website host, sitemap, robots, and redirect behavior are switched to `https://superghost.bionic.sh`
- Sparkle feed URLs and nightly feed URLs point only at the new repo/domain
```

- [ ] **Step 4: Expand `Distribution Verification` with concrete verifier bullets**

Append bullets that explicitly require checks against:
```md
- release scripts and workflows
- Homebrew cask/test scripts
- canonical URLs in website metadata, sitemap, robots, and redirect middleware
- README and install snippets for DMG/Homebrew/nightly downloads
```

- [ ] **Step 5: Re-run the coverage check**

Run:
```bash
rg -n "release_asset_guard|sparkle_generate_appcast|build-sign-upload|bump-version|update-homebrew|nightly.yml|robots.ts|sitemap.ts|seo.ts|proxy.ts|external dependency checklist" docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
```
Expected: each release/public surface above is now called out directly.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
git commit -m "docs: harden rename design release and public surface blockers"
```

### Task 4: Rewrite Boundary Verification For History And Localization

**Files:**
- Modify: `docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md`
- Reference: `CHANGELOG.md`
- Reference: `README.md`
- Reference: `README.ja.md`
- Reference: `web/messages/en.json`
- Reference: `web/messages/ja.json`
- Reference: `Resources/InfoPlist.xcstrings`
- Reference: `Resources/Localizable.xcstrings`

- [ ] **Step 1: Confirm the current spec has no archival exception policy**

Run:
```bash
rg -n "historical|archival|legacy reference policy|localized verification|README translations|web/messages|Localizable.xcstrings|InfoPlist.xcstrings" docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
```
Expected: no explicit archival policy and no concrete localization sweep requirements.

- [ ] **Step 2: Replace the absolute boundary rule with an active-surface rule**

Edit the boundary section so it says, in substance:
```md
- No active install, update, runtime, or supported automation surface may require `cmux`
- Historical references in changelogs, archived blog posts, old PR links, and issue references may remain when they document past reality
- Historical references must not be presented as the canonical current install/update path
```

- [ ] **Step 3: Add a `Localization Sweep` subsection**

Add explicit bullets requiring updates across:
```md
- app localization catalogs (`Resources/InfoPlist.xcstrings`, `Resources/Localizable.xcstrings`)
- website locale message files under `web/messages/`
- translated README files and install snippets
- code-backed localized docs under `web/app/[locale]/docs/**`
- code-backed localized blog/changelog surfaces under `web/app/[locale]/blog/**` and `web/app/[locale]/docs/changelog/**`
- any localized docs/blog copy that teaches current commands, URLs, env vars, sockets, or download assets
```

- [ ] **Step 4: Add localized verification bullets**

Extend verification so it requires:
```md
- at least one sweep command across `README*.md`, `web/messages/*.json`, `Resources/*.xcstrings`, `web/app/[locale]/docs/**`, `web/app/[locale]/blog/**`, and `web/app/[locale]/docs/changelog/**`
- confirmation that current install/update/runtime identifiers are updated in non-English surfaces, not just English copy
```

- [ ] **Step 5: Re-run the coverage check**

Run:
```bash
rg -n "historical|archival|legacy reference policy|localized verification|README translations|web/messages|Localizable.xcstrings|InfoPlist.xcstrings" docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
```
Expected: all localization and archival-policy terms above now appear.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
git commit -m "docs: harden rename design boundaries and localization verification"
```

### Task 5: Split The Hardened Design Into Four Executable Workstream Plans

**Files:**
- Create: `docs/superpowers/plans/2026-04-04-superghost-identity-build-cutover.md`
- Create: `docs/superpowers/plans/2026-04-04-superghost-runtime-contract-cutover.md`
- Create: `docs/superpowers/plans/2026-04-04-superghost-distribution-localization-cutover.md`
- Create: `docs/superpowers/plans/2026-04-04-superghost-release-gating-validation.md`
- Reference: `docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md`

- [ ] **Step 1: Write the identity/build execution plan**

The plan must cover:
```md
- `Package.swift`
- `GhosttyTabs.xcodeproj/project.pbxproj`
- shared schemes
- test target/module renames
- tagged/staging/nightly identity matrix implementation
- CI selectors and test-host updates
```

- [ ] **Step 2: Write the runtime-contract execution plan**

The plan must cover:
```md
- CLI binary names and usage text
- env vars, defaults domains, keychain services
- socket paths and marker files
- config-file and config-directory renames (`cmux.json`, `~/.config/cmux/`, trust/approval state tied to them)
- reload/test automation shims
- remote daemon paths under local and remote hosts
- shell integration wrappers and helper binaries
```

- [ ] **Step 3: Write the distribution/localization execution plan**

The plan must cover:
```md
- README + translated READMEs
- `web/messages/*.json`
- `Resources/*.xcstrings`
- code-backed current docs under `web/app/[locale]/docs/**`
- code-backed current blog/changelog surfaces under `web/app/[locale]/blog/**` and `web/app/[locale]/docs/changelog/**`
- canonical website metadata and download links
- Homebrew cask/tap naming and install docs
- public repo/domain references
```

- [ ] **Step 4: Write the release-gating/validation execution plan**

The plan must cover:
```md
- stable/nightly release workflows
- Sparkle feed generation
- remote-daemon asset generation and guards
- Homebrew publication verification
- historical-reference exceptions
- explicit no-release conditions when external dependencies are not ready
```

- [ ] **Step 5: Verify all four follow-on plans exist, use the required header, and contain real scope content**

Run:
```bash
IDENTITY=docs/superpowers/plans/2026-04-04-superghost-identity-build-cutover.md
RUNTIME=docs/superpowers/plans/2026-04-04-superghost-runtime-contract-cutover.md
DISTRIBUTION=docs/superpowers/plans/2026-04-04-superghost-distribution-localization-cutover.md
RELEASE=docs/superpowers/plans/2026-04-04-superghost-release-gating-validation.md

for file in "$IDENTITY" "$RUNTIME" "$DISTRIBUTION" "$RELEASE"; do
  test -f "$file"
  rg -n "^# .* Implementation Plan$|^> \\*\\*For agentic workers:" "$file"
  rg -n "^## File Map$|^### Task [0-9]+:" "$file"
  test "$(rg -c "^### Task [0-9]+:" "$file")" -ge 2
  rg -n "^Run:$|^```bash$" "$file"
  ! rg -n "TODO|TBD|placeholder|fill me in|\\.\\.\\." "$file"
done

rg -n "Package.swift|project\\.pbxproj|cmux-unit|cmuxTests|tagged DEV|TEST_HOST|BUNDLE_LOADER" "$IDENTITY"
rg -n "SocketControlSettings|\\.cmux|\\.cmuxterm|cmux\\.json|\\.config/cmux|defaults domain|keychain" "$RUNTIME"
rg -n "web/messages|web/app/\\[locale\\]/docs|web/app/\\[locale\\]/blog|Resources/(Localizable|InfoPlist)\\.xcstrings|Homebrew|tap|README" "$DISTRIBUTION"
rg -n "release\\.yml|nightly\\.yml|build_remote_daemon_release_assets|release_asset_guard|appcast(-universal)?\\.xml|cmuxd-remote" "$RELEASE"
```
Expected: each file exists, matches the required header pattern, contains a file map, contains at least two executable tasks with verification commands, contains no placeholder text, and includes the subsystem-specific scope markers above.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md docs/superpowers/plans/
git commit -m "docs: split superghost rename into executable workstream plans"
```

### Task 6: Final Validation Of The Hardened Design Package

**Files:**
- Modify: `docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md`
- Create: `docs/superpowers/plans/2026-04-04-superghost-identity-build-cutover.md`
- Create: `docs/superpowers/plans/2026-04-04-superghost-runtime-contract-cutover.md`
- Create: `docs/superpowers/plans/2026-04-04-superghost-distribution-localization-cutover.md`
- Create: `docs/superpowers/plans/2026-04-04-superghost-release-gating-validation.md`

- [ ] **Step 1: Run a final spec coverage sweep**

Run:
```bash
rg -n "SwiftPM|cmux-unit|tagged DEV|\\.cmux|\\.cmuxterm|defaults domain|keychain|release_asset_guard|sparkle_generate_appcast|update-homebrew|robots.ts|sitemap.ts|historical|archival|web/messages|Localizable.xcstrings" docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
```
Expected: every token above appears in the hardened spec.

- [ ] **Step 2: Verify the plan set is self-consistent**

Run:
```bash
find docs/superpowers/plans -maxdepth 1 -type f | sort
```
Expected: this remediation plan plus the four follow-on plans exist with no placeholder filenames.

- [ ] **Step 3: Request plan-document review**

Dispatch one reviewer with:
```text
Plan to review: docs/superpowers/plans/2026-04-04-superghost-full-rename-design-remediation.md
Spec for reference: docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md
```
Approve only if the plan clearly closes the five review findings: build graph gaps, hidden runtime state, release/update blockers, channel identity ambiguity, and archival/localization verification gaps.
Also require that the plan explicitly covers the stable release workflow, remote-daemon asset generation, Homebrew/public URL blockers, active-surface vs archival policy, code-backed non-English docs surfaces, config-file/config-directory identities (`cmux.json`, `~/.config/cmux`), and rejection of placeholder follow-on plans.

- [ ] **Step 4: If review finds issues, fix the plan and rerun the reviewer**

Do not proceed until the reviewer returns:
```text
Status: Approved
```

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-04-04-superghost-full-rename-design.md docs/superpowers/plans/
git commit -m "docs: finalize superghost rename remediation planning set"
```
