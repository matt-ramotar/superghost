# Superghost Homebrew Support Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Homebrew a working, current install path for stable `Superghost` releases so `brew tap matt-ramotar/homebrew-cmux && brew install --cask superghost` stays aligned with the latest GitHub release.

**Architecture:** Treat Homebrew as a release-adjacent publication lane with its own contract tests. First add failing checks that catch stale cask metadata and outdated install docs, then harden the update workflow so it publishes the latest stable release instead of silently drifting, and finally update the tap/docs surfaces plus perform the one-time operational backfill for the already-published `v0.64.0` release. Keep the existing tap repository name `matt-ramotar/homebrew-cmux` in this phase to avoid coupling working Homebrew support to a separate repo-rename migration.

**Tech Stack:** GitHub Actions, shell scripts, Homebrew cask metadata, GitHub releases, Markdown docs, Next.js docs page.

---

## File Map

- Create: `tests/test_homebrew_release_contract.sh`
  Responsibility: fail when the canonical Homebrew tap/cask/install contract drifts from the intended `Superghost` release lane.
- Modify: `tests/test_homebrew_sha.sh`
  Responsibility: verify the checked-in Homebrew cask matches the latest stable GitHub release version and DMG checksum, not just an older self-consistent release.
- Modify: `.github/workflows/ci.yml`
  Responsibility: run the Homebrew contract tests on every PR and `main` push.
- Modify: `.github/workflows/update-homebrew.yml`
  Responsibility: publish the latest stable release into the tap and fail loudly when required publication credentials are missing.
- Modify: `scripts/release_identity.sh`
  Responsibility: keep the Homebrew tap/cask/release URLs in one shell source of truth.
- Modify: `homebrew-cmux/Casks/superghost.rb`
  Responsibility: represent the latest stable `Superghost` release in the tap submodule.
- Modify: `homebrew-cmux/README.md`
  Responsibility: teach the correct Homebrew install, upgrade, uninstall, and untap commands.
- Modify: `README.md`
  Responsibility: teach the current canonical Homebrew install and upgrade commands in the main repo.
- Modify: `web/app/[locale]/docs/getting-started/page.tsx`
  Responsibility: update the executable Homebrew command snippets on the docs site.

### Scope Note

This plan is intentionally limited to making Homebrew publication and install instructions work with the current tap repo. A later migration can rename the tap repo itself from `homebrew-cmux` to `homebrew-superghost` once the cask lane is stable and automated.

### Submodule Safety Note

`homebrew-cmux` is a git submodule. Any tap metadata change must be committed in the submodule first, pushed to its remote, and only then recorded in the parent repo. Do not create an orphaned submodule commit or update the parent pointer before the tap commit exists on a durable remote ref.

### Task 1: Add Failing Homebrew Contract Tests

**Files:**
- Create: `tests/test_homebrew_release_contract.sh`
- Modify: `tests/test_homebrew_sha.sh`
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: Inventory the current Homebrew drift**

Run:
```bash
rg -n 'homebrew-cmux|brew tap|brew install --cask|brew upgrade --cask|RELEASE_HOMEBREW_TAP_REPOSITORY|RELEASE_CASK_NAME' \
  scripts/release_identity.sh \
  .github/workflows/update-homebrew.yml \
  README.md \
  homebrew-cmux/README.md \
  web/app/[locale]/docs/getting-started/page.tsx \
  tests/test_homebrew_sha.sh
gh release view v0.64.0 --json tagName,assets
sed -n '1,40p' homebrew-cmux/Casks/superghost.rb
```
Expected: the latest release is `v0.64.0`, while the checked-in cask and install docs are still stale or still teaching `cmux`.

- [ ] **Step 2: Write a failing Homebrew install-contract test**

Create `tests/test_homebrew_release_contract.sh` with assertions that all of the following are true:
- `scripts/release_identity.sh` exports `RELEASE_CASK_NAME="superghost"`
- `scripts/release_identity.sh` exports `RELEASE_HOMEBREW_TAP_REPOSITORY="matt-ramotar/homebrew-cmux"`
- `README.md` contains `brew tap matt-ramotar/homebrew-cmux`
- `README.md` contains `brew install --cask superghost`
- `README.md` contains `brew upgrade --cask superghost`
- `homebrew-cmux/README.md` contains the same `superghost` install/upgrade commands
- `web/app/[locale]/docs/getting-started/page.tsx` contains the same executable command snippets
- none of those canonical install surfaces still contain `brew install --cask cmux` or `brew tap manaflow-ai/cmux`

The script must exit non-zero with clear messages when any assertion fails.

