import Foundation

enum SearchKnobs {
    /// How many of the best-ranked sentences pick looks at.
    static let maxCandidates = 6
    static let roleLinkBonus = 0.10
    /// Divided by `1 + distance` from the tap.
    static let reactionNear = 0.30
    /// Content lemmas that say little about meaning.
    static let stopLemmas: Set<String> = ["be", "have", "do", "say", "get", "go", "make", "let", "can", "will", "shall", "would", "could", "should"]
    /// The role of the target event → roles of earlier events that usually answer it (causal network, spec §5.5).
    static let roleLinks: [EventRole: Set<EventRole>] = [
        .attempt: [.goal, .initiatingEvent],
        .internalResponse: [.initiatingEvent, .outcome],
        .outcome: [.attempt],
        .goal: [.initiatingEvent, .internalResponse],
        .setting: [.setting]
    ]
}

extension SearchQuery {
    /// The query for one candidate phrase: the phrase itself, with its track, role, person names and reaction cue
    /// (from the phrase, or from another event in its sentence).
    static func make(candidate: UnderlineCandidate, in sentence: IndexedSentence, tagger: ChapterIndexSvc) -> SearchQuery {
        let phrase = candidate.phrase
        let tokens = tagger.index(ChapterInput(chapterIndex: 0, plainText: phrase.text), names: false).flatMap(\.tokens)
        let names = sentence.names.filter { $0.kind == .person && NSIntersectionRange($0.range, phrase.range).length > 0 }.map(\.text)
        let words = Set(phrase.text.lowercased().split { !$0.isLetter }.map(String.init))
        // A cue anywhere in an event phrase's sentence ("immediately sat up, …, and began to whistle") says the whole sentence
        // answers the one before, so every event in it looks there. A name doesn't use it.
        let sentenceCue = phrase.role != nil
            && (sentence.events.contains { $0.role == .reaction } || sentence.tokens.contains { EventKnobs.reactionCues.contains($0.lemma) })
        return SearchQuery(text: phrase.text, lemmas: contentLemmas(tokens), track: phrase.track, role: phrase.role, names: names,
                           reactionCue: !words.isDisjoint(with: EventKnobs.reactionCues) || sentenceCue)
    }

    /// Lemmas of nouns, verbs and adjectives, without the ones that say little.
    static func contentLemmas(_ tokens: [WordToken]) -> Set<String> {
        Set(tokens.filter { ["Noun", "Verb", "Adjective"].contains($0.wordClass) }.map(\.lemma))
            .subtracting(SearchKnobs.stopLemmas)
    }
}

/// Ranks the sentences before the underlined one by the rare words they share with the phrase (spec §5.4).
/// The sentence pool comes only from `ReadBoundary`.
enum CandidateScorer {
    /// Every sentence of the pool, best first: shared content lemmas weighted by rarity (IDF), scaled within the search,
    /// plus the role bonuses. A name phrase only searches sentences that mention the name.
    static func rank(_ q: SearchQuery, in ch: IndexedChapter, before sentence: Int) -> [Candidate] {
        var pool = ReadBoundary.searchable(before: sentence, first: ch.first, last: ch.last).compactMap(ch.sentence)
        if q.track == .character, !q.names.isEmpty {
            pool = pool.filter { sentence in q.names.contains { containsWord($0, in: sentence.text) } }
        }
        // Shared words count by rarity (IDF): sharing "limes" means more than sharing "want".
        let weight: (String) -> Double = { lemma in ch.wordStats?.idf(lemma) ?? 1 }
        let queryWeight = q.lemmas.reduce(0) { $0 + weight($1) }
        let rawWords = pool.map { s in
            queryWeight <= 0 ? 0 : SearchQuery.contentLemmas(s.tokens).intersection(q.lemmas).reduce(0) { $0 + weight($1) } / queryWeight
        }
        let words = scaled(rawWords)
        return pool.indices.map { i -> Candidate in
            let bonus = bonus(for: pool[i], q, sentence: sentence)
            return Candidate(sentence: pool[i].index, rawWords: rawWords[i], words: words[i], bonus: bonus, score: words[i] + bonus)
        }
        .sorted { ($0.score, $0.sentence) > ($1.score, $1.sentence) }
    }

    private static func bonus(for s: IndexedSentence, _ q: SearchQuery, sentence: Int) -> Double {
        let distance = Double(abs(sentence - s.index))
        var bonus = 0.0
        if let role = q.role {
            let linked = SearchKnobs.roleLinks[role] ?? []
            let isJustBefore = role == .reaction && s.index == sentence - 1
            if isJustBefore || s.events.contains(where: { $0.role.map(linked.contains) == true }) { bonus += SearchKnobs.roleLinkBonus }
        }
        if q.reactionCue { bonus += SearchKnobs.reactionNear / (1 + distance) }
        return bonus
    }

    /// Min–max to 0…1. With fewer than two values, or all equal, every value is 0.
    private static func scaled(_ values: [Double]) -> [Double] {
        guard let low = values.min(), let high = values.max(), high > low else { return values.map { _ in 0 } }
        return values.map { ($0 - low) / (high - low) }
    }

    private static func containsWord(_ word: String, in text: String) -> Bool {
        text.range(of: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b", options: [.regularExpression, .caseInsensitive]) != nil
    }
}
