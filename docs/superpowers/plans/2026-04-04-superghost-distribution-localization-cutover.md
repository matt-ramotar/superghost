# Superghost Distribution And Localization Cutover Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename distribution, documentation, and localization surfaces so public install/update/docs flows teach `Superghost` everywhere, across English and non-English assets.

**Architecture:** Update canonical public endpoints first, then README/install surfaces, then localization catalogs and website message files, then code-backed localized docs/blog/changelog surfaces, and finally Homebrew/public download flows that still expose the old repo/domain.

**Tech Stack:** Markdown docs, JSON locale files, xcstrings catalogs, Next.js routes/content, Homebrew cask metadata, GitHub release URLs.

## File Map

- Modify: `README.md`
  Responsibility: rename canonical download/install/update instructions and repo/domain references.
- Modify: `README*.md`
  Responsibility: keep translated install/update/runtime instructions aligned with the renamed contract across every shipped README locale.
- Modify: `web/messages/*.json`
  Responsibility: rename localized website copy that teaches current commands, app names, URLs, or install flows across every locale bundle.
- Modify: `Resources/InfoPlist.xcstrings`
  Responsibility: rename localized app-permission and bundle-facing strings.
- Modify: `Resources/Localizable.xcstrings`
  Responsibility: rename localized UI/runtime/update strings across supported languages.
- Modify: `web/app/[locale]/docs/**`
  Responsibility: rename current code-backed docs content and install instructions in each locale.
- Modify: `web/app/[locale]/blog/**`
  Responsibility: rename current blog content where it teaches the current product/runtime contract.
- Modify: `web/app/[locale]/docs/changelog/**`
  Responsibility: keep current changelog/install guidance aligned while preserving explicitly historical references where appropriate.
- Modify: `web/i18n/seo.ts`
  Responsibility: rename canonical domain and metadata values.
- Modify: `web/app/robots.ts`
  Responsibility: rename canonical sitemap and host references.
- Modify: `web/app/sitemap.ts`
  Responsibility: rename canonical host references.
- Modify: `web/proxy.ts`
  Responsibility: rename redirect targets for the canonical public domain.
- Modify: `web/app/[locale]/layout.tsx`
  Responsibility: rename live site metadata, host, and repo references exposed from the localized app shell.
- Modify: `web/app/[locale]/page.tsx`
  Responsibility: rename homepage repo, issue, and download references presented as the current public path.
- Modify: `web/app/[locale]/nightly/**`
  Responsibility: rename nightly download links and update-channel guidance exposed by live website pages.
- Modify: `web/app/[locale]/community/**`
  Responsibility: rename live community/support pages when they expose current repo, issue, or discussion links.
- Modify: `web/app/[locale]/components/**`
  Responsibility: rename shared live download/install components that expose current asset, repo, or issue links.
- Modify: `web/app/[locale]/(legal)/**`
  Responsibility: rename live legal/support pages when they expose current repo, host, or product references.
- Modify: `web/app/[locale]/posthog.tsx`
  Responsibility: rename active analytics/bootstrap references that encode the current public host or product identity.
- Modify: `homebrew-cmux/Casks/cmux.rb`
  Responsibility: rename the cask name, download URL, and homepage for the new public install contract.
- Modify: `homebrew-cmux/README.md`
  Responsibility: rename tap/install instructions and repo references.
- Modify: `tests/test_homebrew_sha.sh`
  Responsibility: keep the Homebrew DMG/checksum verification aligned with the renamed cask and DMG URL.

### Task 1: Rename Canonical Public URLs, README Install Flows, And Download References

**Files:**
- Modify: `README.md`
- Modify: `README*.md`
- Modify: `web/i18n/seo.ts`
- Modify: `web/app/robots.ts`
- Modify: `web/app/sitemap.ts`
- Modify: `web/proxy.ts`
- Modify: `web/app/[locale]/layout.tsx`
- Modify: `web/app/[locale]/page.tsx`
- Modify: `web/app/[locale]/nightly/**`
- Modify: `web/app/[locale]/community/**`
- Modify: `web/app/[locale]/components/**`
- Modify: `web/app/[locale]/(legal)/**`
- Modify: `web/app/[locale]/posthog.tsx`

