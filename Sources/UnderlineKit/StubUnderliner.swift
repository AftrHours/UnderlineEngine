import Foundation

/// An `Underlining` that returns what it was given, for an app's tests: no engine, no model download, no waiting.
public struct StubUnderliner: Underlining {
    public let version: Int
    public let summary: String
    private let batches: @Sendable (Int) -> [UnderlineBatch]

    /// `batches` gets the chapter index and returns what to emit for it.
    public init(version: Int = 1, summary: String = "Stub", batches: @escaping @Sendable (Int) -> [UnderlineBatch] = { _ in [] }) {
        self.version = version
        self.summary = summary
        self.batches = batches
    }

    public func underlines(inChapter chapter: Int, of book: any BookSource, startingAt sentence: Int) -> AsyncStream<UnderlineBatch> {
        let result = batches(chapter)
        return AsyncStream { continuation in
            for batch in result { continuation.yield(batch) }
            continuation.finish()
        }
    }
}
