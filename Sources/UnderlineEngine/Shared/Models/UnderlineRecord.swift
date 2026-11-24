import Foundation

/// Why a candidate phrase got no underline (spec §5.7).
public enum DropReason: String, Sendable, Codable, Hashable {
    /// The phrase's sentence is not in the chapter.
    case noCandidate
    /// No earlier sentence shares a content word with the phrase.
    case pickedNone
    /// The picked reference is in the phrase's own paragraph: the reader has just read it, so no underline.
    case explainedInParagraph
    /// Not enough evidence for the distance to the reference.
    case confirmRejected
    /// The phrase's text does not sit at its own range in the sentence.
    case guardRejected
    /// It overlaps a better underline in the same sentence.
    case densityLimit
}

/// One finished paragraph: its underlines and a record for every phrase considered.
public struct ParagraphResult: Sendable {
    public let underlines: [Underline]
    public let records: [UnderlineRecord]

    public init(underlines: [Underline], records: [UnderlineRecord]) {
        self.underlines = underlines
        self.records = records
    }
}

/// What happened to one candidate phrase, kept or dropped (spec §5.7). Contains book text: local logs only.
public struct UnderlineRecord: Sendable, Codable, Hashable {
    public let chapterIndex: Int
    public let sentence: Int
    public let phrase: String
    public let kind: UnderlineKind
    public let embedding: EmbeddingEngine
    /// The candidates in pick's order, best first.
    public var candidates: [Int] = []
    /// The share of the phrase's word weight each candidate shares, in the same order.
    public var candidateScores: [Double] = []
    public var pickedSentence: Int?
    /// Confirm's answer for the picked sentence; `nil` when confirm was not reached.
    public var confirmed: Bool?
    public var kept = false
    public var dropped: DropReason?
    public var searchMs: Int?
    /// The phrase's range within its sentence, UTF-16.
    public var phraseRange: NSRange?

    init(chapterIndex: Int, sentence: Int, phrase: String, kind: UnderlineKind, embedding: EmbeddingEngine, phraseRange: NSRange?) {
        self.chapterIndex = chapterIndex
        self.sentence = sentence
        self.phrase = phrase
        self.kind = kind
        self.embedding = embedding
        self.phraseRange = phraseRange
    }
}
