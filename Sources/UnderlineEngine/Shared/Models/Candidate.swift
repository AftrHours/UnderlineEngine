import Foundation

/// One scored sentence from the search (spec §5.5).
public struct Candidate: Sendable, Codable, Hashable {
    /// Global sentence index.
    public let sentence: Int
    /// IDF weight of the phrase's content lemmas that the sentence shares ÷ the phrase's whole IDF weight, 0…1.
    public let rawWords: Double
    /// `rawWords` scaled to 0…1 within this search.
    public let words: Double
    /// Role-link and reaction-cue bonuses.
    public let bonus: Double
    /// The ranking score: `words + bonus`.
    public let score: Double
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
    /// The phrase, or another event in its sentence, has "immediately", "then"…: its cause is just before.
    let reactionCue: Bool
}
