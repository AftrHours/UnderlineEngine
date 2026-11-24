import Foundation

extension UnderlineCtrl {
    /// One candidate phrase through search → pick → confirm → guards (spec §5.4–5.5). The limiter runs later, per paragraph.
    func evaluate(_ candidate: UnderlineCandidate, in chapter: IndexedChapter) async -> (KeptUnderline?, UnderlineRecord) {
        let clock = ContinuousClock()
        var record = UnderlineRecord(chapterIndex: chapter.chapterIndex, sentence: candidate.sentence, phrase: candidate.phrase.text,
                                     kind: candidate.kind, embedding: chapter.embedding, phraseRange: candidate.phrase.range)
        func drop(_ reason: DropReason) -> (KeptUnderline?, UnderlineRecord) {
            record.dropped = reason
            return (nil, record)
        }
        guard let sentence = chapter.sentence(candidate.sentence) else { return drop(.noCandidate) }

        // Search: every earlier sentence of the chapter, ranked by shared rare words; stubs can't be references.
        let searchStart = clock.now
        let query = SearchQuery.make(candidate: candidate, in: sentence, tagger: indexSvc)
        let ranking = CandidateScorer.rank(query, in: chapter, before: candidate.sentence)
            .filter { chapter.sentence($0.sentence).map { !UnderlineGuard.isStub($0) } ?? false }
        let ordered = RulesPicker.evidenceOrder(ranking)
        record.candidates = ordered.map(\.sentence)
        record.candidateScores = ordered.map(\.rawWords)
        record.searchMs = Self.milliseconds(clock.now - searchStart)

        // Pick: the first candidate, by evidence order, outside the phrase's own paragraph.
        guard !ordered.isEmpty else { return drop(.pickedNone) }
        guard let pick = ordered.first(where: { $0.sentence < candidate.sentence }),
              let ref = chapter.sentence(pick.sentence) else { return drop(.pickedNone) }
        record.pickedSentence = pick.sentence
        if UnderlineGuard.isInSameParagraph(ref, as: sentence) { return drop(.explainedInParagraph) }

        // Confirm: evidence points against a bar that rises with distance.
        let explains = RulesPicker.evidencePoints(phrase: candidate.phrase, in: sentence, reference: ref, stats: chapter.wordStats) {
            RulesPicker.softMatch(phrase: candidate.phrase, in: sentence, reference: ref, stats: chapter.wordStats)
        }
        record.confirmed = explains
        guard explains else { return drop(.confirmRejected) }

        guard let range = UnderlineGuard.paragraphRange(of: candidate.phrase, in: sentence) else { return drop(.guardRejected) }
        let underline = Underline(sentence: sentence.index, paragraph: sentence.paragraph, range: range, text: candidate.phrase.text,
                                  kind: candidate.kind, role: candidate.phrase.role,
                                  reference: AnswerPassage(sentence: ref.index, paragraph: ref.paragraph, range: ref.range, text: ref.text),
                                  decidedBy: .rules)
        record.kept = true
        return (KeptUnderline(underline: underline, score: pick.rawWords), record)
    }
}