- [ ] **Step 3: Strengthen the existing SHA test so it checks release freshness**

Update `tests/test_homebrew_sha.sh` so it:
- fetches the latest stable GitHub release tag from `matt-ramotar/superghost`
- compares that tag version to the version in `homebrew-cmux/Casks/superghost.rb`
- fails if the cask version is behind the latest release
- only then downloads `superghost-macos.dmg` for that exact version and verifies the SHA matches

Keep the script’s existing file-size and HTTP checks.

- [ ] **Step 4: Run the Homebrew tests and verify they fail**

Run:
```bash
bash tests/test_homebrew_release_contract.sh
bash tests/test_homebrew_sha.sh
```
Expected:
- `test_homebrew_release_contract.sh` FAILS because the canonical docs still teach legacy commands
- `test_homebrew_sha.sh` FAILS because the cask is still pinned to `0.63.1` while the latest stable release is `0.64.0`

- [ ] **Step 5: Wire the tests into CI**

Add two new steps to `.github/workflows/ci.yml` under `workflow-guard-tests`:
- `run: ./tests/test_homebrew_release_contract.sh`
- `run: ./tests/test_homebrew_sha.sh`

- [ ] **Step 6: Commit the failing test coverage**

```bash
git add tests/test_homebrew_release_contract.sh tests/test_homebrew_sha.sh .github/workflows/ci.yml
git commit -m "test: cover homebrew release contract"
```

### Task 2: Harden Homebrew Publication Automation

**Files:**
- Modify: `.github/workflows/update-homebrew.yml`
- Modify: `scripts/release_identity.sh`
- Modify: `tests/test_homebrew_sha.sh`

- [ ] **Step 1: Keep release identity as the only Homebrew source of truth**

Confirm `scripts/release_identity.sh` is the only place that defines:
- `RELEASE_CASK_NAME`
- `RELEASE_LEGACY_CASK_NAME`
- `RELEASE_DMG_ASSET_NAME`
- `RELEASE_GITHUB_REPOSITORY`
- `RELEASE_HOMEBREW_TAP_REPOSITORY`

If any Homebrew repo/name/asset literals are duplicated elsewhere in `.github/workflows/update-homebrew.yml`, replace them with sourced values instead of adding new constants.

- [ ] **Step 2: Make missing tap credentials a hard publication failure**

Update `.github/workflows/update-homebrew.yml` so stable release publication does not silently succeed when `HOMEBREW_TAP_TOKEN` is absent.

For this phase:
- if the workflow reaches the publication path for a stable semver release and the token is missing, the workflow must fail with a clear message
- keep the existing non-release ref skip behavior intact
- keep manual `workflow_dispatch` support intact

The failure message must tell the operator to set `HOMEBREW_TAP_TOKEN` for `matt-ramotar/superghost`.

- [ ] **Step 3: Keep the workflow verification close to the publication path**

After the cask file is rewritten in `.github/workflows/update-homebrew.yml`, keep or add explicit checks for:
- cask SHA equals downloaded DMG SHA
- cask version equals the requested release version
- legacy `cmux.rb` is removed when the release cask name differs

Do not rely on a later manual eyeball check.

- [ ] **Step 4: Run the guard tests to verify the workflow-level changes**

Run:
```bash
bash tests/test_homebrew_release_contract.sh
bash tests/test_homebrew_sha.sh
```
Expected: still FAIL at this point until the tap metadata and docs are updated, but the workflow logic and error messages are now aligned with the intended release contract.

- [ ] **Step 5: Commit the workflow hardening**

```bash
git add .github/workflows/update-homebrew.yml scripts/release_identity.sh tests/test_homebrew_sha.sh
git commit -m "ci: harden homebrew publication workflow"
```

### Task 3: Update Tap Metadata And Canonical Install Docs

**Files:**
- Modify: `homebrew-cmux/Casks/superghost.rb`
- Modify: `homebrew-cmux/README.md`
- Modify: `README.md`
- Modify: `web/app/[locale]/docs/getting-started/page.tsx`

- [ ] **Step 1: Update the tap cask to the latest stable release**

Update `homebrew-cmux/Casks/superghost.rb` so it matches the latest stable GitHub release:
- version `0.64.0`
- SHA256 for `https://github.com/matt-ramotar/superghost/releases/download/v0.64.0/superghost-macos.dmg`
- installed app `Superghost.app`
- installed binary `superghost`
- zap paths under `Superghost` / `sh.bionic.superghost`

Do not reintroduce a canonical `cmux.rb` stable cask.

- [ ] **Step 2: Update the tap README**

