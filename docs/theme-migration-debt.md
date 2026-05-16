# Chrome migration debt

Inventory of remaining `NSColor(hex:)` and other hardcoded chrome literals in the
Superghost source tree, captured at the end of Milestone 5 of the theme system
plan (`/Users/matt.ramotar/.claude/plans/gleaming-wobbling-rainbow.md`).

The plan's M5 description ("Wave-1 chrome migration: 33 files / ~1,050 instances")
was based on an unscoped grep that conflated three very different categories:

1. **Built-in theme definitions** — every preset's chrome tokens are themselves
   `NSColor(hex: "#...")` calls. These are intentional and load-bearing; they
   are the *source* of truth the migration is migrating toward.
2. **GhosttyConfig defaults** — the `GhosttyConfig` struct's stored-property
   defaults are hex literals. Same reasoning: they're the canonical "what does
   the terminal look like before the user picks anything" baseline.
3. **Chrome consumers** — call sites that *read* a color and use it to paint
   something. These are the only candidates for migration to the token system.

After auditing the tree the actual debt is much smaller than the plan estimated.

## File-by-file inventory (as of 2026-05-16)

### Sources/BuiltInThemes.swift — 248 calls — **NOT DEBT**
The eight curated presets each contain ~30 `NSColor(hex:)` calls. These are the
source of truth for chrome tokens. Future presets add more; existing ones don't
get touched.

### Sources/GhosttyConfig.swift — 18 calls — **NOT DEBT**
The `GhosttyConfig` struct's stored-property defaults — the "Ghostty fallback
when no theme file exists" baseline. These are read once at app launch and
projected into the active `SuperghostTheme` via `SuperghostTheme.fromGhosttyConfig`.
They should stay as literals because they describe Ghostty's defaults, not
Superghost's chrome.

### Sources/SuperghostTheme.swift — 2 calls — **NOT DEBT**
Inside `SuperghostTheme.fromGhosttyConfig` — fallback values for chrome tokens
when projecting from a Ghostty-only config (which has no chrome). These are the
boot-strap path that lets a raw Ghostty config show as a theme; M7's
`deriveChromeFrom` is the post-MVP replacement.

### Sources/TabManager.swift — 2 calls — **NOT DEBT**
Both calls parse user-supplied hex strings (per-workspace tab color). Not
literals.

### Sources/cmuxApp.swift — 10 calls — **NOT DEBT (already wired via M5)**
All 10 calls read from one of the legacy UserDefaults keys: `sidebarTintHex`,
`sidebarTintHexLight`, `sidebarTintHexDark`, `sidebarSelectionColorHex`,
`sidebarNotificationBadgeColorHex`, `bgGlassTintHex`. Of these, the four sidebar
keys are now written by `ThemeStore.applyToLegacySidebarDefaults(theme:)` on
every `applyTheme(_:)` call, so a preset switch flows through to these readers
without changing the readers themselves.

`bgGlassTintHex` is the only one not yet wired to ThemeStore. The user-controlled
glass tint slider lives outside the theme system today; M6's footer-action work
is the place to decide whether to route it through `ThemeStore.activeTheme.tokens`
or keep it as an independent user override.

### Sources/ContentView.swift — 10 calls — **PARTIALLY DEBT**

| Line  | Literal     | Category                                                  | Status |
|-------|-------------|-----------------------------------------------------------|--------|
| 40    | `#CDD6F4`   | Catppuccin text on accent (selected workspace label fg)   | DEBT — see below |
| 126   | (param)     | `sidebarSelectionColorHex` UserDefaults read              | wired via M5 |
| 131   | `#393C49`   | Pre-theme-system sidebar selection fallback (dark)        | DEFENSIVE — see below |
| 2456  | `#CDD6F4`   | Same as line 40, second use site                          | DEBT — same |
| 3210  | (param)     | `bgGlassTintHex` UserDefaults read                        | M6 candidate |
| 3461  | (param)     | `bgGlassTintHex` UserDefaults read                        | M6 candidate |
| 11149 | (param)     | `sidebarNotificationBadgeColorHex` UserDefaults read      | wired via M5 |
| 11898 | (param)     | `sidebarSelectionColorHex` UserDefaults read              | wired via M5 |
| 11960 | (param)     | Workspace tab color fallback (user-supplied)              | N/A |
| 13925 | (param)     | `sidebarTintHex` UserDefaults read                        | wired via M5 |

The two `#CDD6F4` calls are the only chrome literals (not user-supplied, not
theme-system internals) outstanding. They paint the selected workspace label
foreground; today they hardcode the Catppuccin Mocha text color. M6 should
replace both with `ThemeStore.shared.snapshot().tokens.inkHeadline` (or whatever
ink step matches the original design intent, which the original commit doesn't
record).

The `#393C49` literal at line 131 is the pre-theme-system default for the dark
sidebar selection. Since M5, `ThemeStore.init` seeds
`sidebarSelectionColorHex` from the active theme's `accentInline`, so this
literal is only reached if both the UserDefaults read and the parse fail. It's
defensive code, not migration debt — kept as a safety net for corrupted
defaults. See the comment at the call site.

## Summary

| Category                                                       | Count |
|----------------------------------------------------------------|------:|
| Theme system source-of-truth literals (intentional)            |   268 |
| User-supplied hex parsers (not literals)                       |     4 |
| UserDefaults consumers wired by `applyToLegacySidebarDefaults` |    14 |
| `bgGlassTintHex` consumers (M6 candidates)                     |     3 |
| Actual chrome migration debt                                   |   **2** |

The "actual debt" line is the two `#CDD6F4` text-foreground uses in ContentView.
Everything else either is itself the theme definition, reads from a wired key,
or parses user input. The plan's 1,050-instance estimate was off by ~3 orders
of magnitude because it counted (1) and (2).

## Migration policy

For any new chrome literal, prefer one of (in order):

1. Read from `ThemeStore.shared.snapshot().tokens.<token>` directly. Best for
   AppKit hot paths where `@EnvironmentObject` isn't practical.
2. Read from `themeStore.activeTheme.tokens.<token>` via SwiftUI
   `@EnvironmentObject`. Best for SwiftUI views in the panel chrome.
3. If the value must persist across app launches (Sparkle update mid-paint,
   first-frame paint before `ThemeStore` initializes), add a new
   UserDefaults key and write it from
   `ThemeStore.applyToLegacySidebarDefaults(theme:)` so the key tracks the
   active theme. Document the new key in `Sources/cmuxApp.swift` alongside the
   existing four.

Never add a new hex literal that's not a theme definition without updating
this document and explaining why a token doesn't fit.
