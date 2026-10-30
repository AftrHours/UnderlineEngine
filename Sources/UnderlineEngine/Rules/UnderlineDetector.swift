import Foundation

enum UnderlineKnobs {
    /// Event phrases shorter than this (in words) are never underlined. Names are exempt.
    static let minPhraseWords = 2
    /// A phrase made only of these words says nothing a reader could be confused about.
    static let generalWords: Set<String> = [
        "this", "that", "it", "these", "those", "there", "here", "so", "do", "did", "does", "done", "be", "was", "were", "is",
        "are", "been", "am", "had", "has", "have", "not", "then", "now", "too", "very", "just"
    ]
    /// A proper name is a candidate only if it wasn't mentioned in this many earlier sentences.
    static let nameGapSentences = 20
    /// Most underlines kept per paragraph, best first (spec §5.6).
    static let maxPerParagraph = 2
    /// Tie-break order in the limiter; `person` last (spec §4.2).
    static let kindOrder: [UnderlineKind] = [.reaction, .action, .feeling, .outcome, .place, .thing, .person]
}

/// One phrase that might get an underline, before any search.
struct UnderlineCandidate: Sendable, Hashable {
    /// Global sentence index.
    let sentence: Int
    let phrase: EventPhrase
    let kind: UnderlineKind
}

/// Detect (spec §5.3): the sentence's events and names worth checking. Pure.
enum UnderlineDetector {
    /// `recentNames` are person names mentioned in the last `UnderlineKnobs.nameGapSentences` sentences; they're skipped.
    static func candidates(in sentence: IndexedSentence, recentNames: Set<String> = []) -> [UnderlineCandidate] {
        let starts = sentence.events.map(\.range.location)
        let events = sentence.events.filter { event in
            guard event.text.split(whereSeparator: \.isWhitespace).count >= UnderlineKnobs.minPhraseWords, !isGeneral(event.text) else { return false }
            guard event.track == .cause || event.track == .goal else { return true }
            // The splitter can keep "…because…" inside the event, so look for the reason after its first word.
            let next = starts.filter { $0 > event.range.location }.min()
            let head = sentence.tokens.first { $0.range.location >= event.range.location }?.range ?? event.range
            return EventRoles.reasonClause(after: head, in: sentence, stopAt: next) == nil
        }
        var seen = Set<String>()
        let names = sentence.names.filter { $0.kind == .person && !recentNames.contains($0.text) && seen.insert($0.text).inserted }
            .map { EventPhrase(text: $0.text, range: $0.range, role: nil, track: .character) }
        return (events + names).map { UnderlineCandidate(sentence: sentence.index, phrase: $0, kind: UnderlineKind.of($0)) }
    }

    /// Every word of the phrase is a general word.
    static func isGeneral(_ phrase: String) -> Bool {
        let words = phrase.lowercased().split { !$0.isLetter }.map(String.init)
        return words.allSatisfy(UnderlineKnobs.generalWords.contains)
    }
}
