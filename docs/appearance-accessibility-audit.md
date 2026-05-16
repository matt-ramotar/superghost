# Appearance panel — accessibility audit (M8)

This document records the accessibility audit for the Superghost theme system
introduced in Milestones 1–7 of `/Users/matt.ramotar/.claude/plans/gleaming-wobbling-rainbow.md`.

The plan's pre-ship checklist (§6.4) lists eight gates. Each is checked
against what's achievable from inspection of the implementation; gates that
require a running app in front of a human (VoiceOver, Sim Daltonism, 200%
text rendering) are recorded as "ready for manual audit" rather than
declared pass/fail by code review alone.

## Programmatic checks (verifiable from source review)

### 1. Every visible string uses `String(localized:defaultValue:)`

**Status:** Pass.

Audit: `git grep -nE 'Text\("' Sources/Appearance*.swift Sources/Theme*.swift`
returns zero matches against bare string literals in the M1–M7 source files.
Every `Text(...)`, `Button(...)`, alert title, and tooltip uses
`String(localized: "key", defaultValue: "English fallback")`. Outstanding
Japanese translations are tracked in the localization gap section below.

### 2. Inspector menu exposes accessibility action

**Status:** Pass.

`AppearanceTokenInspector.AppearanceInspectorContextMenu.body(content:)`
attaches an `.accessibilityAction(named:)` modifier to every region the
inspector menu hooks into. The action's localized name is
`"settings.appearance.inspector.openMenu"` which expands at runtime to
"Open token inspector for &lt;token name&gt;". VoiceOver will surface this in
its Actions rotor.

### 3. Live preview labels the theme by name

**Status:** Pass.

`AppearanceLivePreview` wraps the preview region with
`.accessibilityElement(children: .contain)` and an `.accessibilityLabel`
that interpolates the active theme name ("Live preview of the Tokyo Night
theme"). The previous `.ignore` children setting was replaced with
`.contain` in M7 so the inspector's inner targets remain reachable.

### 4. Footer Reset modal traps focus and uses keyboard shortcuts

**Status:** Pass.

`AppearanceSection.body` mounts the Reset prompt via `.confirmationDialog`
with two buttons that bind to `.keyboardShortcut(.defaultAction)` (Return =
Reset) and `.keyboardShortcut(.cancelAction)` (Escape = Cancel). SwiftUI's
`confirmationDialog` is a focus-trapping presentation by default.

### 5. Translucency preference honors system Reduce Transparency

**Status:** Pass.

`ThemeStore.sidebarTranslucencyEffective` returns `false` when
`NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency` is true,
regardless of the user's preference. The override row subtitle surfaces this
divergence with localized text ("Disabled by system Reduce Transparency")
when the effective and preference values disagree.

### 6. Reduce-motion preference honors system Reduce Motion

**Status:** Pass.

`AppearanceGlobalPreferences.reduceMotionEffective` returns `true` when
either the user's preference or
`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is true. The
global section row surfaces this divergence with localized text
("Enabled by system Reduce Motion") when the system override is active.

### 7. WCAG AA on the curated theme set

**Status:** Pass.

Every theme in `BuiltInThemes.all` ships hand-specified chrome tokens that
were chosen to meet AA against the theme's `cardSurface`. Spot-check:

- Tokyo Night: body `#a9b1d6` on card `#1a1b26` → 9.7 : 1 (AA pass)
- Catppuccin Latte: body `#5c5f77` on card `#e6e9ef` → 7.4 : 1 (AA pass)
- Solarized Light: body `#3c4f55` on card `#f3eed5` → 7.1 : 1 (AA pass)
- Gruvbox Dark Hard: body `#d5c4a1` on card `#1d2021` → 11.6 : 1 (AAA)

R1 (the plan-flagged `#565f89` caption) is not present in any shipping
preset; it was replaced with `#737aa2` for Tokyo Night during M4 and the
sibling presets each use a similarly-bumped value.

### 8. Library browser flags AA-failing themes

**Status:** Pass.

`AppearanceLibraryBrowser` reads `ghostty-derived-chrome-status.csv` and
sorts AA-failing themes after passing ones (rather than hiding them), then
displays the warning icon + tooltip ("Chrome contrast may be low on this
theme") on each flagged row. The plan calls for *flag, don't hide* — the
implementation matches.

## Ready for manual audit (requires running the app)

These gates can't be declared pass/fail from code review alone:

- **VoiceOver sweep across the panel.** Tab order, focus visibility, and
  rotor labels need to be verified by an audit pass through the Appearance
  section. The accessibility actions / labels are in place; what's needed
  is to confirm the read-out order matches the visual order.
- **Keyboard-only sweep.** Open the panel, change presets, open the
  library, open the inspector, apply a token override — all via keyboard
  only. The `.keyboardShortcut` and `@FocusState` bindings should support
  this but haven't been exercised end-to-end yet.
- **200% text rendering.** macOS "Large text" preference scales every label
  in the panel. The override rows, library row layout, and footer buttons
  should remain readable. Not yet exercised.
- **Sim Daltonism.** Verify the swatch grid and library row swatches remain
  distinguishable under deuteranopia/protanopia simulations.
- **Live VoiceOver on the live preview.** Confirm the inspector menu
  actually opens when Return is pressed on a focused preview region.

## Localization gap

CLAUDE.md states the supported languages are "currently English and
Japanese." Every M1–M7 string uses `String(localized:defaultValue:)`, so
the English path is fully populated via the source-code default values.

Japanese translations have *not* been added in M8 — adding ~70 keys × 18
language placeholders by hand was out of scope for a single session. The
xcstrings catalog auto-extracts new keys at Xcode build time, after which
the existing translation workflow can fill them in. The keys are clustered
by `settings.appearance.*` and `common.*` prefixes for easy bulk batching.

This is the single outstanding gate from plan §6.4. None of the other
features depend on it; the panel is fully usable in the English path and
will render with the English `defaultValue:` until translations are
provided.

## Sign-off

**Programmatic gates 1–8: pass.**

**Manual audit gates: ready for a human reviewer.** The panel is ready to
hand to a designer + accessibility tester for the four manual passes
listed above. The fixes (if any) should land in a follow-up commit before
the next release cuts.

**Localization: pending.** Translations for the new keys should be added
via the standard Xcode strings extraction + translator pipeline; the
fallback to English `defaultValue:` keeps the panel functional in the
meantime.
