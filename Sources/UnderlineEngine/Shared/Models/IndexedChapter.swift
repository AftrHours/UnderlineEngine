import Foundation

public enum TaggingEngine: String, Sendable, Codable {
    case naturalLanguage, fallback
}

public enum EmbeddingEngine: String, Sendable, Codable {
    case sentence, wordAverage, none
}

public enum NameKind: String, Sendable, Codable {
    case person, place, organization
}

/// One word of a sentence. `range` is within the sentence, UTF-16.
public struct WordToken: Sendable, Codable, Hashable {
    public let text: String
    public let lemma: String
    public let wordClass: String
    public let range: NSRange
}

/// A name found by NER (or the fallback rules). `range` is within the sentence, UTF-16.
public struct NameMention: Sendable, Codable, Hashable {
    public let text: String
    public let range: NSRange
    public let kind: NameKind
}

/// One prepared sentence: text, tags, names, events and its vector (spec §5.2).
public struct IndexedSentence: Sendable, Codable {
    /// Global sentence index.
    public let index: Int
    /// Global paragraph index.
    public let paragraph: Int
    /// Within the paragraph, UTF-16.
    public let range: NSRange
    public let text: String
    public let tokens: [WordToken]
    public let names: [NameMention]
    public var events: [EventPhrase] = []
    public var vector: [Float]?
}

/// A prepared chapter (spec §5.2). The app keeps it in memory; a later round may save it (§12).
public struct IndexedChapter: Sendable, Codable {
    public let chapterIndex: Int
    public let sentences: [IndexedSentence]
    public let tagging: TaggingEngine
    public let embedding: EmbeddingEngine

    /// Global index of the chapter's first sentence.
    public var first: Int { sentences.first?.index ?? 0 }
    /// Global index of the chapter's last sentence (`first - 1` when the chapter is empty).
    public var last: Int { sentences.last?.index ?? first - 1 }

    /// The sentence with this global index, or `nil`. Checks the index, so a gap in the app's numbering can never
    /// hand back a later sentence (which would break the read boundary).
    public func sentence(_ global: Int) -> IndexedSentence? {
        let local = global - first
        if sentences.indices.contains(local), sentences[local].index == global { return sentences[local] }
        return sentences.first { $0.index == global }
    }
}
