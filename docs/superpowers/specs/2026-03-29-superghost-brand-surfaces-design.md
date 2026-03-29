# Superghost Brand Surfaces Design

## Summary

This design defines the first rebrand phase from `cmux` to `Superghost`.
The phase is intentionally limited to English, user-facing brand surfaces.
Operational identifiers remain unchanged until a later internal rename.

## Approved Decisions

- Canonical brand styling is `Superghost`.
- This phase updates only English user-facing surfaces.
- Real operational identifiers remain `cmux` for now.
- Concrete commands, install names, package names, and other live identifiers stay as they are until the real rename happens.
- The provided icon sources are:
  - `/Users/matt.ramotar/Downloads/superghost.icns`
  - `/Users/matt.ramotar/Downloads/superghost.iconset`
- The provided icon applies to macOS app icons only in this phase.
- Website logo, favicon, and other web branding artwork remain unchanged in this phase.

## Goals

1. Present the product as `Superghost` across English user-facing copy.
2. Preserve correctness wherever the actual shipped command, package, or artifact name is still `cmux`.
3. Update the macOS app icon assets to the provided Superghost icon artwork without expanding into a broader web-art pass.

## Non-Goals

- Renaming the CLI executable.
- Renaming Swift package, target, module, or test bundle names.
- Renaming bundle identifiers.
- Renaming environment variables, socket paths, or on-disk support directories.
- Renaming Homebrew tap/cask names.
- Renaming release asset names, feed URLs, repo URLs, or domain names.
- Updating non-English localizations.
- Replacing website logo, favicon, Open Graph logo art, or nightly web logo art.

## Scope

### English Copy Surfaces

The implementation phase should update English user-facing copy in:

- `README.md`
- `web/messages/en.json`
- `Resources/Localizable.xcstrings`
- `Resources/InfoPlist.xcstrings`

These files hold the public marketing/docs copy and the app-visible localized strings for the current phase.

### macOS App Icon Surfaces

The implementation phase should update:

- `Assets.xcassets/AppIcon.appiconset`
- `Assets.xcassets/AppIcon-Debug.appiconset`
- `Assets.xcassets/AppIcon-Nightly.appiconset`

The source of truth is the provided `superghost.iconset`, with `superghost.icns` available as a verification artifact if needed.

## Naming Rules

### Replace With `Superghost`

Use `Superghost` for:

- Product name in titles, headings, body copy, and descriptions.
- App-facing English labels and descriptive text.
- Alt text and metadata where the reference is branding, not an operational token.
- Permission/body copy such as microphone or camera descriptions when they refer to the app by brand.

### Keep As `cmux`

Keep `cmux` unchanged when it is a real live identifier, including:

- CLI commands such as `cmux notify`
- Install commands such as `brew install --cask cmux`
- Package, cask, and tap names
- Repo URLs and GitHub org/repo references
- Domains such as `cmux.com`
- Release asset names such as `cmux-macos.dmg`
- Environment variables such as `CMUX_SOCKET_PATH`
- Socket paths and support-directory paths
- Bundle identifiers and target/product internals

### Transitional Copy Rule

If a sentence is about the product but also needs to teach a still-live identifier, use `Superghost` for the product and preserve the identifier inline.

Examples:

- "Install Superghost with `brew install --cask cmux`."
- "Superghost includes the `cmux` CLI for automation."

### Historical Content Rule

Historical references may keep `cmux` when they refer to a past event, artifact, or post title that was originally published under that name.

Examples:

- "Launching cmux on Show HN"
- "The Zen of cmux"

## App Icon Design Handling

### Asset Mapping

The provided `superghost.iconset` should be mapped onto the app icon asset catalogs at the usual macOS sizes.
If the current asset catalogs include dark variants or nightly/debug-specific variants, the implementation should decide per catalog:

- Reuse the provided art directly where the asset expects the standard size.
- Preserve catalog structure and `Contents.json` shape.
- Avoid changing catalog names or asset identifiers in this phase.

### Existing Worktree Constraint

The current worktree already contains uncommitted changes in `Assets.xcassets/AppIcon.appiconset`.
The implementation phase must treat those as existing in-flight changes and reconcile them with the provided Superghost source art rather than assuming a clean baseline or reverting anything automatically.

## Expected User-Visible Outcome

After this phase:

- English-facing docs and app copy present the product as `Superghost`.
- Command examples and install snippets remain operationally accurate by continuing to show `cmux` where required.
- The macOS app icon uses the new Superghost artwork.
- Some built or OS-derived names may still show `cmux` because target/product internals are explicitly out of scope for this phase.

## Verification Criteria

### Copy Verification

Verify that English brand copy in the scoped files now follows the naming rules:

- Brand prose says `Superghost`.
- Live identifiers still say `cmux`.
- No English sentence incorrectly instructs users to run a non-existent `superghost` command.

### Icon Verification

Verify that the app icon catalogs contain the intended Superghost artwork across the app, debug, and nightly icon sets, without changing catalog names or build identifiers.

### Boundary Verification

Verify that the following remain untouched in this phase:

- Non-English localization files
- Website logo and favicon artwork
- CLI/package/bundle/env/socket/release identifiers

## Risks

- Over-eager search/replace could incorrectly rename commands, package names, URLs, or env vars.
- App display surfaces derived from build settings may still show `cmux`, which is acceptable for this phase but should be called out in review.
- Existing icon asset changes in the worktree increase the chance of accidental overwrite if implementation does not reconcile carefully.

## Follow-On Work

A later phase can perform the internal/product rename, which would cover:

- Executable and package names
- Xcode product names
- Bundle IDs
- Release asset names
- Homebrew naming
- Website logo/favicon refresh
- Non-English localization updates
