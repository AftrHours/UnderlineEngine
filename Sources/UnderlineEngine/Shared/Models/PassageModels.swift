import Foundation

/// How an answer was decided. Always the rules; kept because iRead saves it (`decidedBy`).
public enum AnswerPath: String, Sendable, Codable, Hashable {
    case rules
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
