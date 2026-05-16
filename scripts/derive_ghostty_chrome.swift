#!/usr/bin/env swift

// scripts/derive_ghostty_chrome.swift
//
// Build-time / pre-commit script that runs `ThemeTokens.deriveChromeFrom(...)` against
// every theme file in the Ghostty submodule and emits a CSV summary with WCAG AA pass/fail
// for the derived chrome.
//
// The plan calls for this as Milestone 4's R6 mitigation: before we ship the future
// "Browse Ghostty library" panel (M7), we need to know which of the 312 themes produce
// usable chrome under our derivation algorithm. The CSV is the receipt — themes that fail
// AA will be flagged in the browser UI rather than silently shipped as broken.
//
// USAGE:
//   ./scripts/derive_ghostty_chrome.swift \
//       --themes ghostty/zig-out/share/ghostty/themes \
//       --output Resources/ghostty-derived-chrome-status.csv
//
// IMPORTANT: This script duplicates the derivation algorithm from
// `Sources/ThemeTokens.swift` because Swift scripts can't import app-target types
// without a Package.swift wrapper. Keep the two in sync — if you change
// `ThemeTokens.deriveChromeFrom(...)`, run this script again and verify the CSV diff
// makes sense. The included unit test
// (`testGhosttyDerivedChromeStatusCSVIsDeterministicallyShaped`) asserts the CSV shape,
// not the contents — content drift is *expected* and reviewed in PR diffs.

import Foundation
import AppKit

// MARK: - Argument parsing

func usage() -> Never {
    let exec = (CommandLine.arguments.first as NSString?)?.lastPathComponent ?? "derive_ghostty_chrome.swift"
    FileHandle.standardError.write(Data("""
        usage: \(exec) --themes <ghostty/themes/dir> --output <csv/path>

        Reads every theme file in the themes directory, derives Superghost chrome
        tokens from each, and emits a CSV with the per-theme AA outcome.
        """.utf8))
    exit(2)
}

var themesDir: String?
var outputPath: String?
var i = 1
while i < CommandLine.arguments.count {
    let arg = CommandLine.arguments[i]
    switch arg {
    case "--themes":
        i += 1
        guard i < CommandLine.arguments.count else { usage() }
        themesDir = CommandLine.arguments[i]
    case "--output":
        i += 1
        guard i < CommandLine.arguments.count else { usage() }
        outputPath = CommandLine.arguments[i]
    case "-h", "--help":
        usage()
    default:
        FileHandle.standardError.write(Data("unknown argument: \(arg)\n".utf8))
        usage()
    }
    i += 1
}
guard let themesDir, let outputPath else { usage() }

// MARK: - Color utilities (mirror Sources/GhosttyConfig.swift + ThemeTokens.swift)

extension NSColor {
    convenience init?(scriptHex hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "#", with: "")
        guard s.count == 6 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&rgb) else { return nil }
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }

    func toHex() -> String {
        guard let s = usingColorSpace(.sRGB) else { return "#000000" }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        s.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02x%02x%02x", Int(round(r*255)), Int(round(g*255)), Int(round(b*255)))
    }

    var luminanceLocal: Double {
        guard let s = usingColorSpace(.sRGB) else { return 0 }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        s.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    func darkenLocal(by amount: CGFloat) -> NSColor {
        var h: CGFloat = 0, sa: CGFloat = 0, br: CGFloat = 0, al: CGFloat = 0
        guard let s = usingColorSpace(.sRGB) else { return self }
        s.getHue(&h, saturation: &sa, brightness: &br, alpha: &al)
        return NSColor(hue: h, saturation: sa, brightness: max(0, min(1, br * (1 - amount))), alpha: al)
    }

    func lightenLocal(by amount: CGFloat) -> NSColor {
        var h: CGFloat = 0, sa: CGFloat = 0, br: CGFloat = 0, al: CGFloat = 0
        guard let s = usingColorSpace(.sRGB) else { return self }
        s.getHue(&h, saturation: &sa, brightness: &br, alpha: &al)
        return NSColor(hue: h, saturation: sa, brightness: min(1, br + (1.0 - br) * amount), alpha: al)
    }
}

func blendLocal(_ a: NSColor, _ b: NSColor, ratio r: CGFloat) -> NSColor {
    let rr = max(0, min(1, r))
    guard let ac = a.usingColorSpace(.sRGB), let bc = b.usingColorSpace(.sRGB) else { return a }
    var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
    var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
    ac.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
    bc.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
    return NSColor(
        red: ar + (br - ar) * rr,
        green: ag + (bg - ag) * rr,
        blue: ab + (bb - ab) * rr,
        alpha: aa + (ba - aa) * rr
    )
}

