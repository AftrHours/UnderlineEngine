import Foundation
import Testing
@testable import UnderlineEngine

private func candidate(_ sentence: Int, raw: Double, score: Double? = nil) -> Candidate {
    Candidate(sentence: sentence, rawWords: raw, words: raw, bonus: 0, score: score ?? raw)
}

@Test func evidenceOrderKeepsOnlyCandidatesThatShareAWord() {
    let order = RulesPicker.evidenceOrder([candidate(5, raw: 0.6), candidate(4, raw: 0), candidate(2, raw: 0.3)])
    #expect(order.map(\.sentence) == [5, 2])
}

@Test func evidenceOrderPutsTheNearerOfTwoCloseScoresFirst() {
    let order = RulesPicker.evidenceOrder([candidate(3, raw: 0.62), candidate(9, raw: 0.60), candidate(1, raw: 0.2)])
    #expect(order.map(\.sentence) == [9, 3, 1])
}

@Test func evidenceOrderLooksAtTheTopSixOnly() {
    let ranking = (0..<10).map { candidate(100 - $0, raw: 1 - Double($0) / 10) }
    #expect(RulesPicker.evidenceOrder(ranking).count == SearchKnobs.maxCandidates)
}

/// `count` sentences of one paragraph each; the first is `first`, the last is `last`, the rest are filler.
private func sentences(first: String, last: String, count: Int) -> (IndexedSentence, IndexedSentence) {
    let filler = (0..<(count - 2)).map { _ in "Nothing happened then." }
    let text = ([first] + filler + [last]).joined(separator: "\n\n")
    var all = ChapterIndexSvc().index(ChapterInput(chapterIndex: 0, plainText: text))
    for i in all.indices { all[i].events = EventSplitter.events(in: all[i]) }
    return (all[0], all[all.count - 1])
}

private func phrase(_ text: String, in s: IndexedSentence) -> EventPhrase {
    EventPhrase(text: text, range: (s.text as NSString).range(of: text), role: nil, track: .goal)
}

@Test func aSharedNounNearbyIsEnough() {
    let (ref, s) = sentences(first: "Beth found the silver thimble under the chair.", last: "Meg lost the silver thimble again.", count: 5)
    #expect(RulesPicker.evidencePoints(phrase: phrase("lost the silver thimble", in: s), in: s, reference: ref, stats: nil) { nil })
}

@Test func farBackOneSharedNounNeedsMoreEvidence() {
    let (ref, s) = sentences(first: "Beth sewed a thimble for her doll.", last: "Meg dropped the thimble on the floor.", count: 30)
    let p = phrase("dropped the thimble on the floor", in: s)
    #expect(!RulesPicker.evidencePoints(phrase: p, in: s, reference: ref, stats: nil) { nil })
    #expect(!RulesPicker.evidencePoints(phrase: p, in: s, reference: ref, stats: nil) { 0.1 })
    #expect(RulesPicker.evidencePoints(phrase: p, in: s, reference: ref, stats: nil) { 0.5 })
}

@Test func theSoftMatchIsOnlyAskedForWhenItDecides() {
    var asked = 0
    let (ref, s) = sentences(first: "Beth found the silver thimble under the chair.", last: "Meg lost the silver thimble again.", count: 5)
    _ = RulesPicker.evidencePoints(phrase: phrase("lost the silver thimble", in: s), in: s, reference: ref, stats: nil) { asked += 1; return nil }
    #expect(asked == 0)
    let (ref2, s2) = sentences(first: "The kitten slept by the fire.", last: "Jo laughed at the joke.", count: 5)
    _ = RulesPicker.evidencePoints(phrase: phrase("laughed at the joke", in: s2), in: s2, reference: ref2, stats: nil) { asked += 1; return nil }
    #expect(asked == 0)
}
