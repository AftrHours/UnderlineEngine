import Foundation
import Testing
@testable import UnderlineEngine

private func littleWomen() async throws -> IndexedChapter {
    let text = try String(contentsOf: datasetURL("little-women-ch1.txt"), encoding: .utf8)
    return await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: text), embedding: EmbeddingSvcUnavailable())
}

/// Every underline and record `paragraphResults` gives, from `start` (the chapter's first sentence when `nil`).
private func results(_ c: UnderlineCtrl, _ ch: IndexedChapter, from start: Int? = nil) async -> ([Underline], [UnderlineRecord]) {
    var underlines: [Underline] = []
    var records: [UnderlineRecord] = []
    for await result in c.paragraphResults(in: ch, startingAt: start ?? ch.first) {
        underlines += result.underlines
        records += result.records
    }
    return (underlines, records)
}

@Test func everyStartGivesTheSameResults() async throws {
    let ch = try await littleWomen()
    let c = ctrl()
    let (all, records) = await results(c, ch)
    #expect(!all.isEmpty)
    // Timings differ between runs, so compare what was decided.
    func decisions(_ records: [UnderlineRecord]) -> [String] {
        records.map { "\($0.sentence) \($0.phrase) \($0.kept) \(String(describing: $0.dropped))" }.sorted()
    }
    for start in [ch.sentences[100].index, 99_999] {
        let (underlines, seen) = await results(c, ch, from: start)
        #expect(Set(underlines) == Set(all))
        #expect(underlines.count == all.count)
        #expect(decisions(seen) == decisions(records))
    }
}

@Test func streamStartsAtTheReadersParagraphThenWraps() async throws {
    let ch = try await littleWomen()
    let start = ch.sentences[100]
    let paragraphs = await results(ctrl(), ch, from: start.index).0.map(\.paragraph)
    let firstWrap = paragraphs.firstIndex { $0 < start.paragraph } ?? paragraphs.count
    #expect(paragraphs.prefix(firstWrap).allSatisfy { $0 >= start.paragraph })
    #expect(paragraphs.suffix(from: firstWrap).allSatisfy { $0 < start.paragraph })
    #expect(Array(paragraphs.prefix(firstWrap)) == paragraphs.prefix(firstWrap).sorted())
}

@Test func shownUnderlinesNeverOverlap() async throws {
    let ch = try await littleWomen()
    let (all, records) = await results(ctrl(), ch)
    for (i, a) in all.enumerated() {
        for b in all[(i + 1)...] where a.sentence == b.sentence {
            #expect(NSIntersectionRange(a.range, b.range).length == 0)
        }
    }
    let limited = records.filter { $0.dropped == .densityLimit }
    #expect(limited.allSatisfy { !$0.kept })
    #expect(records.filter(\.kept).count == all.count)
}

@Test func emptyChapterFinishesImmediately() async {
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, paragraphs: [], sentences: []), embedding: EmbeddingSvcUnavailable())
    #expect(await results(ctrl(), ch, from: 0).0.isEmpty)
}

@Test func chapterWithNoEventsYieldsNothing() async {
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: "Oh. Ah. Hm."), embedding: EmbeddingSvcUnavailable())
    #expect(await results(ctrl(), ch, from: 0).0.isEmpty)
}

@Test func oneSentenceChapterHasNoUnderline() async {
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: "Jo immediately sat up and began to whistle."),
                                             embedding: EmbeddingSvcUnavailable())
    #expect(await results(ctrl(), ch).0.isEmpty)
}

@Test(.timeLimit(.minutes(1))) func cancellationStopsTheStream() async throws {
    let ch = try await littleWomen()
    let c = ctrl()
    let consumer = Task {
        var seen = 0
        for await _ in c.paragraphResults(in: ch, startingAt: ch.first) {
            seen += 1
            if seen == 1 { withUnsafeCurrentTask { $0?.cancel() } }
        }
        return seen
    }
    let seen = await consumer.value
    #expect(seen >= 1)
    #expect(seen < UnderlineCtrl.paragraphs(of: ch).count)
}

@Test func paragraphsHoldingMatchesTheWholeChapterForThoseParagraphs() async throws {
    let ch = try await littleWomen()
    let c = ctrl()
    let (all, allRecords) = await results(c, ch)
    let picked: Set<Int> = [23, 39, 54, 190]
    let paragraphs = Set(picked.compactMap { ch.sentence($0)?.paragraph })
    let (some, records) = await c.underlines(paragraphsHolding: picked, in: ch)
    #expect(Set(some.underlines) == Set(all.filter { paragraphs.contains($0.paragraph) }))
    let inThose = allRecords.filter { r in ch.sentence(r.sentence).map { paragraphs.contains($0.paragraph) } ?? false }
    let key = { (r: UnderlineRecord) in "\(r.sentence)|\(r.phrase)|\(r.kept)|\(r.dropped?.rawValue ?? "")|\(r.candidates)|\(r.pickedSentence ?? -1)" }
    #expect(records.map(key) == inThose.map(key))
}

@Test func onlyTheDroppedRecordIsMarkedWhenIdsRepeat() {
    let ref = AnswerPassage(sentence: 0, paragraph: 0, range: NSRange(location: 0, length: 1), text: "r")
    func pair(_ length: Int, _ score: Double, _ phrase: String) -> (KeptUnderline, UnderlineRecord) {
        let u = Underline(sentence: 1, paragraph: 0, range: NSRange(location: 0, length: length), text: phrase, kind: .action, role: nil,
                          reference: ref, decidedBy: .rules)
        var r = UnderlineRecord(chapterIndex: 0, sentence: 1, phrase: phrase, kind: .action, embedding: .none,
                                phraseRange: NSRange(location: 0, length: length))
        r.candidates = [0]
        r.pickedSentence = 0
        r.kept = true
        return (KeptUnderline(underline: u, score: score), r)
    }
    let (a, ra) = pair(2, 0.9, "Jo"), (b, rb) = pair(20, 0.5, "Jo's going to the war")
    var records = [ra, rb]
    let shown = UnderlineCtrl.limit([(a, 0), (b, 1)], records: &records, maxPerParagraph: 5)
    #expect(shown.map(\.0.text) == ["Jo"])
    #expect(shown.map(\.1.phrase) == ["Jo"])
    #expect(records[0].kept && records[0].dropped == nil)
    #expect(!records[1].kept && records[1].dropped == .densityLimit)
}

@Test func noRecordInTheWholeChapterUsesALaterSentence() async throws {
    let ch = try await littleWomen()
    let (_, records) = await results(ctrl(), ch)
    #expect(records.count > 100)
    for r in records {
        #expect(r.candidates.allSatisfy { $0 < r.sentence }, "S\(r.sentence) \(r.phrase): candidates")
        #expect(r.pickedSentence.map { $0 < r.sentence } ?? true)
    }
}
