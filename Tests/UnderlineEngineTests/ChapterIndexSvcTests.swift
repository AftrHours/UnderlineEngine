import Foundation
import Testing
@testable import UnderlineEngine

@Test func tokenRangesRoundTripWithCurlyQuotesAndEmoji() {
    let s = ChapterIndexSvc().index(ChapterInput(chapterIndex: 0, plainText: "\u{201C}Don\u{2019}t,\u{201D} said Jo 😀 and laughed\u{2014}loudly."))[0]
    #expect(!s.tokens.isEmpty)
    for t in s.tokens { #expect((s.text as NSString).substring(with: t.range) == t.text) }
}

@Test func tagsLemmasAndPersonNames() {
    let input = ChapterInput(chapterIndex: 0, plainText: "Jo said sadly, \"We haven't got Father.\"")
    let s = ChapterIndexSvc().index(input)[0]
    #expect(s.names.contains { $0.text == "Jo" && $0.kind == .person })
    #expect(s.tokens.contains { $0.lemma == "say" })
}

@Test func fallbackFindsCapitalisedNamesNotAtSentenceStart() {
    let s = ChapterIndexSvc(forceFallback: true).index(ChapterInput(chapterIndex: 0, plainText: "Then Meg spoke to Beth."))[0]
    #expect(s.names.map(\.text) == ["Meg", "Beth"])
}
