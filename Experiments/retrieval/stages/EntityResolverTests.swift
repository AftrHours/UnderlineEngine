import Foundation
import Testing
@testable import UnderlineEngine

private func sentences(_ text: String) -> [IndexedSentence] {
    ChapterIndexSvc().index(ChapterInput(chapterIndex: 0, plainText: text))
}

/// Names as the tagger would find them, so the tests don't depend on NaturalLanguage's models.
private func sentence(_ index: Int, _ text: String, names: [String]) -> IndexedSentence {
    let base = sentences(text)[0]
    let mentions = names.map { NameMention(text: $0, range: (text as NSString).range(of: $0), kind: .person) }
    return IndexedSentence(index: index, paragraph: index, range: base.range, text: text, tokens: base.tokens, names: mentions)
}

@Test func fullNameJoinsTheFirstNameAndTitledNamesStayApart() {
    let chapter = [
        sentence(0, "Jo grumbled on the rug.", names: ["Jo"]),
        sentence(1, "Jo sat up.", names: ["Jo"]),
        sentence(2, "Jo laughed.", names: ["Jo"]),
        sentence(3, "Jo March was fifteen.", names: ["Jo March"]),
        sentence(4, "Mrs. March came in.", names: ["Mrs. March"])
    ]
    let book = EntityResolver.book([chapter])
    #expect(book.entityOf["jo march"] == "jo")
    #expect(book.entityOf["mrs march"] == "mrs march")
    #expect(book.gender["mrs march"] == .female)
}

@Test func genderComesFromThePronounsAfterTheName() {
    let chapter = [
        sentence(0, "Laurie bowed and he smiled.", names: ["Laurie"]),
        sentence(1, "He was shy.", names: []),
        sentence(2, "Laurie came back; his hat was wet.", names: ["Laurie"]),
        sentence(3, "Beth sighed and she sat down.", names: ["Beth"]),
        sentence(4, "She was tired, and her hands were cold.", names: []),
    ]
    let book = EntityResolver.book([chapter])
    #expect(book.gender["laurie"] == .male)
    #expect(book.gender["beth"] == .female)
}

@Test func pronounsResolveToTheLastPersonOfThatGender() {
    let book = EntityBook(entityOf: ["jo": "jo", "laurie": "laurie"], gender: ["jo": .female, "laurie": .male])
    let chapter = [
        sentence(0, "Jo met Laurie at the gate.", names: ["Jo", "Laurie"]),
        sentence(1, "She gave him the letter.", names: []),
        sentence(2, "It rained.", names: [])
    ]
    let mentions = EntityResolver.mentions(in: chapter, book: book)
    #expect(mentions[1]?.map(\.entity) == ["jo", "laurie"])
    #expect(mentions[1]?.allSatisfy(\.isPronoun) == true)
    #expect(mentions[2] == nil)
}

@Test func pronounsDoNotReachTooFarBack() {
    let book = EntityBook(entityOf: ["jo": "jo"], gender: ["jo": .female])
    var chapter = [sentence(0, "Jo left.", names: ["Jo"])]
    for i in 1...EntityKnobs.pronounReach { chapter.append(sentence(i, "It rained.", names: [])) }
    chapter.append(sentence(EntityKnobs.pronounReach + 1, "She came back.", names: []))
    #expect(EntityResolver.mentions(in: chapter, book: book)[EntityKnobs.pronounReach + 1] == nil)
}
