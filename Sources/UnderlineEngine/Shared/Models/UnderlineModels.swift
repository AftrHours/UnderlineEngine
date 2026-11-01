import Foundation

/// What sort of thing an underline sits on (spec §4.2).
public enum UnderlineKind: String, Sendable, Codable, Hashable, CaseIterable {
    case action, reaction, feeling, outcome, place, thing, person

    /// The kind of an event phrase, from its role and track. A name (`role == nil`) is a person.
    public static func of(_ phrase: EventPhrase) -> UnderlineKind {
        switch phrase.role {
        case nil: .person
        case .reaction?: .reaction
        case .internalResponse?: .feeling
        case .outcome?: .outcome
        case .setting?: phrase.track == .place ? .place : .thing
        case .attempt?, .goal?, .initiatingEvent?: .action
        }
    }
}

/// One underlined phrase and the earlier passage that explains it (spec §4.1).
public struct Underline: Sendable, Codable, Hashable, Identifiable {
    /// Global index of the underlined sentence.
    public let sentence: Int
    /// Global paragraph index.
    public let paragraph: Int
    /// The phrase, within the paragraph, UTF-16.
    public let range: NSRange
    public let text: String
    public let kind: UnderlineKind
    public let role: EventRole?
    /// Always before `sentence`.
    public let reference: AnswerPassage
    public let decidedBy: AnswerPath

    public var id: String { "\(sentence):\(range.location)" }

    public init(sentence: Int, paragraph: Int, range: NSRange, text: String, kind: UnderlineKind, role: EventRole?,
                reference: AnswerPassage, decidedBy: AnswerPath) {
        self.sentence = sentence
        self.paragraph = paragraph
        self.range = range
        self.text = text
        self.kind = kind
        self.role = role
        self.reference = reference
        self.decidedBy = decidedBy
    }
}

/// Every underline of one chapter.
public struct ChapterUnderlines: Sendable, Codable, Hashable {
    public let chapterIndex: Int
    public let underlines: [Underline]

    public init(chapterIndex: Int, underlines: [Underline]) {
        self.chapterIndex = chapterIndex
        self.underlines = underlines
    }
}

/// A named set of instructions and prompt layout, compared by the harness (spec §5.5).
public enum PromptVariant: String, Sendable, Codable, Hashable, CaseIterable {
    case baseline, strictDefinition, fewShot
}
