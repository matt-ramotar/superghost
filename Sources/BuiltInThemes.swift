import Foundation
import AppKit

// Curated built-in themes shipped with Superghost. The Milestone 2 walking skeleton needs
// at least two themes (one dark, one light) to prove the architecture; Milestone 4 grows
// this to the full 8–12 set per handoff §2 and validates contrast on every chrome token.
//
// Color values for each theme come from:
//   - Tokyo Night: handoff §2 "Token Architecture", values are the published Tokyo Night
//     palette (https://github.com/folke/tokyonight.nvim) with chrome derived for the
//     specific ladder Matt's prototype calls out.
//   - Catppuccin Latte: published Catppuccin Latte palette
//     (https://github.com/catppuccin/catppuccin#-palette) with chrome chosen to mirror the
//     Tokyo Night ladder in the inverse direction.
//
// Both are *fully specified* (not derived). That's the contract M4 codifies for every
// built-in: ship every chrome token with a hand-chosen value so the curated set is the
// reference for what "good" looks like.
enum BuiltInThemes {
    static var all: [SuperghostTheme] {
        [tokyoNight, catppuccinLatte]
    }

    static let tokyoNight = SuperghostTheme(
        id: "tokyo-night",
        name: "Tokyo Night",
        mode: .dark,
        source: .builtIn,
        backgroundColor: NSColor(hex: "#1a1b26")!,
        foregroundColor: NSColor(hex: "#c0caf5")!,
        cursorColor: NSColor(hex: "#7aa2f7")!,
        cursorTextColor: NSColor(hex: "#1a1b26")!,
        selectionBackground: NSColor(hex: "#283457")!,
        selectionForeground: NSColor(hex: "#c0caf5")!,
        palette: [
            0: NSColor(hex: "#15161e")!,
            1: NSColor(hex: "#f7768e")!,
            2: NSColor(hex: "#9ece6a")!,
            3: NSColor(hex: "#e0af68")!,
            4: NSColor(hex: "#7aa2f7")!,
            5: NSColor(hex: "#bb9af7")!,
            6: NSColor(hex: "#7dcfff")!,
            7: NSColor(hex: "#a9b1d6")!,
            8: NSColor(hex: "#414868")!,
            9: NSColor(hex: "#f7768e")!,
            10: NSColor(hex: "#9ece6a")!,
            11: NSColor(hex: "#e0af68")!,
            12: NSColor(hex: "#7aa2f7")!,
            13: NSColor(hex: "#bb9af7")!,
            14: NSColor(hex: "#7dcfff")!,
            15: NSColor(hex: "#c0caf5")!
        ],
        cardSurface: NSColor(hex: "#1a1b26")!,
        liftedSurface: NSColor(hex: "#1f2335")!,
        hairlineBorder: NSColor(hex: "#2f334d")!,
        hairlineBorderHover: NSColor(hex: "#3d4263")!,
        inkHeadline: NSColor(hex: "#c0caf5")!,
        inkBody: NSColor(hex: "#a9b1d6")!,
        // Bumped from the handoff's #565f89 (R1 in the plan — fails AA on caption sizes).
        // The plan defers this to M6; we ship the safe value from the start so the walking
        // skeleton already meets AA. Documented in the plan-fix log.
        inkMuted: NSColor(hex: "#737aa2")!,
        inkCaption: NSColor(hex: "#737aa2")!,
        accentSolid: NSColor(hex: "#3d59a1")!,
        accentInline: NSColor(hex: "#7aa2f7")!,
        semanticSuccess: NSColor(hex: "#1a2b25")!,
        semanticWarning: NSColor(hex: "#3d3328")!,
        semanticDanger: NSColor(hex: "#3c2c3a")!,
        semanticInfo: NSColor(hex: "#16263a")!,
        semanticSkill: NSColor(hex: "#3d4263")!,
        translucentSidebar: true,
        contrastBoost: 68
    )

    static let catppuccinLatte = SuperghostTheme(
        id: "catppuccin-latte",
        name: "Catppuccin Latte",
        mode: .light,
        source: .builtIn,
        backgroundColor: NSColor(hex: "#eff1f5")!,
        foregroundColor: NSColor(hex: "#4c4f69")!,
        cursorColor: NSColor(hex: "#1e66f5")!,
        cursorTextColor: NSColor(hex: "#eff1f5")!,
        selectionBackground: NSColor(hex: "#bcc0cc")!,
        selectionForeground: NSColor(hex: "#4c4f69")!,
        palette: [
            0: NSColor(hex: "#5c5f77")!,
            1: NSColor(hex: "#d20f39")!,
            2: NSColor(hex: "#40a02b")!,
            3: NSColor(hex: "#df8e1d")!,
            4: NSColor(hex: "#1e66f5")!,
            5: NSColor(hex: "#ea76cb")!,
            6: NSColor(hex: "#179299")!,
            7: NSColor(hex: "#acb0be")!,
            8: NSColor(hex: "#6c6f85")!,
            9: NSColor(hex: "#d20f39")!,
            10: NSColor(hex: "#40a02b")!,
            11: NSColor(hex: "#df8e1d")!,
            12: NSColor(hex: "#1e66f5")!,
            13: NSColor(hex: "#ea76cb")!,
            14: NSColor(hex: "#179299")!,
            15: NSColor(hex: "#bcc0cc")!
        ],
        cardSurface: NSColor(hex: "#e6e9ef")!,
        liftedSurface: NSColor(hex: "#dce0e8")!,
        hairlineBorder: NSColor(hex: "#ccd0da")!,
        hairlineBorderHover: NSColor(hex: "#bcc0cc")!,
        inkHeadline: NSColor(hex: "#4c4f69")!,
        inkBody: NSColor(hex: "#5c5f77")!,
        inkMuted: NSColor(hex: "#6c6f85")!,
        inkCaption: NSColor(hex: "#7c7f93")!,
        accentSolid: NSColor(hex: "#1e66f5")!,
        accentInline: NSColor(hex: "#1e66f5")!,
        semanticSuccess: NSColor(hex: "#d9eedb")!,
        semanticWarning: NSColor(hex: "#f5e6c8")!,
        semanticDanger: NSColor(hex: "#f5d6dc")!,
        semanticInfo: NSColor(hex: "#d7e3fc")!,
        semanticSkill: NSColor(hex: "#e0e3ef")!,
        translucentSidebar: true,
        contrastBoost: 60
    )

    // Resolve a preset by id. Used by `ThemeStore` and `AppearanceSection`.
    static func preset(withId id: String) -> SuperghostTheme? {
        all.first(where: { $0.id == id })
    }

    // Default theme to apply for a given color scheme when the user hasn't picked one yet.
    static func defaultPreset(for mode: ThemeMode) -> SuperghostTheme {
        switch mode {
        case .dark: return tokyoNight
        case .light: return catppuccinLatte
        }
    }
}
