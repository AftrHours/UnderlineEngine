import Foundation
import FoundationModels

public enum ModelChoice: Sendable {
    /// Rules, then Foundation Models as a veto on what the rules accepted, when Apple Intelligence is available.
    /// Optional: on Little Women chapters 1–3 the model turned down right and wrong links about equally often
    /// (best prompt: 31 of 55 kept, 19 right), so it costs right links and time for little precision.
    case automatic
    /// Rules only: the default. Same result on every device, about 8 s a chapter.
    case rulesOnly
}

public enum EmbeddingChoice: Sendable {
    /// Apple's built-in sentence embedding (`NLEmbedding`): always on the device.
    case automatic
    /// `NLContextualEmbedding`, the embedding the measured results use. Its model assets may have to be downloaded by the
    /// system first, so only `UnderlineCtrl.make(model:embedding:)` can load it; it falls back to `.automatic` when it can't.
    case contextual
    case none
}

/// The use case: prepare a chapter and find the phrases worth underlining, each with the earlier passage
/// that explains it (spec §5, §6).
public final class UnderlineCtrl: Sendable {
    let modelSvc: any UnderlineModelSvc
    let embeddingSvc: any EmbeddingSvc
    let indexSvc: ChapterIndexSvc
    let searchMode: SearchMode
    let bookCache = BookStatsCache()

    public convenience init(model: ModelChoice = .rulesOnly, embedding: EmbeddingChoice = .automatic) {
        self.init(model: model, embedding: embedding, search: .both)
    }

    /// Harness only: compares search modes. The app always gets `.both`. `.contextual` needs `make(model:embedding:)`;
    /// here it gets `NLEmbedding`.
    convenience init(model: ModelChoice, embedding: EmbeddingChoice = .automatic, search: SearchMode) {
        let embeddingSvc: any EmbeddingSvc = embedding == .none ? EmbeddingSvcUnavailable() : EmbeddingSvcApple()
        self.init(modelSvc: Self.modelSvc(model), embeddingSvc: embeddingSvc, search: search)
    }

    /// The engine with any embedding, `.contextual` included: loads `NLContextualEmbedding` (the system may download its
    /// assets first) and falls back to `NLEmbedding` when it can't. With no arguments it is the measured engine (R22):
    /// rules only and the contextual embedding. Prepare chapters with `prepare(_:ofBook:chapters:)`.
    public static func make(model: ModelChoice = .rulesOnly, embedding: EmbeddingChoice = .contextual) async -> UnderlineCtrl {
        guard embedding == .contextual, let contextual = await EmbeddingSvcContextual.make() else {
            return UnderlineCtrl(model: model, embedding: embedding == .none ? .none : .automatic)
        }
        return UnderlineCtrl(modelSvc: modelSvc(model), embeddingSvc: contextual)
    }

    private static func modelSvc(_ model: ModelChoice) -> any UnderlineModelSvc {
        model == .automatic && SystemLanguageModel.default.availability == .available
            ? UnderlineModelSvcFoundation() : UnderlineModelSvcUnavailable()
    }

    init(modelSvc: any UnderlineModelSvc, embeddingSvc: any EmbeddingSvc, indexSvc: ChapterIndexSvc = .init(), search: SearchMode = .both) {
        self.modelSvc = modelSvc
        self.embeddingSvc = embeddingSvc
        self.indexSvc = indexSvc
        self.searchMode = search
    }

    /// Whether pick and confirm use the on-device model.
    public var usesModel: Bool { modelSvc.isAvailable }

    /// The embedding this engine actually uses (`.contextual` falls back to `.sentence` when its assets are missing).
    public var embeddingEngine: EmbeddingEngine { embeddingSvc.engine }

    /// Once per book, before any chapter: counts how many sentences hold each word over the whole book (the rarity the
    /// rules confirm and the IDF weights rely on), and with the contextual embedding sets its centre from every fifth
    /// sentence. Pass the result to `prepare(_:bookStats:)` for every chapter; it is `Codable`, so it can be cached.
    /// Takes about as long as tagging the book; call it off the main thread.
    public func prepareBook(_ chapters: [ChapterInput]) -> WordStats {
        let sentences = chapters.flatMap(indexSvc.index)
        if let contextual = embeddingSvc as? EmbeddingSvcContextual {
            contextual.center(on: sentences.enumerated().filter { $0.offset % 5 == 0 }.map(\.element.text))
        }
        return WordStats(sentences: sentences)
    }

    /// Splits, tags, finds events and embeds the whole chapter. Call it off the main thread when the chapter opens.
    /// With `bookStats` (from `prepareBook`), word rarity is the book's; without it, the chapter's own, which is much worse.
    public func prepare(_ chapter: ChapterInput, bookStats: WordStats? = nil) async -> IndexedChapter {
        var prepared = await indexSvc.prepare(chapter, embedding: embeddingSvc)
        if let bookStats { prepared.wordStats = bookStats }
        return prepared
    }

    /// Prepares a chapter with word rarity from its whole book, as the measured runs do. The book is worked out once, the
    /// first time one of its chapters is prepared (`chapters` is only called then), and kept until a chapter of another
    /// book is prepared: preparing a book also centres the contextual embedding on it. `book` is any stable ID of the book.
    public func prepare(_ chapter: ChapterInput, ofBook book: String,
                        chapters: @escaping @Sendable () -> [ChapterInput]) async -> IndexedChapter {
        let stats = await bookCache.stats(for: book) { self.prepareBook(chapters()) }
        return await prepare(chapter, bookStats: stats)
    }

    static func milliseconds(_ duration: Duration) -> Int {
        Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
    }
}

/// The open book's word rarity. One book at a time, because preparing a book also re-centres the contextual embedding.
actor BookStatsCache {
    private var current: (book: String, stats: WordStats)?

    func stats(for book: String, make: @Sendable () -> WordStats) -> WordStats {
        if let current, current.book == book { return current.stats }
        let stats = make()
        current = (book, stats)
        return stats
    }
}
