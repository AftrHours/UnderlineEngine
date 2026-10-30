import Evaluations
import Foundation
import FoundationModels
@testable import UnderlineEngine

/// The metrics of spec §8.6, by name. Each evaluator returns one of these; `.ignore` when it doesn't apply.
@available(macOS 27, *)
enum EvalMetric {
    /// 1 for a mismatched underline, 0 for a right one, ignored where nothing was shown: its mean is the mismatch rate.
    static let mismatch = Metric("mismatch rate")
    static let noSpoiler = Metric("no spoiler")
    static let outcome = Metric("outcome")
    static let referencePrecision = Metric("reference precision")
    static let underlineRecall = Metric("underline recall")
    static let phraseAccuracy = Metric("phrase accuracy")
    static let candidateRecall = Metric("candidate recall")
    static let confirmAgreement = Metric("confirm agreement")
    static let searchMs = Metric("search ms")
    static let pickMs = Metric("pick ms")
    static let confirmMs = Metric("confirm ms")
    static let explains = Metric("explains the phrase")

    /// The judge's metric under our name, so it's aggregated and read back by name. A score of 0.5 or more is a pass.
    static func renamed(_ metric: Metric, as name: Metric) -> Metric {
        switch metric.value {
        case .passing: name.passing(rationale: metric.rationale)
        case .failing: name.failing(rationale: metric.rationale)
        case .ignore: name.ignore(rationale: metric.rationale)
        case .scoring(let v): v >= 0.5 ? name.passing(rationale: metric.rationale) : name.failing(rationale: metric.rationale)
        @unknown default: name.ignore(rationale: metric.rationale)
        }
    }

    static let deterministic = [mismatch, noSpoiler, outcome, referencePrecision, underlineRecall, phraseAccuracy, candidateRecall,
                                confirmAgreement, searchMs, pickMs, confirmMs]
}

/// The §4.3 definition, as the model judge's pass and fail descriptions.
enum JudgeText {
    static let pass = "The passage names the same person, thing, place or situation as the underlined phrase, or gives the cause, goal or earlier event the phrase depends on."
    static let fail = "The passage only shares the topic or uses similar words; a reader shown it would still not know why or what the phrase is about."
}

/// One golden item as an Evaluations sample. The prompt is what the model judge reads.
@available(macOS 27, *)
struct GoldSample: ModelSampleProtocol {
    let resolved: ResolvedItem
    let sentenceText: String
    let expectedTexts: [String]

    var item: GoldItem { resolved.item }
    var input: ModelSampleInput {
        ModelSampleInput(prompt: Prompt("A reader of a novel is skimming. In this sentence: \"\(sentenceText)\"\nthe phrase \"\(item.phrase)\" is underlined."))
    }
    var output: ModelSampleOutput<EngineResult, String> { ModelSampleOutput(value: expected) }
    var expected: EngineResult? { EngineResult.expectation(item.expected, texts: expectedTexts) }
}

/// Runs the engine once over the paragraphs holding the given sentences, and hands every sample its share.
actor ChapterRun {
    private let ctrl: UnderlineCtrl
    private let chapter: IndexedChapter
    private let sentences: Set<Int>
    private var cached: (ChapterUnderlines, [UnderlineRecord])?

    init(ctrl: UnderlineCtrl, chapter: IndexedChapter, sentences: Set<Int>) {
        self.ctrl = ctrl
        self.chapter = chapter
        self.sentences = sentences
    }

    func result() async -> (ChapterUnderlines, [UnderlineRecord]) {
        if let cached { return cached }
        let clock = ContinuousClock()
        let start = clock.now
        var underlines: [Underline] = []
        var records: [UnderlineRecord] = []
        let paragraphs = UnderlineCtrl.paragraphs(of: chapter).filter { p in p.contains { sentences.contains($0.index) } }
        for (i, paragraph) in paragraphs.enumerated() {
            let (u, r) = await ctrl.underlines(paragraphsHolding: Set(paragraph.map(\.index)), in: chapter)
            underlines += u.underlines
            records += r
            // Progress goes to stderr so it shows up straight away, even when the output is redirected to a file.
            let seconds = (clock.now - start).components.seconds
            FileHandle.standardError.write(Data("paragraph \(i + 1) of \(paragraphs.count) · \(records.count) phrases · \(underlines.count) underlines · \(seconds) s\n".utf8))
        }
        let out = (ChapterUnderlines(chapterIndex: chapter.chapterIndex, underlines: underlines), records)
        cached = out
        return out
    }
}

/// The golden set run through the engine (spec §8.2–8.6), on Apple's Evaluations framework.
@available(macOS 27, *)
struct GoldenEvaluation: Evaluation {
    let samples: [GoldSample]
    let run: ChapterRun
    let judge: ModelJudgeEvaluator<GoldSample>

    init(gold: GoldSet, ctrl: UnderlineCtrl, chapter: IndexedChapter, judgeModel: any LanguageModel) {
        samples = gold.items.compactMap { item in
            guard let r = item.resolve(in: chapter), let s = chapter.sentence(r.sentence) else { return nil }
            return GoldSample(resolved: r, sentenceText: s.text, expectedTexts: r.references.compactMap { chapter.sentence($0)?.text })
        }
        run = ChapterRun(ctrl: ctrl, chapter: chapter, sentences: Set(samples.map(\.resolved.sentence)))
        judge = ModelJudgeEvaluator(EvalMetric.explains.name,
            scale: .passFail(passDescription: JudgeText.pass, failDescription: JudgeText.fail),
            judge: judgeModel,
            prompt: ModelJudgePrompt(evaluationTarget: { "Earlier passage shown when the reader taps the phrase: \"\($0.referenceText ?? "")\"" }))
    }

