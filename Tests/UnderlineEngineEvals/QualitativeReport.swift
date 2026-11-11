import Foundation
@testable import UnderlineEngine

/// Which run a report row comes from.
struct RunInfo: Sendable {
    let runID: String
    let runKind: String
    let searchMode: String
}

/// One phrase in the qualitative report (spec §8.7): one value per column, in `header` order.
struct QualitativeRow: Sendable {
    static let header = [
        "run_id", "run_kind", "search_mode", "gold_id",
        "sentence", "paragraph", "sentence_text", "sentence_with_underline", "phrase", "phrase_range",
        "tagging_engine", "words", "names", "events", "phrase_role", "kind",
        "embedding", "search_mode_used", "candidates", "top_candidate_text",
        "path", "pick", "picked_sentence", "confirm", "confirm_evidence",
        "underlined", "dropped_reason", "reference", "reference_text", "distance",
        "expected", "outcome", "miss_cause", "judge", "judge_rationale",
        "search_ms", "confirm_ms"
    ]

    let values: [String]
    /// Worst first: the outcome's rank, else a judge failure, else last.
    let sortRank: Int
    let sentence: Int
    let phrase: String

    /// The value of one `header` column.
    subscript(_ column: String) -> String {
        QualitativeRow.header.firstIndex(of: column).map { values[$0] } ?? ""
    }
}

/// Builds and writes the qualitative report (spec §8.7) as Markdown. Written by the harness only.
enum QualitativeReport {
    /// One row per phrase considered (kept or dropped), plus one per golden item the engine never considered.
    /// `outcomes` is keyed by golden item id; `judge` by `"<sentence>:<phrase>"` of the record.
    static func rows(run: RunInfo, chapter: IndexedChapter, records: [UnderlineRecord], gold: [ResolvedItem]?,
                     outcomes: [String: Outcome], judge: [String: (verdict: String, rationale: String)]) -> [QualitativeRow] {
        var used = Set<String>()
        var rows = records.map { record -> QualitativeRow in
            let item = gold?.first { $0.sentence == record.sentence && matches(record.phrase, $0.item) }
            if let item { used.insert(item.item.id) }
            return row(run: run, chapter: chapter, sentence: record.sentence, phrase: record.phrase, record: record, item: item,
                       outcome: item.flatMap { outcomes[$0.item.id] }, judge: judge["\(record.sentence):\(record.phrase)"])
        }
        for item in gold ?? [] where !used.contains(item.item.id) {
            rows.append(row(run: run, chapter: chapter, sentence: item.sentence, phrase: item.item.phrase, record: nil, item: item,
                            outcome: outcomes[item.item.id], judge: nil))
        }
        return rows.sorted { ($0.sortRank, $0.sentence, $0.phrase) < ($1.sortRank, $1.sentence, $1.phrase) }
    }

