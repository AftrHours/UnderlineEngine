import Foundation

/// Checks everything the model returns before it can become an underline (spec §5.5). Pure.
enum UnderlineGuard {
    /// The reference is in the phrase's own paragraph: the reader has just read it.
    static func isInSameParagraph(_ reference: IndexedSentence, as sentence: IndexedSentence) -> Bool {
        reference.paragraph == sentence.paragraph
    }

    /// The words the model gave as evidence are a quote from the passage it was shown. A "yes" whose evidence is the phrase itself,
    /// or words that are not in the passage, is not trusted. Case, punctuation and quote marks don't matter; "…" or "..." may skip
    /// words between two pieces of the quote.
    static func quotes(_ evidence: String, from passage: String) -> Bool {
        let pieces = evidence.replacingOccurrences(of: "...", with: "\u{2026}").split(separator: "\u{2026}")
            .map { words(String($0)) }.filter { !$0.isEmpty }
        let source = words(passage)
        guard !pieces.isEmpty else { return false }
        return pieces.allSatisfy { piece in
            guard source.count >= piece.count else { return false }
            return (0...(source.count - piece.count)).contains { Array(source[$0..<$0 + piece.count]) == piece }
        }
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased().replacingOccurrences(of: "\u{2019}", with: "'")
            .split { !($0.isLetter || $0.isNumber || $0 == "'") }
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'")) }.filter { !$0.isEmpty }
    }

    /// The phrase's range within the paragraph, or `nil` unless the sentence text at the phrase's own range is the phrase.
    static func paragraphRange(of phrase: EventPhrase, in sentence: IndexedSentence) -> NSRange? {
        let text = sentence.text as NSString
        guard phrase.range.location != NSNotFound, phrase.range.length > 0,
              NSMaxRange(phrase.range) <= text.length,
              text.substring(with: phrase.range) == phrase.text else { return nil }
        return NSRange(location: sentence.range.location + phrase.range.location, length: phrase.range.length)
    }
}
