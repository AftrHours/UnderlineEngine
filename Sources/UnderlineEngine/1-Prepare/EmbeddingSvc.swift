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

/// Apple's contextual (BERT-style) embedding: one vector per token, averaged into one per sentence. Its assets download
/// on first use, so `make()` returns `nil` when they can't be loaded in time. The app's default (R22) through `UnderlineCtrl.make()`.
final class EmbeddingSvcContextual: EmbeddingSvc, @unchecked Sendable {
    let engine: EmbeddingEngine = .contextual
    private let model: NLContextualEmbedding
    private let lock = NSLock()
    /// The average vector of the book, subtracted from every vector. Averaged token vectors all point the same way
    /// (half the sentence pairs in Little Women chapter 1 score 0.94 or more); removing the shared part spreads them out.
    private var center: [Double]?

    private init(model: NLContextualEmbedding) { self.model = model }

    /// Sets the center from these texts (a sample of the book is enough).
    func center(on texts: [String]) {
        let vectors = texts.compactMap(raw)
        guard let first = vectors.first else { return }
        var sum = [Double](repeating: 0, count: first.count)
        for v in vectors { for i in sum.indices where i < v.count { sum[i] += v[i] } }
        lock.lock()
        center = sum.map { $0 / Double(vectors.count) }
        lock.unlock()
    }

    /// How long `make()` waits for the assets to download. The request can wait forever (offline, or in the Simulator),
    /// and the caller then falls back to `NLEmbedding` instead of never underlining.
    static let assetWait: Duration = .seconds(10)

    static func make(wait: Duration = assetWait) async -> EmbeddingSvcContextual? {
        guard let model = NLContextualEmbedding(language: .english) else { return nil }
        if !model.hasAvailableAssets {
            guard await assetsArrive(for: model, within: wait) else { return nil }
        }
        do { try model.load() } catch { return nil }
        return EmbeddingSvcContextual(model: model)
    }

    /// Whichever comes first: the assets, or the end of `limit`. Not a task group, which would still wait for a request
    /// that ignores cancellation.
    private static func assetsArrive(for model: NLContextualEmbedding, within limit: Duration) async -> Bool {
        let once = ResumeOnce()
        let request = UncheckedBox(model)
        return await withCheckedContinuation { continuation in
            once.set(continuation)
            Task { once.resume((try? await request.value.requestAssets()) == .available) }
            Task {
                try? await Task.sleep(for: limit)
                once.resume(false)
            }
        }
    }

    func vector(for text: String) -> [Float]? {
        guard let v = raw(text) else { return nil }
        lock.lock()
        let c = center
        lock.unlock()
        guard let c else { return v.map(Float.init) }
        return v.indices.map { Float(v[$0] - (c.indices.contains($0) ? c[$0] : 0)) }
    }

    /// The contextual vector of the words at `range` as they are used in `text` (token vectors averaged, not centered).
    /// "stairs" in a sentence about two sisters hugging and "stairs" Laurie runs down get different vectors.
    func wordVector(in text: String, at range: NSRange) -> [Double]? {
        guard let span = Range(range, in: text) else { return nil }
        lock.lock()
        defer { lock.unlock() }
        guard let result = try? model.embeddingResult(for: text, language: .english) else { return nil }
        var sum: [Double] = []
        var count = 0
        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, tokenRange in
            guard tokenRange.overlaps(span) else { return true }
            if sum.isEmpty { sum = vector } else { for i in sum.indices where i < vector.count { sum[i] += vector[i] } }
            count += 1
            return true
        }
        guard count > 0 else { return nil }
        return sum.map { $0 / Double(count) }
    }

    private func raw(_ text: String) -> [Double]? {
        lock.lock()
        defer { lock.unlock() }
        guard let result = try? model.embeddingResult(for: text, language: .english) else { return nil }
        var sum: [Double] = []
        var count = 0
        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, _ in
            if sum.isEmpty { sum = vector } else { for i in sum.indices where i < vector.count { sum[i] += vector[i] } }
            count += 1
            return true
        }
        guard count > 0 else { return nil }
        return sum.map { $0 / Double(count) }
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

/// Resumes a continuation once, from whichever task gets there first.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Bool, Never>?

    func set(_ continuation: CheckedContinuation<Bool, Never>) {
        lock.withLock { self.continuation = continuation }
    }

    func resume(_ value: Bool) {
        let waiting = lock.withLock { () -> CheckedContinuation<Bool, Never>? in
            defer { continuation = nil }
            return continuation
        }
        waiting?.resume(returning: value)
    }
}

/// Carries a value the compiler can't prove Sendable (`NLContextualEmbedding`) into a task that only reads it.
private struct UncheckedBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}