    /// The report: a summary, one section per underline shown (with boxes to tick when reviewing),
    /// then a table of every phrase not underlined. Rows keep the order `rows` gives them, worst first.
    static func markdown(_ rows: [QualitativeRow], run: RunInfo) -> String {
        let shown = rows.filter { $0["underlined"] == "yes" }
        let notShown = rows.filter { $0["underlined"] != "yes" }
        let golden = rows.contains { !$0["gold_id"].isEmpty }
        let pass = shown.filter { $0["judge"] == "pass" }.count, fail = shown.filter { $0["judge"] == "fail" }.count

        var out = ["# \(run.runID)", ""]
        out.append("Run `\(run.runKind)` · search `\(run.searchMode)` · \(rows.count) phrases · **\(shown.count) underlined**"
                   + (pass + fail > 0 ? " · judge \(pass) pass / \(fail) fail" : ""))
        out.append("")
        if golden {
            out += ["## Golden outcomes", "", "| Outcome | Items |", "|---|---|"]
            out += counts(rows.filter { !$0["gold_id"].isEmpty }.map { $0["outcome"] }).map { "| \($0.0) | \($0.1) |" }
            out.append("")
        }
        out += ["## Not underlined, by reason", "", "| Reason | Phrases |", "|---|---|"]
        out += counts(notShown.map { $0["dropped_reason"].isEmpty ? "never considered" : $0["dropped_reason"] })
            .map { "| `\($0.0)` | \($0.1) |" }

        out += ["", "## Underlined", "", "Tick one box per phrase and write a note if needed.", ""]
        if shown.isEmpty { out += ["None.", ""] }
        for r in shown { out += section(r) }

        out += ["## Not underlined", ""]
        if notShown.isEmpty {
            out.append("None.")
        } else {
            out += golden
                ? ["| S | Phrase | Reason | Top candidate | Expected | Outcome |", "|---|---|---|---|---|---|"]
                : ["| S | Phrase | Reason | Top candidate |", "|---|---|---|---|"]
            for r in notShown {
                var cells = [r["sentence"], r["phrase"], r["dropped_reason"].isEmpty ? "never considered" : "`\(r["dropped_reason"])`",
                             r["candidates"].split(separator: " ").first.map(String.init) ?? ""]
                if golden { cells += [r["expected"], r["outcome"]] }
                out.append("| " + cells.map(cell).joined(separator: " | ") + " |")
            }
        }
        return out.joined(separator: "\n") + "\n"
    }

    /// One underline: the sentence with the phrase in bold, its reference, why it was kept, and the review boxes.
    private static func section(_ r: QualitativeRow) -> [String] {
        var out = ["### S\(r["sentence"]) · \(r["phrase"])", ""]
        out.append(quote(r["sentence_with_underline"].replacingOccurrences(of: "[[", with: "**").replacingOccurrences(of: "]]", with: "**")))
        out += ["", "**Reference S\(r["reference"])**, \(r["distance"]) sentences earlier:", "", quote(r["reference_text"]), ""]
        if !r["gold_id"].isEmpty { out.append("- Golden `\(r["gold_id"])`: expected \(r["expected"]) · \(r["outcome"])") }
        out.append("- Kind `\(r["kind"])` · role `\(r["phrase_role"])` · path `\(r["path"])` · candidates \(r["candidates"])")
        if !r["confirm"].isEmpty { out.append("- Confirm: \(r["confirm"]) · \"\(r["confirm_evidence"])\"") }
        if !r["judge"].isEmpty { out.append("- Judge: **\(r["judge"])** · \(r["judge_rationale"])") }
        out.append("- Time: search \(r["search_ms"]) ms, confirm \(r["confirm_ms"].isEmpty ? "-" : r["confirm_ms"]) ms")
        out += ["", "<details><summary>NLTagger</summary>", "",
                "- Words: \(r["words"])", "- Names: \(r["names"].isEmpty ? "-" : r["names"])", "- Events: \(r["events"])",
                "", "</details>", ""]
        out += ["- [ ] right", "- [ ] wrong passage", "- [ ] shouldn't be underlined", "", "Note:", ""]
        return out
    }

    /// Each distinct value with how often it appears, most first.
    private static func counts(_ values: [String]) -> [(String, Int)] {
        Dictionary(grouping: values, by: { $0 }).map { ($0.key, $0.value.count) }.sorted { ($1.1, $0.0) < ($0.1, $1.0) }
    }

    /// A Markdown quote, every line prefixed.
    private static func quote(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { "> " + $0 }.joined(separator: "\n")
    }

    /// A table cell: pipes escaped, line breaks flattened.
    static func cell(_ text: String) -> String {
        text.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
    }

