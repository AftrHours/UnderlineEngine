import Foundation

/// One scored sentence from the search (spec §5.5).
public struct Candidate: Sendable, Codable, Hashable {
    /// Global sentence index.
    public let sentence: Int
    /// Cosine similarity to the query, 0…1 (0 without embeddings).
    public let rawMeaning: Double
    /// Shared content lemmas ÷ query lemmas, 0…1.
    public let rawWords: Double
    /// `rawMeaning` and `rawWords` scaled to 0…1 within this search.
    public let meaning: Double
    public let words: Double
    /// Track hint, role link and distance bonuses.
    public let bonus: Double
    /// The ranking score (scaled signals + bonus).
    public let score: Double
    /// The unscaled signals combined for the search mode; the rules judge uses this (scaled scores collapse
    /// to 0 with a single candidate).
    public let rawScore: Double
}

/// What the search looks for, built from one candidate phrase.
struct SearchQuery: Sendable {
    /// The phrase.
    let text: String
    let lemmas: Set<String>
    let track: Track
    let role: EventRole?
    /// Person names inside the phrase.
    let names: [String]
    /// The phrase has "immediately", "then"…: its cause is just before.
    let reactionCue: Bool
    let vector: [Float]?
}

struct SearchResult: Sendable {
    /// Every scored sentence, best first.
    let ranking: [Candidate]
    let modeUsed: SearchMode
    /// The highest sentence index that was scored, for the spoiler check.
    let highestScored: Int?

}
