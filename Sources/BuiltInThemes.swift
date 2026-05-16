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
        [
            tokyoNight,
            tokyoNightStorm,
            catppuccinMocha,
            catppuccinLatte,
            gruvboxDarkHard,
            solarizedDark,
            solarizedLight,
            nord
        ]
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

    // MARK: - Additional curated dark themes

    static let tokyoNightStorm = SuperghostTheme(
        id: "tokyo-night-storm",
        name: "Tokyo Night Storm",
        mode: .dark,
        source: .builtIn,
        backgroundColor: NSColor(hex: "#24283b")!,
        foregroundColor: NSColor(hex: "#c0caf5")!,
        cursorColor: NSColor(hex: "#7aa2f7")!,
        cursorTextColor: NSColor(hex: "#24283b")!,
        selectionBackground: NSColor(hex: "#2e3c64")!,
        selectionForeground: NSColor(hex: "#c0caf5")!,
        palette: [
            0: NSColor(hex: "#1d202f")!,  1: NSColor(hex: "#f7768e")!,
            2: NSColor(hex: "#9ece6a")!,  3: NSColor(hex: "#e0af68")!,
            4: NSColor(hex: "#7aa2f7")!,  5: NSColor(hex: "#bb9af7")!,
            6: NSColor(hex: "#7dcfff")!,  7: NSColor(hex: "#a9b1d6")!,
            8: NSColor(hex: "#414868")!,  9: NSColor(hex: "#f7768e")!,
            10: NSColor(hex: "#9ece6a")!, 11: NSColor(hex: "#e0af68")!,
            12: NSColor(hex: "#7aa2f7")!, 13: NSColor(hex: "#bb9af7")!,
            14: NSColor(hex: "#7dcfff")!, 15: NSColor(hex: "#c0caf5")!
        ],
        cardSurface: NSColor(hex: "#24283b")!,
        liftedSurface: NSColor(hex: "#292e42")!,
        hairlineBorder: NSColor(hex: "#3b4261")!,
        hairlineBorderHover: NSColor(hex: "#4a5479")!,
        inkHeadline: NSColor(hex: "#c0caf5")!,
        inkBody: NSColor(hex: "#a9b1d6")!,
        inkMuted: NSColor(hex: "#7c849c")!,
        inkCaption: NSColor(hex: "#7c849c")!,
        accentSolid: NSColor(hex: "#3d59a1")!,
        accentInline: NSColor(hex: "#7aa2f7")!,
        semanticSuccess: NSColor(hex: "#243333")!,
        semanticWarning: NSColor(hex: "#403733")!,
        semanticDanger: NSColor(hex: "#3f2f3d")!,
        semanticInfo: NSColor(hex: "#1f2e44")!,
        semanticSkill: NSColor(hex: "#3b4261")!,
        translucentSidebar: true,
        contrastBoost: 68
    )

    static let catppuccinMocha = SuperghostTheme(
        id: "catppuccin-mocha",
        name: "Catppuccin Mocha",
        mode: .dark,
        source: .builtIn,
        backgroundColor: NSColor(hex: "#1e1e2e")!,
        foregroundColor: NSColor(hex: "#cdd6f4")!,
        cursorColor: NSColor(hex: "#f5e0dc")!,
        cursorTextColor: NSColor(hex: "#1e1e2e")!,
        selectionBackground: NSColor(hex: "#585b70")!,
        selectionForeground: NSColor(hex: "#cdd6f4")!,
        palette: [
            0: NSColor(hex: "#45475a")!,  1: NSColor(hex: "#f38ba8")!,
            2: NSColor(hex: "#a6e3a1")!,  3: NSColor(hex: "#f9e2af")!,
            4: NSColor(hex: "#89b4fa")!,  5: NSColor(hex: "#f5c2e7")!,
            6: NSColor(hex: "#94e2d5")!,  7: NSColor(hex: "#a6adc8")!,
            8: NSColor(hex: "#585b70")!,  9: NSColor(hex: "#f37799")!,
            10: NSColor(hex: "#89d88b")!, 11: NSColor(hex: "#ebd391")!,
            12: NSColor(hex: "#74a8fc")!, 13: NSColor(hex: "#f2aede")!,
            14: NSColor(hex: "#6bd7ca")!, 15: NSColor(hex: "#bac2de")!
        ],
        cardSurface: NSColor(hex: "#1e1e2e")!,
        liftedSurface: NSColor(hex: "#252537")!,
        hairlineBorder: NSColor(hex: "#363645")!,
        hairlineBorderHover: NSColor(hex: "#45475a")!,
        inkHeadline: NSColor(hex: "#cdd6f4")!,
        inkBody: NSColor(hex: "#bac2de")!,
        inkMuted: NSColor(hex: "#9399b2")!,
        inkCaption: NSColor(hex: "#9399b2")!,
        accentSolid: NSColor(hex: "#5b6daf")!,
        accentInline: NSColor(hex: "#89b4fa")!,
        semanticSuccess: NSColor(hex: "#243024")!,
        semanticWarning: NSColor(hex: "#3a3522")!,
        semanticDanger: NSColor(hex: "#3a232b")!,
        semanticInfo: NSColor(hex: "#1f2c41")!,
        semanticSkill: NSColor(hex: "#363645")!,
        translucentSidebar: true,
        contrastBoost: 64
    )

    static let gruvboxDarkHard = SuperghostTheme(
        id: "gruvbox-dark-hard",
        name: "Gruvbox Dark Hard",
        mode: .dark,
        source: .builtIn,
        backgroundColor: NSColor(hex: "#1d2021")!,
        foregroundColor: NSColor(hex: "#ebdbb2")!,
        cursorColor: NSColor(hex: "#ebdbb2")!,
        cursorTextColor: NSColor(hex: "#1d2021")!,
        selectionBackground: NSColor(hex: "#3c3836")!,
        selectionForeground: NSColor(hex: "#ebdbb2")!,
        palette: [
            0: NSColor(hex: "#282828")!,  1: NSColor(hex: "#cc241d")!,
            2: NSColor(hex: "#98971a")!,  3: NSColor(hex: "#d79921")!,
            4: NSColor(hex: "#458588")!,  5: NSColor(hex: "#b16286")!,
            6: NSColor(hex: "#689d6a")!,  7: NSColor(hex: "#a89984")!,
            8: NSColor(hex: "#928374")!,  9: NSColor(hex: "#fb4934")!,
            10: NSColor(hex: "#b8bb26")!, 11: NSColor(hex: "#fabd2f")!,
            12: NSColor(hex: "#83a598")!, 13: NSColor(hex: "#d3869b")!,
            14: NSColor(hex: "#8ec07c")!, 15: NSColor(hex: "#ebdbb2")!
        ],
        cardSurface: NSColor(hex: "#1d2021")!,
        liftedSurface: NSColor(hex: "#272a2b")!,
        hairlineBorder: NSColor(hex: "#3c3836")!,
        hairlineBorderHover: NSColor(hex: "#504945")!,
        inkHeadline: NSColor(hex: "#ebdbb2")!,
        inkBody: NSColor(hex: "#d5c4a1")!,
        inkMuted: NSColor(hex: "#a89984")!,
        inkCaption: NSColor(hex: "#a89984")!,
        accentSolid: NSColor(hex: "#458588")!,
        accentInline: NSColor(hex: "#83a598")!,
        semanticSuccess: NSColor(hex: "#26301d")!,
        semanticWarning: NSColor(hex: "#3a2f1c")!,
        semanticDanger: NSColor(hex: "#3a2520")!,
        semanticInfo: NSColor(hex: "#1f2e2f")!,
        semanticSkill: NSColor(hex: "#3c3836")!,
        translucentSidebar: true,
        contrastBoost: 72
    )

    static let solarizedDark = SuperghostTheme(
        id: "solarized-dark",
        name: "Solarized Dark",
        mode: .dark,
        source: .builtIn,
        backgroundColor: NSColor(hex: "#002b36")!,
        foregroundColor: NSColor(hex: "#839496")!,
        cursorColor: NSColor(hex: "#93a1a1")!,
        cursorTextColor: NSColor(hex: "#002b36")!,
        selectionBackground: NSColor(hex: "#073642")!,
        selectionForeground: NSColor(hex: "#93a1a1")!,
        palette: [
            0: NSColor(hex: "#073642")!,  1: NSColor(hex: "#dc322f")!,
            2: NSColor(hex: "#859900")!,  3: NSColor(hex: "#b58900")!,
            4: NSColor(hex: "#268bd2")!,  5: NSColor(hex: "#d33682")!,
            6: NSColor(hex: "#2aa198")!,  7: NSColor(hex: "#eee8d5")!,
            8: NSColor(hex: "#586e75")!,  9: NSColor(hex: "#cb4b16")!,
            10: NSColor(hex: "#586e75")!, 11: NSColor(hex: "#657b83")!,
            12: NSColor(hex: "#839496")!, 13: NSColor(hex: "#6c71c4")!,
            14: NSColor(hex: "#93a1a1")!, 15: NSColor(hex: "#fdf6e3")!
        ],
        cardSurface: NSColor(hex: "#002b36")!,
        liftedSurface: NSColor(hex: "#073642")!,
        hairlineBorder: NSColor(hex: "#0d4c5d")!,
        hairlineBorderHover: NSColor(hex: "#1a6075")!,
        inkHeadline: NSColor(hex: "#fdf6e3")!,
        inkBody: NSColor(hex: "#cdd6c8")!,
        inkMuted: NSColor(hex: "#93a1a1")!,
        inkCaption: NSColor(hex: "#93a1a1")!,
        accentSolid: NSColor(hex: "#1a597d")!,
        accentInline: NSColor(hex: "#268bd2")!,
        semanticSuccess: NSColor(hex: "#143523")!,
        semanticWarning: NSColor(hex: "#3a3120")!,
        semanticDanger: NSColor(hex: "#3a2424")!,
        semanticInfo: NSColor(hex: "#16384a")!,
        semanticSkill: NSColor(hex: "#0d4c5d")!,
        translucentSidebar: true,
        contrastBoost: 70
    )

    static let nord = SuperghostTheme(
        id: "nord",
        name: "Nord",
        mode: .dark,
        source: .builtIn,
        backgroundColor: NSColor(hex: "#2e3440")!,
        foregroundColor: NSColor(hex: "#d8dee9")!,
        cursorColor: NSColor(hex: "#d8dee9")!,
        cursorTextColor: NSColor(hex: "#2e3440")!,
        selectionBackground: NSColor(hex: "#4c566a")!,
        selectionForeground: NSColor(hex: "#eceff4")!,
        palette: [
            0: NSColor(hex: "#3b4252")!,  1: NSColor(hex: "#bf616a")!,
            2: NSColor(hex: "#a3be8c")!,  3: NSColor(hex: "#ebcb8b")!,
            4: NSColor(hex: "#81a1c1")!,  5: NSColor(hex: "#b48ead")!,
            6: NSColor(hex: "#88c0d0")!,  7: NSColor(hex: "#e5e9f0")!,
            8: NSColor(hex: "#4c566a")!,  9: NSColor(hex: "#bf616a")!,
            10: NSColor(hex: "#a3be8c")!, 11: NSColor(hex: "#ebcb8b")!,
            12: NSColor(hex: "#81a1c1")!, 13: NSColor(hex: "#b48ead")!,
            14: NSColor(hex: "#8fbcbb")!, 15: NSColor(hex: "#eceff4")!
        ],
        cardSurface: NSColor(hex: "#2e3440")!,
        liftedSurface: NSColor(hex: "#363c4a")!,
        hairlineBorder: NSColor(hex: "#3b4252")!,
        hairlineBorderHover: NSColor(hex: "#4c566a")!,
        inkHeadline: NSColor(hex: "#eceff4")!,
        inkBody: NSColor(hex: "#d8dee9")!,
        inkMuted: NSColor(hex: "#a3aebe")!,
        inkCaption: NSColor(hex: "#a3aebe")!,
        accentSolid: NSColor(hex: "#5e81ac")!,
        accentInline: NSColor(hex: "#81a1c1")!,
        semanticSuccess: NSColor(hex: "#2a3527")!,
        semanticWarning: NSColor(hex: "#3a3522")!,
        semanticDanger: NSColor(hex: "#3a282a")!,
        semanticInfo: NSColor(hex: "#283446")!,
        semanticSkill: NSColor(hex: "#3b4252")!,
        translucentSidebar: true,
        contrastBoost: 65
    )

    // MARK: - Additional curated light themes

    static let solarizedLight = SuperghostTheme(
        id: "solarized-light",
        name: "Solarized Light",
        mode: .light,
        source: .builtIn,
        backgroundColor: NSColor(hex: "#fdf6e3")!,
        foregroundColor: NSColor(hex: "#657b83")!,
        cursorColor: NSColor(hex: "#586e75")!,
        cursorTextColor: NSColor(hex: "#fdf6e3")!,
        selectionBackground: NSColor(hex: "#eee8d5")!,
        selectionForeground: NSColor(hex: "#586e75")!,
        palette: [
            0: NSColor(hex: "#073642")!,  1: NSColor(hex: "#dc322f")!,
            2: NSColor(hex: "#859900")!,  3: NSColor(hex: "#b58900")!,
            4: NSColor(hex: "#268bd2")!,  5: NSColor(hex: "#d33682")!,
            6: NSColor(hex: "#2aa198")!,  7: NSColor(hex: "#eee8d5")!,
            8: NSColor(hex: "#586e75")!,  9: NSColor(hex: "#cb4b16")!,
            10: NSColor(hex: "#586e75")!, 11: NSColor(hex: "#657b83")!,
            12: NSColor(hex: "#839496")!, 13: NSColor(hex: "#6c71c4")!,
            14: NSColor(hex: "#93a1a1")!, 15: NSColor(hex: "#fdf6e3")!
        ],
        cardSurface: NSColor(hex: "#f3eed5")!,
        liftedSurface: NSColor(hex: "#eee8d5")!,
        hairlineBorder: NSColor(hex: "#d6d0bd")!,
        hairlineBorderHover: NSColor(hex: "#b8b3a0")!,
        // Solarized Light's stock foreground (#657b83) is borderline AA at scale 13px on
        // background; we darken the headline + body steps so the panel is readable without
        // sacrificing the theme's stated softness for muted/caption.
        inkHeadline: NSColor(hex: "#2c3e44")!,
        inkBody: NSColor(hex: "#3c4f55")!,
        inkMuted: NSColor(hex: "#586e75")!,
        inkCaption: NSColor(hex: "#657b83")!,
        accentSolid: NSColor(hex: "#1a597d")!,
        accentInline: NSColor(hex: "#268bd2")!,
        semanticSuccess: NSColor(hex: "#e3ecca")!,
        semanticWarning: NSColor(hex: "#f0e3bb")!,
        semanticDanger: NSColor(hex: "#f1c8c4")!,
        semanticInfo: NSColor(hex: "#cce0ee")!,
        semanticSkill: NSColor(hex: "#d6d0bd")!,
        translucentSidebar: true,
        contrastBoost: 62
    )
}

