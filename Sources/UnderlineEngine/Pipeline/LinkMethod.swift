import Foundation

public protocol LinkMethod: Sendable {
    var name: String { get }
    var version: Int { get }
    var summary: String { get }
    func prepare(_ chapter: ChapterInput, ofBook book: String,
                 chapters: @escaping @Sendable () -> [ChapterInput]) async -> IndexedChapter
    func results(in chapter: IndexedChapter, startingAt sentence: Int) -> AsyncStream<ParagraphResult>
}

public final class Linker: LinkMethod {
    public static let version = 5
    private let ctrl: UnderlineCtrl
    public var name: String { "R8" }
    public var version: Int { Self.version }
    public var summary: String { "Rules only · \(ctrl.embeddingEngine.rawValue) embedding" }
    public init(ctrl: UnderlineCtrl) {
        self.ctrl = ctrl
    }

    public static func make(embedding: EmbeddingChoice = .contextual) async -> Linker {
        Linker(ctrl: await UnderlineCtrl.make(model: .rulesOnly, embedding: embedding))
    }

    public func prepare(_ chapter: ChapterInput, ofBook book: String,
                        chapters: @escaping @Sendable () -> [ChapterInput]) async -> IndexedChapter {
        await ctrl.prepare(chapter, ofBook: book, chapters: chapters)
    }

    public func results(in chapter: IndexedChapter, startingAt sentence: Int) -> AsyncStream<ParagraphResult> {
        ctrl.paragraphResults(in: chapter, startingAt: sentence)
    }
}