Rewrite `homebrew-cmux/README.md` so the canonical commands are:
```bash
brew tap matt-ramotar/homebrew-cmux
brew install --cask superghost
brew upgrade --cask superghost
brew uninstall --cask superghost
brew untap matt-ramotar/homebrew-cmux
```

All product/repo references in that README should describe `Superghost`, not `cmux`.

- [ ] **Step 3: Update the main README install instructions**

Change the Homebrew section in `README.md` so it teaches the same canonical commands as the tap README and no longer instructs users to install `cmux` or tap `manaflow-ai/cmux`.

- [ ] **Step 4: Update the website getting-started command snippets**

Update `web/app/[locale]/docs/getting-started/page.tsx` so the rendered Homebrew snippets use:
```bash
brew tap matt-ramotar/homebrew-cmux
brew install --cask superghost
brew upgrade --cask superghost
```

This task is limited to executable command snippets; broader localization copy cleanup is a separate follow-up.

- [ ] **Step 5: Handle the Homebrew submodule safely**

Run:
```bash
git -C homebrew-cmux checkout -b superghost-homebrew-support
git -C homebrew-cmux add Casks/superghost.rb README.md
git -C homebrew-cmux commit -m "Update Superghost Homebrew cask"
git -C homebrew-cmux push origin HEAD
git add homebrew-cmux README.md web/app/[locale]/docs/getting-started/page.tsx
```
Expected: the tap commit exists on the tap remote before the parent repo records the new submodule pointer.

- [ ] **Step 6: Run the Homebrew tests and verify they pass**

Run:
```bash
bash tests/test_homebrew_release_contract.sh
bash tests/test_homebrew_sha.sh
```
Expected: PASS. The cask version matches `v0.64.0`, the SHA matches the published DMG, and the canonical docs all teach `superghost`.

- [ ] **Step 7: Commit the repo-side Homebrew support changes**

```bash
git add homebrew-cmux README.md web/app/[locale]/docs/getting-started/page.tsx
git commit -m "docs: publish superghost homebrew install path"
```

### Task 4: Provision Publication Credentials And Backfill The Current Release

**Files:**
- None. This task is operational: GitHub repo settings, Actions reruns, and a clean-machine smoke test.

- [ ] **Step 1: Create a tap write token**

Create a fine-grained GitHub token that can write contents to `matt-ramotar/homebrew-cmux`.

Minimum required access:
- repository contents: read and write
- target repo: `matt-ramotar/homebrew-cmux`

- [ ] **Step 2: Add the token to the main repo secrets**

Add the token as `HOMEBREW_TAP_TOKEN` in the GitHub Actions secrets for `matt-ramotar/superghost`.

Expected: `.github/workflows/update-homebrew.yml` can now push cask updates instead of failing on missing credentials.

- [ ] **Step 3: Backfill the already-published stable release**

Manually dispatch the `Update Homebrew Cask` workflow for version `0.64.0`.

Run:
```bash
gh workflow run update-homebrew.yml -f version=0.64.0
RUN_ID="$(gh run list --workflow 'Update Homebrew Cask' --limit 1 --json databaseId --jq '.[0].databaseId')"
gh run watch "$RUN_ID"
```
Expected: the tap repo receives the `0.64.0` cask update and the workflow finishes green.

- [ ] **Step 4: Verify the tap remotely**

Run:
```bash
gh api repos/matt-ramotar/homebrew-cmux/contents/Casks/superghost.rb --jq '.download_url'
curl -L "$(gh api repos/matt-ramotar/homebrew-cmux/contents/Casks/superghost.rb --jq '.download_url')"
```
Expected: the remote tap cask reports `version "0.64.0"` and the matching SHA.

- [ ] **Step 5: Smoke-test install on a clean Mac**

Run on the target machine:
```bash
brew untap matt-ramotar/homebrew-cmux || true
brew tap matt-ramotar/homebrew-cmux
brew install --cask superghost
test -d /Applications/Superghost.app
test -x /opt/homebrew/bin/superghost || test -x /usr/local/bin/superghost
brew upgrade --cask superghost
```
Expected:
- Homebrew installs `Superghost.app`
- the `superghost` CLI shim exists in the Homebrew prefix
- `brew upgrade --cask superghost` completes without switching back to `cmux`

- [ ] **Step 6: Record completion**

Capture the successful workflow URL and clean-machine smoke-test output in the PR or merge notes so the next release has an executable reference for Homebrew publication.

---

Plan complete and saved to `docs/superpowers/plans/2026-04-12-superghost-homebrew-support.md`. Ready to execute?
