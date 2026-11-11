import Foundation

extension UnderlineCtrl {
    /// One candidate phrase through search → confirm the top candidate → guards (spec §5.4–5.5). The limiter runs later, per paragraph.
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

        // Pick: the model path takes search's top candidate; the rules path picks by score and margin.
        let picked: Int?
        if modelSvc.isAvailable {
            record.path = .model
            picked = candidates.first?.sentence
        } else {
            record.path = .rules
            picked = RulesPicker.decide(result.ranking, mode: result.modeUsed)
        }
        guard let pick = picked, let ref = chapter.sentence(pick) else { return drop(.pickedNone) }
        record.pickedSentence = pick
        if UnderlineGuard.isInSameParagraph(ref, as: sentence) { return drop(.explainedInParagraph) }

        // Confirm: does this one earlier sentence explain the phrase?
        if modelSvc.isAvailable {
            if let reason = await modelConfirm(candidate, sentence: sentence, reference: ref, record: &record) { return drop(reason) }
        } else {
            let explains = RulesPicker.confirm(phrase: candidate.phrase, in: sentence, reference: ref)
            record.confirm = ConfirmTrace(explains: explains, evidence: nil)
            guard explains else { return drop(.confirmRejected) }
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
    /// Returns the drop reason, or `nil` when the model says the passage explains the phrase.
    private func modelConfirm(_ candidate: UnderlineCandidate, sentence: IndexedSentence, reference ref: IndexedSentence,
                              record: inout UnderlineRecord) async -> DropReason? {
        let clock = ContinuousClock()
        let me = IndexedText(index: sentence.index, text: sentence.text)
        let passage = IndexedText(index: ref.index, text: ref.text)
        record.promptSentences = [passage.index, me.index].sorted()
        let start = clock.now
        defer { record.times.confirmMs = Self.milliseconds(clock.now - start) }
        guard let confirm = try? await modelSvc.confirm(phrase: candidate.phrase.text, sentence: me, passage: passage)
        else { return .modelFailed }
        record.confirm = ConfirmTrace(explains: confirm.explains, evidence: confirm.evidence)
        return confirm.explains ? nil : .confirmRejected
    }
}
