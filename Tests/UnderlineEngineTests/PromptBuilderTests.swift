import Foundation
import Testing
@testable import UnderlineEngine

private let underlined = IndexedText(index: 9, text: "Jo immediately sat up and began to whistle.")
private let candidates = [IndexedText(index: 3, text: "Meg spoke of money."), IndexedText(index: 7, text: "\"Jo does use such slang words!\" observed Amy.")]

@Test func candidateTextIsCutTo40Words() {
    let long = (1...60).map(String.init).joined(separator: " ")
    let p = PromptBuilder.confirm(phrase: "x y", sentence: underlined, passage: IndexedText(index: 1, text: long))
    #expect(PromptBuilder.cut(long).split(separator: " ").count == 41)   // 40 words + "…"
    #expect(p.prompt.contains(PromptBuilder.cut(long)))
    #expect(!p.prompt.contains(" 41 "))
}

@Test
func confirmPromptHoldsOnlyThePhraseSentenceAndOnePassage() {
    let p = PromptBuilder.confirm(phrase: "began to whistle", sentence: underlined, passage: candidates[1])
    #expect(p.sentenceIndexes == [9, 7])
    #expect(p.prompt.contains(candidates[1].text))
    #expect(!p.prompt.contains(candidates[0].text))
    #expect(p.prompt.contains("began to whistle"))
}
