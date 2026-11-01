import Foundation
import NaturalLanguage

/// Turns text into a vector that stands for its meaning (spec §5.5). A protocol, so the model can change
/// (a bundled Core ML model later) and tests can run without embeddings.
protocol EmbeddingSvc: Sendable {
    var engine: EmbeddingEngine { get }
    func vector(for text: String) -> [Float]?
}

/// Apple's built-in English sentence embedding, or averaged word vectors when that is missing.
final class EmbeddingSvcApple: EmbeddingSvc, @unchecked Sendable {
    let engine: EmbeddingEngine
    private let sentence: NLEmbedding?
    private let word: NLEmbedding?
    // NLEmbedding isn't documented as thread-safe, so calls go through one lock.
    private let lock = NSLock()

    init() {
        sentence = NLEmbedding.sentenceEmbedding(for: .english)
        word = sentence == nil ? NLEmbedding.wordEmbedding(for: .english) : nil
        engine = sentence != nil ? .sentence : word != nil ? .wordAverage : .none
    }

    func vector(for text: String) -> [Float]? {
        lock.lock()
        defer { lock.unlock() }
        if let sentence {
            return sentence.vector(for: text).map { $0.map(Float.init) }
        }
        guard let word else { return nil }
        let vectors = text.lowercased().split { !$0.isLetter }.compactMap { word.vector(for: String($0)) }
        guard let first = vectors.first else { return nil }
        var sum = [Double](repeating: 0, count: first.count)
        for vector in vectors { for i in sum.indices { sum[i] += vector[i] } }
        return sum.map { Float($0 / Double(vectors.count)) }
    }
}

/// No embeddings: search runs on words only.
struct EmbeddingSvcUnavailable: EmbeddingSvc {
    var engine: EmbeddingEngine { .none }
    func vector(for text: String) -> [Float]? { nil }
}

enum Cosine {
    /// Cosine similarity mapped to 0…1 as `(1 + cos) / 2`; 0 for empty or mismatched vectors.
    static func similarity(_ a: [Float], _ b: [Float]) -> Double {
        guard !a.isEmpty, a.count == b.count else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in a.indices {
            dot += Double(a[i]) * Double(b[i])
            normA += Double(a[i]) * Double(a[i])
            normB += Double(b[i]) * Double(b[i])
        }
        guard normA > 0, normB > 0 else { return 0 }
        return (1 + dot / (normA.squareRoot() * normB.squareRoot())) / 2
    }
}
