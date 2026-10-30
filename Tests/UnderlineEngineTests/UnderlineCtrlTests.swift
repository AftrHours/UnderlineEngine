import Foundation
import Testing
@testable import UnderlineEngine

/// The candidate in the last sentence whose phrase mentions the war.
private func warCandidate(_ ch: IndexedChapter) throws -> UnderlineCandidate {
    let last = try #require(ch.sentence(ch.last))
    return try #require(UnderlineDetector.candidates(in: last).first { $0.phrase.text.contains("war") })
}

private func accepting(_ ch: IndexedChapter) -> FakeUnderlineModel {
    let fake = FakeUnderlineModel()
    fake.pickResult = ModelPick(quote: "gone away to the war", candidate: 1)
    fake.confirmResult = ModelConfirm(evidence: "gone away to the war", explains: true)
    return fake
}

@Test func acceptedPickAndConfirmKeepsUnderline() async throws {
    let ch = await fixtureChapter()
    let (kept, record) = await ctrl(accepting(ch)).evaluate(try warCandidate(ch), in: ch)
    let u = try #require(kept?.underline)
    #expect(u.reference.sentence == 0)
    #expect(u.decidedBy == .model)
    #expect(record.kept)
    #expect(record.dropped == nil)
    #expect(record.path == .model)
    #expect(record.confirm == ConfirmTrace(explains: true, evidence: "gone away to the war"))
    let s = try #require(ch.sentence(u.sentence))
    #expect((s.text as NSString).substring(with: NSRange(location: u.range.location - s.range.location, length: u.range.length)) == u.text)
}

@Test func spoilerNeverReachesAPrompt() async throws {
    let ch = await fixtureChapter()
    for s in ch.sentences {
        for c in UnderlineDetector.candidates(in: s) {
            let fake = accepting(ch)
            let (_, record) = await ctrl(fake).evaluate(c, in: ch)
            for call in fake.calls {
                #expect(call.indexes.first == c.sentence)
                #expect(call.indexes.dropFirst().allSatisfy { $0 < c.sentence })
            }
            #expect(record.promptSentences.allSatisfy { $0 <= c.sentence })
            #expect(record.promptSentences.filter { $0 == c.sentence }.count <= 2)
            #expect(record.candidates.allSatisfy { $0 < c.sentence })
            #expect(Set(fake.calls.flatMap(\.indexes)) == Set(record.promptSentences))
        }
    }
}

@Test func pickNoneDropsWithPickedNone() async throws {
    let ch = await fixtureChapter()
    let fake = FakeUnderlineModel()
    let (kept, record) = await ctrl(fake).evaluate(try warCandidate(ch), in: ch)
    #expect(kept == nil)
    #expect(record.dropped == .pickedNone)
    #expect(!fake.calls.contains { $0.kind == .confirm })
}

@Test func confirmNoDropsWithConfirmRejected() async throws {
    let ch = await fixtureChapter()
    let fake = accepting(ch)
    fake.confirmResult = ModelConfirm(evidence: "", explains: false)
    let (kept, record) = await ctrl(fake).evaluate(try warCandidate(ch), in: ch)
    #expect(kept == nil)
    #expect(record.dropped == .confirmRejected)
    #expect(record.pickedSentence == 0)
}

@Test func pickOfSentenceNotInCandidatesDropsWithGuardRejected() async throws {
    let ch = await fixtureChapter()
    let fake = accepting(ch)
    fake.pickResult = ModelPick(quote: "gone away to the war", candidate: 9)
    let (kept, record) = await ctrl(fake).evaluate(try warCandidate(ch), in: ch)
    #expect(kept == nil)
    #expect(record.dropped == .guardRejected)
    #expect(!fake.calls.contains { $0.kind == .confirm })
}

@Test func emptyQuoteDropsWithGuardRejected() async throws {
    let ch = await fixtureChapter()
    let fake = accepting(ch)
    fake.pickResult = ModelPick(quote: "", candidate: 1)
    let (kept, record) = await ctrl(fake).evaluate(try warCandidate(ch), in: ch)
    #expect(kept == nil)
    #expect(record.dropped == .guardRejected)
}

@Test func firstSentenceMakesNoModelCall() async throws {
    let ch = await fixtureChapter()
    let first = try #require(ch.sentence(ch.first))
    for c in UnderlineDetector.candidates(in: first) {
        let fake = accepting(ch)
        let (kept, record) = await ctrl(fake).evaluate(c, in: ch)
        #expect(kept == nil)
        #expect(fake.calls.isEmpty)
        #expect(record.dropped == .noCandidate)
    }
}

@Test func exceededContextHalvesThenFallsBackToRules() async throws {
    let ch = await fixtureChapter()
    let fake = accepting(ch)
    fake.pickError = .exceededContext
    let (kept, record) = await ctrl(fake).evaluate(try warCandidate(ch), in: ch)
    #expect(fake.calls.filter { $0.kind == .pick }.count <= 2)
    #expect(record.path == .rules)
    #expect(kept?.underline.decidedBy == .rules)
}

@Test func otherModelErrorDropsInsteadOfFallingBackToRules() async throws {
    let ch = await fixtureChapter()
    for (pickError, confirmError) in [(ModelFailure.failed("boom"), nil), (nil, ModelFailure.failed("boom")), (nil, ModelFailure.exceededContext)] {
        let fake = accepting(ch)
        fake.pickError = pickError
        fake.confirmError = confirmError
        let (kept, record) = await ctrl(fake).evaluate(try warCandidate(ch), in: ch)
        #expect(kept == nil)
        #expect(record.path == .model)
        #expect(record.dropped == .modelFailed)
    }
}

@Test func recordCarriesTheCandidatesScores() async throws {
    let ch = await fixtureChapter()
    let (_, record) = await ctrl(accepting(ch)).evaluate(try warCandidate(ch), in: ch)
    #expect(record.candidateScores.count == record.candidates.count)
    #expect(record.candidateScores.allSatisfy { $0 >= SearchKnobs.minRawScore[.words, default: 1] })
    #expect(record.candidateScores == record.candidateScores.sorted(by: >) || record.candidates.count < 2)
}

@Test func unavailableModelUsesRulesPathWithDecidedByRules() async throws {
    let ch = await fixtureChapter()
    let (kept, record) = await ctrl(UnderlineModelSvcUnavailable()).evaluate(try warCandidate(ch), in: ch)
    #expect(record.path == .rules)
    #expect(kept?.underline.decidedBy == .rules)
    #expect(kept?.underline.reference.sentence == 0)
    #expect(record.promptSentences.isEmpty)
}

@Test func chapterNotStartingAtZero() async throws {
    let ch = await fixtureChapter(firstSentence: 1_000)
    let fake = accepting(ch)
    let (kept, record) = await ctrl(fake).evaluate(try warCandidate(ch), in: ch)
    #expect(kept?.underline.reference.sentence == 1_000)
    #expect(kept?.underline.sentence == 1_004)
    #expect(record.candidates.allSatisfy { (1_000..<1_004).contains($0) })
    #expect(fake.calls.flatMap(\.indexes).allSatisfy { (1_000...1_004).contains($0) })
}

@Test func recordCarriesThePhrasesOwnRange() async throws {
    let ch = await fixtureChapter()
    let c = try warCandidate(ch)
    let (_, kept) = await ctrl(accepting(ch)).evaluate(c, in: ch)
    #expect(kept.phraseRange == c.phrase.range)
    let (_, dropped) = await ctrl(FakeUnderlineModel()).evaluate(c, in: ch)
    #expect(dropped.phraseRange == c.phrase.range)
}
