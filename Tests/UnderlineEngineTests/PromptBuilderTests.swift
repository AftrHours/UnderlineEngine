import Foundation
import Testing
@testable import UnderlineEngine

private let underlined = IndexedText(index: 9, text: "Jo immediately sat up and began to whistle.")
private let candidates = [IndexedText(index: 3, text: "Meg spoke of money."), IndexedText(index: 7, text: "\"Jo does use such slang words!\" observed Amy.")]

@Test(arguments: PromptVariant.allCases)
func pickPromptHoldsExactlyTheGivenSentences(variant: PromptVariant) {
    let p = PromptBuilder.pick(phrase: "began to whistle", roleHint: "an action", sentence: underlined, candidates: candidates, variant: variant)
    #expect(p.sentenceIndexes == [9, 3, 7])
    #expect(p.prompt.contains(underlined.text))
    #expect(candidates.allSatisfy { p.prompt.contains($0.text) })
    #expect(p.prompt.contains("1. Meg spoke of money."))
    #expect(p.prompt.contains("2. "))
    #expect(!p.prompt.contains("3. "))
    #expect(p.prompt.contains("began to whistle"))
}

@Test func candidateTextIsCutTo40Words() {
    let long = (1...60).map(String.init).joined(separator: " ")
    let p = PromptBuilder.pick(phrase: "x y", roleHint: nil, sentence: underlined, candidates: [IndexedText(index: 1, text: long)], variant: .baseline)
    #expect(PromptBuilder.cut(long).split(separator: " ").count == 41)   // 40 words + "…"
    #expect(p.prompt.contains(PromptBuilder.cut(long)))
    #expect(!p.prompt.contains(" 41 "))
}

@Test(arguments: PromptVariant.allCases)
func confirmPromptHoldsOnlyThePhraseSentenceAndOnePassage(variant: PromptVariant) {
    let p = PromptBuilder.confirm(phrase: "began to whistle", sentence: underlined, passage: candidates[1], variant: variant)
    #expect(p.sentenceIndexes == [9, 7])
    #expect(p.prompt.contains(candidates[1].text))
    #expect(!p.prompt.contains(candidates[0].text))
    #expect(p.prompt.contains("began to whistle"))
}

@Test func instructionsDifferBetweenVariants() {
    let picks = Set(PromptVariant.allCases.map { PromptBuilder.pick(phrase: "a b", roleHint: nil, sentence: underlined, candidates: candidates, variant: $0).instructions })
    let confirms = Set(PromptVariant.allCases.map { PromptBuilder.confirm(phrase: "a b", sentence: underlined, passage: candidates[0], variant: $0).instructions })
    #expect(picks.count == PromptVariant.allCases.count)
    #expect(confirms.count == PromptVariant.allCases.count)
}

@Test func roleHintsInPlainWords() {
    #expect(PromptBuilder.roleHint(.reaction) == "a reaction: look for what it reacts to")
    #expect(PromptBuilder.roleHint(nil) == nil)
}
