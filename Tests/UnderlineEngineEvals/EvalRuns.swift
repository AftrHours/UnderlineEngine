import Evaluations
import Foundation
import FoundationModels
import Testing
@testable import UnderlineEngine

/// The harness runs (spec §8), on Apple's Evaluations framework. They call the model, so they only run with
/// `UNDERLINE_EVALS=1 swift test --filter UnderlineEngineEvals` (the sweep also needs `UNDERLINE_SWEEP=1`;
/// `UNDERLINE_SWEEP_LIMIT=60` sweeps only the first 60 sentences).
/// Results are saved with `EvaluationResult.saveJSON` under `Eval/results/<kind>/`.
@available(macOS 27, *)
enum Evals {
    static var enabled: Bool { ProcessInfo.processInfo.environment["UNDERLINE_EVALS"] != nil }
    static var sweepEnabled: Bool { enabled && ProcessInfo.processInfo.environment["UNDERLINE_SWEEP"] != nil }

    static let root = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    static func load(model: ModelChoice, search: SearchMode) async throws -> (UnderlineCtrl, IndexedChapter, GoldSet) {
        let ctrl = UnderlineCtrl(model: model, search: search)
        let text = try String(contentsOf: root.appendingPathComponent("Dataset/little-women-ch1.txt"), encoding: .utf8)
        let chapter = await ctrl.prepare(ChapterInput(chapterIndex: 0, plainText: text))
        return (ctrl, chapter, try loadGold())
    }

    /// Apple's larger Private Cloud Compute model judges when it actually answers, so the engine's model isn't grading
    /// itself. It can report itself available and still fail from a test runner, so one tiny call is tried first;
    /// otherwise the on-device model judges.
    static func judgeModel() async -> (any LanguageModel, String) {
        let pcc = PrivateCloudComputeLanguageModel()
        if pcc.isAvailable, (try? await LanguageModelSession(model: pcc).respond(to: "Reply with OK.")) != nil {
            return (pcc, "privateCloudCompute")
        }
        return (SystemLanguageModel.default, "onDevice")
    }

    static func info(_ ctrl: UnderlineCtrl, _ chapter: IndexedChapter, judge: String) -> [String: String] {
        let k = KnobSnapshot.current
        return ["search": ctrl.searchMode.rawValue, "path": ctrl.usesModel ? "model" : "rules",
                "judge model": judge, "embeddings": chapter.embedding.rawValue, "embedWeight": "\(k.embedWeight)",
                "wordsWeight": "\(k.wordsWeight)", "maxCandidates": "\(k.maxCandidates)", "maxPerParagraph": "\(k.maxPerParagraph)",
                "minRawScore": k.minRawScore.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")]
    }

    /// Saves the result and returns the newest earlier result of the same kind, for "changed since last run".
    static func save(_ result: EvaluationResult, kind: String) throws -> (saved: URL, previous: URL?) {
        let dir = root.appendingPathComponent("Eval/results/\(kind)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let previous = latestResult(in: dir)
        return (try result.saveJSON(to: dir, includeReportMetadata: true), previous)
    }

    /// The newest saved result in a folder (`saveJSON` names files `<Evaluation>-<id>.xcevalresult`).
    static func latestResult(in dir: URL) -> URL? {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey],
                                                                  options: .skipsHiddenFiles)) ?? []
        return files.filter { $0.pathExtension == "xcevalresult" }.max { modified($0) < modified($1) }
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    static func mean(_ result: EvaluationResult, _ metric: Metric) -> String {
        let v = result.aggregateValue(.mean(of: metric))
        let isTime = metric.name.hasSuffix("ms")
        return v.isNaN || v < 0 ? "–" : String(format: isTime ? "%.0f" : "%.0f%%", isTime ? v : v * 100)
    }

    /// The item id and outcome from one row of a saved result, whose columns are JSON strings.
    static func earlierOutcome(input: String, metric: String) -> (id: String, outcome: Outcome)? {
        guard let sample = try? JSONDecoder().decode(GoldSample.self, from: Data(input.utf8)),
              let object = try? JSONSerialization.jsonObject(with: Data(metric.utf8)) as? [String: Any],
              let rationale = object["rationale"] as? String,
              let outcome = Outcome.all.first(where: { $0.label == rationale }) else { return nil }
        return (sample.item.id, outcome)
    }