    var dataset: ArrayLoader<GoldSample> { ArrayLoader(samples: samples) }

    func subject(from sample: GoldSample) async throws -> ModelSubject<EngineResult> {
        let (underlines, records) = await run.result()
        var result = EngineResult.from(item: sample.resolved, underlines: underlines, records: records)
        result.outcome = OutcomeClassifier.classify(sample.resolved, underlines: underlines, records: records)
        return ModelSubject(value: result)
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        for metric in EvalMetric.deterministic + [EvalMetric.explains] { aggregator.computeMean(of: metric) }
    }

    @EvaluatorsBuilder<GoldSample, ModelSubject<EngineResult>>
    var evaluators: [any EvaluatorProtocol<GoldSample, ModelSubject<EngineResult>>] {
        Evaluator<GoldSample> { _, subject in
            switch subject.value.outcome {
            case .mismatch?: EvalMetric.mismatch.scoring(1, rationale: "reference S\(subject.value.referenceSentence ?? -1)")
            case .underlinedRight?: EvalMetric.mismatch.scoring(0)
            default: EvalMetric.mismatch.ignore()
            }
        }
        Evaluator<GoldSample> { s, subject in
            guard let used = subject.value.highestUsed, used >= s.resolved.sentence else { return EvalMetric.noSpoiler.passing() }
            return EvalMetric.noSpoiler.failing(rationale: "used S\(used) at or after S\(s.resolved.sentence)")
        }
        Evaluator<GoldSample> { _, subject in
            guard let outcome = subject.value.outcome else { return EvalMetric.outcome.ignore() }
            return outcome.isGood ? EvalMetric.outcome.passing(rationale: outcome.label) : EvalMetric.outcome.failing(rationale: outcome.label)
        }
        Evaluator<GoldSample> { s, subject in
            guard s.item.expected.isAnswerable, subject.value.underlined, let ref = subject.value.referenceSentence else {
                return EvalMetric.referencePrecision.ignore()
            }
            return s.resolved.references.contains(ref) ? EvalMetric.referencePrecision.passing() : EvalMetric.referencePrecision.failing(rationale: "S\(ref)")
        }
        Evaluator<GoldSample> { s, subject in
            guard s.item.expected.isAnswerable else { return EvalMetric.underlineRecall.ignore() }
            return subject.value.outcome == .underlinedRight ? EvalMetric.underlineRecall.passing()
                : EvalMetric.underlineRecall.failing(rationale: subject.value.outcome?.label)
        }
        Evaluator<GoldSample> { s, subject in
            guard subject.value.underlined, let phrase = subject.value.phrase else { return EvalMetric.phraseAccuracy.ignore() }
            let a = TextMatch.normalized(phrase), b = TextMatch.normalized(s.item.phrase)
            return EvalMetric.phraseAccuracy.scoring(Double(min(a.count, b.count)) / Double(max(a.count, b.count, 1)), rationale: "\"\(phrase)\"")
        }
        Evaluator<GoldSample> { s, subject in
            guard s.item.expected.isAnswerable, !subject.value.candidates.isEmpty || subject.value.dropped == DropReason.noCandidate.rawValue else {
                return EvalMetric.candidateRecall.ignore()
            }
            return subject.value.candidates.contains(where: s.resolved.references.contains) ? EvalMetric.candidateRecall.passing()
                : EvalMetric.candidateRecall.failing(rationale: subject.value.candidates.map { "S\($0)" }.joined(separator: " "))
        }
        Evaluator<GoldSample> { s, subject in
            guard s.item.expected.isAnswerable, subject.value.dropped == DropReason.confirmRejected.rawValue, let picked = subject.value.pickedSentence else {
                return EvalMetric.confirmAgreement.ignore()
            }
            return s.resolved.references.contains(picked) ? EvalMetric.confirmAgreement.failing(rationale: "rejected a right pick S\(picked)")
                : EvalMetric.confirmAgreement.passing(rationale: "rejected a wrong pick S\(picked)")
        }
        Evaluator<GoldSample> { _, subject in subject.value.searchMs.map { EvalMetric.searchMs.scoring(Double($0)) } ?? EvalMetric.searchMs.ignore() }
        Evaluator<GoldSample> { _, subject in subject.value.pickMs.map { EvalMetric.pickMs.scoring(Double($0)) } ?? EvalMetric.pickMs.ignore() }
        Evaluator<GoldSample> { _, subject in subject.value.confirmMs.map { EvalMetric.confirmMs.scoring(Double($0)) } ?? EvalMetric.confirmMs.ignore() }
        // The model judge only grades rows where an underline was shown: there's nothing else to grade.
        Evaluator<GoldSample> { [judge] s, subject in
            guard subject.value.underlined else { return EvalMetric.explains.ignore(rationale: "no underline to judge") }
            guard let verdict = try await judge.metrics(subject: subject, input: s).first else {
                return EvalMetric.explains.ignore(rationale: "judge gave no score")
            }
            return EvalMetric.renamed(verdict, as: EvalMetric.explains)
        }
    }
}
