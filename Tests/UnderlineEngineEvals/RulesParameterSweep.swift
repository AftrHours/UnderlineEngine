import Foundation
import Testing
@testable import UnderlineEngine

/// One phrase, searched once, so many rule settings can be tried on it without searching again.
private struct SweepCase {
    let chapter: Int
    let paragraph: Int
    let sentence: IndexedSentence
    let phrase: EventPhrase
    /// Search found something above the floor (otherwise `noCandidate`, whatever the rules).
    let hasCandidate: Bool
    /// The full ranking, stubs removed, best first.
    let ranking: [Candidate]
}

private struct SweepSetting: Hashable {
    let minScore: Double
    let margin: Double
    let rareShare: Double
    let nounOrTwo: Bool
    let maxPerParagraph: Int
}

/// Parameter analysis for the rules path: searches every phrase of a book once, then replays pick, confirm and the
/// paragraph limit for a grid of settings, and scores each against Claude's labels in `Dataset/labels/claude-labels.csv`.
///
///     UNDERLINE_RULES_SWEEP=1 UNDERLINE_BOOK=little-women swift test --filter rulesParameterSweep
///     UNDERLINE_BOOK_EMBEDDING=apple …   (default: contextual)
///
/// Output: `Eval/results/rules-parameter-sweep-<embedding>/sweep.csv` and `sweep.md`.
@available(macOS 27, *)
@Test(.enabled(if: ProcessInfo.processInfo.environment["UNDERLINE_RULES_SWEEP"] != nil), .timeLimit(.minutes(240)))
func rulesParameterSweep() async throws {
    let env = ProcessInfo.processInfo.environment
    let book = env["UNDERLINE_BOOK"] ?? "little-women"
    let dir = Evals.root.appendingPathComponent("Dataset/\(book)")
    let index = try JSONDecoder().decode([BookChapter].self, from: Data(contentsOf: dir.appendingPathComponent("index.json")))
    let contextual = env["UNDERLINE_BOOK_EMBEDDING"] != "apple"

    let embedding: any EmbeddingSvc
    if contextual {
        guard let svc = await EmbeddingSvcContextual.make() else { Issue.record("NLContextualEmbedding is not available"); return }
        var sample: [String] = []
        for c in index {
            let text = try String(contentsOf: dir.appendingPathComponent(c.file), encoding: .utf8)
            sample += ChapterIndexSvc().index(ChapterInput(chapterIndex: c.number - 1, plainText: text)).enumerated()
                .filter { $0.offset % 5 == 0 }.map(\.element.text)
        }
        svc.center(on: sample)
        embedding = svc
    } else {
        embedding = EmbeddingSvcApple()
    }
    let indexSvc = ChapterIndexSvc()
    var chapters: [(Int, IndexedChapter)] = []
    for c in index {
        let text = try String(contentsOf: dir.appendingPathComponent(c.file), encoding: .utf8)
        chapters.append((c.number, await indexSvc.prepare(ChapterInput(chapterIndex: c.number - 1, plainText: text), embedding: embedding)))
    }
    let stats = WordStats(chapters: chapters.map(\.1))

    // Search every phrase once.
    var cases: [SweepCase] = []
    var chapterOf: [Int: IndexedChapter] = [:]
    for (number, var chapter) in chapters {
        chapter.wordStats = stats
        chapterOf[number] = chapter
        for sentence in chapter.sentences {
            for candidate in UnderlineDetector.candidates(in: sentence, recentNames: UnderlineCtrl.recentNames(before: sentence.index, in: chapter)) {
                let query = SearchQuery.make(candidate: candidate, in: sentence, embedding: embedding, tagger: indexSvc)
                let result = CandidateScorer.rank(query, in: chapter, before: sentence.index, mode: .both)
                let ranking = result.ranking.filter { chapter.sentence($0.sentence).map { !UnderlineGuard.isStub($0) } ?? false }
                cases.append(SweepCase(chapter: number, paragraph: sentence.paragraph, sentence: sentence, phrase: candidate.phrase,
                                       hasCandidate: !UnderlineSearch.candidates(result).isEmpty, ranking: ranking))
            }
        }
    }

    // Claude's labels: (chapter, sentence, phrase, reference) -> verdict.
    var labels: [String: String] = [:]
    let labelText = try String(contentsOf: Evals.root.appendingPathComponent("Dataset/labels/claude-labels.csv"), encoding: .utf8)
    for line in labelText.split(whereSeparator: \.isNewline).dropFirst() {
        let f = parseCSVLine(String(line))
        if f.count >= 5 { labels["\(f[0])|\(f[1])|\(f[2])|\(f[3])"] = f[4] }
    }

    var settings: [SweepSetting] = []
    for minScore in [0.50, 0.55, 0.60, 0.65, 0.70] {
        for margin in [0.0, 0.03, 0.05] {
            for rareShare in [0.004, 0.0085, 0.015, 0.03] {
                for nounOrTwo in [true, false] {
                    for maxPerParagraph in [1, 2, 99] {
                        settings.append(SweepSetting(minScore: minScore, margin: margin, rareShare: rareShare, nounOrTwo: nounOrTwo,
                                                     maxPerParagraph: maxPerParagraph))
                    }
                }
            }
        }
    }

    // UNDERLINE_RULES_SWEEP_DUMP="0.6,0.05,0.004,noun-or-two,1;…" writes the underlines of those settings, for review.
    let dumps = Set((env["UNDERLINE_RULES_SWEEP_DUMP"] ?? "").split(separator: ";").map(String.init))
    let kind = "rules-parameter-sweep-\(contextual ? "contextual" : "apple")"
    let out = Evals.root.appendingPathComponent("Eval/results/\(kind)")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

    var rows: [[String]] = []
    for setting in settings {
        // Pick and confirm per phrase.
        var kept: [(SweepCase, Int, Double)] = []
        for c in cases where c.hasCandidate {
            guard let top = c.ranking.first, top.rawScore >= setting.minScore,
                  top.rawScore - (c.ranking.dropFirst().first?.rawScore ?? 0) >= setting.margin,
                  let chapter = chapterOf[c.chapter], let ref = chapter.sentence(top.sentence),
                  !UnderlineGuard.isInSameParagraph(ref, as: c.sentence),
                  RulesPicker.confirm(phrase: c.phrase, in: c.sentence, reference: ref, stats: stats,
                                      rareShare: setting.rareShare, nounOrTwo: setting.nounOrTwo) else { continue }
            kept.append((c, top.sentence, top.rawScore))
        }
        // The paragraph limit: best first.
        var shown: [(SweepCase, Int)] = []
        for group in Dictionary(grouping: kept, by: { "\($0.0.chapter)|\($0.0.paragraph)" }).values {
            shown += group.sorted { $0.2 > $1.2 }.prefix(setting.maxPerParagraph).map { ($0.0, $0.1) }
        }
        let name = "\(setting.minScore),\(setting.margin),\(setting.rareShare),\(setting.nounOrTwo ? "noun-or-two" : "any-rare"),"
            + (setting.maxPerParagraph == 99 ? "none" : String(setting.maxPerParagraph))
        if dumps.contains(name) {
            var lines = [["chapter", "sentence", "phrase", "sentence_with_underline", "reference", "reference_text", "distance", "claude_label"]]
            for (c, ref) in shown.sorted(by: { ($0.0.chapter, $0.0.sentence.index) < ($1.0.chapter, $1.0.sentence.index) }) {
                let ns = c.sentence.text as NSString
                let marked = NSMaxRange(c.phrase.range) <= ns.length
                    ? ns.replacingCharacters(in: c.phrase.range, with: "[[" + ns.substring(with: c.phrase.range) + "]]") : c.sentence.text
                lines.append(["\(c.chapter)", "\(c.sentence.index)", c.phrase.text, marked, "\(ref)",
                              chapterOf[c.chapter]?.sentence(ref)?.text ?? "", "\(c.sentence.index - ref)",
                              labels["\(c.chapter)|\(c.sentence.index)|\(c.phrase.text)|\(ref)"] ?? ""])
            }
            try ("\u{FEFF}" + lines.map { QualitativeCSV.line($0) }.joined(separator: "\n") + "\n")
                .write(to: out.appendingPathComponent("underlines-\(name.replacingOccurrences(of: ",", with: "_")).csv"), atomically: true, encoding: .utf8)
        }
        var yes = 0, partial = 0, no = 0
        for (c, ref) in shown {
            switch labels["\(c.chapter)|\(c.sentence.index)|\(c.phrase.text)|\(ref)"] {
            case "yes"?: yes += 1
            case "partial"?: partial += 1
            case "no"?: no += 1
            default: break
            }
        }
        let labeled = yes + partial + no
        let precision = labeled > 0 ? Double(yes) / Double(labeled) : 0
        rows.append([String(setting.minScore), String(setting.margin), String(setting.rareShare), setting.nounOrTwo ? "noun-or-two" : "any-rare",
                     setting.maxPerParagraph == 99 ? "none" : String(setting.maxPerParagraph), String(shown.count), String(labeled),
                     String(yes), String(partial), String(no), String(format: "%.2f", precision),
                     String(format: "%.0f", precision * Double(shown.count))])
    }

    let head = ["min_score", "margin", "rare_share", "confirm", "max_per_paragraph", "underlines", "labeled", "yes", "partial", "no",
                "labeled_precision", "est_correct"]
    try ("\u{FEFF}" + ([head] + rows).map { QualitativeCSV.line($0) }.joined(separator: "\n") + "\n")
        .write(to: out.appendingPathComponent("sweep.csv"), atomically: true, encoding: .utf8)
    print("phrases searched: \(cases.count) · settings: \(settings.count) · labels: \(labels.count) · \(out.path)")
}

/// A CSV line with standard quoting (the labels file).
func parseCSVLine(_ line: String) -> [String] {
    var fields: [String] = [], field = "", quoted = false
    var chars = Array(line), i = 0
    while i < chars.count {
        let ch = chars[i]
        if quoted {
            if ch == "\"" {
                if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { quoted = false }
            } else { field.append(ch) }
        } else if ch == "\"" { quoted = true } else if ch == "," { fields.append(field); field = "" } else if ch != "\r" { field.append(ch) }
        i += 1
    }
    fields.append(field)
    chars = []
    return fields
}
