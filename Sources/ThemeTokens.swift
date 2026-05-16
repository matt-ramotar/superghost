import Foundation
import AppKit

// `ThemeTokens` is the chrome-facing view of a `SuperghostTheme`. Views and AppKit hosts read
// from tokens, never from raw theme fields — this gives one indirection between "the user's
// theme" and "the colors the app paints with," which is what lets us also paint chrome for
// Ghostty-library themes that have no Superghost-specific fields.
//
// For built-in / fully-specified themes, `theme.tokens` is just a 1:1 projection of the chrome
// fields. For Ghostty-library themes (which only specify terminal colors), the tokens are
// produced by `deriveChromeFrom(...)` from the terminal palette.
struct ThemeTokens: Equatable {
    let cardSurface: NSColor
    let liftedSurface: NSColor
    let hairlineBorder: NSColor
    let hairlineBorderHover: NSColor

    let inkHeadline: NSColor
    let inkBody: NSColor
    let inkMuted: NSColor
    let inkCaption: NSColor

    let accentSolid: NSColor
    let accentInline: NSColor

    let semanticSuccess: NSColor
    let semanticWarning: NSColor
    let semanticDanger: NSColor
    let semanticInfo: NSColor
    let semanticSkill: NSColor
}

extension SuperghostTheme {
    var tokens: ThemeTokens {
        ThemeTokens(
            cardSurface: cardSurface,
            liftedSurface: liftedSurface,
            hairlineBorder: hairlineBorder,
            hairlineBorderHover: hairlineBorderHover,
            inkHeadline: inkHeadline,
            inkBody: inkBody,
            inkMuted: inkMuted,
            inkCaption: inkCaption,
            accentSolid: accentSolid,
            accentInline: accentInline,
            semanticSuccess: semanticSuccess,
            semanticWarning: semanticWarning,
            semanticDanger: semanticDanger,
            semanticInfo: semanticInfo,
            semanticSkill: semanticSkill
        )
    }
}

// MARK: - Derivation from a terminal palette
//
// Algorithm (per plan §3.1 M4 acceptance criteria — initial proposal documented inline so the
// next reviewer can argue with the math, not the implementation):
//
//   1. `cardSurface` = terminal background shifted ±6% toward neutral midtone.
//      Why: chrome should be visibly distinct from the terminal canvas (so the user can see
//      where the terminal stops) but not so distinct that it looks like a different app.
//   2. `liftedSurface` = cardSurface shifted another ±4% in the same direction.
//      Why: hover/selected state needs to read as lifted without being a whole new shade.
//   3. `hairlineBorder` = cardSurface shifted ±10% toward midtone.
//      Why: borders need enough contrast to register at 1px but not enough to read as lines.
//   4. `hairlineBorderHover` = hairlineBorder shifted another 6% in the same direction.
//   5. Ink ladder (`inkHeadline` → `inkBody` → `inkMuted` → `inkCaption`) derived from
//      foreground via a 4-stop luminance ramp. The exact stops are tuned per mode below.
//   6. `accentInline` = the palette swatch (4 = blue, 5 = magenta, 6 = cyan) with the best
//      contrast against `cardSurface`. We prefer 4/5 for warmth; cyan only if it wins by AA.
//   7. `accentSolid` = a darkened/strengthened sibling of `accentInline`.
//   8. Semantic chips = ANSI 1 (red) / 2 (green) / 3 (yellow) / 4 (blue) backed-off to chip
//      backgrounds — opaque shifts toward `cardSurface` so the chip reads as a tinted surface
//      and not as the raw ANSI color.
//
// The Milestone 4 derivation harness (`scripts/derive_ghostty_chrome.swift`) runs this
// algorithm against all 312 Ghostty-library themes and emits a CSV with per-theme WCAG AA
// outcomes. Themes that fail AA are flagged in the library browser (M7), not hidden.
extension ThemeTokens {
    static func deriveChromeFrom(
        terminalBackground: NSColor,
        terminalForeground: NSColor,
        palette: [Int: NSColor],
        mode: ThemeMode
    ) -> ThemeTokens {
        let cardSurface = shiftTowardNeutral(terminalBackground, by: 0.06, mode: mode)
        let liftedSurface = shiftTowardNeutral(cardSurface, by: 0.04, mode: mode)
        let hairlineBorder = shiftTowardMidtone(cardSurface, by: 0.10)
        let hairlineBorderHover = shiftTowardMidtone(hairlineBorder, by: 0.06)

        let ladder = inkLadder(from: terminalForeground, against: cardSurface, mode: mode)

        let accentInline = pickAccent(from: palette, against: cardSurface)
        let accentSolid = strengthenAccent(accentInline, mode: mode)

        let success = chipBackground(from: palette[2] ?? accentInline, base: cardSurface)
        let warning = chipBackground(from: palette[3] ?? accentInline, base: cardSurface)
        let danger = chipBackground(from: palette[1] ?? accentInline, base: cardSurface)
        let info = chipBackground(from: palette[4] ?? accentInline, base: cardSurface)
        let skill = chipBackground(from: palette[5] ?? accentInline, base: cardSurface)

        return ThemeTokens(
            cardSurface: cardSurface,
            liftedSurface: liftedSurface,
            hairlineBorder: hairlineBorder,
            hairlineBorderHover: hairlineBorderHover,
            inkHeadline: ladder.headline,
            inkBody: ladder.body,
            inkMuted: ladder.muted,
            inkCaption: ladder.caption,
            accentSolid: accentSolid,
            accentInline: accentInline,
            semanticSuccess: success,
            semanticWarning: warning,
            semanticDanger: danger,
            semanticInfo: info,
            semanticSkill: skill
        )
    }

