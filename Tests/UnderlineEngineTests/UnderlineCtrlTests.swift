import Foundation
import Testing
@testable import UnderlineEngine

/// The candidate in the last sentence whose phrase mentions the war.
private func warCandidate(_ ch: IndexedChapter) throws -> UnderlineCandidate {
    let last = try #require(ch.sentence(ch.last))
    return try #require(UnderlineDetector.candidates(in: last).first { $0.phrase.text.contains("war") })
}

@Test func confirmedTopCandidateKeepsUnderline() async throws {
    let ch = await fixtureChapter()
    let (kept, record) = await ctrl().evaluate(try warCandidate(ch), in: ch)
    let u = try #require(kept?.underline)
    #expect(u.reference.sentence == 0)
    #expect(u.decidedBy == .rules)
    #expect(record.kept)
    #expect(record.dropped == nil)
    #expect(record.pickedSentence == record.candidates.first)
    #expect(record.confirmed == true)
    let s = try #require(ch.sentence(u.sentence))
    #expect((s.text as NSString).substring(with: NSRange(location: u.range.location - s.range.location, length: u.range.length)) == u.text)
}

@Test func candidatesAreAlwaysEarlierSentences() async throws {
    let ch = await fixtureChapter()
    for s in ch.sentences {
        for c in UnderlineDetector.candidates(in: s) {
            let (_, record) = await ctrl().evaluate(c, in: ch)
            #expect(record.candidates.allSatisfy { $0 < c.sentence })
            #expect(record.pickedSentence.map { $0 < c.sentence } ?? true)
        }
    }
}

/// The phrase and the sentence that explains it, in one paragraph.
private func oneParagraphChapter() async -> IndexedChapter {
    await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: "Father had gone away to the war. Jo said she would face the war like Father."),
                                    embedding: EmbeddingSvcUnavailable())
}

@Test func pickInTheSameParagraphDropsBeforeConfirm() async throws {
    let ch = await oneParagraphChapter()
    let (kept, record) = await ctrl().evaluate(try warCandidate(ch), in: ch)
    #expect(kept == nil)
    #expect(record.dropped == .explainedInParagraph)
    #expect(record.pickedSentence == 0)
    #expect(record.confirmed == nil)
}

@Test func firstSentenceHasNothingToPick() async throws {
    let ch = await fixtureChapter()
    let first = try #require(ch.sentence(ch.first))
    for c in UnderlineDetector.candidates(in: first) {
        let (kept, record) = await ctrl().evaluate(c, in: ch)
        #expect(kept == nil)
        #expect(record.dropped == .pickedNone)
        #expect(record.candidates.isEmpty)
    }
}

@Test func recordCarriesTheCandidatesScores() async throws {
    let ch = await fixtureChapter()
    let (_, record) = await ctrl().evaluate(try warCandidate(ch), in: ch)
    #expect(record.candidateScores.count == record.candidates.count)
    #expect(record.candidateScores.allSatisfy { $0 > 0 })
}

@Test func chapterNotStartingAtZero() async throws {
    let ch = await fixtureChapter(firstSentence: 1_000)
    let (kept, record) = await ctrl().evaluate(try warCandidate(ch), in: ch)
    #expect(kept?.underline.reference.sentence == 1_000)
    #expect(kept?.underline.sentence == 1_004)
    #expect(record.candidates.allSatisfy { (1_000..<1_004).contains($0) })
}

@Test func recordCarriesThePhrasesOwnRange() async throws {
    let ch = await fixtureChapter()
    let c = try warCandidate(ch)
    let (_, record) = await ctrl().evaluate(c, in: ch)
    #expect(record.phraseRange == c.phrase.range)
}
