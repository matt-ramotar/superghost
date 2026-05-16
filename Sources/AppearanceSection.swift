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
    @ObservedObject private var fileSync = AppearanceFileSync.shared

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

            // M3: per-mode override section. Light + Dark side-by-side at desktop widths;
            // the section header is implicit because the panel only has one set of
            // overrides per mode and the live preview already communicates which mode is
            // active.
            AppearanceOverrideCard(
                title: String(localized: "settings.appearance.overrides.activeMode", defaultValue: "Active theme overrides"),
                isModified: themeStore.isModifiedFromPreset,
                onReset: { themeStore.resetToLastAppliedPreset() }
            ) {
                AppearanceOverrideRows(themeStore: themeStore)
            }
        }
        .id(SettingsNavigationTarget.appearance)  // navigation target — routed via `proxy.scrollTo` in SettingsView
        // Conflict prompt — surfaced when an external editor saves the Ghostty config
        // while the panel has pending in-flight edits (plan §2.6, closes R5).
        .alert(
            String(
                localized: "settings.appearance.conflict.title",
                defaultValue: "Config file changed outside Superghost"
            ),
            isPresented: Binding(
                get: { fileSync.pendingConflict != nil },
                set: { newValue in if !newValue { fileSync.acceptExternalEdit() } }
            ),
            presenting: fileSync.pendingConflict
        ) { _ in
            Button(
                String(
                    localized: "settings.appearance.conflict.reloadFromDisk",
                    defaultValue: "Reload from disk"
                ),
                role: .destructive
            ) {
                fileSync.acceptExternalEdit()
            }
            Button(
                String(
                    localized: "settings.appearance.conflict.keepPanelEdits",
                    defaultValue: "Keep panel edits"
                )
            ) {
                fileSync.overridePanelEdits(with: themeStore.activeTheme)
            }
        } message: { report in
            Text(
                String(
                    localized: "settings.appearance.conflict.message",
                    defaultValue: "Your Ghostty config file was modified outside Superghost while the panel had unsaved edits. Reload from disk to accept the external version, or keep your panel edits to overwrite the file."
                ) + "\n\n— " + report.path.lastPathComponent
            )
        }
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

// MARK: - Override card (M3 — modified·reset indicator + per-mode rows)

private struct AppearanceOverrideCard<Content: View>: View {
    let title: String
    let isModified: Bool
    let onReset: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
                if isModified {
                    // The "modified · reset" indicator (handoff §3.6). The plan flags this
                    // as R3 ("may read as nag") and asks us to ship it as designed,
                    // checking back for feedback post-launch. The phrasing here matches
                    // the spec; if the post-launch read says it reads as a scold, the
                    // change is local to this view.
                    HStack(spacing: 4) {
                        Text(String(localized: "settings.appearance.overrides.modified", defaultValue: "modified"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Button(action: onReset) {
                            Text(String(localized: "settings.appearance.overrides.reset", defaultValue: "reset"))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.4))

            Divider().opacity(0.4)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.vertical, 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: NSColor.separatorColor).opacity(0.5), lineWidth: 1)
                )
        )
    }
}

private struct AppearanceOverrideRows: View {
    @ObservedObject var themeStore: ThemeStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Translucent sidebar — toggles the user's *intent* per R7. The actual
            // effective state factors in Reduce Transparency at read time.
            AppearanceOverrideRow(
                title: String(
                    localized: "settings.appearance.overrides.translucentSidebar",
                    defaultValue: "Translucent sidebar"
                ),
                subtitle: themeStore.sidebarTranslucencyEffective != themeStore.sidebarTranslucencyPreference
                    ? String(
                        localized: "settings.appearance.overrides.translucentSidebar.reducedByAccessibility",
                        defaultValue: "Disabled by system Reduce Transparency"
                    )
                    : nil
            ) {
                Toggle("", isOn: $themeStore.sidebarTranslucencyPreference)
                    .labelsHidden()
                    .controlSize(.small)
            }

            Divider().opacity(0.3).padding(.horizontal, 14)

            // Contrast slider — adjusts `contrastBoost` on the active theme. Marks the
            // theme modified so the indicator appears and the reset action restores the
            // preset value.
            AppearanceOverrideRow(
                title: String(
                    localized: "settings.appearance.overrides.contrast",
                    defaultValue: "Contrast boost"
                ),
                subtitle: String(
                    localized: "settings.appearance.overrides.contrast.subtitle",
                    defaultValue: "Strengthen ink-on-surface contrast. Higher values help readability; lower preserves the theme's intended mood."
                )
            ) {
                HStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { Double(themeStore.activeTheme.contrastBoost) },
                            set: { newValue in
                                themeStore.updateActiveTheme { theme in
                                    theme = SuperghostTheme(
                                        id: theme.id,
                                        name: theme.name,
                                        mode: theme.mode,
                                        source: theme.source,
                                        backgroundColor: theme.backgroundColor,
                                        foregroundColor: theme.foregroundColor,
                                        cursorColor: theme.cursorColor,
                                        cursorTextColor: theme.cursorTextColor,
                                        selectionBackground: theme.selectionBackground,
                                        selectionForeground: theme.selectionForeground,
                                        palette: theme.palette,
                                        cardSurface: theme.cardSurface,
                                        liftedSurface: theme.liftedSurface,
                                        hairlineBorder: theme.hairlineBorder,
                                        hairlineBorderHover: theme.hairlineBorderHover,
                                        inkHeadline: theme.inkHeadline,
                                        inkBody: theme.inkBody,
                                        inkMuted: theme.inkMuted,
                                        inkCaption: theme.inkCaption,
                                        accentSolid: theme.accentSolid,
                                        accentInline: theme.accentInline,
                                        semanticSuccess: theme.semanticSuccess,
                                        semanticWarning: theme.semanticWarning,
                                        semanticDanger: theme.semanticDanger,
                                        semanticInfo: theme.semanticInfo,
                                        semanticSkill: theme.semanticSkill,
                                        translucentSidebar: theme.translucentSidebar,
                                        contrastBoost: Int(newValue.rounded())
                                    )
                                }
                            }
                        ),
                        in: 0...100,
                        step: 1
                    )
                    .frame(width: 140)

                    Text("\(themeStore.activeTheme.contrastBoost)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
    }
}

private struct AppearanceOverrideRow<Trailing: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let trailing: Trailing

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
                .layoutPriority(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
