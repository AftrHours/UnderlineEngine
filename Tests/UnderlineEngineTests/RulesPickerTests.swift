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

private func stats(_ filler: String, with extra: [IndexedSentence]) -> WordStats {
    WordStats(sentences: (0..<300).map { _ in indexed(filler) } + extra)
}

@Test func confirmAcceptsARareSharedNoun() {
    let s = indexed("Jo said she would whistle a tune on the porch.")
    let ref = indexed("Amy sat alone on the porch.")
    #expect(RulesPicker.confirm(phrase: phrase("would whistle a tune on the porch", in: s), in: s, reference: ref,
                                stats: stats("The parlor was quiet.", with: [s, ref])))
    #expect(!RulesPicker.confirm(phrase: phrase("would whistle a tune on the porch", in: s), in: s, reference: ref,
                                 stats: stats("Everyone sat on the porch.", with: [s, ref])))
}

@Test func confirmRejectsARareVerbAlone() {
    let s = indexed("Jo said she came to amuse him.")
    let ref = indexed("The idea amused Meg greatly.")
    #expect(!RulesPicker.confirm(phrase: phrase("came to amuse him", in: s), in: s, reference: ref,
                                 stats: stats("The parlor was quiet.", with: [s, ref])))
}

@Test func confirmAcceptsTwoRareWordsEvenIfOneIsAVerb() {
    let s = indexed("Amy decided that virtue was its own reward.")
    let ref = indexed("She felt that virtue was not always rewarded, or its own reward.")
    #expect(RulesPicker.confirm(phrase: phrase("decided that virtue was its own reward", in: s), in: s, reference: ref,
                                stats: stats("The parlor was quiet.", with: [s, ref])))
}

@Test func confirmNeedsTheSameWordClass() {
    // NLTagger reads "a cold" as an adjective, so it can't tell that pair apart; a noun against a verb it can.
    let s = indexed("After dinner they took a long walk by the river.")
    let verb = indexed("Meg will walk to the river tomorrow.")
    let noun = indexed("Amy enjoyed her walk in the park.")
    #expect(!RulesPicker.confirm(phrase: phrase("took a long walk", in: s), in: s, reference: verb,
                                 stats: stats("The parlor was quiet.", with: [s, verb])))
    #expect(RulesPicker.confirm(phrase: phrase("took a long walk", in: s), in: s, reference: noun,
                                stats: stats("The parlor was quiet.", with: [s, noun])))
}

@Test func confirmNoLongerAcceptsARoleLinkAlone() {
    let s = indexed("Jo immediately sat up, put her hands in her pockets, and began to whistle.")
    let ref = indexed("Meg planned a quiet evening by the fire.")
    #expect(!RulesPicker.confirm(phrase: phrase("began to whistle", in: s), in: s, reference: ref, stats: WordStats(sentences: [s, ref])))
}