    private static func row(run: RunInfo, chapter: IndexedChapter, sentence index: Int, phrase: String, record: UnderlineRecord?,
                            item: ResolvedItem?, outcome: Outcome?, judge: (verdict: String, rationale: String)?) -> QualitativeRow {
        let s = chapter.sentence(index)
        let text = s?.text ?? item?.item.sentence.text ?? ""
        let range = record?.phraseRange ?? located(phrase, in: text)
        let phraseEvent = s?.events.first { $0.range == range } ?? s?.events.first { $0.text == phrase }
        let kept = record?.kept == true
        let reference = kept ? record?.pickedSentence : nil
        let picked = record?.pickedSentence
        let missCause: String = if case .missed(let c)? = outcome { c.label } else { "" }
        let expected: String = switch item?.item.expected {
        case .underline(let refs)?: "underline: " + refs.map { "S\($0)" }.joined(separator: " or ")
        case .none(let reason)?: "none: \(reason.rawValue)"
        case nil: ""
        }
        let values: [String] = [
            run.runID, run.runKind, run.searchMode, item?.item.id ?? "",
            "\(index)", s.map { "\($0.paragraph)" } ?? "", text, marked(text, range), phrase, range.map { "\($0.location)+\($0.length)" } ?? "",
            chapter.tagging.rawValue,
            s?.tokens.map { "\($0.text)/\($0.lemma)/\($0.wordClass)" }.joined(separator: " · ") ?? "",
            s?.names.map { "\($0.text) (\($0.kind.rawValue))" }.joined(separator: " · ") ?? "",
            s?.events.map { "\($0.text) (\($0.role?.rawValue ?? "name"))" }.joined(separator: " · ") ?? "",
            record == nil ? "" : (phraseEvent?.role?.rawValue ?? "name"), record?.kind.rawValue ?? item?.item.kind.rawValue ?? "",
            record?.embedding.rawValue ?? "", record?.searchModeUsed?.rawValue ?? "",
            record.map { r in r.candidates.enumerated().map { i, s in
                r.candidateScores.indices.contains(i) ? "S\(s):" + String(format: "%.2f", r.candidateScores[i]) : "S\(s)"
            }.joined(separator: " ") } ?? "",
            record?.candidates.first.flatMap { chapter.sentence($0)?.text } ?? "",
            record?.path?.rawValue ?? "",
            picked.flatMap { p in record?.candidates.firstIndex(of: p).map { "\($0 + 1)" } } ?? "",
            picked.map { "\($0)" } ?? "",
            record?.confirm.map { $0.explains ? "yes" : "no" } ?? "", record?.confirm?.evidence ?? "",
            record == nil ? "" : (kept ? "yes" : "no"), record?.dropped?.rawValue ?? "",
            reference.map { "\($0)" } ?? "", reference.flatMap { chapter.sentence($0)?.text } ?? "",
            reference.map { "\(index - $0)" } ?? "",
            expected, outcome?.label ?? "", missCause, judge?.verdict ?? "", judge?.rationale ?? "",
            record?.times.searchMs.map(String.init) ?? "", record?.times.confirmMs.map(String.init) ?? ""
        ]
        let rank = outcome?.rank ?? (judge?.verdict == "fail" ? 1 : 50)
        return QualitativeRow(values: values, sortRank: rank, sentence: index, phrase: phrase)
    }

    /// The sentence with the phrase wrapped in `[[…]]` at its range (the first occurrence when there's no range).
    private static func marked(_ text: String, _ range: NSRange?) -> String {
        let ns = text as NSString
        guard let range, range.location != NSNotFound, NSMaxRange(range) <= ns.length else { return text }
        return ns.replacingCharacters(in: range, with: "[[" + ns.substring(with: range) + "]]")
    }

    private static func located(_ phrase: String, in text: String) -> NSRange? {
        let r = (text as NSString).range(of: phrase, options: .caseInsensitive)
        return r.location == NSNotFound ? nil : r
    }
}

@available(macOS 27, *)
extension Evals {
    /// Writes the report next to the saved result, with the same base name.
    static func saveReport(_ rows: [QualitativeRow], run: RunInfo, beside json: URL) throws -> URL {
        let url = json.deletingPathExtension().appendingPathExtension("md")
        try QualitativeReport.markdown(rows, run: run).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
