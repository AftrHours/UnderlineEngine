import Foundation
import Testing
@testable import UnderlineEngine

private func littleWomen() async throws -> IndexedChapter {
    let text = try String(contentsOf: datasetURL("little-women-ch1.txt"), encoding: .utf8)
    return await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: text), embedding: EmbeddingSvcUnavailable())
}

private func autoAccepting() -> FakeUnderlineModel {
    let fake = FakeUnderlineModel()
    fake.autoAccept = true
    return fake
}

private func collect(_ stream: AsyncStream<(Underline, UnderlineRecord)>) async -> [Underline] {
    var out: [Underline] = []
    for await (u, _) in stream { out.append(u) }
    return out
}

@Test func streamSetEqualsAllUnderlines() async throws {
    let ch = try await littleWomen()
    let c = ctrl(autoAccepting())
    let (all, _) = await c.allUnderlines(in: ch)
    #expect(!all.underlines.isEmpty)
    for start in [ch.first, ch.sentences[100].index, 99_999] {
        let streamed = await collect(c.underlines(in: ch, startingAt: start))
        #expect(Set(streamed) == Set(all.underlines))
        #expect(streamed.count == all.underlines.count)
    }
}

@Test func paragraphResultsMatchAllUnderlines() async throws {
    let ch = try await littleWomen()
    let c = ctrl(autoAccepting())
    let (all, records) = await c.allUnderlines(in: ch)
    for start in [ch.first, ch.sentences[100].index] {
        var underlines: [Underline] = []
        var seen: [UnderlineRecord] = []
        for await result in c.paragraphResults(in: ch, startingAt: start) {
            underlines += result.underlines
            seen += result.records
        }
        #expect(Set(underlines) == Set(all.underlines))
        // Timings differ between runs, so compare what was decided.
        func decisions(_ records: [UnderlineRecord]) -> [String] {
            records.map { "\($0.sentence) \($0.phrase) \($0.kept) \(String(describing: $0.dropped))" }.sorted()
        }
        #expect(decisions(seen) == decisions(records))
    }
}

@Test func streamStartsAtTheReadersParagraphThenWraps() async throws {
    let ch = try await littleWomen()
    let start = ch.sentences[100]
    let paragraphs = await collect(ctrl(autoAccepting()).underlines(in: ch, startingAt: start.index)).map(\.paragraph)
    let firstWrap = paragraphs.firstIndex { $0 < start.paragraph } ?? paragraphs.count
    #expect(paragraphs.prefix(firstWrap).allSatisfy { $0 >= start.paragraph })
    #expect(paragraphs.suffix(from: firstWrap).allSatisfy { $0 < start.paragraph })
    #expect(Array(paragraphs.prefix(firstWrap)) == paragraphs.prefix(firstWrap).sorted())
}

@Test func limitIsPerParagraph() async throws {
    let ch = try await littleWomen()
    let (all, _) = await ctrl(autoAccepting()).allUnderlines(in: ch)
    let perParagraph = Dictionary(grouping: all.underlines, by: \.paragraph).mapValues(\.count)
    #expect(perParagraph.values.allSatisfy { $0 <= UnderlineKnobs.maxPerParagraph })
}

@Test func densityDropsAppearInRecords() async throws {
    let ch = try await littleWomen()
    let (all, records) = await ctrl(autoAccepting()).allUnderlines(in: ch)
    let limited = records.filter { $0.dropped == .densityLimit }
    #expect(!limited.isEmpty)
    #expect(limited.allSatisfy { !$0.kept })
    #expect(records.filter(\.kept).count == all.underlines.count)
}

@Test func emptyChapterFinishesImmediately() async {
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, paragraphs: [], sentences: []), embedding: EmbeddingSvcUnavailable())
    let c = ctrl(autoAccepting())
    #expect(await collect(c.underlines(in: ch, startingAt: 0)).isEmpty)
    #expect(await c.allUnderlines(in: ch).0.underlines.isEmpty)
}

