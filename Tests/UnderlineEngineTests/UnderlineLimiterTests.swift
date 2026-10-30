import Foundation
import Testing
@testable import UnderlineEngine

private func kept(_ sentence: Int, paragraph: Int, at location: Int, length: Int = 5, score: Double, kind: UnderlineKind = .action) -> KeptUnderline {
    let ref = AnswerPassage(sentence: 0, paragraph: 0, range: NSRange(location: 0, length: 1), text: "r")
    let u = Underline(sentence: sentence, paragraph: paragraph, range: NSRange(location: location, length: length), text: "x",
                      kind: kind, role: nil, reference: ref, decidedBy: .model)
    return KeptUnderline(underline: u, score: score)
}

@Test func keepsTheBestPerParagraphUpToTheLimit() {
    let input = [kept(1, paragraph: 0, at: 0, score: 0.9), kept(2, paragraph: 0, at: 30, score: 0.5), kept(3, paragraph: 0, at: 60, score: 0.7)]
    let r = UnderlineLimiter.apply(input, maxPerParagraph: 2)
    #expect(r.kept.map(\.underline.sentence) == [1, 3])
    #expect(r.dropped == [1])
}

@Test func overlappingPhrasesKeepOnlyTheHigherScore() {
    let input = [kept(1, paragraph: 0, at: 0, length: 10, score: 0.4), kept(1, paragraph: 0, at: 5, length: 10, score: 0.8)]
    let r = UnderlineLimiter.apply(input, maxPerParagraph: 5)
    #expect(r.kept.map(\.underline.id) == ["1:5"])
    #expect(r.dropped == [0])
}

@Test func differentParagraphsDoNotCompete() {
    let input = [kept(1, paragraph: 0, at: 0, score: 0.9), kept(5, paragraph: 1, at: 0, score: 0.1)]
    #expect(UnderlineLimiter.apply(input, maxPerParagraph: 1).kept.count == 2)
}

@Test func resultDoesNotDependOnInputOrder() {
    let input = [kept(1, paragraph: 0, at: 0, score: 0.9), kept(2, paragraph: 0, at: 30, score: 0.5), kept(3, paragraph: 0, at: 60, score: 0.7),
                 kept(3, paragraph: 0, at: 62, score: 0.6), kept(7, paragraph: 2, at: 0, score: 0.3)]
    let expected = UnderlineLimiter.apply(input, maxPerParagraph: 2)
    for order in [[4, 3, 2, 1, 0], [2, 0, 4, 1, 3], [1, 3, 0, 4, 2]] {
        let r = UnderlineLimiter.apply(order.map { input[$0] }, maxPerParagraph: 2)
        #expect(r.kept.map(\.underline.id) == expected.kept.map(\.underline.id))
        #expect(Set(r.dropped.map { order[$0] }) == Set(expected.dropped))
    }
}

@Test func tieOnScoreKeepsTheEarlierSentence() {
    let input = [kept(4, paragraph: 0, at: 0, score: 0.5), kept(2, paragraph: 0, at: 0, score: 0.5)]
    #expect(UnderlineLimiter.apply(input, maxPerParagraph: 1).kept.map(\.underline.sentence) == [2])
}

@Test func droppedAreInputPositionsEvenWhenIdsRepeat() {
    // A name and an event can start at the same place in one sentence: same id, different lengths.
    let input = [kept(1, paragraph: 0, at: 0, length: 2, score: 0.9, kind: .person), kept(1, paragraph: 0, at: 0, length: 20, score: 0.5)]
    let r = UnderlineLimiter.apply(input, maxPerParagraph: 5)
    #expect(r.kept.map(\.underline.range.length) == [2])
    #expect(r.dropped == [1])
}
