import XCTest

final class CLIWelcomeBrandingTests: XCTestCase {
    func testWelcomeOutputUsesSuperghostBranding() throws {
        let output = try runCLI(arguments: ["welcome"])

        let plain = stripANSIEscapeCodes(output)
        XCTAssertTrue(plain.contains("👻"))
        XCTAssertFalse(plain.contains("Superghost"))
        XCTAssertFalse(plain.contains("the terminal for coding agents"))
        XCTAssertFalse(plain.contains("built for focused agent workflows"))
        XCTAssertFalse(plain.localizedCaseInsensitiveContains("cmux"))
        XCTAssertFalse(plain.contains("Docs"))
        XCTAssertFalse(plain.contains("Discord"))
        XCTAssertFalse(plain.contains("GitHub"))
        XCTAssertFalse(plain.contains("Email"))
        XCTAssertFalse(plain.contains("https://cmux.com/docs"))
        XCTAssertFalse(plain.contains("https://github.com/manaflow-ai/cmux"))
    }

    func testWelcomeHelpUsesSuperghostBranding() throws {
        let output = try runCLI(arguments: ["welcome", "--help"])

        XCTAssertTrue(output.contains("superghost boo"))
        XCTAssertTrue(output.contains("Usage: superghost boo"))
        XCTAssertTrue(output.contains("Show the Superghost welcome screen and useful shortcuts."))
        XCTAssertFalse(output.contains("cmux welcome"))
        XCTAssertFalse(output.contains("Usage: cmux welcome"))
        XCTAssertFalse(output.contains("Show a welcome screen with the cmux logo"))
    }

    func testBuiltAppBundleContainsExecutableSuperghostShim() throws {
        let appBundleURL = try locateBuiltAppBundle()
        let superghostURL = appBundleURL
            .appendingPathComponent("Contents/Resources/bin", isDirectory: true)
            .appendingPathComponent("superghost", isDirectory: false)

        XCTAssertTrue(
            FileManager.default.isExecutableFile(atPath: superghostURL.path),
            "Expected built app bundle to contain executable superghost shim at \(superghostURL.path)"
        )

        let result = try runProcess(executableURL: superghostURL, arguments: ["boo", "--help"])
        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertTrue(result.output.contains("superghost boo"))
        XCTAssertTrue(result.output.contains("Usage: superghost boo"))
    }

