import Foundation
import Testing
@testable import UnderlineEngine

private let text = "Father had gone away to the war. Meg sewed by the fire. Beth played the old piano. Amy drew a small picture. Jo said she would face the war like Father."

private func chapter(firstSentence: Int = 0) async -> IndexedChapter {
    await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: text, firstSentence: firstSentence), embedding: EmbeddingSvcUnavailable())
}

private func item(_ expected: GoldExpected, phrase: String = "face the war like Father", index: Int = 4,
                  sentenceText: String = "Jo said she would face the war like Father.") -> GoldItem {
    GoldItem(id: "t", sentence: GoldRef(index: index, text: sentenceText), phrase: phrase, kind: .action, expected: expected, provisional: true, note: nil)
}

private func record(_ dropped: DropReason?, candidates: [Int] = [0], prompt: [Int] = [4, 0], phrase: String = "would face the war like Father") -> UnderlineRecord {
    UnderlineRecord(chapterIndex: 0, sentence: 4, phrase: phrase, kind: .action, path: .model, promptVariant: .baseline, searchModeUsed: .words,
                    embedding: .none, candidates: candidates, promptSentences: prompt, pickedSentence: nil, quote: nil, confirm: nil,
                    kept: dropped == nil, dropped: dropped, times: StepTimes())
}

private func underline(reference: Int, phrase: String = "would face the war like Father") -> ChapterUnderlines {
    let ref = AnswerPassage(sentence: reference, paragraph: 0, range: NSRange(location: 0, length: 1), text: "r")
    return ChapterUnderlines(chapterIndex: 0, underlines: [Underline(sentence: 4, paragraph: 0, range: NSRange(location: 60, length: 30), text: phrase,
                                                                     kind: .action, role: .attempt, reference: ref, decidedBy: .model)])
}

private let none = ChapterUnderlines(chapterIndex: 0, underlines: [])

private func resolved(_ i: GoldItem) async throws -> ResolvedItem { try #require(i.resolve(in: await chapter())) }

@Test func rightReferenceIsUnderlinedRight() async throws {
    let r = try await resolved(item(.underline(references: [0])))
    #expect(OutcomeClassifier.classify(r, underlines: underline(reference: 0), records: [record(nil)]) == .underlinedRight)
}

@Test func wrongReferenceIsMismatch() async throws {
    let r = try await resolved(item(.underline(references: [0])))
    #expect(OutcomeClassifier.classify(r, underlines: underline(reference: 2), records: [record(nil)]) == .mismatch)
}

@Test func underlineOnANoneItemIsMismatch() async throws {
    let r = try await resolved(item(.none(.temptingWrongPassage)))
    #expect(OutcomeClassifier.classify(r, underlines: underline(reference: 0), records: [record(nil)]) == .mismatch)
}

@Test func noUnderlineOnANoneItemIsCorrectlyNone() async throws {
    let r = try await resolved(item(.none(.explanationLater)))
    #expect(OutcomeClassifier.classify(r, underlines: none, records: [record(.pickedNone)]) == .correctlyNone)
}

@Test func missCausesComeFromTheRecord() async throws {
    let r = try await resolved(item(.underline(references: [0])))
    #expect(OutcomeClassifier.classify(r, underlines: none, records: []) == .missed(.detectMiss))
    #expect(OutcomeClassifier.classify(r, underlines: none, records: [record(.noCandidate, candidates: [])]) == .missed(.searchMiss))
    #expect(OutcomeClassifier.classify(r, underlines: none, records: [record(.pickedNone)]) == .missed(.pickMiss))
    #expect(OutcomeClassifier.classify(r, underlines: none, records: [record(.pickedNone, candidates: [2, 3])]) == .missed(.searchMiss))
    #expect(OutcomeClassifier.classify(r, underlines: none, records: [record(.confirmRejected)]) == .missed(.confirmRejected))
    #expect(OutcomeClassifier.classify(r, underlines: none, records: [record(.guardRejected)]) == .missed(.guardRejected))
    #expect(OutcomeClassifier.classify(r, underlines: none, records: [record(.densityLimit)]) == .missed(.densityLimit))
    #expect(OutcomeClassifier.classify(r, underlines: none, records: [record(.modelFailed)]) == .missed(.modelFailed))
}

@Test func spoilerBeatsEverything() async throws {
    let r = try await resolved(item(.underline(references: [0])))
    #expect(OutcomeClassifier.classify(r, underlines: underline(reference: 0), records: [record(nil, prompt: [4, 0])]) == .underlinedRight)
    #expect(OutcomeClassifier.classify(r, underlines: underline(reference: 0), records: [record(nil, prompt: [4, 0, 5])]) == .spoiler)
    #expect(OutcomeClassifier.classify(r, underlines: underline(reference: 0), records: [record(nil, candidates: [0, 4])]) == .spoiler)
}

@Test func outcomesOrderWorstFirst() {
    let sorted = [Outcome.correctlyNone, .underlinedRight, .missed(.pickMiss), .mismatch, .spoiler].sorted()
    #expect(sorted == [.spoiler, .mismatch, .missed(.pickMiss), .underlinedRight, .correctlyNone])
}

@Test func goldItemJSONRoundTrip() throws {
    for expected in [GoldExpected.underline(references: [0, 2]), .none(.sameSentence)] {
        let i = item(expected)
        let back = try JSONDecoder().decode(GoldItem.self, from: JSONEncoder().encode(i))
        #expect(back == i)
    }
    let json = #"{"id":"a","sentence":{"index":4,"text":"x"},"phrase":"x","kind":"action","expected":{"kind":"none","reason":"explanationLater"},"provisional":true}"#
    #expect(try JSONDecoder().decode(GoldItem.self, from: Data(json.utf8)).expected == .none(.explanationLater))
}

@Test func resolveRelocatesByTextWhenIndexShifts() async throws {
    let r = try #require(item(.underline(references: [0]), index: 7).resolve(in: await chapter()))
    #expect(r.sentence == 4)
    #expect(r.references == [0])
}

@Test func resolveFailsWhenPhraseNotInSentence() async {
    #expect(item(.underline(references: [0]), phrase: "climbed the hill").resolve(in: await chapter()) == nil)
}

@Test func aNameInsideAGoldPhraseIsNotThatPhrasesUnderline() {
    let event = item(.underline(references: [0]), phrase: "Let Marmee think we are getting things for ourselves", index: 4)
    #expect(!matches("Marmee", event))
    #expect(matches("Let Marmee think we are getting things for ourselves", event))
}

@Test func anEngineEventLongerThanTheGoldPhraseStillMatches() {
    let event = item(.underline(references: [0]), phrase: "looked at her rough hands", index: 4)
    #expect(matches("looked at her rough hands with a sigh that any one could hear that time", event))
    #expect(matches("rough hands", event) == false)
}

@Test func aPersonItemMatchesOnlyTheNameItself() {
    let person = GoldItem(id: "p", sentence: GoldRef(index: 4, text: "x"), phrase: "Hugo", kind: .person, expected: .none(.sameSentence),
                          provisional: true, note: nil)
    #expect(matches("Hugo", person))
    #expect(!matches("don't care if Hugo does come at me with a pistol", person))
}
