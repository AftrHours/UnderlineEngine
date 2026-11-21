import Foundation

/// One underlined phrase and the earlier passage it points back to. This is the only shape that leaves the engine, and it is
/// frozen: the fields are the ones iRead keeps on disk and in iCloud, so they are never renamed, retyped or removed
/// (a field an engine no longer fills keeps a fixed value instead). `FrozenShapeTests` fails if this changes.
public struct UnderlineResult: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    /// Global sentence index of the underlined sentence.
    public let sentence: Int
    /// Global paragraph index.
    public let paragraph: Int
    /// The phrase, within its paragraph, UTF-16.
    public let range: NSRange
    public let text: String
    /// What sort of phrase it is: "action", "reaction", "feeling", "outcome", "place", "thing" or "person".
    public let kind: String
    /// "model" or "rules".
    public let decidedBy: String
    /// The earlier passage that explains it.
    public let reference: Passage

    public init(id: String, sentence: Int, paragraph: Int, range: NSRange, text: String, kind: String, decidedBy: String,
                reference: Passage) {
        self.id = id
        self.sentence = sentence
        self.paragraph = paragraph
        self.range = range
        self.text = text
        self.kind = kind
        self.decidedBy = decidedBy
        self.reference = reference
    }

    /// A sentence of the book: global indexes, `range` within its paragraph, UTF-16.
    public struct Passage: Codable, Sendable, Hashable {
        public let sentence: Int
        public let paragraph: Int
        public let range: NSRange
        public let text: String

        public init(sentence: Int, paragraph: Int, range: NSRange, text: String) {
            self.sentence = sentence
            self.paragraph = paragraph
            self.range = range
            self.text = text
        }
    }
}

/// What came back for one paragraph: its underlines, and a line for every phrase the engine looked at (underlined or not),
/// ready to show on a debug sheet. The lines are text on purpose, so the engine can change what it records.
public struct UnderlineBatch: Sendable {
    public let underlines: [UnderlineResult]
    public let considered: [ConsideredPhrase]

    public init(underlines: [UnderlineResult], considered: [ConsideredPhrase] = []) {
        self.underlines = underlines
        self.considered = considered
    }
}

public struct ConsideredPhrase: Sendable, Hashable {
    public let sentence: Int
    public let phrase: String
    /// For example "s12 · rules · explained by s7", or "s12 · dropped: confirmRejected".
    public let detail: String
    public let isUnderlined: Bool

    public init(sentence: Int, phrase: String, detail: String, isUnderlined: Bool) {
        self.sentence = sentence
        self.phrase = phrase
        self.detail = detail
        self.isUnderlined = isUnderlined
    }
}
