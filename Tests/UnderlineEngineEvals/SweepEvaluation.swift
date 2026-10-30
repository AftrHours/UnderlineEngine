import Evaluations
import Foundation
import FoundationModels
@testable import UnderlineEngine

/// One underline the engine would show. There's no expected answer: the model judge pre-labels it for review.
@available(macOS 27, *)
struct SweepSample: ModelSampleProtocol {
    let sentence: Int
    let paragraph: Int
    let sentenceText: String
    let phrase: String

    var input: ModelSampleInput {
        ModelSampleInput(prompt: Prompt("A reader of a novel is skimming. In this sentence: \"\(sentenceText)\"\nthe phrase \"\(phrase)\" is underlined."))
    }
    var output: ModelSampleOutput<EngineResult, String> { ModelSampleOutput() }
    var expected: EngineResult? { nil }
    var key: String { "\(sentence):\(phrase)" }
}

/// Every underline the engine would show in the chapter (or its first sentences), judged one by one (spec §8.5).
@available(macOS 27, *)
struct SweepEvaluation: Evaluation {
    let samples: [SweepSample]
    let results: [String: EngineResult]
    let judge: ModelJudgeEvaluator<SweepSample>

    init(chapter: IndexedChapter, underlines: ChapterUnderlines, records: [UnderlineRecord], judgeModel: any LanguageModel) {
        var samples: [SweepSample] = []
        var results: [String: EngineResult] = [:]
        for u in underlines.underlines {
            guard let s = chapter.sentence(u.sentence) else { continue }
            let sample = SweepSample(sentence: u.sentence, paragraph: u.paragraph, sentenceText: s.text, phrase: u.text)
            var r = EngineResult()
            r.underlined = true
            r.phrase = u.text
            r.referenceSentence = u.reference.sentence
            r.referenceText = u.reference.text
            r.path = u.decidedBy.rawValue
            let inSentence = records.filter { $0.sentence == u.sentence }
            if let rec = inSentence.first(where: { $0.kept && $0.phrase == u.text }) { r.fill(from: rec) }
            r.highestUsed = inSentence.flatMap { $0.candidates + $0.promptSentences.filter { $0 != u.sentence } }.max()
            samples.append(sample)
            results[sample.key] = r
        }
        self.samples = samples
        self.results = results
        judge = ModelJudgeEvaluator(EvalMetric.explains.name,
            scale: .passFail(passDescription: JudgeText.pass, failDescription: JudgeText.fail),
            judge: judgeModel,
            prompt: ModelJudgePrompt(evaluationTarget: { "Earlier passage shown when the reader taps the phrase: \"\($0.referenceText ?? "")\"" }))
    }

    var dataset: ArrayLoader<SweepSample> { ArrayLoader(samples: samples) }

    func subject(from sample: SweepSample) async throws -> ModelSubject<EngineResult> {
        guard let r = results[sample.key] else { throw SubjectInferenceError.failed(reason: "no underline for \(sample.key)") }
        return ModelSubject(value: r)
    }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        aggregator.computeMean(of: EvalMetric.noSpoiler)
        aggregator.computeMean(of: EvalMetric.explains)
    }

    @EvaluatorsBuilder<SweepSample, ModelSubject<EngineResult>>
    var evaluators: [any EvaluatorProtocol<SweepSample, ModelSubject<EngineResult>>] {
        Evaluator<SweepSample> { s, subject in
            guard let used = subject.value.highestUsed, used >= s.sentence else { return EvalMetric.noSpoiler.passing() }
            return EvalMetric.noSpoiler.failing(rationale: "used S\(used) at or after S\(s.sentence)")
        }
        Evaluator<SweepSample> { [judge] s, subject in
            guard let verdict = try await judge.metrics(subject: subject, input: s).first else { return EvalMetric.explains.ignore() }
            return EvalMetric.renamed(verdict, as: EvalMetric.explains)
        }
    }
}