- [ ] **Step 1: Inventory public repo/domain/install references**

Run:
```bash
rg -n 'manaflow-ai/cmux|cmux\\.com|cmux-macos|cmux-nightly-macos|brew tap manaflow-ai/cmux|brew install --cask cmux|The Zen of cmux' \
  README*.md \
  web/i18n/seo.ts \
  web/app/robots.ts \
  web/app/sitemap.ts \
  web/proxy.ts \
  web/app/[locale]/layout.tsx \
  web/app/[locale]/page.tsx \
  web/app/[locale]/nightly \
  web/app/[locale]/community \
  web/app/[locale]/components \
  web/app/[locale]/(legal) \
  web/app/[locale]/posthog.tsx
```
Expected: current docs and metadata still point at the old repo/domain and DMG names.

- [ ] **Step 2: Rename canonical repo/domain/download/install references**

Update README, metadata, and live website entry surfaces so the current install/update flow points only at `matt-ramotar/superghost`, `https://superghost.bionic.sh`, and renamed stable/nightly asset names across the English README, every translated README, and the public-facing website pages/components that surface current repo, issue, discussion, and download links.

- [ ] **Step 3: Verify canonical URL and install surfaces**

Run:
```bash
rg -n 'manaflow-ai/cmux|cmux\\.com|cmux-macos|cmux-nightly-macos|brew tap manaflow-ai/cmux|brew install --cask cmux' \
  README*.md \
  web/i18n/seo.ts \
  web/app/robots.ts \
  web/app/sitemap.ts \
  web/proxy.ts \
  web/app/[locale]/layout.tsx \
  web/app/[locale]/page.tsx \
  web/app/[locale]/nightly \
  web/app/[locale]/community \
  web/app/[locale]/components \
  web/app/[locale]/(legal) \
  web/app/[locale]/posthog.tsx
```
Expected: no active install/update/docs metadata still points at the old repo/domain or asset names.

- [ ] **Step 4: Commit**

```bash
git add README*.md web/i18n/seo.ts web/app/robots.ts web/app/sitemap.ts web/proxy.ts web/app/[locale]/layout.tsx web/app/[locale]/page.tsx web/app/[locale]/nightly web/app/[locale]/community web/app/[locale]/components web/app/[locale]/(legal) web/app/[locale]/posthog.tsx
git commit -m "docs: rename public install and canonical url surfaces"
```

### Task 2: Rename Website Messages And App Localization Catalogs

**Files:**
- Modify: `web/messages/*.json`
- Modify: `Resources/InfoPlist.xcstrings`
- Modify: `Resources/Localizable.xcstrings`

- [ ] **Step 1: Inventory localized product/runtime references**

Run:
```bash
rg -n 'cmux|manaflow-ai/cmux|cmux\\.com|cmux CLI|cmux NIGHTLY|cmux processes only' \
  web/messages/*.json Resources/InfoPlist.xcstrings Resources/Localizable.xcstrings
```
Expected: current localized strings still teach the old product/runtime contract.

- [ ] **Step 2: Rename localized app and website strings**

Update every active localized string that teaches the current app name, CLI name, update/install path, repo/domain, socket/runtime label, or automation mode so every website locale and every app locale catalog stays aligned with English behavior.

- [ ] **Step 3: Verify catalog/message coverage**

Run:
```bash
rg -n 'cmux|manaflow-ai/cmux|cmux\\.com|cmux CLI|cmux NIGHTLY|cmux processes only' \
  web/messages/*.json Resources/InfoPlist.xcstrings Resources/Localizable.xcstrings
```
Expected: active localized catalogs no longer teach the old contract outside intentionally historical copy.

- [ ] **Step 4: Commit**

```bash
git add web/messages/*.json Resources/InfoPlist.xcstrings Resources/Localizable.xcstrings
git commit -m "i18n: rename website and app localization surfaces"
```

### Task 3: Rename Code-Backed Localized Docs, Blog, And Changelog Surfaces

