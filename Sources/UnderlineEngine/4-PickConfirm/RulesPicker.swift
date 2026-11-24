import Foundation

enum JudgeKnobs {
    /// Pick: candidates whose scores are this close count as tied, and the nearer one goes first
    /// (wrong links reach a median 54 sentences back, right ones 22).
    static let tieWindow = 0.05
    /// Confirm, evidence points: +2 a shared rare noun or adjective, +1 two or more shared rare words, +1 a soft lexical match
    /// of at least `softMatch`. Needed: 2 within 20 sentences back, 3 further, so a soft lexical match alone never confirms
    /// (with 1 point enough nearby, near links doubled and were mostly wrong). The bar rises at 20 sentences, not 50
    /// (2026-11-24): links 21–50 back were 30–39% right against 49–51% within 20.
    static let softMatch = 0.3
    static let pointsNeeded: [(within: Int, points: Int)] = [(20, 2), (Int.max, 3)]
}

/// Pick and confirm by rules (spec §5.5).
enum RulesPicker {
    /// Pick's order: the top `limit` candidates that share at least one content word with the phrase, best score first;
    /// when the next candidates score within `JudgeKnobs.tieWindow` of the best one left, the nearest of them goes first.
    static func evidenceOrder(_ ranking: [Candidate], limit: Int = SearchKnobs.maxCandidates) -> [Candidate] {
        var left = Array(ranking.filter { $0.rawWords > 0 }.prefix(limit))
        var ordered: [Candidate] = []
        while let best = left.first {
            let tied = left.filter { best.score - $0.score <= JudgeKnobs.tieWindow }
            let nearest = tied.max { $0.sentence < $1.sentence } ?? best
            ordered.append(nearest)
            left.removeAll { $0.sentence == nearest.sentence }
        }
        return ordered
    }

    /// Confirm: evidence points against a bar that rises with distance (`JudgeKnobs.pointsNeeded`), lemma-level. `soft` gives
    /// the soft lexical match of the phrase's words that the reference doesn't share (token MaxSim), or `nil` without word
    /// vectors (then it gives no point); it is only asked for when its one point decides the outcome. A shared person name
    /// on its own never confirms.
    static func evidencePoints(phrase: EventPhrase, in sentence: IndexedSentence, reference: IndexedSentence, stats: WordStats?,
                               soft: () -> Double?) -> Bool {
        let inPhrase = ChapterTokenVectors.contentTokens(sentence).filter { NSIntersectionRange($0.range, phrase.range).length > 0 }
        let refLemmas = Set(ChapterTokenVectors.contentTokens(reference).map(\.lemma))
        let shared = Set(inPhrase.map(\.lemma)).intersection(refLemmas)
        let rare = stats.map { st in shared.filter { st.isRare($0) } } ?? shared
        let rareNounAdj = inPhrase.contains { $0.wordClass != "Verb" && rare.contains($0.lemma) }
        let wordPoints = (rareNounAdj ? 2 : 0) + (rare.count >= 2 ? 1 : 0)
        let distance = sentence.index - reference.index
        let needed = JudgeKnobs.pointsNeeded.first { distance <= $0.within }?.points ?? Int.max
        if wordPoints >= needed { return true }
        if wordPoints + 1 < needed { return false }
        return (soft() ?? 0) >= JudgeKnobs.softMatch
    }

    /// The soft lexical match for `evidencePoints`: the phrase's content words that the reference doesn't share, each matched
    /// to its closest word of the reference, IDF-weighted. `nil` when the sentences have no word vectors.
    static func softMatch(phrase: EventPhrase, in sentence: IndexedSentence, reference: IndexedSentence, stats: WordStats?) -> Double? {
        guard let words = sentence.wordVectors else { return nil }
        let refLemmas = Set(ChapterTokenVectors.contentTokens(reference).map(\.lemma))
        let novel = words.filter { NSIntersectionRange($0.range, phrase.range).length > 0 && !refLemmas.contains($0.lemma) }
        return novel.isEmpty ? 0 : ChapterTokenVectors.softScore(query: novel, target: reference.wordVectors ?? [], stats: stats)
    }
}
