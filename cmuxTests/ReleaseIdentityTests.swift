import XCTest

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

final class ReleaseIdentityTests: XCTestCase {
    func testReleaseIdentityUsesSuperghostProductName() {
        XCTAssertEqual(ReleaseIdentity.productName, "Superghost")
    }

    func testReleaseIdentityUsesSuperghostBundleIdentifier() {
        XCTAssertEqual(ReleaseIdentity.bundleIdentifier, "sh.bionic.superghost")
    }

    func testReleaseIdentityUsesSuperghostExecutableName() {
        XCTAssertEqual(ReleaseIdentity.executableName, "Superghost")
    }

    func testFallbackFeedUsesSuperghostAppcast() {
        let resolved = UpdateFeedResolver.resolvedFeedURLString(infoFeedURL: nil)

        XCTAssertTrue(resolved.url.hasSuffix("/superghost-appcast.xml"))
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
}
