import Foundation
import Testing
@testable import UnderlineEngine

private func candidate(_ sentence: Int, raw: Double) -> Candidate {
    Candidate(sentence: sentence, rawMeaning: 0, rawWords: raw, meaning: 0, words: 0, bonus: 0, score: raw, rawScore: raw)
}

@Test func decideNeedsAClearlyGoodTopThatIsClearlyAhead() {
    #expect(RulesPicker.decide([], mode: .words) == nil)
    #expect(RulesPicker.decide([candidate(3, raw: 0.40)], mode: .words) == nil)
    #expect(RulesPicker.decide([candidate(3, raw: 0.60), candidate(2, raw: 0.50)], mode: .words) == nil)
    #expect(RulesPicker.decide([candidate(3, raw: 0.80), candidate(2, raw: 0.40)], mode: .words) == 3)
}

private func phrase(_ text: String, in s: IndexedSentence) -> EventPhrase {
    s.events.first { $0.text == text } ?? EventPhrase(text: text, range: (s.text as NSString).range(of: text), role: nil, track: .character)
}

@Test func confirmAcceptsASharedContentWord() {
    let s = indexed("Jo immediately sat up, put her hands in her pockets, and began to whistle.")
    let ref = indexed("Amy hated it when Jo would whistle at dinner.")
    #expect(RulesPicker.confirm(phrase: phrase("began to whistle", in: s), in: s, reference: ref))
}

@Test func confirmAcceptsTheSameName() {
    let s = indexed("Then Hannah came in with the tea.")
    let ref = indexed("Old Hannah had lived with the family for years.")
    #expect(RulesPicker.confirm(phrase: phrase("Hannah", in: s), in: s, reference: ref))
}

@Test func confirmRejectsATopicallyCloseSentenceWithNothingShared() {
    let s = indexed("Jo immediately sat up, put her hands in her pockets, and began to whistle.")
    let ref = indexed("The parlor was cold and quiet.")
    #expect(!RulesPicker.confirm(phrase: phrase("began to whistle", in: s), in: s, reference: ref))
}
