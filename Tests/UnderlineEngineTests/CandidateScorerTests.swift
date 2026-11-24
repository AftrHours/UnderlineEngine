import Foundation
import Testing
@testable import UnderlineEngine

/// A chapter with one sentence per paragraph, prepared without word vectors.
private func chapter(_ sentences: [String], firstSentence: Int = 0) async -> IndexedChapter {
    await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: sentences.joined(separator: "\n\n"), firstSentence: firstSentence),
                                    embedding: EmbeddingSvcUnavailable())
}

private func query(_ text: String, _ track: Track = .cause, role: EventRole? = nil, names: [String] = [], cue: Bool = false) -> SearchQuery {
    SearchQuery(text: text, lemmas: SearchQuery.contentLemmas(indexed(text).tokens), track: track, role: role,
                names: names, reactionCue: cue)
}

@Test func onlyScoresSentencesBeforeTheUnderline() async {
    let ch = await chapter(["A cat sat.", "The cat ran.", "The cat hid.", "The cat slept.", "The cat ate."])
    let r = CandidateScorer.rank(query("cat"), in: ch, before: 2)
    #expect(Set(r.map(\.sentence)) == [0, 1])
}

@Test func neverScoresTheSentenceOrLaterAnywhereInTheChapter() async throws {
    let text = try String(contentsOf: datasetURL("little-women-ch1.txt"), encoding: .utf8)
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: text), embedding: EmbeddingSvcUnavailable())
    for s in ch.sentences where !s.events.isEmpty {
        let r = CandidateScorer.rank(query(s.events[0].text, s.events[0].track), in: ch, before: s.index)
        #expect(r.allSatisfy { $0.sentence < s.index })
    }
}

@Test func firstSentenceHasNoCandidatesAndNoNaN() async {
    let ch = await chapter(["Only one sentence here."])
    let r = CandidateScorer.rank(query("sentence"), in: ch, before: 0)
    #expect(r.isEmpty)
}

@Test func scorerGapInSentenceIndexesNeverLeaksALaterSentence() async {
    let text = "A cat sat. The dog ran. It rained. Jo laughed."
    let ranges = SentenceSplitter.ranges(in: text)
    let sentences = zip([10, 11, 13, 14], ranges).map { SentenceInput(index: $0, paragraph: 0, range: $1) }
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, paragraphs: [ParagraphInput(index: 0, text: text)], sentences: sentences),
                                             embedding: EmbeddingSvcUnavailable())
    let r = CandidateScorer.rank(query("rain"), in: ch, before: 13)
    #expect(r.allSatisfy { $0.sentence < 13 })
}

@Test func globalIndexesNotStartingAtZero() async {
    let ch = await chapter(["The cat sat.", "The cat ran.", "The cat hid."], firstSentence: 1_000)
    let r = CandidateScorer.rank(query("cat"), in: ch, before: 1_002)
    #expect(Set(r.map(\.sentence)) == [1_000, 1_001])
}

@Test func singleCandidateScalesToZeroButKeepsItsRawShare() async {
    let ch = await chapter(["Beth washed dishes all day.", "Her hands were rough."])
    let r = CandidateScorer.rank(query("rough hands dishes"), in: ch, before: 1)
    #expect(r.first?.words == 0)
    #expect((r.first?.rawWords ?? 0) > 0)
    #expect(r.allSatisfy { !$0.score.isNaN })
}

@Test func characterTrackOnlyScoresSentencesWithTheName() async {
    let ch = await chapter(["Meg was the eldest.", "Jo was tall.", "Who was Meg?"])
    let r = CandidateScorer.rank(query("Meg", .character, names: ["Meg"]), in: ch, before: 2)
    #expect(r.map(\.sentence) == [0])
}

@Test func reactionCuePrefersTheSentenceJustBefore() async {
    let ch = await chapter(["Meg spoke of money.", "\"Jo does use such slang words!\" observed Amy.", "Jo immediately sat up and began to whistle."])
    let r = CandidateScorer.rank(query("began to whistle", role: .reaction, cue: true), in: ch, before: 2)
    #expect(r.first?.sentence == 1)
}

@Test func queryFromCandidatePicksUpCueAndNames() {
    let s = indexed("Jo immediately sat up, put her hands in her pockets, and began to whistle.")
    let event = s.events.first { $0.text.hasPrefix("immediately") }!
    let c = UnderlineCandidate(sentence: s.index, phrase: event, kind: UnderlineKind.of(event))
    let sq = SearchQuery.make(candidate: c, in: s, tagger: ChapterIndexSvc())
    #expect(sq.reactionCue)
    #expect(sq.text == event.text)
    #expect(sq.lemmas.contains("sit"))
    let name = s.names.first { $0.text == "Jo" }!
    let nc = UnderlineCandidate(sentence: s.index, phrase: EventPhrase(text: "Jo", range: name.range, role: nil, track: .character), kind: .person)
    #expect(SearchQuery.make(candidate: nc, in: s, tagger: ChapterIndexSvc()).names == ["Jo"])
}

private func makeQuery(_ sentence: IndexedSentence, phrase: EventPhrase) -> SearchQuery {
    let c = UnderlineCandidate(sentence: sentence.index, phrase: phrase, kind: UnderlineKind.of(phrase))
    return SearchQuery.make(candidate: c, in: sentence, tagger: ChapterIndexSvc())
}

@Test func reactionCueInAnotherEventOfTheSentenceReachesThePhrase() throws {
    let s = indexed("Jo immediately sat up, put her hands in her pockets, and began to whistle.")
    let whistle = try #require(s.events.first { $0.text.hasPrefix("began") })
    #expect(!whistle.text.contains("immediately"))
    #expect(makeQuery(s, phrase: whistle).reactionCue)
}

@Test func aSentenceWithoutACueGivesNoCue() throws {
    let s = indexed("Jo sat up, put her hands in her pockets, and began to whistle.")
    let whistle = try #require(s.events.first { $0.text.hasPrefix("began") })
    #expect(!makeQuery(s, phrase: whistle).reactionCue)
}

@Test func aNameDoesNotTakeTheSentencesCue() throws {
    let s = indexed("Jo immediately sat up, put her hands in her pockets, and began to whistle.")
    let name = try #require(s.names.first { $0.text == "Jo" })
    let phrase = EventPhrase(text: "Jo", range: name.range, role: nil, track: .character)
    #expect(!makeQuery(s, phrase: phrase).reactionCue)
}
