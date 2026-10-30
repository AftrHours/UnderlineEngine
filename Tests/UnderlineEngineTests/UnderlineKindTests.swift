import Foundation
import Testing
@testable import UnderlineEngine

private func phrase(_ role: EventRole?, _ track: Track) -> EventPhrase {
    EventPhrase(text: "x", range: NSRange(location: 0, length: 1), role: role, track: track)
}

@Test func kindMapsFromRoleAndTrack() {
    #expect(UnderlineKind.of(phrase(nil, .character)) == .person)
    #expect(UnderlineKind.of(phrase(.reaction, .cause)) == .reaction)
    #expect(UnderlineKind.of(phrase(.internalResponse, .cause)) == .feeling)
    #expect(UnderlineKind.of(phrase(.outcome, .cause)) == .outcome)
    #expect(UnderlineKind.of(phrase(.setting, .place)) == .place)
    #expect(UnderlineKind.of(phrase(.setting, .character)) == .thing)
    #expect(UnderlineKind.of(phrase(.setting, .time)) == .thing)
    #expect(UnderlineKind.of(phrase(.attempt, .goal)) == .action)
    #expect(UnderlineKind.of(phrase(.goal, .goal)) == .action)
    #expect(UnderlineKind.of(phrase(.initiatingEvent, .cause)) == .action)
}

@Test func underlineAndRecordRoundTripThroughJSON() throws {
    let ref = AnswerPassage(sentence: 38, paragraph: 19, range: NSRange(location: 0, length: 12), text: "Jo does use such slang words!")
    let u = Underline(sentence: 39, paragraph: 20, range: NSRange(location: 55, length: 16), text: "began to whistle",
                      kind: .action, role: .attempt, reference: ref, decidedBy: .model)
    #expect(try JSONDecoder().decode(Underline.self, from: JSONEncoder().encode(u)) == u)
    #expect(u.id == "39:55")
    let r = UnderlineRecord(chapterIndex: 0, sentence: 39, phrase: "began to whistle", kind: .action, path: .model,
                            promptVariant: .baseline, searchModeUsed: .both, embedding: .sentence, candidates: [38, 36],
                            promptSentences: [39, 38, 36], pickedSentence: 38, quote: "slang words",
                            confirm: ConfirmTrace(explains: true, evidence: "Amy scolds Jo"), kept: true, dropped: nil,
                            times: StepTimes(searchMs: 3, pickMs: 400, confirmMs: 300))
    let back = try JSONDecoder().decode(UnderlineRecord.self, from: JSONEncoder().encode(r))
    #expect(back.promptSentences == [39, 38, 36])
    #expect(back.confirm == ConfirmTrace(explains: true, evidence: "Amy scolds Jo"))
}
