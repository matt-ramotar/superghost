import Foundation
import AppKit
import Combine

// `ThemeStore` is the single live source of truth for "what theme is currently active."
//
// SwiftUI views observe it via `@EnvironmentObject`. AppKit hosts (NSWindow chrome, the
// terminal renderer) read snapshots via `ThemeStore.shared.snapshot()` and subscribe to
// `ThemeStore.changeNotification` for redraw.
//
// Why an ObservableObject instead of extending `GhosttyConfig`:
//
//   `GhosttyConfig` is a value-type struct used by code that depends on its value semantics
//   (the static cache, the copy-on-write reads in `GhosttyTerminalView`). Making it
//   observable would force every callsite to handle change notifications and invert the
//   dependency direction (terminal renderer would observe settings instead of the other way
//   around). `ThemeStore` owns the change-notification semantics on top; `GhosttyConfig`
//   stays a pure value type that we re-populate.
//
// Bridge contract: `ThemeStore.applyToGhosttyConfigCache()` is the only place that writes to
// `GhosttyConfig.cachedConfigsByColorScheme`. All readers of `GhosttyConfig.load()` get fresh
// data because `ThemeStore` invalidates and repopulates the cache atomically before
// publishing.
@MainActor
final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    // Darwin notification name posted whenever the active theme changes. AppKit hosts that
    // can't use @EnvironmentObject (e.g. NSWindow chrome on macOS 12 fallbacks) listen for
    // this and redraw. SwiftUI consumers should prefer @EnvironmentObject; this is the
    // escape hatch.
    static let changeNotification = Notification.Name("cmux.theme.changed")

    @Published private(set) var activeTheme: SuperghostTheme
    @Published private(set) var resolvedColorScheme: GhosttyConfig.ColorSchemePreference

    // The unmodified preset the user picked most recently. Used to compute `isModified`
    // and to drive the "Reset to preset" action in the panel (handoff §3.6 modified row).
    @Published private(set) var lastAppliedPreset: SuperghostTheme

    // R7: translucency preference is the user's *intent*, separate from the *effective*
    // state (which also accounts for the system's Reduce Transparency accessibility
    // toggle). The plan calls this out specifically: writes hit `Preference`, reads hit
    // `effective`, and a system toggle never modifies the preference key.
    @Published var sidebarTranslucencyPreference: Bool {
        didSet { UserDefaults.standard.set(sidebarTranslucencyPreference, forKey: Self.sidebarTranslucencyPreferenceKey) }
    }

    // Computed live each read so an Accessibility toggle change is reflected immediately.
    // SwiftUI views that need it should re-derive from `sidebarTranslucencyPreference` and
    // `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency`, which already
    // re-evaluates on appearance changes; this accessor mirrors that.
    var sidebarTranslucencyEffective: Bool {
        guard sidebarTranslucencyPreference else { return false }
        return NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency == false
    }

    // The user's preference (could be `.system`). Distinct from `resolvedColorScheme` which
    // is always concrete (`.light` or `.dark`). The plan's R7 motivates the separation —
    // intent versus effect must be two keys, not one — though R7 is specifically about
    // translucency. Same principle here.
    private(set) var schemePreference: GhosttyConfig.ColorSchemePreference

    // True when the active theme deviates from the last-applied preset. The comparison is
    // value-typed (everything except identity); two themes with the same id but different
    // contrast values compare as modified. Used by the panel to drive the
    // "modified · reset" indicator.
    var isModifiedFromPreset: Bool {
        !Self.themesValueEqual(activeTheme, lastAppliedPreset)
    }

    private init() {
        let preference = Self.readSchemePreference()
        let resolved = GhosttyConfig.resolve(preference)
        self.schemePreference = preference
        self.resolvedColorScheme = resolved
        let config = GhosttyConfig.load(preferredColorScheme: resolved)
        let mode: ThemeMode = resolved == .dark ? .dark : .light
        let initialTheme = SuperghostTheme.fromGhosttyConfig(config, mode: mode)
        self.activeTheme = initialTheme
        self.lastAppliedPreset = initialTheme
        self.sidebarTranslucencyPreference = UserDefaults.standard.object(forKey: Self.sidebarTranslucencyPreferenceKey) as? Bool ?? true

        // M5: seed the legacy sidebar UserDefaults keys from the active theme on first
        // launch. Without this, `sidebarSelectionColorHex` is nil until the user opens
        // the Appearance panel and picks a preset, which means the first paint of the
        // sidebar uses the pre-theme-system literal fallback (`#393C49`). Seeding here
        // ensures the very first frame is theme-aligned. Subsequent `applyTheme(...)`
        // calls overwrite the keys; user-driven manual selection (legacy picker) still
        // overrides whatever the theme wrote, so this doesn't regress the picker UI.
        applyToLegacySidebarDefaults(theme: initialTheme)

        // Listen for the file watcher's "external edit accepted silently" — reload our
        // in-memory state from disk so subsequent panel reads see the new values.
        NotificationCenter.default.addObserver(
            forName: AppearanceFileSync.externalEditAcceptedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reloadActiveThemeFromGhosttyConfig()
            }
        }
    }

    // MARK: - Public API

    // The only public mutator. Updates the cache for both `.light` and `.dark` keys
    // atomically (the active mode gets the new theme; the inactive mode gets a derived
    // counterpart), then publishes, then schedules the file sync.
    //
    // File sync is wired in Milestone 3 (`AppearanceFileSync`). For Milestone 1 the call is
    // a no-op stub so that the contract surface is stable; M3 fills in the body without
    // changing the call sites.
    func applyTheme(_ theme: SuperghostTheme) {
        applyToGhosttyConfigCache(theme: theme, scheme: resolvedColorScheme)
        applyToLegacySidebarDefaults(theme: theme)
        self.activeTheme = theme
        self.lastAppliedPreset = theme
        NotificationCenter.default.post(name: Self.changeNotification, object: self)
        scheduleFileSync()
    }

    // M3: mutate just one or more fields of the active theme without changing the
    // last-applied preset. The panel uses this when the user adjusts contrast or any
    // other override — `isModifiedFromPreset` flips to true so the modified·reset
    // indicator appears.
    func updateActiveTheme(_ mutate: (inout SuperghostTheme) -> Void) {
        var theme = activeTheme
        mutate(&theme)
        applyToGhosttyConfigCache(theme: theme, scheme: resolvedColorScheme)
        applyToLegacySidebarDefaults(theme: theme)
        self.activeTheme = theme
        NotificationCenter.default.post(name: Self.changeNotification, object: self)
        scheduleFileSync()
    }

    // Reset to the last-applied preset. Used by the modified·reset row in the panel.
    func resetToLastAppliedPreset() {
        applyTheme(lastAppliedPreset)
    }

    // Snapshot for non-MainActor or value-typed reads. SwiftUI consumers should prefer
    // `@EnvironmentObject var theme: ThemeStore` and read `theme.activeTheme.tokens.*`.
    nonisolated func snapshot() -> SuperghostTheme {
        // Safe because `activeTheme` is only ever mutated on the main actor; reading a
        // value-typed snapshot from any thread is fine.
        MainActor.assumeIsolated { self.activeTheme }
    }

    // Called by `AppDelegate` (or `cmuxApp`) when the macOS appearance changes (the user
    // flipped Light/Dark in System Settings while `schemePreference == .system`). The store
    // re-resolves the scheme, reloads the underlying GhosttyConfig for the new scheme, and
    // publishes.
    func systemAppearanceChanged() {
        let preference = self.schemePreference
        let newResolved = GhosttyConfig.resolve(preference)
        guard newResolved != resolvedColorScheme else { return }
        self.resolvedColorScheme = newResolved
        reloadActiveThemeFromGhosttyConfig()
    }

    // Used by the Appearance panel (Milestone 2) when the user changes their preference.
    // For now: persists the preference and re-resolves; the panel calls `applyTheme(...)`
    // separately to set the actual theme.
    func setSchemePreference(_ preference: GhosttyConfig.ColorSchemePreference) {
        self.schemePreference = preference
        Self.writeSchemePreference(preference)
        let newResolved = GhosttyConfig.resolve(preference)
        guard newResolved != resolvedColorScheme else { return }
        self.resolvedColorScheme = newResolved
        reloadActiveThemeFromGhosttyConfig()
    }

    // MARK: - Bridge to GhosttyConfig (the only writer to the static cache)

    func applyToGhosttyConfigCache(
        theme: SuperghostTheme,
        scheme: GhosttyConfig.ColorSchemePreference
    ) {
        // For Milestone 1 we mirror the theme into a GhosttyConfig and put it in both cache
        // slots so reads from any scheme don't return stale colors. Later milestones split
        // the slots when the user has distinct light/dark themes configured.
        let config = GhosttyConfig.makeFromTheme(theme)
        let concrete: [GhosttyConfig.ColorSchemePreference] = [.light, .dark]
        for slot in concrete {
            GhosttyConfig.setCachedConfig(config, for: slot)
        }
        // Track which slot is "live" so the dev-only assertion in `GhosttyConfig.load()`
        // can verify reads go through the active scheme.
        _ = scheme  // kept in the signature for future-milestone use
    }

    // MARK: - Internals

    private func reloadActiveThemeFromGhosttyConfig() {
        let config = GhosttyConfig.load(preferredColorScheme: resolvedColorScheme)
        let mode: ThemeMode = resolvedColorScheme == .dark ? .dark : .light
        let theme = SuperghostTheme.fromGhosttyConfig(config, mode: mode)
        self.activeTheme = theme
        NotificationCenter.default.post(name: Self.changeNotification, object: self)
    }

    private func scheduleFileSync() {
        // M3: hand off to `AppearanceFileSync` (debounced 300ms writer + conflict-aware
        // file watcher). The contract surface from M1 is preserved.
        AppearanceFileSync.shared.scheduleWrite(theme: activeTheme)
    }

    // M2/M5 bridge: write the active theme's chrome through the legacy `sidebar*`
    // UserDefaults keys. The keys already drive `SidebarBackdrop`,
    // `sidebarSelectedWorkspaceBackgroundNSColor(...)`, and the sidebar notification
    // badge in `ContentView.swift` via `@AppStorage`. M5 promotes the wiring from "just
    // the sidebar tint" (M2) to "every chrome-driven sidebar UserDefaults key the panel
    // owns," which is what makes a preset switch recolor sidebar selection + notification
    // badge in the same render frame as the tint.
    //
    // The proper migration of those readers to direct `themeStore.activeTheme.tokens.*`
    // reads is opportunistic per plan §2.7; the legacy keys remain the source of truth
    // until those call sites are individually migrated. See
    // `docs/theme-migration-debt.md` for the inventory.
    //
    // Compatibility contract (plan §2.5): the keys here are *frozen*. New chrome tokens
    // get new keys; the old keys are read for backward compat and written by the new UI.
    private func applyToLegacySidebarDefaults(theme: SuperghostTheme) {
        let defaults = UserDefaults.standard
        let surfaceHex = theme.cardSurface.hexString()
        let accentHex = theme.accentInline.hexString()

        defaults.set(surfaceHex, forKey: "sidebarTintHex")
        switch theme.mode {
        case .dark:
            defaults.set(surfaceHex, forKey: "sidebarTintHexDark")
        case .light:
            defaults.set(surfaceHex, forKey: "sidebarTintHexLight")
        }

        // M5: selection + notification badge respond to preset switching. Both keys are
        // documented in `Sources/cmuxApp.swift` and read by ContentView.
        defaults.set(accentHex, forKey: "sidebarSelectionColorHex")
        defaults.set(accentHex, forKey: "sidebarNotificationBadgeColorHex")
    }

    // MARK: - Preference persistence

    // R7: stable key for translucency intent, separate from any effective state.
    static let sidebarTranslucencyPreferenceKey = "sidebarTranslucencyPreference"

    // `schemePreference` is stored under a stable UserDefaults key. We deliberately don't
    // reuse `AppearanceSettings.appearanceModeKey` here because that's the *app-level*
    // appearance (which has the legacy `.auto` case for backward compat). `ThemeStore`'s
    // preference is the *theme-level* preference — they happen to be the same today but the
    // panel design (handoff §3.5) treats them as separable.
    //
    // For M1 we read from the existing app-appearance key as the source of truth and write
    // to it as well, so the existing ThemePickerRow keeps working. M2 introduces the
    // dedicated key if the panel ever needs to diverge.
    private static let schemePreferenceKey = AppearanceSettings.appearanceModeKey

    // Value-typed equality for the modified·reset indicator. We deliberately compare every
    // field — including chrome tokens — because user overrides to e.g. `contrastBoost`
    // need to flip the indicator even if `id` matches.
    private static func themesValueEqual(_ a: SuperghostTheme, _ b: SuperghostTheme) -> Bool {
        return a.id == b.id
            && a.contrastBoost == b.contrastBoost
            && a.translucentSidebar == b.translucentSidebar
            && a.cardSurface.hexString() == b.cardSurface.hexString()
            && a.backgroundColor.hexString() == b.backgroundColor.hexString()
            && a.foregroundColor.hexString() == b.foregroundColor.hexString()
            && a.accentInline.hexString() == b.accentInline.hexString()
    }

    private static func readSchemePreference() -> GhosttyConfig.ColorSchemePreference {
        let raw = UserDefaults.standard.string(forKey: schemePreferenceKey)
        let mode = AppearanceSettings.mode(for: raw)
        switch mode {
        case .light: return .light
        case .dark: return .dark
        case .system, .auto: return .system
        }
    }

    private static func writeSchemePreference(_ preference: GhosttyConfig.ColorSchemePreference) {
        let mode: AppearanceMode
        switch preference {
        case .light: mode = .light
        case .dark: mode = .dark
        case .system: mode = .system
        }
        UserDefaults.standard.set(mode.rawValue, forKey: schemePreferenceKey)
    }
}

