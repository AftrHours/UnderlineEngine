import Foundation

public enum EmbeddingChoice: Sendable {
    /// `NLContextualEmbedding`: gives the soft lexical match its word vectors. Its model assets may have to be downloaded by
    /// the system first; when they can't be loaded, the engine runs without word vectors.
    case contextual
    /// No embedding (no word vectors): for tests that must not wait for the model.
    case none
}

/// The use case: prepare a chapter and find the phrases worth underlining, each with the earlier passage
/// that explains it (spec §5, §6).
public final class UnderlineCtrl: Sendable {
    let embeddingSvc: any EmbeddingSvc
    let indexSvc: ChapterIndexSvc
    let bookCache = BookStatsCache()

    /// Loads `NLContextualEmbedding` for `.contextual` (the system may download its assets first, at most
    /// `EmbeddingSvcContextual.assetWait`); without it, no word vectors. Prepare chapters with `prepare(_:ofBook:chapters:)`.
    public static func make(embedding: EmbeddingChoice = .contextual) async -> UnderlineCtrl {
        guard embedding == .contextual, let contextual = await EmbeddingSvcContextual.make() else {
            return UnderlineCtrl(embeddingSvc: EmbeddingSvcUnavailable())
        }
        return UnderlineCtrl(embeddingSvc: contextual)
    }

    init(embeddingSvc: any EmbeddingSvc, indexSvc: ChapterIndexSvc = .init()) {
        self.embeddingSvc = embeddingSvc
        self.indexSvc = indexSvc
    }

    /// The embedding this engine actually uses (`.none` when the contextual model couldn't be loaded).
    public var embeddingEngine: EmbeddingEngine { embeddingSvc.engine }

    /// Once per book, before any chapter: counts how many sentences hold each word over the whole book (the rarity search and
    /// confirm rely on). Pass the result to `prepare(_:bookStats:)` for every chapter; it is `Codable`, so it can be cached.
    /// Takes about as long as tagging the book; call it off the main thread.
    public func prepareBook(_ chapters: [ChapterInput]) -> WordStats {
        WordStats(sentences: chapters.flatMap { indexSvc.index($0, names: false) })
    }

    /// Splits, tags, finds events and gives every content word its vector, for the whole chapter. Call it off the main
    /// thread when the chapter opens. With `bookStats` (from `prepareBook`), word rarity is the book's; without it, the
    /// chapter's own, which is much worse.
    public func prepare(_ chapter: ChapterInput, bookStats: WordStats? = nil) async -> IndexedChapter {
        await indexSvc.prepare(chapter, embedding: embeddingSvc, bookStats: bookStats)
    }

    /// Prepares a chapter with word rarity from its whole book, as the measured runs do. The book is worked out once, the
    /// first time one of its chapters is prepared (`chapters` is only called then), and kept until a chapter of another
    /// book is prepared. `book` is any stable ID of the book.
    public func prepare(_ chapter: ChapterInput, ofBook book: String,
                        chapters: @escaping @Sendable () -> [ChapterInput]) async -> IndexedChapter {
        let stats = await bookCache.stats(for: book) { self.prepareBook(chapters()) }
        return await prepare(chapter, bookStats: stats)
    }

    static func milliseconds(_ duration: Duration) -> Int {
        Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
    }
}

/// The open book's word rarity, one book at a time.
actor BookStatsCache {
    private var current: (book: String, stats: WordStats)?

    func stats(for book: String, make: @Sendable () -> WordStats) -> WordStats {
        if let current, current.book == book { return current.stats }
        let stats = make()
        current = (book, stats)
        return stats
    }
}
