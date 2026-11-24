import Foundation
import Testing
@testable import UnderlineEngine

@Test func prepareFillsEventsForWholeChapter() async throws {
    let input = ChapterInput(chapterIndex: 0, plainText: try String(contentsOf: datasetURL("little-women-ch1.txt"), encoding: .utf8))
    let ch = await ChapterIndexSvc().prepare(input, embedding: EmbeddingSvcUnavailable())
    #expect(ch.sentences.count == 227)
    #expect(ch.sentence(39)?.events.count == 3)
    #expect(ch.sentences.allSatisfy { ($0.wordVectors ?? []).isEmpty })
}

@Test func indexedChapterRoundTripsThroughJSON() async throws {
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 2, plainText: "Jo ran. Meg sighed."), embedding: EmbeddingSvcUnavailable())
    let back = try JSONDecoder().decode(IndexedChapter.self, from: JSONEncoder().encode(ch))
    #expect(back.sentences.map(\.text) == ch.sentences.map(\.text))
    #expect(back.embedding == .none)
    #expect(back.chapterIndex == 2)
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

@Test func bookStatsCountTheWholeBookAndReplaceTheChapters() async {
    let engine = UnderlineCtrl(embeddingSvc: EmbeddingSvcUnavailable())
    let one = ChapterInput(chapterIndex: 0, plainText: "Jo found a parrot. Meg sewed by the fire.")
    let two = ChapterInput(chapterIndex: 1, plainText: "The parrot screamed. Amy drew a picture.", firstParagraph: 1, firstSentence: 2)
    let stats = engine.prepareBook([one, two])
    #expect(stats.sentenceCount == 4)
    #expect(stats.sentencesWith["parrot"] == 2)
    let own = await engine.prepare(two)
    let book = await engine.prepare(two, bookStats: stats)
    #expect(own.wordStats?.sentenceCount == 2)
    #expect(book.wordStats == stats)
}

@Test func preparingByBookUsesTheWholeBookOnceAndRedoesItForAnotherBook() async {
    let engine = UnderlineCtrl(embeddingSvc: EmbeddingSvcUnavailable())
    let one = ChapterInput(chapterIndex: 0, plainText: "Jo found a parrot. Meg sewed by the fire.")
    let two = ChapterInput(chapterIndex: 1, plainText: "The parrot screamed. Amy drew a picture.", firstParagraph: 1, firstSentence: 2)
    let other = ChapterInput(chapterIndex: 0, plainText: "A dragon slept. The hobbit crept by.")
    let calls = Calls()
    let first = await engine.prepare(two, ofBook: "little-women") { calls.add(); return [one, two] }
    let again = await engine.prepare(one, ofBook: "little-women") { calls.add(); return [one, two] }
    #expect(first.wordStats == engine.prepareBook([one, two]))
    #expect(again.wordStats == first.wordStats)
    #expect(calls.count == 1)
    let hobbit = await engine.prepare(other, ofBook: "hobbit") { calls.add(); return [other] }
    #expect(hobbit.wordStats?.sentenceCount == 2)
    #expect(calls.count == 2)
}

private final class Calls: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.withLock { value } }
    func add() { lock.withLock { value += 1 } }
}
