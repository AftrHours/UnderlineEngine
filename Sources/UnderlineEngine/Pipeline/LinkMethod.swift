import Foundation

public protocol LinkMethod: Sendable {
    var name: String { get }
    var version: Int { get }
    var summary: String { get }
    func prepare(_ chapter: ChapterInput, ofBook book: String,
                 chapters: @escaping @Sendable () -> [ChapterInput]) async -> IndexedChapter
    func results(in chapter: IndexedChapter, startingAt sentence: Int) -> AsyncStream<ParagraphResult>
}

/// R9 (2026-11-24), the engine's link method:
/// - search ranks earlier sentences by IDF-weighted shared content lemmas, plus role bonuses;
/// - pick: of the top 6 candidates, those sharing a content word with the phrase, best first, near ties to the nearer
///   sentence; the first goes to confirm (no minimum score, no lead over the second);
/// - confirm by evidence points (`RulesPicker.evidencePoints`): a shared rare noun or adjective, two shared rare words and a
///   soft lexical match (token MaxSim of the words the reference doesn't share) add points; 2 needed within 20 sentences
///   back, 3 further; a shared name counts like any shared noun;
/// - kind and Zwaan's tracks are computed and returned, never scored.
public final class Linker: LinkMethod {
    public static let version = 6
    private let ctrl: UnderlineCtrl
    public var name: String { "R9" }
    public var version: Int { Self.version }
    public var summary: String { "Rules only · lexical retrieval · evidence pick · \(ctrl.embeddingEngine.rawValue) word vectors" }

    init(ctrl: UnderlineCtrl) {
        self.ctrl = ctrl
    }

    public static func make(embedding: EmbeddingChoice = .contextual) async -> Linker {
        Linker(ctrl: await UnderlineCtrl.make(embedding: embedding))
    }

    public func prepare(_ chapter: ChapterInput, ofBook book: String,
                        chapters: @escaping @Sendable () -> [ChapterInput]) async -> IndexedChapter {
        await ctrl.prepare(chapter, ofBook: book, chapters: chapters)
    }

    public func results(in chapter: IndexedChapter, startingAt sentence: Int) -> AsyncStream<ParagraphResult> {
        ctrl.paragraphResults(in: chapter, startingAt: sentence)
    }
}
