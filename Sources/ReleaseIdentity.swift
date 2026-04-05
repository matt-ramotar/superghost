import Darwin
import Foundation

enum ReleaseIdentity {
    static let productName = "Superghost"
    static let executableName = "Superghost"
    static let bundleIdentifier = "sh.bionic.superghost"
    static let stableAppSupportDirectoryName = "Superghost"
    static let stableCacheDirectoryName = "Superghost"
    static let stableBundledCLIName = "superghost"
    static let stableSocketPath = "/tmp/superghost.sock"
    static let stableLastSocketPathFile = "/tmp/superghost-last-socket-path"
    static let stableAppcastAssetName = "superghost-appcast.xml"
    static let stableDMGAssetName = "superghost-macos.dmg"

    static let legacyProductName = "cmux"
    static let legacyBundleIdentifier = "com.cmuxterm.app"
    static let legacyAppSupportDirectoryName = "cmux"
    static let legacyCacheDirectoryName = "cmux"
    static let legacyBundledCLIName = "cmux"
    static let legacyStableSocketPath = "/tmp/cmux.sock"
    static let legacyStableAppcastAssetName = "appcast.xml"
    static let legacyLastSocketPathFile = "/tmp/cmux-last-socket-path"

    private static let releaseDownloadBaseURL = "https://github.com/manaflow-ai/cmux/releases/latest/download"

    static var stableAppcastURL: String {
        "\(releaseDownloadBaseURL)/\(stableAppcastAssetName)"
    }

    static var legacyStableAppcastURL: String {
        "\(releaseDownloadBaseURL)/\(legacyStableAppcastAssetName)"
    }

    static func isStableReleaseBundleIdentifier(_ currentBundleIdentifier: String?) -> Bool {
        normalize(currentBundleIdentifier) == bundleIdentifier
    }

    static func displayName(for currentBundleIdentifier: String?) -> String {
        isStableReleaseBundleIdentifier(currentBundleIdentifier) ? productName : legacyProductName
    }

    static func currentAppDisplayName(bundle: Bundle = .main) -> String {
        displayName(for: bundle.bundleIdentifier)
    }

    static func appSupportDirectoryName(for currentBundleIdentifier: String?) -> String {
        isStableReleaseBundleIdentifier(currentBundleIdentifier)
            ? stableAppSupportDirectoryName
            : legacyAppSupportDirectoryName
    }

    static func cacheDirectoryName(for currentBundleIdentifier: String?) -> String {
        isStableReleaseBundleIdentifier(currentBundleIdentifier)
            ? stableCacheDirectoryName
            : legacyCacheDirectoryName
    }

    static func bundledCLIName(for currentBundleIdentifier: String?) -> String {
        isStableReleaseBundleIdentifier(currentBundleIdentifier)
            ? stableBundledCLIName
            : legacyBundledCLIName
    }

    static func currentCLICommandName(invokedExecutablePath: String? = CommandLine.arguments.first) -> String {
        usesStableReleaseCommand(invokedExecutablePath: invokedExecutablePath)
            ? stableBundledCLIName
            : legacyBundledCLIName
    }

    static func appBrandedText(_ text: String, bundle: Bundle = .main) -> String {
        appBrandedText(text, currentBundleIdentifier: bundle.bundleIdentifier)
    }

    static func appBrandedText(_ text: String, currentBundleIdentifier: String?) -> String {
        replaceLegacyName(
            in: text,
            currentName: displayName(for: currentBundleIdentifier),
            legacyName: legacyProductName
        )
    }

    static func cliBrandedText(
        _ text: String,
        invokedExecutablePath: String? = CommandLine.arguments.first
    ) -> String {
        replaceLegacyName(
            in: text,
            currentName: currentCLICommandName(invokedExecutablePath: invokedExecutablePath),
            legacyName: legacyBundledCLIName
        )
    }

    static func localizedAppString(
        _ key: StaticString,
        defaultValue: String.LocalizationValue,
        bundle: Bundle = .main
    ) -> String {
        appBrandedText(String(localized: key, defaultValue: defaultValue), bundle: bundle)
    }

    static func localizedCLIString(
        _ key: StaticString,
        defaultValue: String.LocalizationValue,
        invokedExecutablePath: String? = CommandLine.arguments.first
    ) -> String {
        cliBrandedText(
            String(localized: key, defaultValue: defaultValue),
            invokedExecutablePath: invokedExecutablePath
        )
    }

    static func usesStableReleaseCommand(invokedExecutablePath: String? = CommandLine.arguments.first) -> Bool {
        normalizedCommandName(invokedExecutablePath) == stableBundledCLIName
    }

    static func appSupportDirectoryName(forInvokedExecutablePath invokedExecutablePath: String? = CommandLine.arguments.first) -> String {
        usesStableReleaseCommand(invokedExecutablePath: invokedExecutablePath)
            ? stableAppSupportDirectoryName
            : legacyAppSupportDirectoryName
    }

    static func lastSocketPathFallback(forInvokedExecutablePath invokedExecutablePath: String? = CommandLine.arguments.first) -> String {
        usesStableReleaseCommand(invokedExecutablePath: invokedExecutablePath)
            ? stableLastSocketPathFile
            : legacyLastSocketPathFile
    }

    static func userScopedSocketPath(
        forInvokedExecutablePath invokedExecutablePath: String? = CommandLine.arguments.first,
        currentUserID: uid_t = getuid()
    ) -> String? {
        guard usesStableReleaseCommand(invokedExecutablePath: invokedExecutablePath) else {
            return nil
        }
        return userScopedStableSocketPath(currentUserID: currentUserID)
    }

    static func bundledCLIURL(bundle: Bundle = .main) -> URL? {
        bundle.resourceURL?.appendingPathComponent("bin/\(bundledCLIName(for: bundle.bundleIdentifier))", isDirectory: false)
    }

    static func bundledCLIExpectedPath(bundle: Bundle = .main) -> String {
        bundle.bundleURL
            .appendingPathComponent("Contents/Resources/bin/\(bundledCLIName(for: bundle.bundleIdentifier))", isDirectory: false)
            .path
    }

    static func defaultCLIInstallDestinationURL(bundleIdentifier currentBundleIdentifier: String?) -> URL {
        let command = bundledCLIName(for: currentBundleIdentifier)
        return URL(fileURLWithPath: "/usr/local/bin/\(command)", isDirectory: false)
    }

    static func notificationNamespace(for currentBundleIdentifier: String?) -> String {
        isStableReleaseBundleIdentifier(currentBundleIdentifier)
            ? bundleIdentifier
            : legacyBundleIdentifier
    }

    static func userScopedStableSocketPath(currentUserID: uid_t = getuid()) -> String {
        "/tmp/superghost-\(currentUserID).sock"
    }

    private static func normalizedCommandName(_ invokedExecutablePath: String?) -> String? {
        guard let value = normalize(invokedExecutablePath) else { return nil }
        return URL(fileURLWithPath: value).lastPathComponent.lowercased()
    }

    private static func replaceLegacyName(
        in text: String,
        currentName: String,
        legacyName: String
    ) -> String {
        guard currentName != legacyName else { return text }
        return text.replacingOccurrences(of: legacyName, with: currentName)
    }

    private static func normalize(_ bundleIdentifier: String?) -> String? {
        guard let bundleIdentifier else { return nil }
        let trimmed = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
