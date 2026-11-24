import Foundation
import NaturalLanguage

/// Gives the contextual vector of words as they are used in a sentence (spec §5.5). A protocol so tests can run without the
/// model, and the model can change later.
protocol EmbeddingSvc: Sendable {
    var engine: EmbeddingEngine { get }
    /// The raw (not centred) vector of each word at `words` in `text`, from one model pass; `nil` where there is none.
    func wordVectors(for text: String, words: [NSRange]) -> [[Double]?]
}

/// Apple's contextual (BERT-style) embedding: one vector per token, averaged into one per word. Its assets download on first
/// use, so `make()` returns `nil` when they can't be loaded in time; the engine then runs without word vectors.
final class EmbeddingSvcContextual: EmbeddingSvc, @unchecked Sendable {
    let engine: EmbeddingEngine = .contextual
    private let model: NLContextualEmbedding
    private let lock = NSLock()
    private init(model: NLContextualEmbedding) { self.model = model }

    /// How long `make()` waits for the assets to download. The request can wait forever (offline, or in the Simulator),
    /// and the caller then runs without word vectors instead of never underlining.
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

    /// One model pass: each word's vector is the average of the token vectors overlapping it (not centred).
    func wordVectors(for text: String, words: [NSRange]) -> [[Double]?] {
        lock.lock()
        let result = try? model.embeddingResult(for: text, language: .english)
        lock.unlock()
        guard let result else { return words.map { _ in nil } }
        var pieces: [(Range<String.Index>, [Double])] = []
        result.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { vector, range in
            pieces.append((range, vector)); return true
        }
        return words.map { range in
            guard let span = Range(range, in: text) else { return nil }
            let hits = pieces.filter { $0.0.overlaps(span) }.map(\.1)
            guard var v = hits.first else { return nil }
            for h in hits.dropFirst() { for i in v.indices where i < h.count { v[i] += h[i] } }
            return v.map { $0 / Double(hits.count) }
        }
    }
}

/// No embedding: no word vectors, so the soft lexical match never gives a point.
struct EmbeddingSvcUnavailable: EmbeddingSvc {
    var engine: EmbeddingEngine { .none }
    func wordVectors(for text: String, words: [NSRange]) -> [[Double]?] { words.map { _ in nil } }
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
