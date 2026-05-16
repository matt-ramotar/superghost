import XCTest
import AppKit

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

// Foundation tests for Milestone 1. These exercise observable runtime behavior — the cache
// is a real shared resource, the resolver is a real function — and never assert source-code
// shape (per CLAUDE.md test policy).
//
// Test isolation note: `GhosttyConfig.cachedConfigsByColorScheme` is process-global state.
// Each test that mutates it must call `GhosttyConfig.invalidateLoadCache()` in tearDown so
// the next test doesn't see a poisoned cache.
final class ThemeStoreFoundationTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        GhosttyConfig.invalidateLoadCache()
    }

    // MARK: - ColorSchemePreference.system addition (R8 closure)

    func testColorSchemeResolveSystemFromDarkAppearance() {
        // When the system appearance is dark, `.system` must resolve to `.dark`.
        // We construct an explicit NSAppearance to avoid depending on the test host's
        // actual appearance (CI may run under either).
        let dark = NSAppearance(named: .darkAqua)!
        let resolved = GhosttyConfig.resolve(.system, appAppearance: dark)
        XCTAssertEqual(resolved, .dark)
    }

    func testColorSchemeResolveSystemFromLightAppearance() {
        let light = NSAppearance(named: .aqua)!
        let resolved = GhosttyConfig.resolve(.system, appAppearance: light)
        XCTAssertEqual(resolved, .light)
    }

    func testColorSchemeResolvePassthroughForConcrete() {
        // `.light` and `.dark` must resolve to themselves regardless of appearance —
        // they're explicit preferences and never re-resolved.
        let dark = NSAppearance(named: .darkAqua)!
        XCTAssertEqual(GhosttyConfig.resolve(.light, appAppearance: dark), .light)
        XCTAssertEqual(GhosttyConfig.resolve(.dark, appAppearance: dark), .dark)

        let light = NSAppearance(named: .aqua)!
        XCTAssertEqual(GhosttyConfig.resolve(.light, appAppearance: light), .light)
        XCTAssertEqual(GhosttyConfig.resolve(.dark, appAppearance: light), .dark)
    }

    func testColorSchemeConcreteCasesExcludesSystem() {
        // `.system` is intentionally not a cache key — the cache stores resolved values only.
        XCTAssertEqual(Set(GhosttyConfig.ColorSchemePreference.concreteCases), Set([.light, .dark]))
        XCTAssertFalse(GhosttyConfig.ColorSchemePreference.concreteCases.contains(.system))
    }

    // MARK: - Cache invalidation atomicity (R4 detection seam)

    func testSetCachedConfigUpdatesLightAndDarkSlotsIndependently() {
        // Two distinct synthetic configs in the two cache slots; loads return the correct
        // one for each requested scheme.
        var lightConfig = GhosttyConfig()
        lightConfig.backgroundColor = NSColor(hex: "#ffffff")!
        var darkConfig = GhosttyConfig()
        darkConfig.backgroundColor = NSColor(hex: "#000000")!

        GhosttyConfig.setCachedConfig(lightConfig, for: .light)
        GhosttyConfig.setCachedConfig(darkConfig, for: .dark)

        let loadedLight = GhosttyConfig.load(preferredColorScheme: .light)
        let loadedDark = GhosttyConfig.load(preferredColorScheme: .dark)

        XCTAssertEqual(loadedLight.backgroundColor.hexString(), "#FFFFFF")
        XCTAssertEqual(loadedDark.backgroundColor.hexString(), "#000000")
    }

    func testSetCachedConfigForSystemResolvesBeforeWriting() {
        // Defensive — caller passes `.system`; cache writes the resolved slot.
        // We can't deterministically know what `.system` resolves to in the test host, but
        // we can assert that after the write, either `.light` or `.dark` returns the config
        // (and the other slot is untouched if it was already populated with a sentinel).
        var sentinel = GhosttyConfig()
        sentinel.backgroundColor = NSColor(hex: "#aaaaaa")!
        var newConfig = GhosttyConfig()
        newConfig.backgroundColor = NSColor(hex: "#bbbbbb")!

        GhosttyConfig.setCachedConfig(sentinel, for: .light)
        GhosttyConfig.setCachedConfig(sentinel, for: .dark)
        GhosttyConfig.setCachedConfig(newConfig, for: .system)

        let resolved = GhosttyConfig.resolve(.system, appAppearance: NSApp?.effectiveAppearance)
        let activeSlotConfig = GhosttyConfig.load(preferredColorScheme: resolved)
        XCTAssertEqual(activeSlotConfig.backgroundColor.hexString(), "#BBBBBB")
    }

    // MARK: - SuperghostTheme Codable round-trip (file-sync foundation)

    func testSuperghostThemeCodableRoundTripPreservesColorsAndIdentity() throws {
        // The handoff schema requires every chrome token to round-trip via JSON; this is the
        // foundation that `AppearanceFileSync` (Milestone 3) builds on. Any color drift here
        // becomes file corruption on save+reload.
        let original = SuperghostTheme(
            id: "test-theme",
            name: "Test Theme",
            mode: .dark,
            source: .builtIn,
            backgroundColor: NSColor(hex: "#1a1b26")!,
            foregroundColor: NSColor(hex: "#c0caf5")!,
            cursorColor: NSColor(hex: "#7aa2f7")!,
            cursorTextColor: NSColor(hex: "#1a1b26")!,
            selectionBackground: NSColor(hex: "#283457")!,
            selectionForeground: NSColor(hex: "#c0caf5")!,
            palette: [0: NSColor(hex: "#15161e")!, 4: NSColor(hex: "#7aa2f7")!],
            cardSurface: NSColor(hex: "#1a1b26")!,
            liftedSurface: NSColor(hex: "#1f2335")!,
            hairlineBorder: NSColor(hex: "#2f334d")!,
            hairlineBorderHover: NSColor(hex: "#3d4263")!,
            inkHeadline: NSColor(hex: "#c0caf5")!,
            inkBody: NSColor(hex: "#a9b1d6")!,
            inkMuted: NSColor(hex: "#737aa2")!,
            inkCaption: NSColor(hex: "#565f89")!,
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

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoded = try JSONDecoder().decode(SuperghostTheme.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.mode, original.mode)
        XCTAssertEqual(decoded.source, original.source)
        XCTAssertEqual(decoded.contrastBoost, 68)
        XCTAssertEqual(decoded.translucentSidebar, true)
        XCTAssertEqual(decoded.backgroundColor.hexString(), original.backgroundColor.hexString())
        XCTAssertEqual(decoded.cardSurface.hexString(), original.cardSurface.hexString())
        XCTAssertEqual(decoded.accentInline.hexString(), original.accentInline.hexString())
        XCTAssertEqual(decoded.palette[4]?.hexString(), "#7AA2F7")
        XCTAssertEqual(decoded.palette[0]?.hexString(), "#15161E")
    }

    // MARK: - ThemeTokens derivation (R6 detection — preview only; harness is M4)

    func testDeriveChromeFromTokyoNightLikePaletteProducesDarkChrome() {
        // Synthetic Tokyo-Night-ish palette. The derivation must produce a cardSurface that
        // is visibly different from the terminal background (so chrome reads as a card) and
        // an ink ladder with AA contrast.
        let palette: [Int: NSColor] = [
            0: NSColor(hex: "#15161e")!,
            1: NSColor(hex: "#f7768e")!,
            2: NSColor(hex: "#9ece6a")!,
            3: NSColor(hex: "#e0af68")!,
            4: NSColor(hex: "#7aa2f7")!,
            5: NSColor(hex: "#bb9af7")!,
            6: NSColor(hex: "#7dcfff")!
        ]
        let tokens = ThemeTokens.deriveChromeFrom(
            terminalBackground: NSColor(hex: "#1a1b26")!,
            terminalForeground: NSColor(hex: "#c0caf5")!,
            palette: palette,
            mode: .dark
        )

        // Chrome surface should be distinguishable from terminal background but in the same
        // visual register (both dark, neither dramatically brighter or darker than the other).
        let contrastVsBg = ThemeTokens.contrastRatio(tokens.cardSurface, NSColor(hex: "#1a1b26")!)
        XCTAssertGreaterThan(contrastVsBg, 1.0, "cardSurface should differ from terminal bg")
        XCTAssertLessThan(contrastVsBg, 2.0, "cardSurface should stay in the same visual register")

        // Body ink against card surface must clear AA for normal text (4.5:1).
        let inkContrast = ThemeTokens.contrastRatio(tokens.inkBody, tokens.cardSurface)
        XCTAssertGreaterThan(inkContrast, 4.5, "inkBody must clear AA on derived cardSurface")

        // Accent should pick a blue-family palette swatch (4, 5, or 6 are valid in this set).
        let acceptableAccents = [palette[4], palette[5], palette[6]].compactMap { $0?.hexString() }
        XCTAssertTrue(
            acceptableAccents.contains(tokens.accentInline.hexString()),
            "accentInline should be drawn from the palette's accent swatches"
        )
    }
}