    /// Prints the qualitative report (spec §8.4): the headline numbers (mismatch rate first), summary by kind, every item
    /// worst first with the judge's rationale, judge agreement with the human labels, and what changed since the previous run.
    static func report(_ result: EvaluationResult, _ evaluation: GoldenEvaluation, previous: URL?) async {
        let inputs = result.detailed[evaluation.inputColumn]
        let responses = result.detailed[evaluation.responseColumn]
        let judged = result.detailed[metric: EvalMetric.explains]
        struct Row { let sample: GoldSample; let r: EngineResult; let outcome: Outcome; let judge: Metric? }
        let rows: [Row] = (0..<result.detailed.rows.count).compactMap { i in
            guard let s = inputs[i], let r = responses[i]?.value, let o = r.outcome else { return nil }
            return Row(sample: s, r: r, outcome: o, judge: judged[i])
        }
        let (underlines, records) = await evaluation.run.result()
        let sentencesRun = Set(records.map(\.sentence)).count

        print("\n== Headline ==")
        print("  mismatch rate: \(mean(result, EvalMetric.mismatch)) (target ≤ 5%)")
        print("  no spoiler: \(mean(result, EvalMetric.noSpoiler)) · reference precision: \(mean(result, EvalMetric.referencePrecision))"
              + " · underline recall: \(mean(result, EvalMetric.underlineRecall)) · judge pass: \(mean(result, EvalMetric.explains))")
        print("  candidate recall: \(mean(result, EvalMetric.candidateRecall)) · confirm agreement: \(mean(result, EvalMetric.confirmAgreement))"
              + " · search/confirm ms: \(mean(result, EvalMetric.searchMs))/\(mean(result, EvalMetric.confirmMs))")
        print("  density: \(underlines.underlines.count) underlines over the \(sentencesRun) sentences with phrases in the golden paragraphs")

        print("\n== Summary by kind ==")
        for kind in UnderlineKind.allCases {
            let k = rows.filter { $0.sample.item.kind == kind }
            if k.isEmpty { continue }
            let counts = Dictionary(grouping: k, by: \.outcome).sorted { $0.key < $1.key }.map { "\($0.key.label) \($0.value.count)" }
            print("  \(kind.rawValue): " + counts.joined(separator: " · "))
        }

        print("\n== Items, worst first ==")
        for row in rows.sorted(by: { ($0.outcome, $0.sample.item.id) < ($1.outcome, $1.sample.item.id) }) {
            let s = row.sample, r = row.r
            print("\(row.outcome.label) · \(s.item.kind.rawValue) · \(s.item.id) · S\(s.resolved.sentence)")
            print("    sentence: \"\(s.sentenceText)\"")
            print("    phrase: \"\(s.item.phrase)\"\(r.phrase.map { $0 == s.item.phrase ? "" : " · engine phrase \"\($0)\"" } ?? "")")
            print("    shown: \(r.underlined ? "S\(r.referenceSentence ?? -1) \"\(r.referenceText ?? "")\"" : "no underline\(r.dropped.map { " (\($0))" } ?? "")")")
            print("    expected: \(s.expected?.referenceText ?? "")")
            if !r.candidates.isEmpty { print("    candidates: \(r.candidates.map { "S\($0)" }.joined(separator: " "))") }
            if let c = r.confirm { print("    confirm: \(c ? "yes" : "no")\(r.confirmEvidence.map { $0.isEmpty ? "" : " — \"\($0)\"" } ?? "")") }
            if let j = row.judge, j.value != .ignore { print("    model judge: \(j.value == .passing ? "pass" : "fail") — \(j.rationale ?? "")") }
        }

        let graded = rows.filter { $0.judge.map { $0.value == .passing || $0.value == .failing } ?? false }
        let agree = graded.filter { ($0.judge?.value == .passing) == ($0.outcome == .underlinedRight) }.count
        print("\n== Model judge vs human labels ==\n  agreement on \(graded.count) shown underlines: \(graded.isEmpty ? "–" : "\(agree)/\(graded.count)")")

