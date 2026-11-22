import Foundation
import Testing
@testable import UnderlineEngine
@testable import UnderlineKit

/// The book run numbers each chapter's sentences from 0 so the labels in `Dataset/labels/` keep matching; the app numbers them
/// across the whole book. This checks that the numbering changes no decision: the same chapter, numbered from 0 or from 5,000,
/// gives the same phrases pointing at the same passages.
@available(macOS 27, *)
@Test func sentenceNumberingDoesNotChangeTheUnderlines() async throws {
    let text = try String(contentsOf: Evals.root.appendingPathComponent("Dataset/little-women/ch01.txt"), encoding: .utf8)
    func underlines(firstParagraph: Int, firstSentence: Int) async -> [String] {
        let input = ChapterInput(chapterIndex: 0, plainText: text, firstParagraph: firstParagraph, firstSentence: firstSentence)
        let source = BookText(id: "numbering-\(firstSentence)", chapters: [BookRunSource.chapterText(input)])
        let method = await Linker.make(embedding: .automatic)
        let chapter = await method.prepare(Underliner.input(0, of: source), ofBook: source.id) { [Underliner.input(0, of: source)] }
        var found: [String] = []
        for await paragraph in method.results(in: chapter, startingAt: chapter.first) {
            found += paragraph.underlines.map { "\($0.text) → \($0.reference.text)" }
        }
        return found.sorted()
    }
    let local = await underlines(firstParagraph: 0, firstSentence: 0)
    let global = await underlines(firstParagraph: 300, firstSentence: 5_000)
    #expect(!local.isEmpty)
    #expect(local == global)
}