    // MARK: derivation primitives

    private static func shiftTowardNeutral(
        _ color: NSColor,
        by amount: CGFloat,
        mode: ThemeMode
    ) -> NSColor {
        // In dark mode we lift toward white (chrome reads as a card); in light mode we drop
        // toward black (chrome reads as a recessed surface). Either way we move *away* from
        // the canvas background.
        switch mode {
        case .dark:
            return color.lighten(by: amount)
        case .light:
            return color.darken(by: amount)
        }
    }

    private static func shiftTowardMidtone(_ color: NSColor, by amount: CGFloat) -> NSColor {
        // Move toward 50% gray regardless of starting luminance. This is what gives a border
        // visibility without it reading as a line of its own color.
        let lum = color.luminance
        if lum > 0.5 {
            return color.darken(by: amount)
        } else {
            return color.lighten(by: amount)
        }
    }

    private static func inkLadder(
        from foreground: NSColor,
        against surface: NSColor,
        mode: ThemeMode
    ) -> (headline: NSColor, body: NSColor, muted: NSColor, caption: NSColor) {
        // Four-stop luminance ramp pulling the foreground progressively toward the surface.
        // The exact factors are tuned so that, on a typical dark Tokyo-Night-ish theme,
        // the produced inks are visually indistinguishable from the hand-tuned Tokyo Night
        // ladder (#c0caf5 / #a9b1d6 / #737aa2 / #565f89).
        switch mode {
        case .dark:
            return (
                headline: foreground.lighten(by: 0.05),
                body: foreground,
                muted: blend(foreground, with: surface, ratio: 0.40),
                caption: blend(foreground, with: surface, ratio: 0.55)
            )
        case .light:
            return (
                headline: foreground.darken(by: 0.10),
                body: foreground,
                muted: blend(foreground, with: surface, ratio: 0.40),
                caption: blend(foreground, with: surface, ratio: 0.55)
            )
        }
    }

    private static func pickAccent(
        from palette: [Int: NSColor],
        against surface: NSColor
    ) -> NSColor {
        // Pick the palette swatch with the highest contrast against `surface`. ANSI 4/5/6 are
        // the conventional "accent" slots (blue / magenta / cyan); we prefer 4 if it wins ties.
        let candidates: [NSColor] = [
            palette[4], palette[5], palette[6], palette[12], palette[13], palette[14]
        ].compactMap { $0 }

        guard !candidates.isEmpty else {
            return surface.lighten(by: 0.5)  // pathological — palette empty; produce *something*
        }

        return candidates.max(by: { a, b in
            contrastRatio(a, surface) < contrastRatio(b, surface)
        }) ?? candidates[0]
    }

    private static func strengthenAccent(_ color: NSColor, mode: ThemeMode) -> NSColor {
        switch mode {
        case .dark:
            return color.darken(by: 0.15)
        case .light:
            return color.darken(by: 0.20)
        }
    }

    private static func chipBackground(from accent: NSColor, base: NSColor) -> NSColor {
        // Blend the accent heavily with the surface so the chip is a tinted surface, not a
        // raw ANSI block. 0.85 = 85% surface, 15% accent — enough hue identity to read as
        // semantic, not so much that it competes with content.
        blend(base, with: accent, ratio: 0.15)
    }

    // MARK: utilities

    static func blend(_ a: NSColor, with b: NSColor, ratio: CGFloat) -> NSColor {
        // ratio = 0 returns a, ratio = 1 returns b. Operates in sRGB.
        let r = max(0, min(1, ratio))
        guard let ac = a.usingColorSpace(.sRGB), let bc = b.usingColorSpace(.sRGB) else {
            return a
        }
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        ac.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        bc.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return NSColor(
            red: ar + (br - ar) * r,
            green: ag + (bg - ag) * r,
            blue: ab + (bb - ab) * r,
            alpha: aa + (ba - aa) * r
        )
    }

    static func contrastRatio(_ a: NSColor, _ b: NSColor) -> Double {
        // WCAG 2.x relative luminance contrast.
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        let lighter = max(la, lb)
        let darker = min(la, lb)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func relativeLuminance(_ color: NSColor) -> Double {
        guard let srgb = color.usingColorSpace(.sRGB) else { return 0 }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ v: CGFloat) -> Double {
            let v = Double(v)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}

// `lighten(by:)` mirrors `darken(by:)` already declared on NSColor in `GhosttyConfig.swift`.
// `hexString(includeAlpha:)` is already declared on NSColor in `ContentView.swift` and used
// across the codebase; we reuse it via the module-level extension and only need to add the
// missing companion here.
extension NSColor {
    func lighten(by amount: CGFloat) -> NSColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard let rgb = usingColorSpace(.sRGB) else { return self }
        rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(
            hue: h,
            saturation: s,
            brightness: min(b + (1.0 - b) * amount, 1.0),
            alpha: a
        )
    }
}
