import SwiftUI
import AppKit
import Foundation

// `AppearanceLibraryBrowser` is the slide-in sheet that lets users browse the
// ~312 themes shipped with Ghostty's submodule. Per plan M7 acceptance
// criteria:
//
//   - Opens from the preset section header link
//   - Search filters by substring (case-insensitive)
//   - "Apply to Light" / "Apply to Dark" updates the corresponding per-mode
//     section in ThemeStore
//   - Themes flagged by the M4 derivation harness CSV display a warning icon
//     and tooltip ("Chrome contrast may be low on this theme")
//
// Data source: `Resources/ghostty-derived-chrome-status.csv` (always bundled).
// Apply path: reads the named theme file from the local Ghostty install or
// dev submodule; degrades gracefully if neither is available.
struct AppearanceLibraryBrowser: View {
    @EnvironmentObject private var themeStore: ThemeStore
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [LibraryEntry] = []
    @State private var searchText: String = ""
    @State private var applyError: String?
    @State private var didLoad: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(String(
                    localized: "settings.appearance.library.title",
                    defaultValue: "Browse Ghostty theme library"
                ))
                .font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 0)
                Button(
                    String(localized: "common.done", defaultValue: "Done"),
                    action: { dismiss() }
                )
                .keyboardShortcut(.cancelAction)
            }
            .padding(14)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(
                    String(
                        localized: "settings.appearance.library.searchPlaceholder",
                        defaultValue: "Search themes"
                    ),
                    text: $searchText
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(nsColor: NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            if didLoad && entries.isEmpty {
                emptyState
            } else {
                List(filteredEntries) { entry in
                    AppearanceLibraryRow(
                        entry: entry,
                        onApplyToLight: { applyEntry(entry, mode: .light) },
                        onApplyToDark: { applyEntry(entry, mode: .dark) }
                    )
                }
                .listStyle(.inset)
            }

            HStack(spacing: 6) {
                if let summary = aaSummaryText {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text(summary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 540, height: 480)
        .onAppear(perform: loadEntries)
        .alert(
            String(
                localized: "settings.appearance.library.applyError.title",
                defaultValue: "Could not load that theme"
            ),
            isPresented: Binding(
                get: { applyError != nil },
                set: { if !$0 { applyError = nil } }
            ),
            presenting: applyError
        ) { _ in
            Button(String(localized: "common.ok", defaultValue: "OK")) { applyError = nil }
        } message: { detail in
            Text(detail)
        }
    }

    private var filteredEntries: [LibraryEntry] {
        guard !searchText.isEmpty else { return entries }
        let needle = searchText.lowercased()
        return entries.filter { $0.name.lowercased().contains(needle) }
    }

    private var aaSummaryText: String? {
        guard !entries.isEmpty else { return nil }
        let passing = entries.filter { $0.passesAA }.count
        return String.localizedStringWithFormat(
            String(
                localized: "settings.appearance.library.aaSummary",
                defaultValue: "%lld of %lld themes pass AA on chrome contrast. Flagged themes still apply, but expect lower readability on derived chrome."
            ),
            Int64(passing),
            Int64(entries.count)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "swatchpalette")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(String(
                localized: "settings.appearance.library.empty.title",
                defaultValue: "Theme library not available"
            ))
            .font(.system(size: 13, weight: .semibold))
            Text(String(
                localized: "settings.appearance.library.empty.body",
                defaultValue: "Superghost couldn't find the Ghostty theme catalog. Install Ghostty or build from source to enable the browser."
            ))
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Loading & applying

    private func loadEntries() {
        guard !didLoad else { return }
        didLoad = true
        let loaded = AppearanceLibraryCatalog.shared.loadEntries()
        // Sort: AA-passing first, then alphabetically. Failing themes still show
        // — the plan calls for flagging, not hiding.
        entries = loaded.sorted { lhs, rhs in
            if lhs.passesAA != rhs.passesAA { return lhs.passesAA }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func applyEntry(_ entry: LibraryEntry, mode: ThemeMode) {
        do {
            let theme = try AppearanceLibraryCatalog.shared.loadTheme(named: entry.name, mode: mode)
            themeStore.applyTheme(theme)
            dismiss()
        } catch {
            applyError = String(
                localized: "settings.appearance.library.applyError.body",
                defaultValue: "Couldn't load \(entry.name). \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - Library row

private struct AppearanceLibraryRow: View {
    let entry: LibraryEntry
    let onApplyToLight: () -> Void
    let onApplyToDark: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Quad swatch: card surface, background, accent, body ink (the
            // four tokens the M4 CSV computes).
            HStack(spacing: 2) {
                swatch(entry.cardSurface)
                swatch(entry.background)
                swatch(entry.foreground)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(entry.aaSubtitle)
                    .font(.caption)
                    .foregroundColor(entry.passesAA ? .secondary : .orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !entry.passesAA {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .help(String(
                        localized: "settings.appearance.library.aaFlag.tooltip",
                        defaultValue: "Chrome contrast may be low on this theme."
                    ))
            }

            HStack(spacing: 4) {
                Button(String(
                    localized: "settings.appearance.library.applyLight",
                    defaultValue: "Light"
                ), action: onApplyToLight)
                .controlSize(.small)

                Button(String(
                    localized: "settings.appearance.library.applyDark",
                    defaultValue: "Dark"
                ), action: onApplyToDark)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }

    private func swatch(_ color: NSColor?) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color(nsColor: color ?? .clear))
            .frame(width: 14, height: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
            )
    }
}

// MARK: - Model

// `LibraryEntry` is one parsed row from `ghostty-derived-chrome-status.csv`.
// We don't pre-load the full theme file at catalog time — the CSV gives us
// enough for the list UI (name + 3 colors + AA outcome), and the theme file
// is only read on Apply (where the user explicitly asked).
struct LibraryEntry: Identifiable {
    let name: String
    let background: NSColor?
    let foreground: NSColor?
    let cardSurface: NSColor?
    let bodyRatio: Double
    let headlineRatio: Double
    let accentRatio: Double
    let passesAA: Bool

    var id: String { name }

    var aaSubtitle: String {
        if passesAA {
            return String.localizedStringWithFormat(
                String(
                    localized: "settings.appearance.library.aaPass",
                    defaultValue: "Body %.1f:1 · accent %.1f:1"
                ),
                bodyRatio, accentRatio
            )
        } else {
            return String.localizedStringWithFormat(
                String(
                    localized: "settings.appearance.library.aaFail",
                    defaultValue: "AA flag: body %.1f:1 falls below 4.5"
                ),
                bodyRatio
            )
        }
    }
}

// MARK: - Catalog loader (singleton)

// `AppearanceLibraryCatalog` is the single owner of the bundled CSV + the path
// resolver for theme files. Tests can inject paths via `setDevThemeDirectory(_:)`.
@MainActor
final class AppearanceLibraryCatalog {
    static let shared = AppearanceLibraryCatalog()

    enum LoadError: Error, LocalizedError {
        case themeFileNotFound(String)
        case themeFileUnparseable(String)

        var errorDescription: String? {
            switch self {
            case .themeFileNotFound(let name):
                return "Theme file '\(name)' was not found on disk."
            case .themeFileUnparseable(let name):
                return "Theme file '\(name)' is missing background/foreground values."
            }
        }
    }

    private var injectedThemeDirectory: URL?

    private init() {}

    func setDevThemeDirectory(_ url: URL?) {
        injectedThemeDirectory = url
    }

    // Parse the bundled CSV and return one LibraryEntry per row. If the CSV
    // is missing entirely (older build), returns an empty array — caller
    // displays the empty state.
    func loadEntries() -> [LibraryEntry] {
        guard let csvData = loadCSVData(), let csv = String(data: csvData, encoding: .utf8) else {
            return []
        }
        var result: [LibraryEntry] = []
        let lines = csv.split(separator: "\n").dropFirst()  // skip header
        for line in lines {
            let cells = parseCSVRow(String(line))
            guard cells.count >= 8 else { continue }
            let name = cells[0]
            let bg = NSColor(hex: cells[1])
            let fg = NSColor(hex: cells[2])
            let surface = NSColor(hex: cells[3])
            let bodyRatio = Double(cells[4]) ?? 0
            let headlineRatio = Double(cells[5]) ?? 0
            let accentRatio = Double(cells[6]) ?? 0
            let aa = cells[7] == "PASS"
            result.append(LibraryEntry(
                name: name,
                background: bg,
                foreground: fg,
                cardSurface: surface,
                bodyRatio: bodyRatio,
                headlineRatio: headlineRatio,
                accentRatio: accentRatio,
                passesAA: aa
            ))
        }
        return result
    }

    func loadTheme(named themeName: String, mode: ThemeMode) throws -> SuperghostTheme {
        guard let directory = themeDirectory() else {
            throw LoadError.themeFileNotFound(themeName)
        }
        let candidate = directory.appendingPathComponent(themeName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: candidate.path) else {
            throw LoadError.themeFileNotFound(themeName)
        }
        let raw = try String(contentsOf: candidate, encoding: .utf8)
        var config = GhosttyConfig()
        config.parse(raw)
        return SuperghostTheme.fromGhosttyConfig(
            config,
            id: "ghostty-library:\(themeName)",
            name: themeName,
            mode: mode,
            source: .ghosttyLibrary
        )
    }

    // MARK: - Internals

    private func loadCSVData() -> Data? {
        // 1. Prefer the file bundled into the app
        if let url = Bundle.main.url(forResource: "ghostty-derived-chrome-status", withExtension: "csv") {
            return try? Data(contentsOf: url)
        }
        // 2. Fallback: read directly from the repo for tests / dev runs without bundling.
        let devPath = URL(fileURLWithPath: "Resources/ghostty-derived-chrome-status.csv", relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        if FileManager.default.fileExists(atPath: devPath.path) {
            return try? Data(contentsOf: devPath)
        }
        return nil
    }

    private func themeDirectory() -> URL? {
        if let injected = injectedThemeDirectory { return injected }
        // 1. Bundled themes directory (release builds, if shipped)
        if let bundled = Bundle.main.url(forResource: "GhosttyThemes", withExtension: nil),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        // 2. Dev path: ghostty submodule output
        let devPath = URL(fileURLWithPath: "ghostty/zig-out/share/ghostty/themes", relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
        if FileManager.default.fileExists(atPath: devPath.path) {
            return devPath
        }
        return nil
    }

    // CSV row parser that handles double-quoted fields with escaped quotes.
    // We hand-roll this because Foundation has no built-in CSV parser and the
    // file format is minimal enough not to warrant a dependency.
    private func parseCSVRow(_ line: String) -> [String] {
        var cells: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if inQuotes {
                if c == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex && line[next] == "\"" {
                        current.append("\"")
                        i = line.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                        i = line.index(after: i)
                        continue
                    }
                } else {
                    current.append(c)
                    i = line.index(after: i)
                    continue
                }
            } else {
                if c == "," {
                    cells.append(current)
                    current = ""
                    i = line.index(after: i)
                    continue
                } else if c == "\"" && current.isEmpty {
                    inQuotes = true
                    i = line.index(after: i)
                    continue
                } else {
                    current.append(c)
                    i = line.index(after: i)
                    continue
                }
            }
        }
        cells.append(current)
        return cells
    }
}
