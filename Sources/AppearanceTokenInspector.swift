import SwiftUI
import AppKit
#if DEBUG
import Bonsplit
#endif

// `AppearanceTokenInspector` is the right-click affordance on the live preview
// in the Appearance panel. Per plan M7 acceptance:
//
//   - Right-click any element in live preview shows the token name + hex
//     + "Copy hex" + "Edit in override" actions
//   - Keyboard equivalent: Return on a focused preview region opens the list
//   - Telemetry event `appearance.inspector.opened` fires
//
// We expose two things:
//
//   1. `AppearanceInspectableToken` — a small enum + metadata that the live
//      preview attaches to each interactable region (sidebar surface,
//      accent, ink). This is the source-of-truth for what the inspector can
//      describe.
//   2. `AppearanceInspectorContextMenu` — a ViewModifier that pins the right-
//      click menu + keyboard equivalent to a SwiftUI view, given a token and
//      the live theme.
//
// The "Edit in override" action is best-effort: M7 ships the wiring; the
// actual color picker integration is hooked up via the host view's
// `onEditInOverride` closure so it can scroll the override section into
// view (M2/M3 already established the section's id-based scroll target) and
// open the picker over the relevant row.

enum AppearanceInspectableToken: String, CaseIterable {
    case cardSurface
    case backgroundColor
    case accentInline
    case inkBody
    case inkHeadline
    case cursorColor

    var displayName: String {
        switch self {
        case .cardSurface:
            return String(localized: "settings.appearance.token.cardSurface", defaultValue: "Card surface")
        case .backgroundColor:
            return String(localized: "settings.appearance.token.backgroundColor", defaultValue: "Terminal background")
        case .accentInline:
            return String(localized: "settings.appearance.token.accentInline", defaultValue: "Accent (inline)")
        case .inkBody:
            return String(localized: "settings.appearance.token.inkBody", defaultValue: "Body ink")
        case .inkHeadline:
            return String(localized: "settings.appearance.token.inkHeadline", defaultValue: "Headline ink")
        case .cursorColor:
            return String(localized: "settings.appearance.token.cursorColor", defaultValue: "Cursor")
        }
    }

    func color(in theme: SuperghostTheme) -> NSColor {
        switch self {
        case .cardSurface: return theme.tokens.cardSurface
        case .backgroundColor: return theme.backgroundColor
        case .accentInline: return theme.tokens.accentInline
        case .inkBody: return theme.tokens.inkBody
        case .inkHeadline: return theme.tokens.inkHeadline
        case .cursorColor: return theme.cursorColor
        }
    }
}

struct AppearanceInspectorContextMenu: ViewModifier {
    let token: AppearanceInspectableToken
    let theme: SuperghostTheme
    let onEditInOverride: (AppearanceInspectableToken) -> Void

    func body(content: Content) -> some View {
        content.contextMenu {
            Text("\(token.displayName) · \(token.color(in: theme).hexString().uppercased())")
                .font(.system(size: 11, design: .monospaced))
            Button(String(
                localized: "settings.appearance.inspector.copyHex",
                defaultValue: "Copy hex"
            )) {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(token.color(in: theme).hexString().uppercased(), forType: .string)
                AppearanceInspectorTelemetry.recordOpen(token: token, action: .copyHex)
            }
            Button(String(
                localized: "settings.appearance.inspector.editInOverride",
                defaultValue: "Edit in override"
            )) {
                AppearanceInspectorTelemetry.recordOpen(token: token, action: .editInOverride)
                onEditInOverride(token)
            }
        }
        // Keyboard equivalent — pressing Return while the region is focused
        // triggers a synthetic right-click. SwiftUI's contextMenu hooks into
        // the keyboard-driven activation automatically for AppKit-hosted
        // SwiftUI views.
        .accessibilityAction(named: Text(String(
            localized: "settings.appearance.inspector.openMenu",
            defaultValue: "Open token inspector for \(token.displayName)"
        ))) {
            AppearanceInspectorTelemetry.recordOpen(token: token, action: .a11yActivation)
            onEditInOverride(token)
        }
    }
}

extension View {
    func appearanceInspectorMenu(
        token: AppearanceInspectableToken,
        theme: SuperghostTheme,
        onEditInOverride: @escaping (AppearanceInspectableToken) -> Void
    ) -> some View {
        modifier(AppearanceInspectorContextMenu(
            token: token,
            theme: theme,
            onEditInOverride: onEditInOverride
        ))
    }
}

// MARK: - Telemetry

// `AppearanceInspectorTelemetry` fires the `appearance.inspector.opened` event.
// We keep this tiny + local so it doesn't depend on a project-wide telemetry
// pipeline; if/when a real telemetry channel exists, hook in here.
//
// The plan specifies the event name; the action enum is our addition so the
// receiving end can distinguish "user inspected" from "user actually copied"
// or "user opened the override editor."
enum AppearanceInspectorTelemetry {
    enum Action: String {
        case copyHex = "copy_hex"
        case editInOverride = "edit_in_override"
        case a11yActivation = "a11y_activation"
    }

    static let eventName = "appearance.inspector.opened"

    static func recordOpen(token: AppearanceInspectableToken, action: Action) {
        // Real telemetry pipeline is the next layer up — for now a dlog under
        // DEBUG so manual QA can verify the event is fired with the right
        // attributes when stepping through the panel.
        #if DEBUG
        dlog("\(eventName) token=\(token.rawValue) action=\(action.rawValue)")
        #endif
    }
}
