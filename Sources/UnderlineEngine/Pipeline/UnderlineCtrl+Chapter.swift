import Foundation

extension UnderlineCtrl {
    /// Only the paragraphs holding these sentences, in order. Same result for them as the whole chapter, because the
    /// limiter is per paragraph. For the harness, which needs only the golden items' paragraphs.
    func underlines(paragraphsHolding sentences: Set<Int>, in chapter: IndexedChapter) async -> (ChapterUnderlines, [UnderlineRecord]) {
        let wanted = Set(sentences.compactMap { chapter.sentence($0)?.paragraph })
        var underlines: [Underline] = []
        var records: [UnderlineRecord] = []
        for paragraph in Self.paragraphs(of: chapter) where paragraph.first.map({ wanted.contains($0.paragraph) }) == true {
            let (shown, recs) = await pass(paragraph, in: chapter)
            underlines += shown.map(\.0)
            records += recs
        }
        return (ChapterUnderlines(chapterIndex: chapter.chapterIndex, underlines: underlines), records)
    }

    /// One result per paragraph, in reading order from the paragraph holding `sentence` (the first one when it's outside
    /// the chapter), to the end, then from the start. Each has its underlines and a record for every phrase considered
    /// (kept or dropped). Ends after the last paragraph, or when the consuming task is cancelled.
    public func paragraphResults(in chapter: IndexedChapter, startingAt sentence: Int) -> AsyncStream<ParagraphResult> {
        let ordered = Self.paragraphs(of: chapter, startingAt: sentence)
        return AsyncStream { continuation in
            let task = Task {
                for paragraph in ordered {
                    if Task.isCancelled { break }
                    let (shown, records) = await self.pass(paragraph, in: chapter)
                    continuation.yield(ParagraphResult(underlines: shown.map(\.0), records: records))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// One paragraph: detect, evaluate every candidate, then the limiter. The stream and the harness both use it,
    /// so they can't disagree. Returns each shown underline with its own record, and every record. Stops early when cancelled.
    private func pass(_ paragraph: [IndexedSentence], in chapter: IndexedChapter) async -> ([(Underline, UnderlineRecord)], [UnderlineRecord]) {
        var kept: [(KeptUnderline, Int)] = []
        var records: [UnderlineRecord] = []
        for sentence in paragraph {
            for candidate in UnderlineDetector.candidates(in: sentence, recentNames: Self.recentNames(before: sentence.index, in: chapter)) {
                if Task.isCancelled { return ([], []) }
                let (k, record) = await evaluate(candidate, in: chapter)
                if let k { kept.append((k, records.count)) }
                records.append(record)
            }
        }
        let shown = Self.limit(kept, records: &records, maxPerParagraph: UnderlineKnobs.maxPerParagraph)
        return (shown, records)
    }

    /// Applies the limiter and marks exactly the dropped records `densityLimit`. Each kept underline carries the position of
    /// its record, because ids and phrase texts can repeat within a sentence.
    static func limit(_ kept: [(KeptUnderline, Int)], records: inout [UnderlineRecord], maxPerParagraph: Int) -> [(Underline, UnderlineRecord)] {
        let result = UnderlineLimiter.apply(kept.map(\.0), maxPerParagraph: maxPerParagraph)
        for i in result.dropped {
            records[kept[i].1].kept = false
            records[kept[i].1].dropped = .densityLimit
        }
        let droppedSet = Set(result.dropped)
        let survivors = kept.indices.filter { !droppedSet.contains($0) }
        let order = { (u: Underline) in (u.sentence, u.range.location, u.range.length) }
        return survivors.map { (kept[$0].0.underline, records[kept[$0].1]) }.sorted { order($0.0) < order($1.0) }
    }

    /// The chapter's sentences grouped by paragraph, in order.
    static func paragraphs(of chapter: IndexedChapter) -> [[IndexedSentence]] {
        var out: [[IndexedSentence]] = []
        for sentence in chapter.sentences {
            if out.last?.last?.paragraph == sentence.paragraph { out[out.count - 1].append(sentence) } else { out.append([sentence]) }
        }
        return out
    }

    /// The chapter's paragraphs from the one holding `sentence` (the first one when it's outside the chapter), then wrapping.
    private static func paragraphs(of chapter: IndexedChapter, startingAt sentence: Int) -> [[IndexedSentence]] {
        let all = paragraphs(of: chapter)
        let start = chapter.sentence(sentence)?.paragraph
        let split = all.firstIndex { $0.first?.paragraph == start } ?? 0
        return Array(all[split...] + all[..<split])
    }

    /// Person names in the `UnderlineKnobs.nameGapSentences` sentences before `index` (earlier text only).
    static func recentNames(before index: Int, in chapter: IndexedChapter) -> Set<String> {
        let from = max(chapter.first, index - UnderlineKnobs.nameGapSentences)
        guard from < index else { return [] }
        return Set((from..<index).compactMap(chapter.sentence).flatMap { $0.names.filter { $0.kind == .person }.map(\.text) })
    }
}
