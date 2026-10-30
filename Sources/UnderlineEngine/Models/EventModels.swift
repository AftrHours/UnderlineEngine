import Foundation

/// The kind of confusion, after Zwaan's event-indexing dimensions (spec §4.2).
public enum Track: String, Sendable, Codable, Hashable, CaseIterable {
    case character, goal, cause, time, place
}

/// The causal role of an event, after Trabasso & van den Broek (spec §4.3).
public enum EventRole: String, Sendable, Codable, Hashable, CaseIterable {
    case setting, initiatingEvent, internalResponse, goal, attempt, reaction, outcome
}

/// One possible "this" in a sentence: an event phrase, or a name (`role == nil`).
public struct EventPhrase: Sendable, Codable, Hashable {
    public let text: String
    /// Within the sentence, UTF-16.
    public let range: NSRange
    public let role: EventRole?
    public let track: Track

    public init(text: String, range: NSRange, role: EventRole?, track: Track) {
        self.text = text
        self.range = range
        self.role = role
        self.track = track
    }
}
