import Foundation

/// Which main search signals are used (spec §5.5). The app always uses `.both`; only the harness compares the others.
enum SearchMode: String, Sendable, Codable, Hashable, CaseIterable {
    case embed, words, both
}

/// How an answer was decided.
public enum AnswerPath: String, Sendable, Codable, Hashable {
    case model, rules
}

/// The answer passage, with the same fields as iRead's `ContextPassage` plus the sentence index.
public struct AnswerPassage: Sendable, Codable, Hashable {
    /// Global sentence index.
    public let sentence: Int
    /// Global paragraph index.
    public let paragraph: Int
    /// Within the paragraph, UTF-16.
    public let range: NSRange
    public let text: String

    public init(sentence: Int, paragraph: Int, range: NSRange, text: String) {
        self.sentence = sentence
        self.paragraph = paragraph
        self.range = range
        self.text = text
    }
}
