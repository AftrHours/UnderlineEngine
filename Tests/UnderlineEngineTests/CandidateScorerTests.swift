import Foundation
import Testing
@testable import UnderlineEngine

/// A chapter with one sentence per paragraph, prepared without embeddings.
private func chapter(_ sentences: [String], firstSentence: Int = 0) async -> IndexedChapter {
    await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: sentences.joined(separator: "\n\n"), firstSentence: firstSentence),
                                    embedding: EmbeddingSvcUnavailable())
}

private func query(_ text: String, _ track: Track, role: EventRole? = nil, names: [String] = [], cue: Bool = false) -> SearchQuery {
    SearchQuery(text: text, lemmas: SearchQuery.contentLemmas(indexed(text).tokens), track: track, role: role,
                names: names, reactionCue: cue, vector: nil)
}

@Test func onlyScoresSentencesBeforeTheUnderline() async {
    let ch = await chapter(["A cat sat.", "The cat ran.", "The cat hid.", "The cat slept.", "The cat ate."])
    let r = CandidateScorer.rank(query("cat", .cause), in: ch, before: 2, mode: .both)
    #expect(Set(r.ranking.map(\.sentence)) == [0, 1])
    #expect(r.highestScored == 1)
}

@Test func neverScoresTheSentenceOrLaterAnywhereInTheChapter() async throws {
    let text = try String(contentsOf: datasetURL("little-women-ch1.txt"), encoding: .utf8)
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: text), embedding: EmbeddingSvcUnavailable())
    for s in ch.sentences where !s.events.isEmpty {
        let r = CandidateScorer.rank(query(s.events[0].text, s.events[0].track), in: ch, before: s.index, mode: .both)
        #expect(r.ranking.allSatisfy { $0.sentence < s.index })
        #expect((r.highestScored ?? -1) < s.index)
    }
}

@Test func firstSentenceHasNoCandidatesAndNoNaN() async {
    let ch = await chapter(["Only one sentence here."])
    let r = CandidateScorer.rank(query("sentence", .cause), in: ch, before: 0, mode: .both)
    #expect(r.ranking.isEmpty)
    #expect(r.highestScored == nil)
    #expect(UnderlineSearch.candidates(r).isEmpty)
}

@Test func scorerGapInSentenceIndexesNeverLeaksALaterSentence() async {
    let text = "A cat sat. The dog ran. It rained. Jo laughed."
    let ranges = SentenceSplitter.ranges(in: text)
    let sentences = zip([10, 11, 13, 14], ranges).map { SentenceInput(index: $0, paragraph: 0, range: $1) }
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, paragraphs: [ParagraphInput(index: 0, text: text)], sentences: sentences),
                                             embedding: EmbeddingSvcUnavailable())
    let r = CandidateScorer.rank(query("rain", .cause), in: ch, before: 13, mode: .words)
    #expect(r.ranking.allSatisfy { $0.sentence < 13 })
}

@Test func globalIndexesNotStartingAtZero() async {
    let ch = await chapter(["The cat sat.", "The cat ran.", "The cat hid."], firstSentence: 1_000)
    let r = CandidateScorer.rank(query("cat", .cause), in: ch, before: 1_002, mode: .words)
    #expect(Set(r.ranking.map(\.sentence)) == [1_000, 1_001])
}

@Test func candidatesBelowTheFloorAreDropped() async {
    let ch = await chapter(["Rain fell on the roof.", "Snow lay on the hill.", "The cat ate fish."])
    let r = CandidateScorer.rank(query("cat fish", .cause), in: ch, before: 2, mode: .words)
    #expect(r.ranking.allSatisfy { $0.rawScore < SearchKnobs.minRawScore[.words, default: 1] })
    #expect(UnderlineSearch.candidates(r).isEmpty)
}

@Test func candidatesAreCappedAndAboveTheFloor() async {
    let ch = await chapter((0..<10).map { "The cat sat on mat \($0)." } + ["Why did the cat sit?"])
    let r = CandidateScorer.rank(query("cat sat mat", .cause), in: ch, before: 10, mode: .words)
    let c = UnderlineSearch.candidates(r)
    #expect(c.count == SearchKnobs.maxCandidates)
    #expect(c.allSatisfy { $0.rawScore >= SearchKnobs.minRawScore[.words, default: 1] })
}

@Test func singleCandidateScalesToZeroButKeepsRawScore() async {
    let ch = await chapter(["Beth washed dishes all day.", "Her hands were rough."])
    let r = CandidateScorer.rank(query("rough hands dishes", .cause), in: ch, before: 1, mode: .words)
    #expect(r.ranking.first?.words == 0)
    #expect((r.ranking.first?.rawWords ?? 0) > 0)
    #expect(r.ranking.allSatisfy { !$0.score.isNaN })
}

@Test func characterTrackOnlyScoresSentencesWithTheName() async {
    let ch = await chapter(["Meg was the eldest.", "Jo was tall.", "Who was Meg?"])
    let r = CandidateScorer.rank(query("Meg", .character, names: ["Meg"]), in: ch, before: 2, mode: .both)
    #expect(r.ranking.map(\.sentence) == [0])
}

@Test func withoutVectorsBothFallsBackToWords() async {
    let ch = await chapter(["A b c.", "D e f."])
    #expect(CandidateScorer.rank(query("a", .cause), in: ch, before: 1, mode: .both).modeUsed == .words)
}

@Test func reactionCuePrefersTheSentenceJustBefore() async {
    let ch = await chapter(["Meg spoke of money.", "\"Jo does use such slang words!\" observed Amy.", "Jo immediately sat up and began to whistle."])
    let r = CandidateScorer.rank(query("began to whistle", .goal, role: .reaction, cue: true), in: ch, before: 2, mode: .both)
    #expect(r.ranking.first?.sentence == 1)
}

@Test func queryFromCandidatePicksUpCueAndNames() {
    let s = indexed("Jo immediately sat up, put her hands in her pockets, and began to whistle.")
    let event = s.events.first { $0.text.hasPrefix("immediately") }!
    let c = UnderlineCandidate(sentence: s.index, phrase: event, kind: UnderlineKind.of(event))
    let sq = SearchQuery.make(candidate: c, in: s, embedding: EmbeddingSvcUnavailable(), tagger: ChapterIndexSvc())
    #expect(sq.reactionCue)
    #expect(sq.text == event.text)
    #expect(sq.lemmas.contains("sit"))
    let name = s.names.first { $0.text == "Jo" }!
    let nc = UnderlineCandidate(sentence: s.index, phrase: EventPhrase(text: "Jo", range: name.range, role: nil, track: .character), kind: .person)
    #expect(SearchQuery.make(candidate: nc, in: s, embedding: EmbeddingSvcUnavailable(), tagger: ChapterIndexSvc()).names == ["Jo"])
}
