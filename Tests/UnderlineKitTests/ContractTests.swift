import Foundation
import Testing
@testable import UnderlineEngine
@testable import UnderlineKit

/// What every `LinkMethod` promises, checked through the public door (`Underliner`). A new method is not done until it passes this.
private func assertContract(_ method: any LinkMethod, sourceLocation: SourceLocation = #_sourceLocation) async throws {
    let one = try String(contentsOf: datasetURL("little-women-ch1.txt"), encoding: .utf8)
    let two = "Jo found a silver locket in the attic. Meg sewed by the window all morning.\n\nThe silver locket was gone by evening. Amy cried because the silver locket was gone."
    let book = makeBook(chapters: [one, two, ""])
    let underliner = Underliner(method: method)
    let paragraphs = Dictionary(uniqueKeysWithValues: (0..<book.chapterCount).flatMap { book.chapterText($0).paragraphs }.map { ($0.index, $0.text) })
    let sentences = Dictionary(uniqueKeysWithValues: (0..<book.chapterCount).flatMap { book.chapterText($0).sentences }.map { ($0.index, $0) })

    for chapter in 0..<book.chapterCount {
        let batches = await collect(underliner, chapter: chapter, of: book)
        let results = batches.flatMap(\.underlines)

        // The read boundary: a reference is always an earlier sentence, in this chapter.
        let mine = Set(book.chapterText(chapter).sentences.map(\.index))
        for r in results {
            #expect(r.reference.sentence < r.sentence, "reference after the phrase: \(r.id)", sourceLocation: sourceLocation)
            #expect(mine.contains(r.sentence) && mine.contains(r.reference.sentence), sourceLocation: sourceLocation)
            // The text is the text at the range, in the right paragraph, for the phrase and for the passage.
            let text = paragraphs[r.paragraph].map { $0 as NSString }
            #expect(text != nil && NSMaxRange(r.range) <= text!.length && text!.substring(with: r.range) == r.text,
                    "phrase text is not at its range: \(r.id)", sourceLocation: sourceLocation)
            let passage = paragraphs[r.reference.paragraph].map { $0 as NSString }
            #expect(passage != nil && NSMaxRange(r.reference.range) <= passage!.length
                    && passage!.substring(with: r.reference.range) == r.reference.text,
                    "passage text is not at its range: \(r.id)", sourceLocation: sourceLocation)
            #expect(sentences[r.sentence]?.paragraph == r.paragraph, sourceLocation: sourceLocation)
            #expect(["action", "reaction", "feeling", "outcome", "place", "thing", "person"].contains(r.kind), sourceLocation: sourceLocation)
            #expect(["model", "rules"].contains(r.decidedBy), sourceLocation: sourceLocation)
        }
        // No id twice.
        #expect(Set(results.map(\.id)).count == results.count, "an id repeats in chapter \(chapter)", sourceLocation: sourceLocation)
        // A chapter with nothing in it gives nothing, and ends.
        if book.chapterText(chapter).sentences.isEmpty { #expect(results.isEmpty, sourceLocation: sourceLocation) }
        // The same input gives the same output.
        let again = await collect(underliner, chapter: chapter, of: book).flatMap(\.underlines)
        #expect(again == results, "chapter \(chapter) differs between two runs", sourceLocation: sourceLocation)
    }
    // The reader's paragraph first: from the one holding `sentence` to the chapter's end, then the ones before it.
    let chapterOne = book.chapterText(0)
    let from = chapterOne.sentences[chapterOne.sentences.count / 2]
    var passedStart = false
    for r in await collect(underliner, chapter: 0, of: book, from: from.index).flatMap(\.underlines) {
        if r.paragraph < from.paragraph { passedStart = true }
        #expect(!(passedStart && r.paragraph >= from.paragraph), "results do not start at the reader's paragraph", sourceLocation: sourceLocation)
    }
    #expect(underliner.version == method.version, sourceLocation: sourceLocation)
    #expect(underliner.summary == method.summary, sourceLocation: sourceLocation)
}

@Test func r8KeepsTheContract() async throws {
    try await assertContract(await Linker.make(embedding: .automatic))
}

@Test func aSecondMethodKeepsTheSameContractWithoutAnyOtherCodeChanging() async throws {
    try await assertContract(PreviousSentenceLinker())
    let book = makeBook(chapters: ["Jo found a silver locket in the attic. Meg sewed by the window all morning. Amy cried at night."])
    let batches = await collect(Underliner(method: PreviousSentenceLinker()), chapter: 0, of: book)
    #expect(batches.flatMap(\.underlines).count == 2)
}

@Test func releasePresetIsR8AndTestingPresetNeedsNoDownload() async {
    let testing = await Underliner.make(.testing)
    #expect(testing.version == Linker.version)
    #expect(Underliner.releaseVersion == testing.version)
    #expect(testing.summary.hasPrefix("Rules only"))
}

@Test func theConsumerCanStopEarlyWithoutHanging() async {
    let book = makeBook(chapters: [String(repeating: "Jo found a silver locket in the attic. Meg sewed by the window all morning.\n\n", count: 40)])
    var seen = 0
    for await _ in Underliner(method: PreviousSentenceLinker()).underlines(inChapter: 0, of: book, startingAt: 0) {
        seen += 1
        if seen == 3 { break }
    }
    #expect(seen == 3)
}

@Test func stubUnderlinerNeedsNoEngine() async {
    let stub = StubUnderliner(version: 7, summary: "Stub") { chapter in
        [UnderlineBatch(underlines: [], considered: [ConsideredPhrase(sentence: chapter, phrase: "x", detail: "d", isUnderlined: false)])]
    }
    let batches = await collect(stub, chapter: 3, of: makeBook(chapters: ["a."]))
    #expect(batches.count == 1 && batches[0].considered[0].sentence == 3)
    #expect(stub.version == 7)
}
