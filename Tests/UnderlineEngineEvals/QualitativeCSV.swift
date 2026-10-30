import Foundation
@testable import UnderlineEngine

/// Which run a CSV row comes from.
struct RunInfo: Sendable {
    let runID: String
    let runKind: String
    let promptVariant: String
    let searchMode: String
}

/// One row of the qualitative analysis CSV (spec §8.7): one value per column, in `header` order.
struct QualitativeRow: Sendable {
    static let header = [
        "run_id", "run_kind", "prompt_variant", "search_mode", "gold_id",
        "sentence", "paragraph", "sentence_text", "sentence_with_underline", "phrase", "phrase_range",
        "tagging_engine", "words", "names", "events", "phrase_role", "kind",
        "embedding", "search_mode_used", "candidates", "top_candidate_text",
        "path", "pick", "picked_sentence", "pick_quote", "confirm", "confirm_evidence",
        "underlined", "dropped_reason", "reference", "reference_text", "distance",
        "expected", "outcome", "miss_cause", "judge", "judge_rationale",
        "search_ms", "pick_ms", "confirm_ms",
        "reviewer_verdict", "reviewer_note"
    ]

    let values: [String]
    /// Worst first: the outcome's rank, else a judge failure, else last.
    let sortRank: Int
    let sentence: Int
    let phrase: String
}

/// Builds and writes the qualitative analysis CSV (spec §8.7). Written by the harness only.
enum QualitativeCSV {
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

    /// UTF-8 with a byte-order mark (so Excel shows curly quotes), a header row, standard quoting.
    static func encode(_ rows: [QualitativeRow]) -> String {
        "\u{FEFF}" + ([line(QualitativeRow.header)] + rows.map { line($0.values) }).joined(separator: "\n") + "\n"
    }

    /// A field with a comma, quote or line break is quoted, inner quotes doubled.
    static func line(_ fields: [String]) -> String {
        fields.map { f in
            f.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) ? "\"" + f.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : f
        }.joined(separator: ",")
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
            run.runID, run.runKind, run.promptVariant, run.searchMode, item?.item.id ?? "",
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
            picked.map { "\($0)" } ?? "", record?.quote ?? "",
            record?.confirm.map { $0.explains ? "yes" : "no" } ?? "", record?.confirm?.evidence ?? "",
            record == nil ? "" : (kept ? "yes" : "no"), record?.dropped?.rawValue ?? "",
            reference.map { "\($0)" } ?? "", reference.flatMap { chapter.sentence($0)?.text } ?? "",
            reference.map { "\(index - $0)" } ?? "",
            expected, outcome?.label ?? "", missCause, judge?.verdict ?? "", judge?.rationale ?? "",
            record?.times.searchMs.map(String.init) ?? "", record?.times.pickMs.map(String.init) ?? "", record?.times.confirmMs.map(String.init) ?? "",
            "", ""
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
    /// Writes the CSV next to the saved result, with the same base name.
    static func saveCSV(_ rows: [QualitativeRow], beside json: URL) throws -> URL {
        let url = json.deletingPathExtension().appendingPathExtension("csv")
        try QualitativeCSV.encode(rows).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