        print("\n== Changed since last run ==")
        guard let previous, let old = try? EvaluationResult.loadJSON(from: previous) else { print("  no earlier run"); return }
        // A loaded result keeps every column as JSON text: decode the sample and read the outcome's rationale.
        let oldInputs = old.detailed["Input", String.self]
        let oldOutcomes = old.detailed[EvalMetric.outcome.name, String.self]
        var before: [String: Outcome] = [:]
        for i in 0..<old.detailed.rows.count {
            if let input = oldInputs[i], let metric = oldOutcomes[i], let e = earlierOutcome(input: input, metric: metric) {
                before[e.id] = e.outcome
            }
        }
        if before.isEmpty { print("  earlier run \(previous.lastPathComponent) has no readable outcomes"); return }
        let changed = rows.compactMap { row in before[row.sample.item.id].flatMap { $0 == row.outcome ? nil : (row, $0) } }
        for (row, was) in changed {
            print("  \(row.sample.item.id): \(was.label) → \(row.outcome.label) \(row.outcome > was ? "(better)" : "(WORSE)")")
        }
        if changed.isEmpty { print("  no outcome changed") }
    }

    /// The qualitative report of a golden run (spec §8.7), written next to the saved result.
    static func goldenReport(_ result: EvaluationResult, _ evaluation: GoldenEvaluation, chapter: IndexedChapter, ctrl: UnderlineCtrl,
                          kind: String, saved: URL) async throws -> URL {
        let inputs = result.detailed[evaluation.inputColumn]
        let responses = result.detailed[evaluation.responseColumn]
        let judged = result.detailed[metric: EvalMetric.explains]
        var outcomes: [String: Outcome] = [:]
        var judge: [String: (verdict: String, rationale: String)] = [:]
        for i in 0..<result.detailed.rows.count {
            guard let s = inputs[i], let r = responses[i]?.value else { continue }
            outcomes[s.item.id] = r.outcome
            if let j = judged[i], j.value == .passing || j.value == .failing, let phrase = r.phrase {
                judge["\(s.resolved.sentence):\(phrase)"] = (j.value == .passing ? "pass" : "fail", j.rationale ?? "")
            }
        }
        let (_, records) = await evaluation.run.result()
        let run = RunInfo(runID: saved.deletingPathExtension().lastPathComponent, runKind: kind,
                          searchMode: ctrl.searchMode.rawValue)
        let rows = QualitativeReport.rows(run: run, chapter: chapter, records: records, gold: evaluation.samples.map(\.resolved),
                                       outcomes: outcomes, judge: judge)
        return try saveReport(rows, run: run, beside: saved)
    }

    /// One golden run: evaluate, save, print the report. Returns the result and where it was saved.
    static func golden(model: ModelChoice, search: SearchMode, kind: (UnderlineCtrl) -> String,
                       printReport: Bool = true) async throws -> (EvaluationResult, GoldenEvaluation, URL) {
        let (ctrl, chapter, gold) = try await load(model: model, search: search)
        let (judge, judgeName) = await judgeModel()
        let evaluation = GoldenEvaluation(gold: gold, ctrl: ctrl, chapter: chapter, judgeModel: judge)
        #expect(evaluation.samples.count == gold.items.count, "some golden items are stale (sentence text or phrase not found)")
        let result = try await evaluation.run(info: info(ctrl, chapter, judge: judgeName))
        let (saved, previous) = try save(result, kind: kind(ctrl))
        print("\n\(result.groupedSummary)\nsaved: \(saved.path)\nrun errors: \(result.errors)")
        let reportFile = try await goldenReport(result, evaluation, chapter: chapter, ctrl: ctrl, kind: kind(ctrl), saved: saved)
        print("qualitative report: \(reportFile.path)")
        if printReport { await report(result, evaluation, previous: previous) }
        #expect(result.aggregateValue(.mean(of: EvalMetric.noSpoiler)) == 1, "a sentence at or after the underlined one was used")
        return (result, evaluation, saved)
    }
}

@available(macOS 27, *)
@Test(.enabled(if: Evals.enabled), .timeLimit(.minutes(60)))
func goldenEvaluation() async throws {
    _ = try await Evals.golden(model: .automatic, search: .both, kind: { "golden-\($0.usesModel ? "model" : "rules")" })
}

@available(macOS 27, *)
@Test(.enabled(if: Evals.enabled), .timeLimit(.minutes(30)))
func rulesBaselineEvaluation() async throws {
    _ = try await Evals.golden(model: .rulesOnly, search: .both, kind: { _ in "golden-rules" })
}

