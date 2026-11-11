import Foundation

enum TextMatch {
    /// Lowercased, curly quotes and apostrophes made straight, whitespace collapsed, punctuation and "…" trimmed at both ends.
    /// The harness uses it to match golden phrases and sentences against the engine's.
    static func normalized(_ text: String) -> String {
        let straight = text.lowercased()
            .replacingOccurrences(of: "\u{201C}", with: "\"").replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\u{2018}", with: "'").replacingOccurrences(of: "\u{2019}", with: "'")
        let collapsed = straight.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return collapsed.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:!?\"'\u{2026}"))
    }
}
