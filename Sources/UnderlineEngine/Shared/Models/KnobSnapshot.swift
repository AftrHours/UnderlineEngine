import Foundation

/// The knobs a run used, for the harness report header.
public struct KnobSnapshot: Sendable, Codable, Hashable {
    public let embedWeight: Double
    public let wordsWeight: Double
    public let maxCandidates: Int
    public let maxPerParagraph: Int
    public let minRawScore: [String: Double]

    public static var current: KnobSnapshot {
        KnobSnapshot(embedWeight: SearchKnobs.embedWeight, wordsWeight: SearchKnobs.wordsWeight, maxCandidates: SearchKnobs.maxCandidates,
                     maxPerParagraph: UnderlineKnobs.maxPerParagraph,
                     minRawScore: Dictionary(uniqueKeysWithValues: SearchKnobs.minRawScore.map { ($0.key.rawValue, $0.value) }))
    }
}
