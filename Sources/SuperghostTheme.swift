import Foundation
import AppKit

// Schema for a Superghost theme — a strict superset of Ghostty's theme format.
//
// Ghostty themes specify terminal colors only (background, foreground, cursor, ANSI palette).
// Superghost themes additionally specify chrome tokens — the colors that the rest of the app
// uses for sidebar, panels, inks, accent moments, semantic chips, and so on.
//
// A `SuperghostTheme` is the canonical in-memory representation. Persistence happens via:
//   - The Ghostty config file (`~/Library/Application Support/Cmux/config`) for terminal colors,
//     so dotfile users can read/edit them with any text editor.
//   - `appearance.json` (`~/Library/Application Support/Cmux/appearance.json`) for the
//     Superghost-only chrome tokens.
//
// File sync (both directions) is wired in Milestone 3 (AppearanceFileSync). Milestone 1 just
// needs the schema and Codable conformance so the persistence layer can pick it up later.
struct SuperghostTheme: Equatable {
    // Identity
    let id: String
    let name: String
    let mode: ThemeMode
    let source: ThemeSource

    // Terminal colors (synced to the Ghostty config file)
    let backgroundColor: NSColor
    let foregroundColor: NSColor
    let cursorColor: NSColor
    let cursorTextColor: NSColor
    let selectionBackground: NSColor
    let selectionForeground: NSColor
    let palette: [Int: NSColor]   // ANSI 0–15

    // Chrome — surface tokens
    let cardSurface: NSColor          // sidebar / lifted card background
    let liftedSurface: NSColor        // hover / selected row background
    let hairlineBorder: NSColor       // resting border
    let hairlineBorderHover: NSColor  // hover / focus border

    // Chrome — text inks (luminance ladder from prominent to muted)
    let inkHeadline: NSColor
    let inkBody: NSColor
    let inkMuted: NSColor
    let inkCaption: NSColor

    // Chrome — accent moments
    let accentSolid: NSColor   // primary CTA background / focus ring
    let accentInline: NSColor  // inline links, in-flow accent

    // Chrome — semantic chip backgrounds (tinted backgrounds for state pills)
    let semanticSuccess: NSColor
    let semanticWarning: NSColor
    let semanticDanger: NSColor
    let semanticInfo: NSColor
    let semanticSkill: NSColor

    // Per-theme defaults (user-overridable in the Appearance panel)
    let translucentSidebar: Bool
    let contrastBoost: Int   // 0–100; the slider position the theme suggests

    static func == (lhs: SuperghostTheme, rhs: SuperghostTheme) -> Bool {
        // Identity + mode + source is enough — two themes with the same id are conceptually equal.
        // We deliberately don't deep-compare colors so that derived/user-tweaked themes with the
        // same id (e.g. "tokyo-night" with a contrast tweak) compare as the same theme identity.
        lhs.id == rhs.id && lhs.mode == rhs.mode && lhs.source == rhs.source
    }
}

enum ThemeMode: String, Codable, CaseIterable, Equatable {
    case light
    case dark
}

enum ThemeSource: String, Codable, Equatable {
    case builtIn = "built-in"
    case ghosttyLibrary = "ghostty-library"
    case imported
    case userCustom = "user-custom"
}

// MARK: - Codable (file sync support)
//
// NSColor isn't Codable; we round-trip via 6-digit hex strings (no alpha, opaque only — which
// matches every theme we've seen in the Ghostty library and every curated theme we ship).
// If a theme ever needs alpha at the chrome level, the right place to add it is here, not at
// the call sites.

