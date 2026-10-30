import Foundation
import Testing
@testable import UnderlineEngine

private func candidate(_ sentence: Int) -> Candidate {
    Candidate(sentence: sentence, rawMeaning: 0, rawWords: 0, meaning: 0, words: 0, bonus: 0, score: 0, rawScore: 0)
}

private func chapter() async -> IndexedChapter {
    await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: "Jo said \"hello\" to Meg. Meg smiled. Jo began to whistle."),
                                    embedding: EmbeddingSvcUnavailable())
}

@Test func pickZeroIsNone() async {
    #expect(UnderlineGuard.checkPick(pick: 0, quote: "", sent: [candidate(0)], chapter: await chapter(), sentence: 2) == .none)
}

@Test func pickOutOfRangeIsRejected() async {
    #expect(UnderlineGuard.checkPick(pick: 2, quote: "Meg smiled", sent: [candidate(1)], chapter: await chapter(), sentence: 2)
            == .rejected(.outOfRange))
}

@Test func pickAtOrAfterTheSentenceIsRejected() async {
    let ch = await chapter()
    #expect(UnderlineGuard.checkPick(pick: 1, quote: "Jo began", sent: [candidate(2)], chapter: ch, sentence: 2) == .rejected(.notEarlier))
    #expect(UnderlineGuard.checkPick(pick: 1, quote: "Meg smiled", sent: [candidate(1)], chapter: ch, sentence: 1) == .rejected(.notEarlier))
}

@Test func quoteMustComeFromThePick() async {
    let ch = await chapter()
    #expect(UnderlineGuard.checkPick(pick: 1, quote: "Amy laughed", sent: [candidate(1)], chapter: ch, sentence: 2) == .rejected(.quoteNotInPick))
    #expect(UnderlineGuard.checkPick(pick: 1, quote: "", sent: [candidate(1)], chapter: ch, sentence: 2) == .rejected(.quoteNotInPick))
}

@Test func curlyQuoteMatchesStraightQuote() async {
    let ch = await chapter()
    #expect(UnderlineGuard.checkPick(pick: 1, quote: "said \u{201C}hello\u{201D}", sent: [candidate(0)], chapter: ch, sentence: 2) == .accepted(0))
}

@Test func paragraphRangeUsesTheEventsOwnOccurrence() {
    let text = "She ran home, and then she ran home again."
    let second = (text as NSString).range(of: "ran home", options: .backwards)
    let sentence = IndexedSentence(index: 4, paragraph: 1, range: NSRange(location: 10, length: (text as NSString).length),
                                   text: text, tokens: [], names: [])
    let phrase = EventPhrase(text: "ran home", range: second, role: .attempt, track: .goal)
    #expect(UnderlineGuard.paragraphRange(of: phrase, in: sentence) == NSRange(location: 10 + second.location, length: second.length))
}

@Test func paragraphRangeIsNilWhenTextDoesNotMatchItsRange() {
    let text = "She ran home."
    let sentence = IndexedSentence(index: 0, paragraph: 0, range: NSRange(location: 0, length: 13), text: text, tokens: [], names: [])
    let phrase = EventPhrase(text: "walked home", range: NSRange(location: 4, length: 8), role: .attempt, track: .goal)
    #expect(UnderlineGuard.paragraphRange(of: phrase, in: sentence) == nil)
    let past = EventPhrase(text: "home", range: NSRange(location: 20, length: 4), role: .attempt, track: .goal)
    #expect(UnderlineGuard.paragraphRange(of: past, in: sentence) == nil)
}

@Test func quoteEndingInTheCutMarkerMatches() async {
    let ch = await chapter()
    #expect(UnderlineGuard.checkPick(pick: 1, quote: "Meg smiled \u{2026}", sent: [candidate(1)], chapter: ch, sentence: 2) == .accepted(1))
    #expect(UnderlineGuard.checkPick(pick: 1, quote: "\u{2026} Meg smiled...", sent: [candidate(1)], chapter: ch, sentence: 2) == .accepted(1))
}
