import SwiftUI
import AppKit

// `AppearanceSection` is the new Settings → Appearance UI surface. Milestone 2 ships the
// walking skeleton — header + live preview + preset strip with two themes. Milestones 3, 6,
// and 7 fill in per-mode overrides, global controls, color picker, and library browser.
//
// Per plan §2.4 this is a section that lives inside the existing `SettingsView` ScrollView,
// using shared `SettingsCard` / `SettingsCardRow` / `SettingsSectionHeader` components.
// We define this in its own file because at ~600 LOC it doesn't belong inside cmuxApp.swift,
// even though the convention for other sections is inline.
//
// The section reads from `ThemeStore.shared` via `@EnvironmentObject`, which is injected at
// the `SettingsRootView` boundary. AppKit chrome (sidebar background, etc.) responds because
// `ThemeStore.applyTheme(_:)` writes through to the legacy `sidebarTintHex*` UserDefaults
// keys that `SidebarBackdrop` already observes; the proper migration of those readers to
// direct `theme.tokens.*` reads is Milestone 5.
struct AppearanceSection: View {
    @EnvironmentObject private var themeStore: ThemeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsAppearanceSectionHeader()

            // Live preview — a miniature Superghost layout. Reacts to ThemeStore changes
            // through @EnvironmentObject. The preview chrome (mini-sidebar, mini-terminal)
            // pulls from `themeStore.activeTheme.tokens`; the proof that the architecture
            // works end-to-end is that this AND the real app sidebar both recolor in the
            // same render frame when a preset is clicked.
            AppearanceLivePreview(theme: themeStore.activeTheme)
                .padding(.top, 4)
                .padding(.bottom, 8)

            // Preset strip — two themes for Milestone 2 (handoff §2's curated set in
            // M4 grows this to 8–12). Click swaps `themeStore.activeTheme` and propagates
            // through the cache + UserDefaults bridge.
            AppearancePresetStrip(
                presets: BuiltInThemes.all,
                activeId: themeStore.activeTheme.id,
                onSelect: { theme in
                    themeStore.applyTheme(theme)
                }
            )
        }
        .id(SettingsNavigationTarget.appearance)  // navigation target — routed via `proxy.scrollTo` in SettingsView
    }
}

// Stable identifier (kept around in case a future caller needs to reference the section
// outside the SettingsNavigationTarget enum).
enum AppearanceSectionAnchor {
    static let id = "settings.section.appearance"
}

private struct SettingsAppearanceSectionHeader: View {
    var body: some View {
        Text(String(localized: "settings.section.appearance", defaultValue: "Appearance"))
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.leading, 2)
            .padding(.bottom, -2)
    }
}

// MARK: - Live preview

private struct AppearanceLivePreview: View {
    let theme: SuperghostTheme

    var body: some View {
        // The preview is a stack of two stripes — sidebar on the left, terminal pane on the
        // right — sized to mirror the actual Superghost workspace at a glance. Picking a
        // preset recolors both stripes in one render frame; that's the M2 acceptance demo.
        HStack(spacing: 0) {
            // Mini-sidebar
            VStack(alignment: .leading, spacing: 6) {
                miniSidebarRow(label: "main", selected: true)
                miniSidebarRow(label: "feature/themes", selected: false)
                miniSidebarRow(label: "test/coverage", selected: false)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(width: 140, alignment: .topLeading)
            .background(Color(nsColor: theme.tokens.cardSurface))

            // Mini-terminal
            VStack(alignment: .leading, spacing: 4) {
                Text("$ superghost --version")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(nsColor: theme.tokens.inkBody))
                Text("0.1.0")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(nsColor: theme.tokens.inkMuted))
                Text("$ _")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(nsColor: theme.cursorColor))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color(nsColor: theme.backgroundColor))
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: theme.tokens.hairlineBorder), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                localized: "settings.appearance.preview.label",
                defaultValue: "Live preview of the \(theme.name) theme"
            )
        )
    }

    @ViewBuilder
    private func miniSidebarRow(label: String, selected: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(nsColor: selected ? theme.tokens.accentInline : theme.tokens.inkMuted))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .foregroundColor(Color(nsColor: selected ? theme.tokens.inkHeadline : theme.tokens.inkBody))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(nsColor: selected ? theme.tokens.liftedSurface : .clear))
        )
    }
}

// MARK: - Preset strip

private struct AppearancePresetStrip: View {
    let presets: [SuperghostTheme]
    let activeId: String
    let onSelect: (SuperghostTheme) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presets, id: \.id) { theme in
                    AppearancePresetCard(
                        theme: theme,
                        isActive: theme.id == activeId,
                        onSelect: { onSelect(theme) }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct AppearancePresetCard: View {
    let theme: SuperghostTheme
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Color preview row — chrome surface + accent + ink, the tokens that most
                // visibly distinguish themes at a glance.
                HStack(spacing: 4) {
                    swatch(theme.tokens.cardSurface)
                    swatch(theme.backgroundColor)
                    swatch(theme.tokens.accentInline)
                    swatch(theme.tokens.inkBody)
                }
                Text(theme.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(modeLabel(theme.mode))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .frame(width: 144, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isActive ? Color.accentColor : Color(nsColor: NSColor.separatorColor).opacity(0.5),
                        lineWidth: isActive ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.name)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private func swatch(_ color: NSColor) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color(nsColor: color))
            .frame(width: 22, height: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
            )
    }

    private func modeLabel(_ mode: ThemeMode) -> String {
        switch mode {
        case .light:
            return String(localized: "settings.appearance.preset.mode.light", defaultValue: "Light mode")
        case .dark:
            return String(localized: "settings.appearance.preset.mode.dark", defaultValue: "Dark mode")
        }
    }
}