extension SuperghostTheme: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, mode, source
        case backgroundColor = "background_color"
        case foregroundColor = "foreground_color"
        case cursorColor = "cursor_color"
        case cursorTextColor = "cursor_text_color"
        case selectionBackground = "selection_background"
        case selectionForeground = "selection_foreground"
        case palette
        case cardSurface = "card_surface"
        case liftedSurface = "lifted_surface"
        case hairlineBorder = "hairline_border"
        case hairlineBorderHover = "hairline_border_hover"
        case inkHeadline = "ink_headline"
        case inkBody = "ink_body"
        case inkMuted = "ink_muted"
        case inkCaption = "ink_caption"
        case accentSolid = "accent_solid"
        case accentInline = "accent_inline"
        case semanticSuccess = "semantic_success"
        case semanticWarning = "semantic_warning"
        case semanticDanger = "semantic_danger"
        case semanticInfo = "semantic_info"
        case semanticSkill = "semantic_skill"
        case translucentSidebar = "translucent_sidebar"
        case contrastBoost = "contrast_boost"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        mode = try c.decode(ThemeMode.self, forKey: .mode)
        source = try c.decode(ThemeSource.self, forKey: .source)

        backgroundColor = try Self.decodeColor(c, .backgroundColor)
        foregroundColor = try Self.decodeColor(c, .foregroundColor)
        cursorColor = try Self.decodeColor(c, .cursorColor)
        cursorTextColor = try Self.decodeColor(c, .cursorTextColor)
        selectionBackground = try Self.decodeColor(c, .selectionBackground)
        selectionForeground = try Self.decodeColor(c, .selectionForeground)

        let paletteHexes = try c.decode([String: String].self, forKey: .palette)
        var resolvedPalette: [Int: NSColor] = [:]
        for (key, hex) in paletteHexes {
            guard let index = Int(key), let color = NSColor(hex: hex) else { continue }
            resolvedPalette[index] = color
        }
        palette = resolvedPalette

        cardSurface = try Self.decodeColor(c, .cardSurface)
        liftedSurface = try Self.decodeColor(c, .liftedSurface)
        hairlineBorder = try Self.decodeColor(c, .hairlineBorder)
        hairlineBorderHover = try Self.decodeColor(c, .hairlineBorderHover)
        inkHeadline = try Self.decodeColor(c, .inkHeadline)
        inkBody = try Self.decodeColor(c, .inkBody)
        inkMuted = try Self.decodeColor(c, .inkMuted)
        inkCaption = try Self.decodeColor(c, .inkCaption)
        accentSolid = try Self.decodeColor(c, .accentSolid)
        accentInline = try Self.decodeColor(c, .accentInline)
        semanticSuccess = try Self.decodeColor(c, .semanticSuccess)
        semanticWarning = try Self.decodeColor(c, .semanticWarning)
        semanticDanger = try Self.decodeColor(c, .semanticDanger)
        semanticInfo = try Self.decodeColor(c, .semanticInfo)
        semanticSkill = try Self.decodeColor(c, .semanticSkill)

        translucentSidebar = try c.decode(Bool.self, forKey: .translucentSidebar)
        contrastBoost = try c.decode(Int.self, forKey: .contrastBoost)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(mode, forKey: .mode)
        try c.encode(source, forKey: .source)
        try c.encode(backgroundColor.hexString(), forKey: .backgroundColor)
        try c.encode(foregroundColor.hexString(), forKey: .foregroundColor)
        try c.encode(cursorColor.hexString(), forKey: .cursorColor)
        try c.encode(cursorTextColor.hexString(), forKey: .cursorTextColor)
        try c.encode(selectionBackground.hexString(), forKey: .selectionBackground)
        try c.encode(selectionForeground.hexString(), forKey: .selectionForeground)

        var paletteOut: [String: String] = [:]
        for (index, color) in palette {
            paletteOut[String(index)] = color.hexString()
        }
        try c.encode(paletteOut, forKey: .palette)

        try c.encode(cardSurface.hexString(), forKey: .cardSurface)
        try c.encode(liftedSurface.hexString(), forKey: .liftedSurface)
        try c.encode(hairlineBorder.hexString(), forKey: .hairlineBorder)
        try c.encode(hairlineBorderHover.hexString(), forKey: .hairlineBorderHover)
        try c.encode(inkHeadline.hexString(), forKey: .inkHeadline)
        try c.encode(inkBody.hexString(), forKey: .inkBody)
        try c.encode(inkMuted.hexString(), forKey: .inkMuted)
        try c.encode(inkCaption.hexString(), forKey: .inkCaption)
        try c.encode(accentSolid.hexString(), forKey: .accentSolid)
        try c.encode(accentInline.hexString(), forKey: .accentInline)
        try c.encode(semanticSuccess.hexString(), forKey: .semanticSuccess)
        try c.encode(semanticWarning.hexString(), forKey: .semanticWarning)
        try c.encode(semanticDanger.hexString(), forKey: .semanticDanger)
        try c.encode(semanticInfo.hexString(), forKey: .semanticInfo)
        try c.encode(semanticSkill.hexString(), forKey: .semanticSkill)
        try c.encode(translucentSidebar, forKey: .translucentSidebar)
        try c.encode(contrastBoost, forKey: .contrastBoost)
    }

    private static func decodeColor(
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) throws -> NSColor {
        let hex = try container.decode(String.self, forKey: key)
        guard let color = NSColor(hex: hex) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Invalid hex color '\(hex)' for key \(key.rawValue)"
            )
        }
        return color
    }
}

// MARK: - Bridge from GhosttyConfig (used by ThemeStore on launch and on cache refresh)

extension SuperghostTheme {
    // Build a theme from a parsed `GhosttyConfig`. Chrome tokens are derived because
    // GhosttyConfig only carries terminal colors. Used at launch before the user has
    // explicitly picked a Superghost theme — the app boots into a derived view of whatever
    // theme the user has set in their Ghostty config.
    //
    // The derivation lives in `ThemeTokens.deriveChromeFrom(...)`; this method just wires it.
    static func fromGhosttyConfig(
        _ config: GhosttyConfig,
        id: String = "ghostty-active",
        name: String = "Ghostty",
        mode: ThemeMode,
        source: ThemeSource = .ghosttyLibrary
    ) -> SuperghostTheme {
        let chrome = ThemeTokens.deriveChromeFrom(
            terminalBackground: config.backgroundColor,
            terminalForeground: config.foregroundColor,
            palette: config.palette,
            mode: mode
        )
        return SuperghostTheme(
            id: id,
            name: name,
            mode: mode,
            source: source,
            backgroundColor: config.backgroundColor,
            foregroundColor: config.foregroundColor,
            cursorColor: config.cursorColor,
            cursorTextColor: config.cursorTextColor,
            selectionBackground: config.selectionBackground,
            selectionForeground: config.selectionForeground,
            palette: config.palette,
            cardSurface: chrome.cardSurface,
            liftedSurface: chrome.liftedSurface,
            hairlineBorder: chrome.hairlineBorder,
            hairlineBorderHover: chrome.hairlineBorderHover,
            inkHeadline: chrome.inkHeadline,
            inkBody: chrome.inkBody,
            inkMuted: chrome.inkMuted,
            inkCaption: chrome.inkCaption,
            accentSolid: chrome.accentSolid,
            accentInline: chrome.accentInline,
            semanticSuccess: chrome.semanticSuccess,
            semanticWarning: chrome.semanticWarning,
            semanticDanger: chrome.semanticDanger,
            semanticInfo: chrome.semanticInfo,
            semanticSkill: chrome.semanticSkill,
            translucentSidebar: true,
            contrastBoost: 50
        )
    }
}
