import Foundation
import Testing
@testable import UnderlineEngine

// Indexes must equal what iRead's EPUBParseSvc produces (spec §6.1).
@Test func littleWomenChapterOneMatchesIRead() throws {
    let text = try String(contentsOf: datasetURL("little-women-ch1.txt"), encoding: .utf8)
    let input = ChapterInput(chapterIndex: 0, plainText: text)
    let s = input.sentences.map { (input.paragraphs[$0.paragraph].text as NSString).substring(with: $0.range) }
    #expect(input.paragraphs.count == 94)
    #expect(input.sentences.count == 227)
    #expect(s[0].hasPrefix("\"Christmas won't be Christmas"))
    #expect(s[1] == "\"It's so dreadful to be poor!\"")       // iRead's tokenizer splits here
    #expect(s[2] == "sighed Meg, looking down at her old dress.")
    #expect(s[23].hasPrefix("And Beth looked at her rough hands"))
    #expect(s[32] == "said Meg, who could remember better times.")
    #expect(s[39] == "Jo immediately sat up, put her hands in her pockets, and began to whistle.")
    #expect(input.sentences[39].paragraph == 20)
}

@Test func noBreakSpaceAfterTitleDoesNotSplitAndRangesAreUTF16() {
    let p = "Mr.\u{00A0}Laurence smiled \u{201C}warmly\u{201D}\u{2014}then left. 😀 Done."
    let r = SentenceSplitter.ranges(in: p)
    #expect(r.count == 2)
    #expect((p as NSString).substring(with: r[0]).hasPrefix("Mr.\u{00A0}Laurence"))
    #expect((p as NSString).substring(with: r[1]) == "😀 Done.")
}

@Test func globalOffsetsAreApplied() {
    let input = ChapterInput(chapterIndex: 3, plainText: "A b.\n\nC d. E f.", firstParagraph: 40, firstSentence: 900)
    #expect(input.paragraphs.map(\.index) == [40, 41])
    #expect(input.sentences.map(\.index) == [900, 901, 902])
    #expect(input.sentences.map(\.paragraph) == [40, 41, 41])
}
