import Foundation

enum JudgeKnobs {
    /// Starting values, set to underline little and rarely wrongly (precision over recall). Tuned with the harness.
    /// Compared with `Candidate.rawScore` (unscaled), because scaled scores collapse to 0 with one candidate.
    static let minScore: [SearchMode: Double] = [.embed: 0.85, .words: 0.50, .both: 0.70]
    static let margin: [SearchMode: Double] = [.embed: 0.03, .words: 0.15, .both: 0.05]
}

/// Pick and confirm without a model (spec §5.5).
enum RulesPicker {
    /// The top candidate wins only when it's clearly good and clearly ahead.
    static func decide(_ ranking: [Candidate], mode: SearchMode) -> Int? {
        guard let top = ranking.first else { return nil }
        let second = ranking.dropFirst().first?.rawScore ?? 0
        guard top.rawScore >= JudgeKnobs.minScore[mode, default: 1],
              top.rawScore - second >= JudgeKnobs.margin[mode, default: 1] else { return nil }
        return top.sentence
    }

    /// The rules confirm: the reference shares a content word or the same person name with the phrase,
    /// or has an event in a role that usually answers the phrase's role.
    static func confirm(phrase: EventPhrase, in sentence: IndexedSentence, reference: IndexedSentence) -> Bool {
        let phraseTokens = sentence.tokens.filter { NSIntersectionRange($0.range, phrase.range).length > 0 }
        if !SearchQuery.contentLemmas(phraseTokens).isDisjoint(with: SearchQuery.contentLemmas(reference.tokens)) { return true }
        let names = sentence.names.filter { $0.kind == .person && NSIntersectionRange($0.range, phrase.range).length > 0 }.map(\.text)
        if names.contains(where: { name in reference.names.contains { $0.text == name } }) { return true }
        guard let role = phrase.role, let linked = SearchKnobs.roleLinks[role] else { return false }
        return reference.events.contains { $0.role.map(linked.contains) == true }
    }
}
