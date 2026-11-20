import Foundation

enum JudgeKnobs {
    /// Compared with `Candidate.rawScore` (unscaled), because scaled scores collapse to 0 with one candidate.
    /// `.both` is 0.60 from the rules parameter sweep on Little Women: the strict rare-word confirm keeps precision,
    /// so a lower floor nearly doubles the right links (about 188 → 345) for a small precision cost (54% → 50%).
    static let minScore: [SearchMode: Double] = [.embed: 0.85, .words: 0.50, .both: 0.60]
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

    /// The rules path's confirm: the phrase and the reference share a rare noun or adjective, two rare words
    /// of any class, or a person name. Words count as shared only with the same lemma and word class.
    /// `rareShare` and `nounOrTwo` exist for the harness's parameter sweep; the engine uses the defaults.
    static func confirm(phrase: EventPhrase, in sentence: IndexedSentence, reference: IndexedSentence, stats: WordStats? = nil,
                        rareShare: Double = WordKnobs.rareShare, nounOrTwo: Bool = true) -> Bool {
        let phraseTokens = sentence.tokens.filter { NSIntersectionRange($0.range, phrase.range).length > 0 }
        let shared = contentWords(phraseTokens).intersection(contentWords(reference.tokens))
        if let stats {
            let rare = shared.filter { stats.isRare($0.lemma, share: rareShare) }
            let rareOK = !nounOrTwo ? !rare.isEmpty
                : rare.contains(where: { $0.wordClass != "Verb" }) || Set(rare.map(\.lemma)).count >= 2
            if rareOK { return true }
        } else if !shared.isEmpty {
            return true
        }
        let names = sentence.names.filter { $0.kind == .person && NSIntersectionRange($0.range, phrase.range).length > 0 }.map(\.text)
        return names.contains(where: { name in reference.names.contains { $0.text == name } })
    }

    /// The rare words and person names the phrase shares with the reference, for the model's prompt.
    static func sharedRareWords(phrase: EventPhrase, in sentence: IndexedSentence, reference: IndexedSentence, stats: WordStats?) -> [String] {
        let phraseTokens = sentence.tokens.filter { NSIntersectionRange($0.range, phrase.range).length > 0 }
        let shared = contentWords(phraseTokens).intersection(contentWords(reference.tokens))
        let words = stats.map { st in shared.filter { st.isRare($0.lemma) } } ?? shared
        let names = sentence.names.filter { $0.kind == .person && NSIntersectionRange($0.range, phrase.range).length > 0 }.map(\.text)
            .filter { name in reference.names.contains { $0.text == name } }
        return Array(Set(words.map(\.lemma))).sorted() + names
    }

    private struct Word: Hashable {
        let lemma: String
        let wordClass: String
    }

    /// Nouns, verbs and adjectives, with their class, without the lemmas that say little.
    private static func contentWords(_ tokens: [WordToken]) -> Set<Word> {
        Set(tokens.filter { ["Noun", "Verb", "Adjective"].contains($0.wordClass) && !SearchKnobs.stopLemmas.contains($0.lemma) }
            .map { Word(lemma: $0.lemma, wordClass: $0.wordClass) })
    }
}