**Files:**
- Modify: `web/app/[locale]/docs/**`
- Modify: `web/app/[locale]/blog/**`
- Modify: `web/app/[locale]/docs/changelog/**`

- [ ] **Step 1: Inventory current code-backed localized surfaces**

Run:
```bash
rg -n 'cmux|manaflow-ai/cmux|cmux\\.com|cmux-macos|cmux-nightly-macos|brew install --cask cmux' \
  web/app/[locale]/docs web/app/[locale]/blog web/app/[locale]/docs/changelog
```
Expected: current code-backed locale content still teaches the old runtime/install contract.

- [ ] **Step 2: Rename current localized docs/blog/changelog content**

Update code-backed localized docs, blog, and changelog content that teaches current install/update/runtime behavior while preserving explicitly historical references that document past reality.

- [ ] **Step 3: Verify code-backed locale content**

Run:
```bash
rg -n 'cmux|manaflow-ai/cmux|cmux\\.com|cmux-macos|cmux-nightly-macos|brew install --cask cmux' \
  web/app/[locale]/docs web/app/[locale]/blog web/app/[locale]/docs/changelog
```
Expected: active current-path instructions are renamed across locale-backed content.

- [ ] **Step 4: Commit**

```bash
git add web/app/[locale]/docs web/app/[locale]/blog web/app/[locale]/docs/changelog
git commit -m "docs: rename localized code-backed content surfaces"
```

### Task 4: Rename Homebrew Cask, Tap Docs, And Public Install Verification

**Files:**
- Modify: `homebrew-cmux/Casks/cmux.rb`
- Modify: `homebrew-cmux/README.md`
- Modify: `tests/test_homebrew_sha.sh`
- Modify: `README.md`
- Modify: `README*.md`

- [ ] **Step 1: Inventory Homebrew/public install references**

Run:
```bash
rg -n 'Homebrew|brew tap manaflow-ai/cmux|brew install --cask cmux|homebrew-cmux|Casks/cmux\\.rb|cmux-macos\\.dmg|manaflow-ai/cmux' \
  homebrew-cmux/Casks/cmux.rb homebrew-cmux/README.md tests/test_homebrew_sha.sh README*.md
```
Expected: the cask, tap docs, checksum test, and README install snippets still use `cmux`.

- [ ] **Step 2: Rename cask/tap/install surfaces**

Rename the cask file, cask class/name, DMG URL, homepage, tap/install snippets, checksum verification script, and English plus translated README references so Homebrew/public install flows align with `superghost`.

- [ ] **Step 3: Verify Homebrew/public install cutover**

Run:
```bash
rg -n 'brew tap manaflow-ai/cmux|brew install --cask cmux|Casks/cmux\\.rb|cmux-macos\\.dmg|manaflow-ai/cmux' \
  homebrew-cmux/Casks/cmux.rb homebrew-cmux/README.md tests/test_homebrew_sha.sh README*.md
! rg -n 'manaflow-ai/cmux|cmux\\.com|brew install --cask cmux|cmux-macos|cmux-nightly-macos|CMUX_|/tmp/cmux|com\\.cmuxterm' \
  README*.md \
  web/messages/*.json \
  Resources/InfoPlist.xcstrings \
  Resources/Localizable.xcstrings \
  web/app/[locale]/docs \
  web/app/[locale]/blog \
  web/app/[locale]/docs/changelog \
  web/app/[locale]/layout.tsx \
  web/app/[locale]/page.tsx \
  web/app/[locale]/nightly \
  web/app/[locale]/community \
  web/app/[locale]/components \
  web/app/[locale]/(legal) \
  web/app/[locale]/posthog.tsx
```
Expected: active Homebrew/install flows no longer teach the old cask, tap, or DMG URL, and the combined localized boundary sweep confirms that no current user-facing locale surface still presents `cmux` as the canonical install, update, or runtime path.

- [ ] **Step 4: Commit**

```bash
git add homebrew-cmux/Casks/cmux.rb homebrew-cmux/README.md tests/test_homebrew_sha.sh README*.md
git commit -m "docs: rename homebrew and public install flows"
```
