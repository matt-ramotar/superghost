import XCTest

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

final class ReleaseIdentityTests: XCTestCase {
    private final class EmptyDirectoriesFileManager: FileManager {
        override func urls(
            for directory: FileManager.SearchPathDirectory,
            in domainMask: FileManager.SearchPathDomainMask
        ) -> [URL] {
            []
        }
    }

    func testReleaseIdentityUsesSuperghostProductName() {
        XCTAssertEqual(ReleaseIdentity.productName, "Superghost")
    }

    func testReleaseIdentityUsesSuperghostBundleIdentifier() {
        XCTAssertEqual(ReleaseIdentity.bundleIdentifier, "sh.bionic.superghost")
    }

    func testReleaseIdentityUsesSuperghostExecutableName() {
        XCTAssertEqual(ReleaseIdentity.executableName, "Superghost")
    }

    func testStableReleaseAppBrandingRewritesLegacyCopy() {
        XCTAssertEqual(
            ReleaseIdentity.appBrandedText(
                "About cmux",
                currentBundleIdentifier: ReleaseIdentity.bundleIdentifier
            ),
            "About Superghost"
        )
    }

    func testLegacyAppBrandingLeavesLegacyCopyUnchanged() {
        XCTAssertEqual(
            ReleaseIdentity.appBrandedText(
                "About cmux",
                currentBundleIdentifier: ReleaseIdentity.legacyBundleIdentifier
            ),
            "About cmux"
        )
    }

    func testStableReleaseCLIBrandingRewritesLegacyUsageCopy() {
        XCTAssertEqual(
            ReleaseIdentity.cliBrandedText(
                "Usage: cmux omo",
                invokedExecutablePath: "/usr/local/bin/superghost"
            ),
            "Usage: superghost omo"
        )
    }

    func testFallbackFeedUsesSuperghostAppcast() {
        let resolved = UpdateFeedResolver.resolvedFeedURLString(
            infoFeedURL: nil,
            bundleIdentifier: ReleaseIdentity.bundleIdentifier
        )

        XCTAssertEqual(
            resolved.url,
            "https://github.com/matt-ramotar/superghost/releases/latest/download/superghost-appcast.xml"
        )
        XCTAssertTrue(resolved.usedFallback)
    }

    func testNonReleaseFallbackFeedUsesLegacyAppcast() {
        let resolved = UpdateFeedResolver.resolvedFeedURLString(
            infoFeedURL: nil,
            bundleIdentifier: ReleaseIdentity.legacyBundleIdentifier
        )

        XCTAssertTrue(resolved.url.hasSuffix("/appcast.xml"))
        XCTAssertFalse(resolved.url.hasSuffix("/superghost-appcast.xml"))
        XCTAssertTrue(resolved.usedFallback)
    }

    func testReleaseSocketDefaultsToSuperghostStablePath() {
        let path = SocketControlSettings.defaultSocketPath(
            bundleIdentifier: "sh.bionic.superghost",
            isDebugBuild: false,
            probeStableDefaultPathEntry: { _ in .missing }
        )

        XCTAssertEqual(path, "/tmp/superghost.sock")
    }

    func testStableReleaseFallbackLastSocketMarkerUsesSuperghostPath() {
        let path = SocketControlSettings.lastSocketPathFile(
            for: ReleaseIdentity.bundleIdentifier,
            fileManager: EmptyDirectoriesFileManager()
        )

        XCTAssertEqual(path, ReleaseIdentity.stableLastSocketPathFile)
    }

    func testSparkleInstallationCacheUsesSuperghostCacheDirectoryForStableRelease() {
        let cachesURL = URL(fileURLWithPath: "/tmp/test-caches", isDirectory: true)

        let resolved = UpdateController.sparkleInstallationCacheBaseURL(
            bundleIdentifier: ReleaseIdentity.bundleIdentifier,
            cachesURL: cachesURL
        )

        XCTAssertEqual(
            resolved.path,
            "/tmp/test-caches/Superghost/org.sparkle-project.Sparkle"
        )
    }

    func testSuperghostCLIUsesSuperghostSocketIdentity() {
        let invokedExecutablePath = "/usr/local/bin/superghost"

        XCTAssertTrue(
            ReleaseIdentity.usesStableReleaseCommand(invokedExecutablePath: invokedExecutablePath)
        )
        XCTAssertEqual(
            ReleaseIdentity.appSupportDirectoryName(forInvokedExecutablePath: invokedExecutablePath),
            "Superghost"
        )
        XCTAssertEqual(ReleaseIdentity.stableSocketPath, "/tmp/superghost.sock")
        XCTAssertEqual(
            ReleaseIdentity.lastSocketPathFallback(forInvokedExecutablePath: invokedExecutablePath),
            "/tmp/superghost-last-socket-path"
        )
        XCTAssertEqual(
            ReleaseIdentity.userScopedSocketPath(
                forInvokedExecutablePath: invokedExecutablePath,
                currentUserID: 501
            ),
            "/tmp/superghost-501.sock"
        )
        XCTAssertEqual(ReleaseIdentity.legacyStableSocketPath, "/tmp/cmux.sock")
    }

    func testSuperghostCLIUsesForkReleaseRepositorySlug() {
        XCTAssertEqual(
            ReleaseIdentity.releaseRepositorySlug(forInvokedExecutablePath: "/usr/local/bin/superghost"),
            "matt-ramotar/superghost"
        )
        XCTAssertEqual(
            ReleaseIdentity.releaseRepositorySlug(forInvokedExecutablePath: "/usr/local/bin/cmux"),
            "manaflow-ai/cmux"
        )
    }
}
