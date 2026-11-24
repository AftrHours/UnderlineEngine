import Foundation

@testable import UnderlineEngine

/// The first sentence of `text`, tagged and split into events (as `prepare` does, without word vectors).
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

let fixtureText = "Father had gone away to the war. Meg sewed by the fire. Beth played the old piano. Amy drew a small picture.\n\nJo said she would face the war like Father."

/// The fixture chapter, prepared without word vectors.
func fixtureChapter(firstSentence: Int = 0) async -> IndexedChapter {
    await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: fixtureText, firstSentence: firstSentence),
                                    embedding: EmbeddingSvcUnavailable())
}

/// The engine without word vectors.
func ctrl() -> UnderlineCtrl {
    UnderlineCtrl(embeddingSvc: EmbeddingSvcUnavailable())
}
