import XCTest

final class CLIWelcomeBrandingTests: XCTestCase {
    func testWelcomeOutputUsesSuperghostBranding() throws {
        let output = try runCLI(arguments: ["welcome"])

        let plain = stripANSIEscapeCodes(output)
        XCTAssertTrue(plain.contains("Superghost"))
        XCTAssertTrue(plain.contains("https://cmux.com/docs"))
        XCTAssertTrue(plain.contains("https://github.com/manaflow-ai/cmux"))
        XCTAssertTrue(plain.contains("Run cmux --help for all commands."))
        XCTAssertFalse(plain.contains("https://superghost.bionic.sh/docs"))
        XCTAssertFalse(plain.contains("https://github.com/matt-ramotar/superghost"))
        XCTAssertFalse(plain.contains("Run superghost --help for all commands."))
    }

    func testWelcomeHelpUsesSuperghostBranding() throws {
        let output = try runCLI(arguments: ["welcome", "--help"])

        XCTAssertTrue(output.contains("Usage: cmux welcome"))
        XCTAssertTrue(output.contains("Show a welcome screen with the Superghost logo"))
        XCTAssertFalse(output.contains("Usage: superghost welcome"))
        XCTAssertFalse(output.contains("Show a welcome screen with the cmux logo"))
    }

    func testUnknownCommandHelpHintUsesCmuxCommand() throws {
        let output = try runCLI(arguments: ["unknown-command", "--help"])

        XCTAssertTrue(output.contains("Run 'cmux help' to see available commands."))
        XCTAssertFalse(output.contains("Run 'superghost help' to see available commands."))
    }

    private func runCLI(arguments: [String]) throws -> String {
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
        XCTAssertEqual(process.terminationStatus, 0, "CLI exited non-zero: \(process.terminationStatus)")
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func stripANSIEscapeCodes(_ value: String) -> String {
        value.replacingOccurrences(
            of: "\u{001B}\\[[0-9;?]*[ -/]*[@-~]",
            with: "",
            options: .regularExpression
        )
    }
}