@available(macOS 27, *)
@Test(.enabled(if: Evals.enabled), .timeLimit(.minutes(180)))
func searchModeComparison() async throws {
    var lines = ["search  cand. recall  mismatch  precision  recall  judge pass"]
    var recall: [SearchMode: Double] = [:]
    for mode in SearchMode.allCases {
        let (result, _, _) = try await Evals.golden(model: .automatic, search: mode,
                                                    kind: { _ in "search-\(mode.rawValue)" }, printReport: false)
        recall[mode] = result.aggregateValue(.mean(of: EvalMetric.candidateRecall))
        lines.append([mode.rawValue.padding(toLength: 7, withPad: " ", startingAt: 0),
                      Evals.mean(result, EvalMetric.candidateRecall).padding(toLength: 13, withPad: " ", startingAt: 0),
                      Evals.mean(result, EvalMetric.mismatch).padding(toLength: 9, withPad: " ", startingAt: 0),
                      Evals.mean(result, EvalMetric.referencePrecision).padding(toLength: 10, withPad: " ", startingAt: 0),
                      Evals.mean(result, EvalMetric.underlineRecall).padding(toLength: 7, withPad: " ", startingAt: 0),
                      Evals.mean(result, EvalMetric.explains)].joined(separator: " "))
    }
    let words = recall[.words] ?? 0
    if (recall[.embed] ?? 0) <= words, (recall[.both] ?? 0) <= words {
        print("\nNOTE: embed and both don't beat words on candidate recall: take these numbers to the product owner before tuning (spec §8.1).")
    }
    print("\n" + lines.joined(separator: "\n"))
}

@available(macOS 27, *)
@Test(.enabled(if: Evals.sweepEnabled), .timeLimit(.minutes(240)))
func sweepEvaluation() async throws {
    let (ctrl, chapter, _) = try await Evals.load(model: .automatic, search: .both)
    let (judge, judgeName) = await Evals.judgeModel()
    let limit = ProcessInfo.processInfo.environment["UNDERLINE_SWEEP_LIMIT"].flatMap(Int.init)
    let swept = chapter.sentences.prefix(limit ?? chapter.sentences.count).map(\.index)
    let (underlines, records) = await ChapterRun(ctrl: ctrl, chapter: chapter, sentences: Set(swept)).result()
    // The spoiler check covers every phrase considered, not only the underlines shown.
    let leaks = records.filter { r in r.candidates.contains { $0 >= r.sentence } || r.promptSentences.contains { $0 > r.sentence } }
    #expect(leaks.isEmpty, "spoiler in \(leaks.map { "S\($0.sentence) \"\($0.phrase)\"" })")

    let evaluation = SweepEvaluation(chapter: chapter, underlines: underlines, records: records, judgeModel: judge)
    let result = try await evaluation.run(info: Evals.info(ctrl, chapter, judge: judgeName))
    let kind = "sweep-\(ctrl.usesModel ? "model" : "rules")\(limit.map { "-first\($0)" } ?? "")"
    let (saved, _) = try Evals.save(result, kind: kind)
    print("\n\(result.groupedSummary)\nsaved: \(saved.path)")

    let sentencesSwept = Set(records.map(\.sentence)).union(swept).count
    let perSentence = Dictionary(grouping: underlines.underlines, by: \.sentence).mapValues(\.count)
    print("\n== Density ==\n  \(underlines.underlines.count) underlines over \(sentencesSwept) sentences: "
          + String(format: "%.1f per 100 sentences", 100 * Double(underlines.underlines.count) / Double(max(sentencesSwept, 1)))
          + " · sentences with more than one: \(perSentence.values.filter { $0 > 1 }.count)")

    // Every underline that would be shown, judge failures first, then by position.
    let inputs = result.detailed[evaluation.inputColumn]
    let judged = result.detailed[metric: EvalMetric.explains]
    let rows = (0..<result.detailed.rows.count).compactMap { i in inputs[i].map { ($0, judged[i]) } }
    var verdicts: [String: (verdict: String, rationale: String)] = [:]
    for (s, j) in rows where j?.value == .passing || j?.value == .failing {
        verdicts[s.key] = (j?.value == .passing ? "pass" : "fail", j?.rationale ?? "")
    }
    let run = RunInfo(runID: saved.deletingPathExtension().lastPathComponent, runKind: kind,
                      searchMode: ctrl.searchMode.rawValue)
    let reportFile = try Evals.saveReport(QualitativeReport.rows(run: run, chapter: chapter, records: records, gold: nil, outcomes: [:], judge: verdicts),
                                      run: run, beside: saved)
    print("qualitative report: \(reportFile.path)")
    print("\n== Underlines, judge failures first ==")
    for (s, verdict) in rows.sorted(by: { a, b in
        let fa = a.1?.value == .failing, fb = b.1?.value == .failing
        return fa != fb ? fa : a.0.sentence < b.0.sentence
    }) {
        let r = evaluation.results[s.key]
        print("\(verdict?.value == .failing ? "✗" : "✓") S\(s.sentence) \"\(s.phrase)\" → S\(r?.referenceSentence ?? -1) \"\(r?.referenceText ?? "")\"")
        if verdict?.value == .failing { print("    judge: \(verdict?.rationale ?? "")") }
    }
    #expect(result.aggregateValue(.mean(of: EvalMetric.noSpoiler)) == 1)
}
