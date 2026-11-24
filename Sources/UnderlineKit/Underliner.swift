import Foundation
import UnderlineEngine

/// Runs one `LinkMethod` behind the `Underlining` door. Everything the app used to decide (the embedding, whether a model is
/// asked, counting words over the whole book, preparing chapters) is decided here, inside the engine.
public final class Underliner: Underlining {
    /// What an app asks for. The engine decides what each one means.
    public enum Preset: Sendable {
        /// What the engine ships: R9 with the contextual embedding.
        case release
        /// The same method without the embedding (no word vectors), for tests that must not wait for the model.
        case testing
    }

    /// The version of what `.release` makes, known without making it (which can take seconds while the embedding loads).
    /// An app compares it with the version saved with a chapter to decide whether the chapter is still current.
    public static var releaseVersion: Int { Linker.version }

    private let method: any LinkMethod

    public var version: Int { method.version }
    public var summary: String { method.summary }

    /// For tools and tests that bring their own method.
    public init(method: any LinkMethod) {
        self.method = method
    }

    /// Async because the contextual embedding may have to be downloaded the first time (at most 10 s, then it falls back).
    public static func make(_ preset: Preset = .release) async -> Underliner {
        switch preset {
        case .release: Underliner(method: await Linker.make(embedding: .contextual))
        case .testing: Underliner(method: await Linker.make(embedding: .none))
        }
    }

    public func underlines(inChapter chapter: Int, of book: any BookSource, startingAt sentence: Int) -> AsyncStream<UnderlineBatch> {
        let method = method
        return AsyncStream { continuation in
            let task = Task {
                let indexed = await method.prepare(Self.input(chapter, of: book), ofBook: book.id) {
                    (0..<book.chapterCount).map { Self.input($0, of: book) }
                }
                guard !Task.isCancelled else { continuation.finish(); return }
                for await paragraph in method.results(in: indexed, startingAt: sentence) {
                    continuation.yield(Self.batch(of: paragraph, in: indexed))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Mapping, the only place that knows both sides

    static func input(_ index: Int, of book: any BookSource) -> ChapterInput {
        let text = book.chapterText(index)
        return ChapterInput(chapterIndex: index,
                            paragraphs: text.paragraphs.map { ParagraphInput(index: $0.index, text: $0.text) },
                            sentences: text.sentences.map { SentenceInput(index: $0.index, paragraph: $0.paragraph, range: $0.range) })
    }

    static func batch(of paragraph: ParagraphResult, in chapter: IndexedChapter) -> UnderlineBatch {
        UnderlineBatch(underlines: paragraph.underlines.map(result),
                       considered: paragraph.records.sorted { $0.sentence < $1.sentence }.map(considered))
    }

    static func result(_ underline: Underline) -> UnderlineResult {
        let reference = underline.reference
        return UnderlineResult(id: underline.id, sentence: underline.sentence, paragraph: underline.paragraph, range: underline.range,
                               text: underline.text, kind: underline.kind.rawValue, decidedBy: underline.decidedBy.rawValue,
                               reference: .init(sentence: reference.sentence, paragraph: reference.paragraph,
                                                range: reference.range, text: reference.text))
    }

    static func considered(_ record: UnderlineRecord) -> ConsideredPhrase {
        let outcome = record.kept
            ? "explained by s\(record.pickedSentence.map(String.init) ?? "?")"
            : "dropped: \(record.dropped?.rawValue ?? "unknown")"
        return ConsideredPhrase(sentence: record.sentence, phrase: record.phrase,
                                detail: ["s\(record.sentence)", record.kind.rawValue, outcome]
                                    .compactMap { $0 }.joined(separator: " · "),
                                isUnderlined: record.kept)
    }
}
