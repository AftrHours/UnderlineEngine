import Foundation

@testable import UnderlineEngine

/// The first sentence of `text`, tagged and split into events (as `prepare` does, without a vector).
func indexed(_ text: String) -> IndexedSentence {
    var sentence = ChapterIndexSvc().index(ChapterInput(chapterIndex: 0, plainText: text))[0]
    sentence.events = EventSplitter.events(in: sentence)
    return sentence
}

/// A file in the repo's `Dataset/` folder.
func datasetURL(_ name: String, file: StaticString = #filePath) -> URL {
    URL(fileURLWithPath: "\(file)")
        .deletingLastPathComponent()   // TextEngineTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repo root
        .appendingPathComponent("Dataset")
        .appendingPathComponent(name)
}

/// A scripted model: returns the given confirm (or throws), and logs the sentence indexes it was given.
final class FakeUnderlineModel: UnderlineModelSvc, @unchecked Sendable {
    var isAvailable = true
    var confirmResult = ModelConfirm(evidence: "", explains: false)
    var confirmError: ModelFailure?
    /// Always confirms.
    var autoAccept = false
    private let lock = NSLock()
    private var log: [[Int]] = []

    /// The sentence indexes of each confirm call: the underlined sentence, then the passage.
    var calls: [[Int]] { lock.withLock { log } }

    func confirm(phrase: String, sentence: IndexedText, passage: IndexedText) async throws(ModelFailure) -> ModelConfirm {
        lock.withLock { log.append([sentence.index, passage.index]) }
        if let confirmError { throw confirmError }
        return autoAccept ? ModelConfirm(evidence: "x", explains: true) : confirmResult
    }
}

let fixtureText = "Father had gone away to the war. Meg sewed by the fire. Beth played the old piano. Amy drew a small picture.\n\nJo said she would face the war like Father."

/// The fixture chapter, prepared without embeddings, so search runs on words only.
func fixtureChapter(firstSentence: Int = 0) async -> IndexedChapter {
    await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: fixtureText, firstSentence: firstSentence),
                                    embedding: EmbeddingSvcUnavailable())
}

func ctrl(_ model: any UnderlineModelSvc) -> UnderlineCtrl {
    UnderlineCtrl(modelSvc: model, embeddingSvc: EmbeddingSvcUnavailable())
}