    func testGeneratedSuperghostShimExecutesOnlyBoo() throws {
        let shimDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: shimDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: shimDirectory) }

        let shimURL = shimDirectory.appendingPathComponent("superghost", isDirectory: false)
        let executableURL = try locateCLIExecutable()
        try generateSuperghostShim(
            shimURL: shimURL,
            fallbackURL: executableURL,
            mode: "fallback-only"
        )

        let helpResult = try runProcess(executableURL: shimURL, arguments: ["boo", "--help"])
        XCTAssertEqual(helpResult.terminationStatus, 0)
        XCTAssertTrue(helpResult.output.contains("superghost boo"))
        XCTAssertTrue(helpResult.output.contains("Usage: superghost boo"))

        let negativeResult = try runProcess(executableURL: shimURL, arguments: ["help"])
        XCTAssertNotEqual(negativeResult.terminationStatus, 0)
        XCTAssertTrue(negativeResult.output.contains("only 'superghost boo' is supported"))
    }

    func testBundleLocalSuperghostShimIgnoresSelectedCLIPath() throws {
        let shimDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: shimDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: shimDirectory) }

        let shimURL = shimDirectory.appendingPathComponent("superghost", isDirectory: false)
        let selectedURL = shimDirectory.appendingPathComponent("selected-cli", isDirectory: false)
        let fallbackURL = shimDirectory.appendingPathComponent("fallback-cli", isDirectory: false)
        try writeExecutable(at: selectedURL, body: "#!/usr/bin/env bash\necho selected:$*\n")
        try writeExecutable(at: fallbackURL, body: "#!/usr/bin/env bash\necho fallback:$*\n")

        let cliPathFile = URL(fileURLWithPath: "/tmp/cmux-last-cli-path", isDirectory: false)
        let savedState = try captureFileState(at: cliPathFile)
        defer { try? restoreFileState(savedState, at: cliPathFile) }
        try selectedURL.path.write(to: cliPathFile, atomically: true, encoding: .utf8)

        try generateSuperghostShim(
            shimURL: shimURL,
            fallbackURL: fallbackURL,
            mode: "fallback-only"
        )

        let result = try runProcess(executableURL: shimURL, arguments: ["boo", "sentinel"])
        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertTrue(result.output.contains("fallback:welcome sentinel"))
        XCTAssertFalse(result.output.contains("selected:"))
    }

    func testExternalSuperghostShimUsesSelectedCLIPath() throws {
        let shimDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: shimDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: shimDirectory) }

        let shimURL = shimDirectory.appendingPathComponent("superghost", isDirectory: false)
        let selectedURL = shimDirectory.appendingPathComponent("selected-cli", isDirectory: false)
        let fallbackURL = shimDirectory.appendingPathComponent("fallback-cli", isDirectory: false)
        try writeExecutable(at: selectedURL, body: "#!/usr/bin/env bash\necho selected:$*\n")
        try writeExecutable(at: fallbackURL, body: "#!/usr/bin/env bash\necho fallback:$*\n")

        let cliPathFile = URL(fileURLWithPath: "/tmp/cmux-last-cli-path", isDirectory: false)
        let savedState = try captureFileState(at: cliPathFile)
        defer { try? restoreFileState(savedState, at: cliPathFile) }
        try selectedURL.path.write(to: cliPathFile, atomically: true, encoding: .utf8)

        try generateSuperghostShim(
            shimURL: shimURL,
            fallbackURL: fallbackURL,
            mode: "prefer-last-cli"
        )

        let result = try runProcess(executableURL: shimURL, arguments: ["boo", "sentinel"])
        XCTAssertEqual(result.terminationStatus, 0)
        XCTAssertTrue(result.output.contains("selected:welcome sentinel"))
        XCTAssertFalse(result.output.contains("fallback:"))
    }

    func testUnknownCommandHelpHintUsesCmuxCommand() throws {
        let output = try runCLI(arguments: ["unknown-command", "--help"])

        XCTAssertTrue(output.contains("Run 'cmux help' to see available commands."))
        XCTAssertFalse(output.contains("Run 'superghost help' to see available commands."))
    }

    private func runCLI(arguments: [String]) throws -> String {
        let executableURL = try locateCLIExecutable()
        let result = try runProcess(executableURL: executableURL, arguments: arguments)
        XCTAssertEqual(result.terminationStatus, 0, "CLI exited non-zero: \(result.terminationStatus)")
        return result.output
    }

    private func locateCLIExecutable() throws -> URL {
        var candidateDirectories: [URL] = []
        if let builtProductsDirectory = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
            candidateDirectories.append(URL(fileURLWithPath: builtProductsDirectory, isDirectory: true))
        }

        var current = Bundle(for: Self.self).bundleURL
        for _ in 0..<5 {
            current.deleteLastPathComponent()
            candidateDirectories.append(current)
        }

        let executableCandidates = candidateDirectories.map { directory in
            directory.appendingPathComponent("cmux")
        }

        guard let executableURL = executableCandidates.first(where: { candidate in
            FileManager.default.isExecutableFile(atPath: candidate.path)
        }) else {
            let candidatePaths = candidateDirectories.map { $0.path }.joined(separator: ", ")
            XCTFail("Unable to locate built cmux executable in candidate directories: \(candidatePaths)")
            throw NSError(domain: "CLIWelcomeBrandingTests", code: 1)
        }

        return executableURL
    }

    private func locateBuiltAppBundle() throws -> URL {
        var candidateDirectories: [URL] = []
        if let builtProductsDirectory = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
            candidateDirectories.append(URL(fileURLWithPath: builtProductsDirectory, isDirectory: true))
        }

        var current = Bundle(for: Self.self).bundleURL
        for _ in 0..<5 {
            current.deleteLastPathComponent()
            candidateDirectories.append(current)
        }

        guard let bundleURL = candidateDirectories
            .map({ $0.appendingPathComponent("cmux DEV.app", isDirectory: true) })
            .first(where: { FileManager.default.fileExists(atPath: $0.path) })
        else {
            let candidatePaths = candidateDirectories.map { $0.path }.joined(separator: ", ")
            XCTFail("Unable to locate built cmux app bundle in candidate directories: \(candidatePaths)")
            throw NSError(domain: "CLIWelcomeBrandingTests", code: 2)
        }

        return bundleURL
    }

    private func locateShimHelper() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("scripts/write-superghost-shim.sh", isDirectory: false)
    }

    private func generateSuperghostShim(shimURL: URL, fallbackURL: URL, mode: String) throws {
        let helper = Process()
        helper.executableURL = locateShimHelper()
        helper.arguments = [shimURL.path, fallbackURL.path, mode]
        try helper.run()
        helper.waitUntilExit()
        XCTAssertEqual(helper.terminationStatus, 0, "Failed to generate superghost shim")
    }

    private func runProcess(executableURL: URL, arguments: [String]) throws -> (terminationStatus: Int32, output: String) {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
    }

    private func writeExecutable(at url: URL, body: String) throws {
        try body.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func captureFileState(at url: URL) throws -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    private func restoreFileState(_ state: Data?, at url: URL) throws {
        if let state {
            try state.write(to: url, options: .atomic)
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func stripANSIEscapeCodes(_ value: String) -> String {
        value.replacingOccurrences(
            of: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]",
            with: "",
            options: .regularExpression
        )
    }
}
