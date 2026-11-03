import Foundation

extension UnderlineCtrl {
    /// One candidate phrase through search → pick → confirm → guards (spec §5.4–5.5). The limiter runs later, per paragraph.
    func evaluate(_ candidate: UnderlineCandidate, in chapter: IndexedChapter) async -> (KeptUnderline?, UnderlineRecord) {
        let clock = ContinuousClock()
        var record = UnderlineRecord(chapterIndex: chapter.chapterIndex, sentence: candidate.sentence, phrase: candidate.phrase.text,
                                     kind: candidate.kind, path: nil, promptVariant: nil, searchModeUsed: nil, embedding: chapter.embedding,
                                     candidates: [], promptSentences: [], pickedSentence: nil, quote: nil, confirm: nil, kept: false,
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

        var reference: Int?
        if modelSvc.isAvailable {
            record.path = .model
            record.promptVariant = promptVariant
            switch await modelPath(candidate, sentence: sentence, candidates: candidates, in: chapter, record: &record) {
            case .accepted(let index): reference = index
            case .dropped(let reason): return drop(reason)
            case .fallBack: break
            }
        }
        if reference == nil {
            record.path = .rules
            guard let pick = RulesPicker.decide(result.ranking, mode: result.modeUsed), let ref = chapter.sentence(pick) else { return drop(.pickedNone) }
            record.pickedSentence = pick
            record.quote = nil
            if UnderlineGuard.isInSameParagraph(ref, as: sentence) { return drop(.explainedInParagraph) }
            let explains = RulesPicker.confirm(phrase: candidate.phrase, in: sentence, reference: ref)
            record.confirm = ConfirmTrace(explains: explains, evidence: nil)
            guard explains else { return drop(.confirmRejected) }
            reference = pick
        }

        guard let index = reference, index < candidate.sentence, let ref = chapter.sentence(index),
              let range = UnderlineGuard.paragraphRange(of: candidate.phrase, in: sentence) else { return drop(.guardRejected) }
        let underline = Underline(sentence: sentence.index, paragraph: sentence.paragraph, range: range, text: candidate.phrase.text,
                                  kind: candidate.kind, role: candidate.phrase.role,
                                  reference: AnswerPassage(sentence: ref.index, paragraph: ref.paragraph, range: ref.range, text: ref.text),
                                  decidedBy: record.path ?? .rules)
        record.kept = true
        let score = result.ranking.first { $0.sentence == index }?.rawScore ?? 0
        return (KeptUnderline(underline: underline, score: score), record)
    }

    private enum ModelOutcome {
        case accepted(Int)
        case dropped(DropReason)
        case fallBack
    }

    /// Pick (fitted to the token budget, halved and retried once on overflow), guard, then confirm the one pick.
    /// Every prompt's sentence indexes go into the record before the call.
    private func modelPath(_ candidate: UnderlineCandidate, sentence: IndexedSentence, candidates: [Candidate], in chapter: IndexedChapter,
                           record: inout UnderlineRecord) async -> ModelOutcome {
        let clock = ContinuousClock()
        let me = IndexedText(index: sentence.index, text: sentence.text)
        let texts = candidates.compactMap { c in chapter.sentence(c.sentence).map { IndexedText(index: $0.index, text: $0.text) } }
        let hint = PromptBuilder.roleHint(candidate.phrase.role)
        let fixed = PromptBuilder.pick(phrase: candidate.phrase.text, roleHint: hint, sentence: me, candidates: [], variant: promptVariant)
        var count = TokenBudget.fit(candidates: texts.map { PromptBuilder.cut($0.text) },
                                    budget: TokenBudget.available(contextSize: modelSvc.contextSize,
                                                                  fixedTokens: TokenBudget.estimate(fixed.instructions + fixed.prompt)),
                                    cost: TokenBudget.estimate)
        var picked: ModelPick?
        let pickStart = clock.now
        defer { record.times.pickMs = Self.milliseconds(clock.now - pickStart) }
        // Spec §5.5: on overflow halve and retry once, then the rules path. Any other failure drops the phrase.
        for attempt in 0..<2 where count > 0 && picked == nil {
            let sent = Array(texts.prefix(count))
            record.promptSentences = Array(Set(record.promptSentences).union([me.index] + sent.map(\.index))).sorted()
            do {
                picked = try await modelSvc.pick(phrase: candidate.phrase.text, roleHint: hint, sentence: me, candidates: sent, variant: promptVariant)
            } catch .exceededContext where attempt == 0 {
                count /= 2
            } catch .exceededContext {
                return .fallBack
            } catch {
                return .dropped(.modelFailed)
            }
        }
        guard let picked else { return .fallBack }

        let sent = Array(candidates.prefix(count))
        record.quote = picked.quote
        record.pickedSentence = sent.indices.contains(picked.candidate - 1) ? sent[picked.candidate - 1].sentence : nil
        switch UnderlineGuard.checkPick(pick: picked.candidate, quote: picked.quote, sent: sent, chapter: chapter, sentence: sentence.index) {
        case .none: return .dropped(.pickedNone)
        case .rejected: return .dropped(.guardRejected)
        case .accepted(let index):
            guard let ref = chapter.sentence(index) else { return .dropped(.guardRejected) }
            if UnderlineGuard.isInSameParagraph(ref, as: sentence) { return .dropped(.explainedInParagraph) }
            let passage = IndexedText(index: ref.index, text: ref.text)
            record.promptSentences = Array(Set(record.promptSentences).union([me.index, passage.index])).sorted()
            let confirmStart = clock.now
            defer { record.times.confirmMs = Self.milliseconds(clock.now - confirmStart) }
            guard let confirm = try? await modelSvc.confirm(phrase: candidate.phrase.text, sentence: me, passage: passage, variant: promptVariant)
            else { return .dropped(.modelFailed) }
            record.confirm = ConfirmTrace(explains: confirm.explains, evidence: confirm.evidence)
            return confirm.explains ? .accepted(index) : .dropped(.confirmRejected)
        }
    }
}
