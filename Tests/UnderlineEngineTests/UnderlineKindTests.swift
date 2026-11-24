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
                      kind: .action, role: .attempt, reference: ref, decidedBy: .rules)
    #expect(try JSONDecoder().decode(Underline.self, from: JSONEncoder().encode(u)) == u)
    #expect(u.id == "39:55")
    var r = UnderlineRecord(chapterIndex: 0, sentence: 39, phrase: "began to whistle", kind: .action, embedding: .contextual,
                            phraseRange: NSRange(location: 0, length: 16))
    r.candidates = [38, 36]
    r.candidateScores = [0.8, 0.4]
    r.pickedSentence = 38
    r.confirmed = true
    r.kept = true
    r.searchMs = 3
    let back = try JSONDecoder().decode(UnderlineRecord.self, from: JSONEncoder().encode(r))
    #expect(back == r)
}
