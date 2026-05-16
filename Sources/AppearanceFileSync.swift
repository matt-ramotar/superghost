import Foundation
import AppKit
import Combine
import Darwin
#if DEBUG
import Bonsplit
#endif

// `AppearanceFileSync` is the bidirectional bridge between `ThemeStore` and the on-disk
// theme files (the Ghostty config + `appearance.json`). It serves two purposes:
//
//   1. **Outbound debounced writer.** After the user changes a theme in the panel,
//      `scheduleWrite()` queues a write 300 ms after the last change so we don't thrash
//      the disk on slider drags.
//   2. **Inbound conflict detector.** A `DispatchSourceFileSystemObject` watches the same
//      files; if a write arrives from outside Superghost (a dotfile user editing in
//      `vim`), we surface the change either by reloading (no pending in-panel edits) or
//      by publishing a conflict on `$pendingConflict` for the panel to surface.
//
// The plan rejects the handoff's "last-write-wins" policy for the Ghostty config file
// specifically (plan §2.6 / R5): an editor user with the panel open can lose work mid-
// session if we silently overwrite their saves. The Superghost-only `appearance.json` is
// allowed to last-write-win because Superghost is the only writer.
//
// The class is `@MainActor` because all of its `@Published` mutations and timer scheduling
// happen on the main run loop. The file watcher dispatches off-main and hops to main when
// it needs to publish.
@MainActor
final class AppearanceFileSync: ObservableObject {
    static let shared = AppearanceFileSync()

    // The debounce interval. 300 ms is the handoff's spec; slow enough that slider drags
    // don't thrash, fast enough that a click-to-save isn't perceptibly delayed.
    static let debounceInterval: TimeInterval = 0.300

    // Surfaced to the panel UI when an external edit lands while there are pending in-
    // panel changes. `nil` means no conflict; non-`nil` means the panel should show the
    // conflict prompt with the external edit's contents.
    @Published private(set) var pendingConflict: ConflictReport?

    // Set whenever the user makes an in-panel edit that hasn't been flushed to disk yet.
    // Used by the file watcher to distinguish "pure external edit during idle panel" from
    // "external edit racing with pending panel work."
    @Published private(set) var hasPendingEdits: Bool = false

    // Identity of the last successful write — used to ignore the file-watcher event that
    // our own write triggers. Without this, every save would round-trip into a "conflict"
    // because the watcher would see our own change.
    private var lastWrittenGhosttyConfigDigest: String?
    private var lastWrittenAppearanceJsonDigest: String?

    private var ghosttyWatcher: DispatchSourceFileSystemObject?
    private var appearanceWatcher: DispatchSourceFileSystemObject?
    private var ghosttyFD: Int32 = -1
    private var appearanceFD: Int32 = -1
    private let watchQueue = DispatchQueue(label: "cmux.appearance.sync.watch", qos: .utility)

    private var pendingWriteWorkItem: DispatchWorkItem?

    private init() {
        // The watchers are lazily started on first `scheduleWrite()` to avoid eagerly
        // touching the filesystem at app launch. M3 only needs them once the panel opens
        // or the user makes a change.
    }

    deinit {
        // Watchers are torn down by their own cancel handlers; `deinit` only sees the
        // pending timer.
        pendingWriteWorkItem?.cancel()
    }

    // MARK: - Public API

