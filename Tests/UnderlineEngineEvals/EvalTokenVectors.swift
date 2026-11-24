import Foundation
import NaturalLanguage
@testable import UnderlineEngine

/// The evals' word vectors, from a separate `NLContextualEmbedding` pass per sentence (the engine keeps its own from
/// prepare, `IndexedSentence.wordVectors`). Centred on the chapter's mean word vector and normalised, the same arithmetic.
struct EvalTokenVectors: Sendable {
    /// Sentence index → (lemma, unit vector) of each content word.
    let words: [Int: [(lemma: String, range: NSRange, vector: [Float])]]

    init(_ chapter: IndexedChapter, model: NLContextualEmbedding) {
        var raw: [Int: [(String, NSRange, [Double])]] = [:]
        var sum: [Double] = []
        var count = 0
        for s in chapter.sentences {
            let content = ChapterTokenVectors.contentTokens(s)
            guard !content.isEmpty, let result = try? model.embeddingResult(for: s.text, language: .english) else { continue }
            var pieces: [(Range<String.Index>, [Double])] = []
            result.enumerateTokenVectors(in: s.text.startIndex..<s.text.endIndex) { vector, range in
                pieces.append((range, vector)); return true
            }
            var vectors: [(String, NSRange, [Double])] = []
            for token in content {
                guard let span = Range(token.range, in: s.text) else { continue }
                let hits = pieces.filter { $0.0.overlaps(span) }.map(\.1)
                guard let first = hits.first else { continue }
                var v = first
                for h in hits.dropFirst() { for i in v.indices where i < h.count { v[i] += h[i] } }
                v = v.map { $0 / Double(hits.count) }
                vectors.append((token.lemma, token.range, v))
                if sum.isEmpty { sum = v } else { for i in sum.indices where i < v.count { sum[i] += v[i] } }
                count += 1
            }
            raw[s.index] = vectors
        }
        let mean = sum.map { $0 / Double(max(count, 1)) }
        words = raw.mapValues { list in
            list.map { lemma, range, v in
                let c = v.indices.map { v[$0] - (mean.indices.contains($0) ? mean[$0] : 0) }
                let norm = c.reduce(0) { $0 + $1 * $1 }.squareRoot()
                return (lemma, range, c.map { Float(norm > 0 ? $0 / norm : 0) })
            }
        }
    }

    /// IDF-weighted mean, over the query words, of each one's best cosine with a word of `sentence`.
    func softScore(query: [(lemma: String, range: NSRange, vector: [Float])], sentence: Int, stats: WordStats?) -> Double {
        guard let target = words[sentence], !target.isEmpty, !query.isEmpty else { return 0 }
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

/// Token vectors per chapter, computed on first use and kept (evals).
final class TokenVectorCache: @unchecked Sendable {
    private let model: NLContextualEmbedding
    private let lock = NSLock()
    private var byChapter: [Int: EvalTokenVectors] = [:]

    init(model: NLContextualEmbedding) { self.model = model }

    func vectors(for chapter: IndexedChapter) -> EvalTokenVectors {
        lock.lock()
        defer { lock.unlock() }
        if let v = byChapter[chapter.chapterIndex] { return v }
        let v = EvalTokenVectors(chapter, model: model)
        byChapter[chapter.chapterIndex] = v
        return v
    }
}
