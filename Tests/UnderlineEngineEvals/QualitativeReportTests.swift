import Foundation
import Testing
@testable import UnderlineEngine

private let run = RunInfo(runID: "R1", runKind: "golden", searchMode: "both")

private func chapter(_ text: String) async -> IndexedChapter {
    await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: text), embedding: EmbeddingSvcUnavailable())
}

private func record(_ sentence: Int, _ phrase: String, range: NSRange? = nil, kept: Bool = false, dropped: DropReason? = nil,
                    picked: Int? = nil, candidates: [Int] = []) -> UnderlineRecord {
    UnderlineRecord(chapterIndex: 0, sentence: sentence, phrase: phrase, kind: .action, path: .model, searchModeUsed: .words, embedding: .none, candidates: candidates, promptSentences: [], pickedSentence: picked,
                    confirm: dropped == .confirmRejected ? ConfirmTrace(explains: false, evidence: "no") : nil,
                    kept: kept, dropped: dropped, times: StepTimes(searchMs: 2), phraseRange: range,
                    candidateScores: candidates.indices.map { [0.62, 0.40, 0.3, 0.2][min($0, 3)] })
}

private func column(_ row: QualitativeRow, _ name: String) -> String {
    #expect(QualitativeRow.header.contains(name), "no column \(name)")
    return row[name]
}

@Test func headerMatchesSpecOrder() {
    #expect(QualitativeRow.header == [
        "run_id", "run_kind", "search_mode", "gold_id",
        "sentence", "paragraph", "sentence_text", "sentence_with_underline", "phrase", "phrase_range",
        "tagging_engine", "words", "names", "events", "phrase_role", "kind",
        "embedding", "search_mode_used", "candidates", "top_candidate_text",
        "path", "pick", "picked_sentence", "confirm", "confirm_evidence",
        "underlined", "dropped_reason", "reference", "reference_text", "distance",
        "expected", "outcome", "miss_cause", "judge", "judge_rationale",
        "search_ms", "confirm_ms"
    ])
}

@Test func underlineMarkedAtItsOwnRange() async {
    let ch = await chapter("A cat ran home. She ran home, and then she ran home again.")
    let s = ch.sentence(1)!
    let second = (s.text as NSString).range(of: "ran home", options: .backwards)
    let rows = QualitativeReport.rows(run: run, chapter: ch, records: [record(1, "ran home", range: second)], gold: nil, outcomes: [:], judge: [:])
    #expect(column(rows[0], "sentence_with_underline") == "She ran home, and then she [[ran home]] again.")
    #expect(column(rows[0], "phrase_range") == "\(second.location)+\(second.length)")
}

@Test func wordsNamesAndEventsColumns() async {
    let ch = await chapter("Jo immediately sat up, put her hands in her pockets, and began to whistle.")
    let rows = QualitativeReport.rows(run: run, chapter: ch, records: [record(0, "began to whistle")], gold: nil, outcomes: [:], judge: [:])
    #expect(column(rows[0], "words").hasPrefix("Jo/"))
    #expect(column(rows[0], "words").contains(" · "))
    #expect(column(rows[0], "names").contains("Jo (person)"))
    #expect(column(rows[0], "events").contains("began to whistle (attempt)"))
}

@Test func droppedPhraseHasRowWithReason() async {
    let ch = await chapter("Meg sewed. Jo began to whistle.")
    let rows = QualitativeReport.rows(run: run, chapter: ch, records: [record(1, "began to whistle", dropped: .confirmRejected, picked: 0, candidates: [0])],
                                   gold: nil, outcomes: [:], judge: [:])
    #expect(column(rows[0], "underlined") == "no")
    #expect(column(rows[0], "dropped_reason") == "confirmRejected")
    #expect(column(rows[0], "pick") == "1")
    #expect(column(rows[0], "picked_sentence") == "0")
    #expect(column(rows[0], "confirm") == "no")
    #expect(column(rows[0], "reference").isEmpty)
}

@Test func keptPhraseShowsReferenceAndDistance() async {
    let ch = await chapter("Meg sewed. Amy drew. Jo began to whistle.")
    let rows = QualitativeReport.rows(run: run, chapter: ch, records: [record(2, "began to whistle", kept: true, picked: 0, candidates: [0, 1])],
                                   gold: nil, outcomes: [:], judge: ["2:began to whistle": ("pass", "fine")])
    #expect(column(rows[0], "underlined") == "yes")
    #expect(column(rows[0], "reference") == "0")
    #expect(column(rows[0], "reference_text") == "Meg sewed.")
    #expect(column(rows[0], "distance") == "2")
    #expect(column(rows[0], "candidates") == "S0:0.62 S1:0.40")
    #expect(column(rows[0], "judge") == "pass")
}

@Test func goldItemWithoutRecordGetsDetectMissRow() async throws {
    let ch = await chapter("Meg sewed. Jo began to whistle.")
    let item = GoldItem(id: "g1", sentence: GoldRef(index: 1, text: "Jo began to whistle."), phrase: "began to whistle", kind: .action,
                        expected: .underline(references: [0]), provisional: true, note: nil)
    let resolved = try #require(item.resolve(in: ch))
    let rows = QualitativeReport.rows(run: run, chapter: ch, records: [], gold: [resolved], outcomes: ["g1": .missed(.detectMiss)], judge: [:])
    #expect(rows.count == 1)
    #expect(column(rows[0], "gold_id") == "g1")
    #expect(column(rows[0], "outcome") == Outcome.missed(.detectMiss).label)
    #expect(column(rows[0], "miss_cause") == "detect miss")
    #expect(column(rows[0], "expected") == "underline: S0")
    #expect(column(rows[0], "path").isEmpty)
}