    // Schedule a write for the active theme. Multiple calls within `debounceInterval`
    // collapse to one write. Called by `ThemeStore.applyTheme(_:)` (and any future edit
    // path) right after the in-memory state changes.
    func scheduleWrite(theme: SuperghostTheme) {
        hasPendingEdits = true
        pendingWriteWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.flushWrite(theme: theme)
            }
        }
        pendingWriteWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounceInterval, execute: work)
        ensureWatchersStarted()
    }

    // The conflict report surfaced by the panel UI as an alert/sheet.
    struct ConflictReport: Identifiable, Equatable {
        let id = UUID()
        let path: URL
        let externalContents: String
        let panelExpectedContents: String

        // Short form for the prompt body. Truncates large diffs.
        var summary: String {
            let lhs = externalContents.prefix(280)
            return lhs.isEmpty
                ? "(empty)"
                : String(lhs)
        }
    }

    // User chose "Reload from disk" — wipe pending edits and re-load.
    func acceptExternalEdit() {
        guard pendingConflict != nil else { return }
        pendingConflict = nil
        hasPendingEdits = false
        // The actual reload is the responsibility of `ThemeStore` (which holds the
        // canonical in-memory state). It observes `pendingConflict` going from non-nil to
        // nil and triggers a fresh `GhosttyConfig.load(...)`. Wiring landing in M3 hookup.
    }

    // User chose "Keep panel edits" — flush our pending work over the file again so the
    // file matches the panel state.
    func overridePanelEdits(with theme: SuperghostTheme) {
        guard pendingConflict != nil else { return }
        pendingConflict = nil
        // Cancel any pending debounce and write now so the file is consistent before the
        // user does anything else.
        pendingWriteWorkItem?.cancel()
        pendingWriteWorkItem = nil
        flushWrite(theme: theme)
    }

    // MARK: - Outbound writer

    private func flushWrite(theme: SuperghostTheme) {
        pendingWriteWorkItem = nil
        hasPendingEdits = false

        // 1. Write the Ghostty config snippet that captures terminal colors. Format
        //    matches the existing parser in `GhosttyConfig.parse(_:)` so dotfile users
        //    see a round-trippable file.
        let configPath = Self.ghosttyConfigURL()
        let configContents = renderGhosttyConfigSnippet(for: theme)
        var configWritten = false
        do {
            try ensureParentDirectoryExists(for: configPath)
            try writeAtomically(configContents, to: configPath)
            lastWrittenGhosttyConfigDigest = digest(of: configContents)
            configWritten = true
        } catch {
            #if DEBUG
            dlog("appearance.sync.write_failed path=\(configPath.lastPathComponent) error=\(error)")
            #endif
        }

        // 2. Write the Superghost-only chrome tokens to `appearance.json`. Last-write-
        //    wins is fine here (plan §2.6) — Superghost is the only writer.
        let appearancePath = Self.appearanceJsonURL()
        let appearanceContents = (try? renderAppearanceJson(for: theme)) ?? ""
        if !appearanceContents.isEmpty {
            do {
                try ensureParentDirectoryExists(for: appearancePath)
                try writeAtomically(appearanceContents, to: appearancePath)
                lastWrittenAppearanceJsonDigest = digest(of: appearanceContents)
            } catch {
                #if DEBUG
                dlog("appearance.sync.write_failed path=\(appearancePath.lastPathComponent) error=\(error)")
                #endif
            }
        }

        // 3. If we updated the Ghostty config, kick the running Ghostty surfaces to
        //    re-read it. Without this, the on-screen terminal background never
        //    changes after a preset switch — the file lands on disk but no one
        //    rereads it until the next app launch or manual Reload Configuration.
        //    The reload itself fans out to every surface via
        //    `refreshTerminalSurfacesAfterGhosttyConfigReload`, so all open tabs
        //    repaint in the same frame.
        if configWritten {
            GhosttyApp.shared.reloadConfiguration(source: "appearanceFileSync.flush")
        }
    }

    // Bypass the debounce and write the theme to disk right now. Use this for
    // preset switches where the user wants instant visual feedback; the
    // debounced `scheduleWrite` stays for slider drags and other high-frequency
    // edits where coalescing wins.
    func flushImmediately(theme: SuperghostTheme) {
        pendingWriteWorkItem?.cancel()
        pendingWriteWorkItem = nil
        flushWrite(theme: theme)
        ensureWatchersStarted()
    }

    private func renderGhosttyConfigSnippet(for theme: SuperghostTheme) -> String {
        // The on-disk Ghostty config snippet. Matches what `GhosttyConfig.parse(_:)`
        // expects: `key = value` lines, `palette` entries as `palette = index=#rrggbb`.
        // We deliberately don't write a `theme = ...` line — we ship terminal colors
        // directly so external edits to `theme = ...` don't accidentally take precedence.
        var lines: [String] = []
        lines.append("# Managed by Superghost — Appearance panel")
        lines.append("# Edit this file by hand to override; see Appearance → Reload from disk.")
        lines.append("")
        lines.append("background = \(theme.backgroundColor.hexString())")
        lines.append("foreground = \(theme.foregroundColor.hexString())")
        lines.append("cursor-color = \(theme.cursorColor.hexString())")
        lines.append("cursor-text = \(theme.cursorTextColor.hexString())")
        lines.append("selection-background = \(theme.selectionBackground.hexString())")
        lines.append("selection-foreground = \(theme.selectionForeground.hexString())")
        for index in 0...15 {
            guard let color = theme.palette[index] else { continue }
            lines.append("palette = \(index)=\(color.hexString())")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func renderAppearanceJson(for theme: SuperghostTheme) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(theme)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func writeAtomically(_ contents: String, to url: URL) throws {
        let data = Data(contents.utf8)
        try data.write(to: url, options: [.atomic])
    }

    private func ensureParentDirectoryExists(for url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func digest(of contents: String) -> String {
        // SHA-style digest would be more correct, but a stable hash is sufficient — we
        // only use it to recognize "this is the file we just wrote." Collisions are
        // benign (worst case: we miss an external edit; the user's next edit reveals it).
        return String(contents.hashValue)
    }

    // MARK: - Inbound watcher

    private func ensureWatchersStarted() {
        if ghosttyWatcher == nil {
            startWatcher(at: Self.ghosttyConfigURL(), assignTo: \.ghosttyWatcher, fdAssignTo: \.ghosttyFD) { [weak self] path in
                Task { @MainActor [weak self] in
                    self?.handleExternalEdit(at: path, isGhosttyConfig: true)
                }
            }
        }
        if appearanceWatcher == nil {
            startWatcher(at: Self.appearanceJsonURL(), assignTo: \.appearanceWatcher, fdAssignTo: \.appearanceFD) { [weak self] path in
                Task { @MainActor [weak self] in
                    self?.handleExternalEdit(at: path, isGhosttyConfig: false)
                }
            }
        }
    }

    private func startWatcher(
        at url: URL,
        assignTo sourceKeyPath: ReferenceWritableKeyPath<AppearanceFileSync, DispatchSourceFileSystemObject?>,
        fdAssignTo fdKeyPath: ReferenceWritableKeyPath<AppearanceFileSync, Int32>,
        onChange: @escaping @Sendable (URL) -> Void
    ) {
        // If the file doesn't exist yet, we can't watch it. The first `scheduleWrite` will
        // create it, and the next `ensureWatchersStarted` call will pick it up.
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend],
            queue: watchQueue
        )
        source.setEventHandler {
            onChange(url)
        }
        source.setCancelHandler {
            Darwin.close(fd)
        }
        source.resume()
        self[keyPath: sourceKeyPath] = source
        self[keyPath: fdKeyPath] = fd
    }

    private func handleExternalEdit(at url: URL, isGhosttyConfig: Bool) {
        // Off-main on `watchQueue`. Read the file off-main; hop to main to publish.
        let contents = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let observed = digest(of: contents)
        let expected = isGhosttyConfig ? lastWrittenGhosttyConfigDigest : lastWrittenAppearanceJsonDigest
        guard observed != expected else {
            // It's our own write echoing back. Ignore.
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.hasPendingEdits, isGhosttyConfig {
                // Real conflict: user has unsaved panel edits AND someone else wrote the
                // file. Surface the prompt so the user picks. Per plan §2.6, this is
                // only enforced for the Ghostty config (where editor users exist);
                // appearance.json silently last-write-wins.
                self.pendingConflict = ConflictReport(
                    path: url,
                    externalContents: contents,
                    panelExpectedContents: ""
                )
            } else {
                // No pending edits → reload silently. The actual reload is `ThemeStore`'s
                // job; we just clear our digest so a subsequent identical write isn't
                // treated as a no-op.
                if isGhosttyConfig {
                    self.lastWrittenGhosttyConfigDigest = observed
                } else {
                    self.lastWrittenAppearanceJsonDigest = observed
                }
                NotificationCenter.default.post(name: Self.externalEditAcceptedNotification, object: url)
            }
        }
    }

    // Posted when an external edit is accepted silently. `ThemeStore` listens and reloads.
    static let externalEditAcceptedNotification = Notification.Name("cmux.appearance.externalEditAccepted")

    // MARK: - Paths

    static func ghosttyConfigURL() -> URL {
        appSupportDirectory().appendingPathComponent("config", isDirectory: false)
    }

    static func appearanceJsonURL() -> URL {
        appSupportDirectory().appendingPathComponent("appearance.json", isDirectory: false)
    }

    private static func appSupportDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        // Match the reader path in `GhosttyTerminalView.cmuxAppSupportConfigURLs`
        // exactly. That code uses:
        //   - "Superghost" for the stable release bundle, AND
        //   - the literal current bundle identifier (e.g.
        //     "com.cmuxterm.app.debug.theme-m8") for everything else,
        //   - with the stable directory as a fallback for debug-like bundles
        //     when the bundle-specific directory doesn't exist.
        // We deliberately do NOT use `ReleaseIdentity.appSupportDirectoryName(for:)`
        // here because that helper collapses every non-stable bundle to the
        // literal string "cmux" — a path the Ghostty reader never visits.
        // Writing to that collapsed path silently no-ops on every DEV / tagged
        // build, which is what broke preset switches in tagged builds during
        // the M8 manual test.
        let bundleId = Bundle.main.bundleIdentifier ?? ReleaseIdentity.bundleIdentifier
        if ReleaseIdentity.isStableReleaseBundleIdentifier(bundleId) {
            return appSupport.appendingPathComponent(ReleaseIdentity.stableAppSupportDirectoryName, isDirectory: true)
        }
        return appSupport.appendingPathComponent(bundleId, isDirectory: true)
    }
}
