import Foundation

enum SearchKnobs {
    static let maxCandidates = 6
    /// Below this unscaled score a candidate is dropped before any model call (spec §5.4). Half of TextEngine's rules-judge minimums.
    static let minRawScore: [SearchMode: Double] = [.embed: 0.425, .words: 0.25, .both: 0.35]
    /// Meaning leads, words come second (spec §5.5). Keep `embedWeight > wordsWeight`.
    static let embedWeight = 0.65
    static let wordsWeight = 0.35
    static let trackHintBonus = 0.10
    static let roleLinkBonus = 0.10
    /// Divided by `1 + distance` from the tap.
    static let causeNear = 0.15
    static let reactionNear = 0.30
    /// Content lemmas that say little about meaning.
    static let stopLemmas: Set<String> = ["be", "have", "do", "say", "get", "go", "make", "let", "can", "will", "shall", "would", "could", "should"]
    static let goalWords: Set<String> = ["want", "wish", "hope", "plan", "mean", "try", "decide", "like", "love", "hate", "need", "tell", "ask", "promise"]
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
    /// The query for one candidate phrase: the phrase itself, with its track, role, person names and reaction cue.
    static func make(candidate: UnderlineCandidate, in sentence: IndexedSentence, embedding: any EmbeddingSvc, tagger: ChapterIndexSvc) -> SearchQuery {
        let phrase = candidate.phrase
        let tokens = tagger.index(ChapterInput(chapterIndex: 0, plainText: phrase.text)).flatMap(\.tokens)
        let names = sentence.names.filter { $0.kind == .person && NSIntersectionRange($0.range, phrase.range).length > 0 }.map(\.text)
        let words = Set(phrase.text.lowercased().split { !$0.isLetter }.map(String.init))
        return SearchQuery(text: phrase.text, lemmas: contentLemmas(tokens), track: phrase.track, role: phrase.role, names: names,
                           reactionCue: !words.isDisjoint(with: EventKnobs.reactionCues), vector: embedding.vector(for: phrase.text))
    }

    /// Lemmas of nouns, verbs and adjectives, without the ones that say little.
    static func contentLemmas(_ tokens: [WordToken]) -> Set<String> {
        Set(tokens.filter { ["Noun", "Verb", "Adjective"].contains($0.wordClass) }.map(\.lemma))
            .subtracting(SearchKnobs.stopLemmas)
    }
}

/// Ranks the sentences before the underlined one by how well they could explain the phrase (spec §5.4).
/// The sentence pool comes only from `ReadBoundary`.
enum CandidateScorer {
    static func rank(_ q: SearchQuery, in ch: IndexedChapter, before sentence: Int, mode: SearchMode) -> SearchResult {
        var pool = ReadBoundary.searchable(before: sentence, first: ch.first, last: ch.last).compactMap(ch.sentence)
        if q.track == .character, !q.names.isEmpty {
            pool = pool.filter { sentence in q.names.contains { containsWord($0, in: sentence.text) } }
        }
        let hasVectors = q.vector != nil && pool.contains { $0.vector != nil }
        let modeUsed: SearchMode = hasVectors ? mode : .words

        let rawMeaning = pool.map { s in q.vector.flatMap { qv in s.vector.map { Cosine.similarity(qv, $0) } } ?? 0 }
        let rawWords = pool.map { s in
            q.lemmas.isEmpty ? 0 : Double(SearchQuery.contentLemmas(s.tokens).intersection(q.lemmas).count) / Double(q.lemmas.count)
        }
        let meaning = scaled(rawMeaning)
        let words = scaled(rawWords)

        let ranking = pool.indices.map { i -> Candidate in
            let bonus = bonus(for: pool[i], q, sentence: sentence)
            let (score, raw): (Double, Double) = switch modeUsed {
            case .embed: (meaning[i] + bonus, rawMeaning[i])
            case .words: (words[i] + bonus, rawWords[i])
            case .both: (SearchKnobs.embedWeight * meaning[i] + SearchKnobs.wordsWeight * words[i] + bonus,
                         SearchKnobs.embedWeight * rawMeaning[i] + SearchKnobs.wordsWeight * rawWords[i])
            }
            return Candidate(sentence: pool[i].index, rawMeaning: rawMeaning[i], rawWords: rawWords[i], meaning: meaning[i],
                             words: words[i], bonus: bonus, score: score, rawScore: raw)
        }
        .sorted { ($0.score, $0.sentence) > ($1.score, $1.sentence) }
        return SearchResult(ranking: ranking, modeUsed: modeUsed, highestScored: pool.map(\.index).max())
    }

    private static func bonus(for s: IndexedSentence, _ q: SearchQuery, sentence: Int) -> Double {
        let distance = Double(abs(sentence - s.index))
        var bonus = 0.0
        if hasTrackHint(s, q.track) { bonus += SearchKnobs.trackHintBonus }
        if let role = q.role {
            let linked = SearchKnobs.roleLinks[role] ?? []
            let isJustBefore = role == .reaction && s.index == sentence - 1
            if isJustBefore || s.events.contains(where: { $0.role.map(linked.contains) == true }) { bonus += SearchKnobs.roleLinkBonus }
        }
        if q.track == .cause { bonus += SearchKnobs.causeNear / (1 + distance) }
        if q.reactionCue { bonus += SearchKnobs.reactionNear / (1 + distance) }
        return bonus
    }

    private static func hasTrackHint(_ s: IndexedSentence, _ track: Track) -> Bool {
        let lemmas = Set(s.tokens.map(\.lemma))
        return switch track {
        case .goal: !lemmas.isDisjoint(with: SearchKnobs.goalWords)
        case .time: !lemmas.isDisjoint(with: EventKnobs.timeWords)
        case .place: !lemmas.isDisjoint(with: EventKnobs.placeWords)
        case .character: lemmas.contains("be")
        case .cause: false
        }
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

/// The candidates sent on to pick and confirm: the best `maxCandidates` at or above the floor. Empty means no underline.
enum UnderlineSearch {
    static func candidates(_ result: SearchResult) -> [Candidate] {
        let floor = SearchKnobs.minRawScore[result.modeUsed, default: 1]
        return Array(result.ranking.filter { $0.rawScore >= floor }.prefix(SearchKnobs.maxCandidates))
    }
}
