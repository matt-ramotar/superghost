import Foundation
import AppKit
import Combine

// `AppearanceGlobalPreferences` is the per-key store for the "Global appearance"
// section introduced by Milestone 6. These preferences live alongside `ThemeStore`
// but are *theme-independent* — a user who switches presets should keep their
// pointer-cursor + reduce-motion + font-smoothing choices.
//
// Design notes:
//
//   - All four keys mirror the R7 "intent vs effective" split from `ThemeStore`:
//     `*Preference` is what the user picked; `*Effective` computes the actual
//     applied state by combining preference with system accessibility settings
//     (Reduce Motion in macOS, etc.). Callers should read `*Effective`.
//   - We deliberately keep this as a thin `@MainActor ObservableObject` so
//     SwiftUI bindings can `Toggle(isOn:)` directly into it. AppKit hot paths
//     should read static snapshots via `AppearanceGlobalPreferences.shared`.
//   - The Reset action in the M6 footer reverts every key to its plan default,
//     not to the system default — the plan default is what we chose to ship.
@MainActor
final class AppearanceGlobalPreferences: ObservableObject {
    static let shared = AppearanceGlobalPreferences()

    // MARK: - Reduce motion (Superghost-side override on top of system)
    //
    // The system already exposes `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.
    // The plan calls for an additional Superghost-side toggle so a user can
    // disable our animation polish without flipping the system-wide accessibility
    // switch. Effective: `preference || system`.
    @Published var reduceMotionPreference: Bool {
        didSet { defaults.set(reduceMotionPreference, forKey: Self.reduceMotionPreferenceKey) }
    }

    var reduceMotionEffective: Bool {
        if reduceMotionPreference { return true }
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    // MARK: - Pointer cursor style
    //
    // Three values: `system` (Ghostty default), `crosshair` (block cursor over text
    // for precision), `ibeam` (text-edit cursor). Future M7 work surfaces the
    // setting in the terminal renderer; M6 only persists the preference.
    enum PointerCursorStyle: String, CaseIterable, Identifiable {
        case system
        case crosshair
        case ibeam

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system:
                return String(
                    localized: "settings.appearance.global.pointer.system",
                    defaultValue: "System default"
                )
            case .crosshair:
                return String(
                    localized: "settings.appearance.global.pointer.crosshair",
                    defaultValue: "Crosshair"
                )
            case .ibeam:
                return String(
                    localized: "settings.appearance.global.pointer.ibeam",
                    defaultValue: "I-beam"
                )
            }
        }
    }

    @Published var pointerCursorStyle: PointerCursorStyle {
        didSet { defaults.set(pointerCursorStyle.rawValue, forKey: Self.pointerCursorStyleKey) }
    }

    // MARK: - Font smoothing (terminal text rendering)
    //
    // macOS default is on; some terminal users prefer it off for crisper pixel
    // rendering at smaller sizes. The plan calls for a global toggle here. M6
    // persists; M7+ wires it through to the Ghostty renderer.
    @Published var terminalFontSmoothing: Bool {
        didSet { defaults.set(terminalFontSmoothing, forKey: Self.terminalFontSmoothingKey) }
    }

    // MARK: - Chrome font size scale
    //
    // Multiplier applied to the chrome (sidebar, status bar, panel) text size.
    // 1.0 = default; 0.85–1.25 covers the practical range. Terminal font size is
    // separate and lives in `GhosttyConfig`.
    @Published var chromeFontSizeScale: Double {
        didSet { defaults.set(chromeFontSizeScale, forKey: Self.chromeFontSizeScaleKey) }
    }

    // MARK: - Defaults / persistence

    static let reduceMotionPreferenceKey = "superghost.appearance.reduceMotion"
    static let pointerCursorStyleKey = "superghost.appearance.pointerCursorStyle"
    static let terminalFontSmoothingKey = "superghost.appearance.terminalFontSmoothing"
    static let chromeFontSizeScaleKey = "superghost.appearance.chromeFontSizeScale"

    static let defaultReduceMotion: Bool = false
    static let defaultPointerCursorStyle: PointerCursorStyle = .system
    static let defaultTerminalFontSmoothing: Bool = true
    static let defaultChromeFontSizeScale: Double = 1.0

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.reduceMotionPreference = defaults.object(forKey: Self.reduceMotionPreferenceKey) as? Bool ?? Self.defaultReduceMotion
        let cursorRaw = defaults.string(forKey: Self.pointerCursorStyleKey)
        self.pointerCursorStyle = PointerCursorStyle(rawValue: cursorRaw ?? Self.defaultPointerCursorStyle.rawValue) ?? Self.defaultPointerCursorStyle
        self.terminalFontSmoothing = defaults.object(forKey: Self.terminalFontSmoothingKey) as? Bool ?? Self.defaultTerminalFontSmoothing
        let storedScale = defaults.object(forKey: Self.chromeFontSizeScaleKey) as? Double ?? Self.defaultChromeFontSizeScale
        // Clamp on init so corrupted defaults don't crash a slider downstream.
        self.chromeFontSizeScale = max(0.85, min(1.25, storedScale))
    }

    // Reset every key to its M6 default. Called by the footer Reset action after
    // the user confirms the modal.
    func resetToDefaults() {
        reduceMotionPreference = Self.defaultReduceMotion
        pointerCursorStyle = Self.defaultPointerCursorStyle
        terminalFontSmoothing = Self.defaultTerminalFontSmoothing
        chromeFontSizeScale = Self.defaultChromeFontSizeScale
    }
}
