import Foundation

enum WordKnobs {
    /// A content word is rare when at most this share of the sentences hold it (about 38 of Little Women's 9,617 sentences),
    /// and never fewer than `rareMin` (the phrase's sentence and the reference both hold it).
    /// 0.004 from the rules parameter sweep: the strictest share tried, and the most precise.
    static let rareShare = 0.004
    static let rareMin = 2
}

/// How many sentences hold each content lemma, over a book or a chapter. A shared rare word ("limes", "eyebrows", "scrape")
/// links two sentences; a shared common one ("want", "see", "mean") doesn't.
public struct WordStats: Sendable, Codable, Equatable {
    public let sentenceCount: Int
    public let sentencesWith: [String: Int]

    init(sentences: [IndexedSentence]) {
        var counts: [String: Int] = [:]
        for s in sentences { for lemma in SearchQuery.contentLemmas(s.tokens) { counts[lemma, default: 0] += 1 } }
        sentenceCount = sentences.count
        sentencesWith = counts
    }

    /// Over several chapters, e.g. the whole book.
    init(chapters: [IndexedChapter]) {
        self.init(sentences: chapters.flatMap(\.sentences))
    }

    /// `ln(1 + sentences / sentences holding the lemma)`: low for a common word, high for a rare one, never 0
    /// (so a word in every sentence of a tiny chapter still counts a little).
    func idf(_ lemma: String) -> Double {
        log(1 + Double(max(sentenceCount, 1)) / Double(max(sentencesWith[lemma] ?? 1, 1)))
    }

    func isRare(_ lemma: String, share: Double = WordKnobs.rareShare) -> Bool {
        (sentencesWith[lemma] ?? 0) <= max(WordKnobs.rareMin, Int(Double(sentenceCount) * share))
    }
}
