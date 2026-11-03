import Foundation

/// Why a candidate phrase got no underline (spec §5.7).
public enum DropReason: String, Sendable, Codable, Hashable {
    case noCandidate, pickedNone, confirmRejected, guardRejected, densityLimit
    /// The model failed for a reason other than its context size; precision first, so no rules fallback.
    case modelFailed
    /// The picked reference is in the phrase's own paragraph: the reader has just read it, so no underline.
    case explainedInParagraph
}

/// What the confirm step said about the one picked passage.
public struct ConfirmTrace: Sendable, Codable, Hashable {
    public let explains: Bool
    public let evidence: String?

    public init(explains: Bool, evidence: String?) {
        self.explains = explains
        self.evidence = evidence
    }
}

public struct StepTimes: Sendable, Codable, Hashable {
    public var searchMs: Int?
    public var pickMs: Int?
    public var confirmMs: Int?

    public init(searchMs: Int? = nil, pickMs: Int? = nil, confirmMs: Int? = nil) {
        self.searchMs = searchMs
        self.pickMs = pickMs
        self.confirmMs = confirmMs
    }
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
    public var path: AnswerPath?
    public var promptVariant: PromptVariant?
    public var searchModeUsed: SearchMode?
    public let embedding: EmbeddingEngine
    /// Sentences sent to the model (or ranked top by the rules), best first.
    public var candidates: [Int]
    /// Every sentence index inside every prompt actually sent (pick and confirm), for the spoiler check.
    public var promptSentences: [Int]
    public var pickedSentence: Int?
    public var quote: String?
    public var confirm: ConfirmTrace?
    public var kept: Bool
    public var dropped: DropReason?
    public var times: StepTimes
    /// The phrase's range within its sentence, UTF-16.
    public var phraseRange: NSRange?
    /// The unscaled search score of each entry in `candidates`, in the same order.
    public var candidateScores: [Double]

    public init(chapterIndex: Int, sentence: Int, phrase: String, kind: UnderlineKind, path: AnswerPath?, promptVariant: PromptVariant?,
                searchModeUsed: SearchMode?, embedding: EmbeddingEngine, candidates: [Int], promptSentences: [Int], pickedSentence: Int?,
                quote: String?, confirm: ConfirmTrace?, kept: Bool, dropped: DropReason?, times: StepTimes,
                phraseRange: NSRange? = nil, candidateScores: [Double] = []) {
        self.chapterIndex = chapterIndex
        self.sentence = sentence
        self.phrase = phrase
        self.kind = kind
        self.path = path
        self.promptVariant = promptVariant
        self.searchModeUsed = searchModeUsed
        self.embedding = embedding
        self.candidates = candidates
        self.promptSentences = promptSentences
        self.pickedSentence = pickedSentence
        self.quote = quote
        self.confirm = confirm
        self.kept = kept
        self.dropped = dropped
        self.times = times
        self.phraseRange = phraseRange
        self.candidateScores = candidateScores
    }
}