@Test func chapterWithNoEventsYieldsNothing() async {
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: "Oh. Ah. Hm."), embedding: EmbeddingSvcUnavailable())
    let fake = autoAccepting()
    #expect(await collect(ctrl(fake).underlines(in: ch, startingAt: 0)).isEmpty)
    #expect(fake.calls.isEmpty)
}

@Test func oneSentenceChapterMakesNoModelCall() async {
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: "Jo immediately sat up and began to whistle."),
                                             embedding: EmbeddingSvcUnavailable())
    let fake = autoAccepting()
    #expect(await ctrl(fake).allUnderlines(in: ch).0.underlines.isEmpty)
    #expect(fake.calls.isEmpty)
}

@Test(.timeLimit(.minutes(1))) func cancellationStopsTheStream() async throws {
    let ch = try await littleWomen()
    let fake = autoAccepting()
    let c = ctrl(fake)
    let consumer = Task {
        var seen = 0
        for await _ in c.underlines(in: ch, startingAt: ch.first) {
            seen += 1
            if seen == 1 { withUnsafeCurrentTask { $0?.cancel() } }
        }
        return seen
    }
    let seen = await consumer.value
    #expect(seen >= 1)
    // The phrase in flight when the cancel lands still finishes its pick and confirm, then nothing more starts.
    try await Task.sleep(for: .milliseconds(200))
    let afterCancel = fake.calls.count
    try await Task.sleep(for: .milliseconds(200))
    #expect(fake.calls.count == afterCancel)
    let (all, _) = await c.allUnderlines(in: ch)
    #expect(seen < all.underlines.count)
}

@Test func paragraphsHoldingMatchesTheWholeChapterForThoseParagraphs() async throws {
    let ch = try await littleWomen()
    let c = ctrl(autoAccepting())
    let (all, allRecords) = await c.allUnderlines(in: ch)
    let picked: Set<Int> = [23, 39, 54, 190]
    let paragraphs = Set(picked.compactMap { ch.sentence($0)?.paragraph })
    let (some, records) = await c.underlines(paragraphsHolding: picked, in: ch)
    #expect(Set(some.underlines) == Set(all.underlines.filter { paragraphs.contains($0.paragraph) }))
    let inThose = allRecords.filter { r in ch.sentence(r.sentence).map { paragraphs.contains($0.paragraph) } ?? false }
    let key = { (r: UnderlineRecord) in "\(r.sentence)|\(r.phrase)|\(r.kept)|\(r.dropped?.rawValue ?? "")|\(r.candidates)|\(r.pickedSentence ?? -1)" }
    #expect(records.map(key) == inThose.map(key))
}

@Test func onlyTheDroppedRecordIsMarkedWhenIdsRepeat() {
    let ref = AnswerPassage(sentence: 0, paragraph: 0, range: NSRange(location: 0, length: 1), text: "r")
    func pair(_ length: Int, _ score: Double, _ phrase: String) -> (KeptUnderline, UnderlineRecord) {
        let u = Underline(sentence: 1, paragraph: 0, range: NSRange(location: 0, length: length), text: phrase, kind: .action, role: nil,
                          reference: ref, decidedBy: .model)
        let r = UnderlineRecord(chapterIndex: 0, sentence: 1, phrase: phrase, kind: .action, path: .model, promptVariant: .baseline,
                                searchModeUsed: .words, embedding: .none, candidates: [0], promptSentences: [1, 0], pickedSentence: 0, quote: "r",
                                confirm: nil, kept: true, dropped: nil, times: StepTimes(), phraseRange: NSRange(location: 0, length: length))
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
    let (_, records) = await ctrl(autoAccepting()).allUnderlines(in: ch)
    #expect(records.count > 100)
    for r in records {
        #expect(r.candidates.allSatisfy { $0 < r.sentence }, "S\(r.sentence) \(r.phrase): candidates")
        #expect(r.promptSentences.allSatisfy { $0 <= r.sentence }, "S\(r.sentence) \(r.phrase): prompts")
        #expect(r.pickedSentence.map { $0 < r.sentence } ?? true)
    }
}
