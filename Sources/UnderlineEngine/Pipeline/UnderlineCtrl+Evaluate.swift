import Foundation

extension UnderlineCtrl {
    /// One candidate phrase through search → rules pick and confirm → (with Foundation Models) the model's confirm → guards (spec §5.4–5.5). The limiter runs later, per paragraph.
    func evaluate(_ candidate: UnderlineCandidate, in chapter: IndexedChapter) async -> (KeptUnderline?, UnderlineRecord) {
        let clock = ContinuousClock()
        var record = UnderlineRecord(chapterIndex: chapter.chapterIndex, sentence: candidate.sentence, phrase: candidate.phrase.text,
                                     kind: candidate.kind, path: nil, searchModeUsed: nil, embedding: chapter.embedding,
                                     candidates: [], promptSentences: [], pickedSentence: nil, confirm: nil, kept: false,
                                     dropped: nil, times: StepTimes(), phraseRange: candidate.phrase.range,
                                     candidateScores: [])
        func drop(_ reason: DropReason) -> (KeptUnderline?, UnderlineRecord) {
            record.dropped = reason
            return (nil, record)
        }
        guard let sentence = chapter.sentence(candidate.sentence) else { return drop(.noCandidate) }

        let searchStart = clock.now
        let query = SearchQuery.make(candidate: candidate, in: sentence, embedding: embeddingSvc, tagger: indexSvc)
        let result = CandidateScorer.rank(query, in: chapter, before: candidate.sentence, mode: searchMode)
        let candidates = UnderlineSearch.candidates(result)
        record.searchModeUsed = result.modeUsed
        record.candidates = candidates.map(\.sentence)
        record.candidateScores = candidates.map(\.rawScore)
        record.times.searchMs = Self.milliseconds(clock.now - searchStart)
        guard !candidates.isEmpty else { return drop(.noCandidate) }

        // Pick and confirm by rules on both paths: no stub reference, a clear top score, a shared rare word or name.
        // With Foundation Models the model then has the last word on what the rules accepted; it can only take away.
        record.path = modelSvc.isAvailable ? .model : .rules
        let ranking = result.ranking.filter { chapter.sentence($0.sentence).map { !UnderlineGuard.isStub($0) } ?? false }
        guard let pick = RulesPicker.decide(ranking, mode: result.modeUsed), let ref = chapter.sentence(pick) else { return drop(.pickedNone) }
        record.pickedSentence = pick
        if UnderlineGuard.isInSameParagraph(ref, as: sentence) { return drop(.explainedInParagraph) }

        let explains = RulesPicker.confirm(phrase: candidate.phrase, in: sentence, reference: ref, stats: chapter.wordStats)
        record.confirm = ConfirmTrace(explains: explains, evidence: nil)
        guard explains else { return drop(.confirmRejected) }
        if modelSvc.isAvailable, let reason = await modelConfirm(candidate, sentence: sentence, reference: ref, stats: chapter.wordStats, record: &record) {
            return drop(reason)
        }

        guard pick < candidate.sentence, let range = UnderlineGuard.paragraphRange(of: candidate.phrase, in: sentence)
        else { return drop(.guardRejected) }
        let underline = Underline(sentence: sentence.index, paragraph: sentence.paragraph, range: range, text: candidate.phrase.text,
                                  kind: candidate.kind, role: candidate.phrase.role,
                                  reference: AnswerPassage(sentence: ref.index, paragraph: ref.paragraph, range: ref.range, text: ref.text),
                                  decidedBy: record.path ?? .rules)
        record.kept = true
        let score = result.ranking.first { $0.sentence == pick }?.rawScore ?? 0
        return (KeptUnderline(underline: underline, score: score), record)
    }

    /// One model call: the phrase, its sentence and the one earlier passage. Both sentence indexes go into the record before the call.
    /// Returns the drop reason, or `nil` when the model says the passage is linked (and, when its evidence is meant as a quote,
    /// the quote is in the passage). The words the rules found in both go into the prompt as an anchor.
    private func modelConfirm(_ candidate: UnderlineCandidate, sentence: IndexedSentence, reference ref: IndexedSentence,
                              stats: WordStats?, record: inout UnderlineRecord) async -> DropReason? {
        let clock = ContinuousClock()
        let me = IndexedText(index: sentence.index, text: sentence.text)
        let passage = IndexedText(index: ref.index, text: ref.text)
        record.promptSentences = [passage.index, me.index].sorted()
        let start = clock.now
        defer { record.times.confirmMs = Self.milliseconds(clock.now - start) }
        let shared = RulesPicker.sharedRareWords(phrase: candidate.phrase, in: sentence, reference: ref, stats: stats)
        guard let confirm = try? await modelSvc.confirm(phrase: candidate.phrase.text, sentence: me, passage: passage, shared: shared)
        else { return .modelFailed }
        record.confirm = ConfirmTrace(explains: confirm.explains, evidence: confirm.evidence)
        guard confirm.explains else { return .confirmRejected }
        guard confirm.isQuote else { return nil }
        return UnderlineGuard.quotes(confirm.evidence, from: PromptBuilder.cut(passage.text)) ? nil : .evidenceNotInPassage
    }
}