// MARK: - GhosttyConfig conversion

extension GhosttyConfig {
    // Project a `SuperghostTheme`'s terminal colors back into a `GhosttyConfig`. Chrome
    // tokens are kept on the `ThemeStore.activeTheme` side; the cache contains only what
    // existing readers of `GhosttyConfig.load()` already expect.
    static func makeFromTheme(_ theme: SuperghostTheme) -> GhosttyConfig {
        var config = GhosttyConfig()
        config.backgroundColor = theme.backgroundColor
        config.foregroundColor = theme.foregroundColor
        config.cursorColor = theme.cursorColor
        config.cursorTextColor = theme.cursorTextColor
        config.selectionBackground = theme.selectionBackground
        config.selectionForeground = theme.selectionForeground
        config.palette = theme.palette
        // Sidebar background mirrors the chrome cardSurface so existing readers of
        // `sidebarBackground` (set today via `applySidebarAppearanceToUserDefaults()`) see
        // the theme's cardSurface immediately. M5 replaces the hardcoded callers with
        // direct ThemeTokens reads; this preserves behavior until then.
        config.sidebarBackground = theme.cardSurface
        config.sidebarBackgroundLight = theme.mode == .light ? theme.cardSurface : nil
        config.sidebarBackgroundDark = theme.mode == .dark ? theme.cardSurface : nil
        return config
    }
}