func wcagRelLuminance(_ c: NSColor) -> Double {
    guard let s = c.usingColorSpace(.sRGB) else { return 0 }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    s.getRed(&r, green: &g, blue: &b, alpha: &a)
    func ch(_ v: CGFloat) -> Double {
        let d = Double(v)
        return d <= 0.03928 ? d / 12.92 : pow((d + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)
}

func contrastLocal(_ a: NSColor, _ b: NSColor) -> Double {
    let la = wcagRelLuminance(a)
    let lb = wcagRelLuminance(b)
    let hi = max(la, lb)
    let lo = min(la, lb)
    return (hi + 0.05) / (lo + 0.05)
}

// MARK: - Theme parser (subset of GhosttyConfig.parse for terminal colors)

struct ParsedTheme {
    var background: NSColor?
    var foreground: NSColor?
    var palette: [Int: NSColor] = [:]
}

func parseTheme(at path: String) throws -> ParsedTheme {
    let contents = try String(contentsOfFile: path, encoding: .utf8)
    var theme = ParsedTheme()
    for rawLine in contents.split(separator: "\n") {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
        let parts = trimmed.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { continue }
        let key = parts[0]
        let value = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        switch key {
        case "background": theme.background = NSColor(scriptHex: value)
        case "foreground": theme.foreground = NSColor(scriptHex: value)
        case "palette":
            let pp = value.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            if pp.count == 2, let idx = Int(pp[0]), let c = NSColor(scriptHex: pp[1]) {
                theme.palette[idx] = c
            }
        default: break
        }
    }
    return theme
}

// MARK: - Derivation (mirror of ThemeTokens.deriveChromeFrom)

struct DerivedChrome {
    let cardSurface: NSColor
    let inkHeadline: NSColor
    let inkBody: NSColor
    let inkMuted: NSColor
    let accentInline: NSColor
}

func derive(theme parsed: ParsedTheme) -> DerivedChrome? {
    guard let bg = parsed.background, let fg = parsed.foreground else { return nil }
    let isDark = bg.luminanceLocal < 0.5
    let cardSurface = isDark ? bg.lightenLocal(by: 0.06) : bg.darkenLocal(by: 0.06)
    let inkHeadline = isDark ? fg.lightenLocal(by: 0.05) : fg.darkenLocal(by: 0.10)
    let inkBody = fg
    let inkMuted = blendLocal(fg, cardSurface, ratio: 0.40)
    let candidates: [NSColor] = [parsed.palette[4], parsed.palette[5], parsed.palette[6],
                                  parsed.palette[12], parsed.palette[13], parsed.palette[14]].compactMap { $0 }
    let accent = candidates.max(by: { contrastLocal($0, cardSurface) < contrastLocal($1, cardSurface) })
        ?? cardSurface.lightenLocal(by: 0.5)
    return DerivedChrome(
        cardSurface: cardSurface,
        inkHeadline: inkHeadline,
        inkBody: inkBody,
        inkMuted: inkMuted,
        accentInline: accent
    )
}

// MARK: - Main

let fm = FileManager.default
let themeFiles: [String]
do {
    let entries = try fm.contentsOfDirectory(atPath: themesDir)
    themeFiles = entries.filter { !$0.hasPrefix(".") }.sorted()
} catch {
    FileHandle.standardError.write(Data("could not read themes dir \(themesDir): \(error)\n".utf8))
    exit(1)
}

var csv: [String] = []
csv.append("theme,bg_hex,fg_hex,card_surface,ink_body_on_card,ink_headline_on_card,accent_on_card,passes_aa")

var passing = 0
var failing = 0
var skipped = 0

for name in themeFiles {
    let path = "\(themesDir)/\(name)"
    let parsed = (try? parseTheme(at: path)) ?? ParsedTheme()
    guard let derived = derive(theme: parsed) else {
        csv.append("\"\(name.replacingOccurrences(of: "\"", with: "\"\""))\",,,,,,,SKIPPED")
        skipped += 1
        continue
    }
    let bodyRatio = contrastLocal(derived.inkBody, derived.cardSurface)
    let headlineRatio = contrastLocal(derived.inkHeadline, derived.cardSurface)
    let accentRatio = contrastLocal(derived.accentInline, derived.cardSurface)
    let pass = bodyRatio >= 4.5  // AA for body text
    if pass { passing += 1 } else { failing += 1 }
    csv.append(String(
        format: "\"%@\",%@,%@,%@,%.2f,%.2f,%.2f,%@",
        name.replacingOccurrences(of: "\"", with: "\"\""),
        parsed.background?.toHex() ?? "",
        parsed.foreground?.toHex() ?? "",
        derived.cardSurface.toHex(),
        bodyRatio, headlineRatio, accentRatio,
        pass ? "PASS" : "FAIL"
    ))
}

let csvText = csv.joined(separator: "\n") + "\n"
try? csvText.write(toFile: outputPath, atomically: true, encoding: .utf8)

let total = passing + failing
let passRate = total > 0 ? Double(passing) / Double(total) * 100 : 0
print("derived \(total) themes (skipped \(skipped))")
print(String(format: "AA pass rate: %.1f%% (%d / %d)", passRate, passing, total))
print("output: \(outputPath)")
