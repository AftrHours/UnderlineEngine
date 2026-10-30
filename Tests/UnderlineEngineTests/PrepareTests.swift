import Foundation
import Testing
@testable import UnderlineEngine

@Test func prepareFillsEventsAndVectorsForWholeChapter() async throws {
    let input = ChapterInput(chapterIndex: 0, plainText: try String(contentsOf: datasetURL("little-women-ch1.txt"), encoding: .utf8))
    let ch = await ChapterIndexSvc().prepare(input, embedding: EmbeddingSvcApple())
    #expect(ch.sentences.count == 227)
    #expect(ch.sentence(39)?.events.count == 3)
    if ch.embedding != .none { #expect(ch.sentences.allSatisfy { $0.vector?.count == 512 }) }
}

@Test func indexedChapterRoundTripsThroughJSON() async throws {
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 2, plainText: "Jo ran. Meg sighed."), embedding: EmbeddingSvcUnavailable())
    let back = try JSONDecoder().decode(IndexedChapter.self, from: JSONEncoder().encode(ch))
    #expect(back.sentences.map(\.text) == ch.sentences.map(\.text))
    #expect(back.embedding == .none)
    #expect(back.chapterIndex == 2)
}

@Test func cosineHandlesEmptyAndMismatched() {
    #expect(Cosine.similarity([], [1]) == 0)
    #expect(abs(Cosine.similarity([1, 0], [1, 0]) - 1) < 1e-9)
    #expect(abs(Cosine.similarity([1, 0], [-1, 0])) < 1e-9)
}

/// One paragraph of four sentences, given to the engine with the global sentence indexes in `indexes`.
private func chapterWithIndexes(_ indexes: [Int], extra: [SentenceInput] = [], duplicateParagraph: Bool = false) async -> IndexedChapter {
    let text = "A cat sat. The dog ran. It rained. Jo laughed."
    let ranges = SentenceSplitter.ranges(in: text)
    let sentences = zip(indexes, ranges).map { SentenceInput(index: $0, paragraph: 0, range: $1) } + extra
    let paragraphs = [ParagraphInput(index: 0, text: text)] + (duplicateParagraph ? [ParagraphInput(index: 0, text: "Other.")] : [])
    return await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, paragraphs: paragraphs, sentences: sentences),
                                          embedding: EmbeddingSvcUnavailable())
}

@Test func gapInSentenceIndexesNeverLeaksALaterSentence() async {
    let ch = await chapterWithIndexes([10, 11, 13, 14])
    #expect(ch.sentence(12) == nil)
    #expect(ch.sentence(13)?.text == "It rained.")
}

@Test func sentencesGivenOutOfOrderAreSorted() async {
    let ch = await chapterWithIndexes([3, 1, 2, 4])
    #expect(ch.sentences.map(\.index) == [1, 2, 3, 4])
    #expect(ch.sentence(1)?.text == "The dog ran.")
}

@Test func duplicateParagraphsAndBadRangesDoNotCrash() async {
    let bad = SentenceInput(index: 5, paragraph: 0, range: NSRange(location: 40, length: 99))
    let missing = SentenceInput(index: 6, paragraph: 7, range: NSRange(location: 0, length: 1))
    let ch = await chapterWithIndexes([1, 2, 3, 4], extra: [bad, missing], duplicateParagraph: true)
    #expect(ch.sentences.map(\.index) == [1, 2, 3, 4])
}
