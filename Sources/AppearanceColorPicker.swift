import SwiftUI
import AppKit

// `AppearanceColorPicker` is the inline color popover that the Appearance panel
// uses when the user wants to override a single chrome token (e.g. accentInline,
// cardSurface). Per plan M7 acceptance criteria:
//
//   - Hex input is focus-on-open
//   - Validates on commit (Return / focus loss)
//   - Accepts paste of #rrggbb or rrggbb
//   - Escape cancels (caller dismisses the popover)
//   - Swatch grid of theme-driven presets for one-click selection
//   - NSColorPanel fallback button for users who want the full system picker
//
// The popover is purely presentational — it surfaces the *current* value and
// reports back a new value via the `onCommit` callback. The caller decides
// whether to write that value to ThemeStore (so the same popover can be reused
// in the future for non-theme color contexts like workspace tab colors).
struct AppearanceColorPicker: View {
    let token: String  // human-readable label, e.g. "Accent inline"
    let initialColor: NSColor
    let swatchSuggestions: [NSColor]
    let onCommit: (NSColor) -> Void
    let onCancel: () -> Void

    @State private var hexInput: String
    @State private var validationMessage: String?
    @FocusState private var hexFieldFocused: Bool

    init(
        token: String,
        initialColor: NSColor,
        swatchSuggestions: [NSColor] = [],
        onCommit: @escaping (NSColor) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.token = token
        self.initialColor = initialColor
        self.swatchSuggestions = swatchSuggestions
        self.onCommit = onCommit
        self.onCancel = onCancel
        _hexInput = State(initialValue: initialColor.hexString())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header — token name + current swatch preview.
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(nsColor: previewColor ?? initialColor))
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(token)
                        .font(.system(size: 12, weight: .semibold))
                    Text(hexInput.uppercased())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }

            // Hex field — focus-on-open, validates on commit.
            VStack(alignment: .leading, spacing: 4) {
                TextField("", text: $hexInput, onCommit: commitHex)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .focused($hexFieldFocused)
                    .onAppear {
                        // SwiftUI focus is set on the *next* layout cycle; without
                        // this delay the @FocusState binding wins a race against the
                        // popover's first responder hand-off.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                            hexFieldFocused = true
                        }
                    }
                if let message = validationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            if !swatchSuggestions.isEmpty {
                Divider()
                Text(String(
                    localized: "settings.appearance.colorPicker.suggestions",
                    defaultValue: "Theme colors"
                ))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(22), spacing: 6), count: 8),
                    spacing: 6
                ) {
                    ForEach(Array(swatchSuggestions.enumerated()), id: \.offset) { _, color in
                        Button(action: { selectSwatch(color) }) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(nsColor: color))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(color.hexString().uppercased())
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button(action: openSystemColorPanel) {
                    Text(String(
                        localized: "settings.appearance.colorPicker.systemPicker",
                        defaultValue: "System color picker…"
                    ))
                    .font(.system(size: 12))
                }
                Spacer(minLength: 0)
                Button(
                    String(localized: "common.cancel", defaultValue: "Cancel"),
                    role: .cancel,
                    action: onCancel
                )
                .keyboardShortcut(.cancelAction)
                Button(
                    String(localized: "common.apply", defaultValue: "Apply"),
                    action: commitHex
                )
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private var previewColor: NSColor? {
        NSColor(hex: normalisedHex(hexInput))
    }

    private func commitHex() {
        let normalised = normalisedHex(hexInput)
        guard let color = NSColor(hex: normalised) else {
            validationMessage = String(
                localized: "settings.appearance.colorPicker.invalidHex",
                defaultValue: "Enter a hex color like #1a1b26."
            )
            return
        }
        validationMessage = nil
        hexInput = color.hexString()
        onCommit(color)
    }

    private func selectSwatch(_ color: NSColor) {
        hexInput = color.hexString()
        validationMessage = nil
        onCommit(color)
    }

    private func openSystemColorPanel() {
        let panel = NSColorPanel.shared
        panel.color = previewColor ?? initialColor
        panel.setTarget(SystemColorPanelTarget.shared)
        panel.setAction(#selector(SystemColorPanelTarget.colorDidChange(_:)))
        SystemColorPanelTarget.shared.onChange = { color in
            self.hexInput = color.hexString()
            self.validationMessage = nil
            self.onCommit(color)
        }
        panel.makeKeyAndOrderFront(nil)
    }

    // Strip leading `#`, lowercase, normalise short forms (M7 only accepts
    // 6-digit hex per the schema; 3-digit shortcut is not in scope).
    private func normalisedHex(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let withoutHash = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        return "#" + withoutHash.lowercased()
    }
}

// `SystemColorPanelTarget` is an objc target shim for NSColorPanel — it's
// needed because NSColorPanel's target/action API doesn't accept Swift
// closures directly. We keep a single shared target and route the active
// `onChange` closure through it; only one color picker can use the system
// panel at a time anyway (it's a singleton).
@MainActor
private final class SystemColorPanelTarget: NSObject {
    static let shared = SystemColorPanelTarget()
    var onChange: ((NSColor) -> Void)?

    @objc func colorDidChange(_ sender: NSColorPanel) {
        onChange?(sender.color)
    }
}
