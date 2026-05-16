import Foundation

// `ThemeURL` produces and parses `superghost://theme?...` deep links for the
// Milestone 6 "Share theme URL" footer action. The URL serialises the active
// `SuperghostTheme` as a JSON payload and base64-encodes it into a single query
// parameter so the link is copy-paste safe in chat, email, and editors that
// fold long URLs.
//
// Format:
//
//   superghost://theme?v=1&t=<base64-url-encoded JSON>
//
// `v` is the schema version. We anticipate future format changes (additional
// fields, compression) and the version lets the receiver gracefully reject
// payloads it doesn't understand. M6 only emits and accepts v=1.
//
// The URL handler lives in `cmuxApp` and routes accepted payloads to
// `ThemeStore.applyTheme(_:)`.
enum ThemeURL {
    static let scheme = "superghost"
    static let host = "theme"
    static let versionParameterName = "v"
    static let dataParameterName = "t"
    static let currentVersion = "1"

    enum DecodeError: Error, CustomStringConvertible {
        case wrongScheme
        case wrongHost
        case missingVersion
        case unsupportedVersion(String)
        case missingPayload
        case malformedBase64
        case malformedJson(Error)

        var description: String {
            switch self {
            case .wrongScheme:
                return "URL scheme is not superghost://"
            case .wrongHost:
                return "URL host is not 'theme'"
            case .missingVersion:
                return "URL is missing the version parameter"
            case .unsupportedVersion(let v):
                return "Unsupported theme URL version: \(v)"
            case .missingPayload:
                return "URL is missing the theme payload"
            case .malformedBase64:
                return "Theme payload is not valid base64"
            case .malformedJson(let error):
                return "Theme payload JSON is malformed: \(error)"
            }
        }
    }

    // Encode a theme to a `superghost://theme?...` URL. Returns nil if JSON
    // encoding fails (should be impossible for a well-formed SuperghostTheme).
    static func encode(_ theme: SuperghostTheme) -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(theme) else { return nil }
        // Use base64url (URL- and filename-safe variant): + → -, / → _, no padding.
        let base64url = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: versionParameterName, value: currentVersion),
            URLQueryItem(name: dataParameterName, value: base64url)
        ]
        return components.url
    }

    // Decode a `superghost://theme?...` URL back into a SuperghostTheme. Used by
    // the URL handler in cmuxApp.
    static func decode(_ url: URL) throws -> SuperghostTheme {
        guard url.scheme == scheme else { throw DecodeError.wrongScheme }
        guard url.host == host else { throw DecodeError.wrongHost }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw DecodeError.missingPayload
        }
        let items = components.queryItems ?? []
        let version = items.first(where: { $0.name == versionParameterName })?.value
        guard let version else { throw DecodeError.missingVersion }
        guard version == currentVersion else { throw DecodeError.unsupportedVersion(version) }
        guard let payload = items.first(where: { $0.name == dataParameterName })?.value, !payload.isEmpty else {
            throw DecodeError.missingPayload
        }

        // Convert base64url back to standard base64 by re-padding and substituting.
        var b64 = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingRemainder = b64.count % 4
        if paddingRemainder != 0 {
            b64 += String(repeating: "=", count: 4 - paddingRemainder)
        }
        guard let data = Data(base64Encoded: b64) else { throw DecodeError.malformedBase64 }
        do {
            return try JSONDecoder().decode(SuperghostTheme.self, from: data)
        } catch {
            throw DecodeError.malformedJson(error)
        }
    }
}
