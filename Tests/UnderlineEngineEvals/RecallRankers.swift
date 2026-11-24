import Foundation
import NaturalLanguage
@testable import UnderlineEngine

/// Search experiments for the retrieval recall test (2026-11-23). Not used by the engine: each ranks the same pool R8 searches,
/// so their recall@k can be compared with R8's.
///
/// - BM25: the shared-word score with term frequency and sentence-length normalisation (k1 1.2, b 0.75), book-level IDF.
/// - Soft words (token max-similarity): each content word of the phrase, read in its sentence by `NLContextualEmbedding`,
///   is matched to the most similar content word of the earlier sentence; the cosines are averaged, weighted by IDF.
///   "dollar" can then match "money" without sharing the lemma.
enum RecallRankers {
    static let k1 = 1.2
    static let b = 0.75

    static func contentTokens(_ s: IndexedSentence) -> [WordToken] { ChapterTokenVectors.contentTokens(s) }

    /// BM25 score of each sentence for the query lemmas.
    static func bm25(_ query: Set<String>, pool: [IndexedSentence], stats: WordStats, avgLength: Double) -> [Int: Double] {
        let n = Double(max(stats.sentenceCount, 1))
        var out: [Int: Double] = [:]
        for s in pool {
            let lemmas = contentTokens(s).map(\.lemma)
            let length = Double(lemmas.count)
            var tf: [String: Double] = [:]
            for l in lemmas where query.contains(l) { tf[l, default: 0] += 1 }
            out[s.index] = tf.reduce(0) { sum, item in
                let df = Double(stats.sentencesWith[item.key] ?? 0)
                let idf = log(1 + (n - df + 0.5) / (df + 0.5))
                return sum + idf * item.value * (k1 + 1) / (item.value + k1 * (1 - b + b * length / max(avgLength, 1)))
            }
        }
        return out
    }
}