@Test func rowsSortedWorstFirst() async throws {
    let ch = await chapter("Meg sewed. Amy drew. Beth sang. Jo began to whistle. Hannah came in.")
    func gold(_ id: String, _ s: Int, _ phrase: String) throws -> ResolvedItem {
        try #require(GoldItem(id: id, sentence: GoldRef(index: s, text: ch.sentence(s)!.text), phrase: phrase, kind: .action,
                              expected: .underline(references: [0]), provisional: true, note: nil).resolve(in: ch))
    }
    let items = [try gold("right", 1, "drew"), try gold("miss", 2, "sang"), try gold("wrong", 3, "began to whistle"), try gold("leak", 4, "came in")]
    let outcomes: [String: Outcome] = ["right": .underlinedRight, "miss": .missed(.pickMiss), "wrong": .mismatch, "leak": .spoiler]
    let rows = QualitativeReport.rows(run: run, chapter: ch, records: [], gold: items, outcomes: outcomes, judge: [:])
    #expect(rows.map { column($0, "gold_id") } == ["leak", "wrong", "miss", "right"])
}

@Test func everyRowHasOneValuePerColumn() async {
    let ch = await chapter("Meg sewed. Jo began to whistle.")
    let rows = QualitativeReport.rows(run: run, chapter: ch, records: [record(1, "began to whistle", kept: true, picked: 0)], gold: nil, outcomes: [:], judge: [:])
    #expect(rows[0].values.count == QualitativeRow.header.count)
}

@Test func sweepRowsHaveNoExpectedOrOutcome() async {
    let ch = await chapter("Meg sewed. Jo began to whistle.")
    let sweep = RunInfo(runID: "R2", runKind: "sweep", searchMode: "both")
    let rows = QualitativeReport.rows(run: sweep, chapter: ch, records: [record(1, "began to whistle", kept: true, picked: 0)], gold: nil, outcomes: [:], judge: [:])
    #expect(column(rows[0], "expected").isEmpty)
    #expect(column(rows[0], "outcome").isEmpty)
    #expect(column(rows[0], "run_kind") == "sweep")
}

@Test func markdownShowsUnderlineWithReferenceAndReviewBoxes() async {
    let ch = await chapter("Meg sewed. Amy drew. Jo began to whistle.")
    let rows = QualitativeReport.rows(run: run, chapter: ch, records: [record(2, "began to whistle", kept: true, picked: 0, candidates: [0, 1])],
                                      gold: nil, outcomes: [:], judge: ["2:began to whistle": ("fail", "only shares a topic")])
    let md = QualitativeReport.markdown(rows, run: run)
    #expect(md.hasPrefix("# R1\n"))
    #expect(md.contains("**1 underlined** · judge 0 pass / 1 fail"))
    #expect(md.contains("### S2 · began to whistle"))
    #expect(md.contains("> Jo **began to whistle**."))
    #expect(md.contains("**Reference S0**, 2 sentences earlier:"))
    #expect(md.contains("> Meg sewed."))
    #expect(md.contains("- Judge: **fail** · only shares a topic"))
    #expect(md.contains("- [ ] right\n- [ ] wrong passage\n- [ ] shouldn't be underlined"))
    #expect(!md.contains("Golden outcomes"))
}

@Test func markdownListsDroppedPhrasesInATable() async {
    let ch = await chapter("Meg sewed. Jo began to whistle.")
    let rows = QualitativeReport.rows(run: run, chapter: ch, records: [record(1, "began | to whistle", dropped: .confirmRejected, picked: 0, candidates: [0])],
                                      gold: nil, outcomes: [:], judge: [:])
    let md = QualitativeReport.markdown(rows, run: run)
    #expect(md.contains("| `confirmRejected` | 1 |"))
    #expect(md.contains("## Underlined\n\nTick one box per phrase and write a note if needed.\n\nNone."))
    #expect(md.contains("| 1 | began \\| to whistle | `confirmRejected` | S0:0.62 |"))
}

@Test func markdownForGoldenRunCountsOutcomes() async throws {
    let ch = await chapter("Meg sewed. Jo began to whistle.")
    let item = GoldItem(id: "g1", sentence: GoldRef(index: 1, text: "Jo began to whistle."), phrase: "began to whistle", kind: .action,
                        expected: .underline(references: [0]), provisional: true, note: nil)
    let resolved = try #require(item.resolve(in: ch))
    let rows = QualitativeReport.rows(run: run, chapter: ch, records: [], gold: [resolved], outcomes: ["g1": .missed(.detectMiss)], judge: [:])
    let md = QualitativeReport.markdown(rows, run: run)
    #expect(md.contains("## Golden outcomes"))
    #expect(md.contains("| ⚠️ missed (detect miss) | 1 |"))
    #expect(md.contains("| `never considered` | 1 |"))
    #expect(md.contains("| 1 | began to whistle | never considered |  | underline: S0 | ⚠️ missed (detect miss) |"))
}
