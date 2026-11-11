import Foundation
import FoundationModels

public enum ModelChoice: Sendable {
    /// Foundation Models when Apple Intelligence is available, otherwise rules.
    case automatic
    case rulesOnly
}

public enum EmbeddingChoice: Sendable {
    case automatic
    case none
}

/// The use case: prepare a chapter and find the phrases worth underlining, each with the earlier passage
/// that explains it (spec §5, §6).
public final class UnderlineCtrl: Sendable {
    let modelSvc: any UnderlineModelSvc
    let embeddingSvc: any EmbeddingSvc
    let indexSvc: ChapterIndexSvc
    let searchMode: SearchMode

    public convenience init(model: ModelChoice = .automatic, embedding: EmbeddingChoice = .automatic) {
        self.init(model: model, embedding: embedding, search: .both)
    }

    /// Harness only: compares search modes. The app always gets `.both`.
    convenience init(model: ModelChoice, embedding: EmbeddingChoice = .automatic, search: SearchMode) {
        let modelSvc: any UnderlineModelSvc = model == .automatic && SystemLanguageModel.default.availability == .available
            ? UnderlineModelSvcFoundation() : UnderlineModelSvcUnavailable()
        let embeddingSvc: any EmbeddingSvc = embedding == .automatic ? EmbeddingSvcApple() : EmbeddingSvcUnavailable()
        self.init(modelSvc: modelSvc, embeddingSvc: embeddingSvc, search: search)
    }

    init(modelSvc: any UnderlineModelSvc, embeddingSvc: any EmbeddingSvc, indexSvc: ChapterIndexSvc = .init(), search: SearchMode = .both) {
        self.modelSvc = modelSvc
        self.embeddingSvc = embeddingSvc
        self.indexSvc = indexSvc
        self.searchMode = search
    }

    /// Whether pick and confirm use the on-device model.
    public var usesModel: Bool { modelSvc.isAvailable }

    /// Splits, tags, finds events and embeds the whole chapter. Call it off the main thread when the chapter opens.
    public func prepare(_ chapter: ChapterInput) async -> IndexedChapter {
        await indexSvc.prepare(chapter, embedding: embeddingSvc)
    }

    static func milliseconds(_ duration: Duration) -> Int {
        Int(duration.components.seconds * 1000 + duration.components.attoseconds / 1_000_000_000_000_000)
    }
}
