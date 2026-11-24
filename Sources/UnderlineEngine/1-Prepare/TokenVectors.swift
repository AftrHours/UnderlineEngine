import Foundation
import NaturalLanguage

// Token-level contextual vectors (2026-11-23): what R9's soft lexical match reads. The engine keeps them from prepare's own
// model pass (`IndexedSentence.wordVectors`). The evals' separate-pass version is `EvalTokenVectors` in the tests.

/// Contextual vectors of every content word in a chapter, one model pass per sentence, centred on the chapter's mean token
/// vector (raw token vectors all point the same way) and normalised, so a dot product is a cosine.
enum ChapterTokenVectors {
    /// Nouns, verbs and adjectives without the lemmas that say little (`SearchKnobs.stopLemmas`).
    static func contentTokens(_ s: IndexedSentence) -> [WordToken] {
        s.tokens.filter { ["Noun", "Verb", "Adjective"].contains($0.wordClass) && !SearchKnobs.stopLemmas.contains($0.lemma) }
    }

    /// Centres the raw word vectors (by sentence position) on their chapter mean, normalises them, and stores them in
    /// `wordVectors`.
    static func center(_ sentences: inout [IndexedSentence], raw: [Int: [(String, NSRange, [Double])]]) {
        var sum: [Double] = []
        var count = 0
        for i in raw.keys.sorted() {
            for (_, _, v) in raw[i] ?? [] {
                if sum.isEmpty { sum = v } else { for k in sum.indices where k < v.count { sum[k] += v[k] } }
                count += 1
            }
        }
        let mean = sum.map { $0 / Double(max(count, 1)) }
        for (i, list) in raw {
            sentences[i].wordVectors = list.map { lemma, range, v in
                let c = v.indices.map { v[$0] - (mean.indices.contains($0) ? mean[$0] : 0) }
                let norm = c.reduce(0) { $0 + $1 * $1 }.squareRoot()
                return WordVector(lemma: lemma, range: range, vector: c.map { Float(norm > 0 ? $0 / norm : 0) })
            }
        }
    }

    /// IDF-weighted mean, over the query words, of each one's best cosine with a word of `target` (token MaxSim).
    static func softScore(query: [WordVector], target: [WordVector], stats: WordStats?) -> Double {
        guard !target.isEmpty, !query.isEmpty else { return 0 }
        var total = 0.0, weights = 0.0
        for q in query {
            let w = stats?.idf(q.lemma) ?? 1
            var best = -1.0
            for t in target {
                var dot: Float = 0
                for i in 0..<min(q.vector.count, t.vector.count) { dot += q.vector[i] * t.vector[i] }
                best = max(best, Double(dot))
            }
            total += w * best
            weights += w
        }
        return weights > 0 ? total / weights : 0
    }
}
