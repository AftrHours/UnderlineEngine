import Foundation
import Testing
@testable import UnderlineEngine

/// Offline test of confirm fixes for R9 (2026-11-23): the evidence of every link an R9 book run underlined, with its verdict,
/// so `Experiments/retrieval/r9_confirm_fixes.py` can score stricter confirm rules on exactly the links R9 makes.
///
///     UNDERLINE_R9_FEATURES=little-women swift test --filter r9ConfirmFeatures
///
/// Reads `Eval/results/book-<book>-r9-contextual/chNN.csv` and the book's label file. Output:
/// `Eval/results/features-<book>/r9-links.csv`.
@available(macOS 27, *)
@Test(.enabled(if: ProcessInfo.processInfo.environment["UNDERLINE_R9_FEATURES"] != nil), .timeLimit(.minutes(120)))
func r9ConfirmFeatures() async throws {
    let book = ProcessInfo.processInfo.environment["UNDERLINE_R9_FEATURES"]!
    let dir = Evals.root.appendingPathComponent("Dataset/\(book)")
    let index = try JSONDecoder().decode([BookChapter].self, from: Data(contentsOf: dir.appendingPathComponent("index.json")))
    let labelsName = book == "little-women" ? "claude-labels.csv" : "claude-labels-\(book).csv"
    var verdicts: [String: String] = [:]
    for l in try LinkFeatureInput.engineLinks(Evals.root.appendingPathComponent("Dataset/labels/\(labelsName)")) {
        verdicts["\(l.chapter)|\(l.sentence)|\(l.phrase)|\(l.reference)"] = l.verdict
    }
    let runDir = Evals.root.appendingPathComponent("Eval/results/book-\(book)-r9-contextual")

    let ctrl = await UnderlineCtrl.make(embedding: .contextual)
    guard ctrl.embeddingEngine == .contextual else { Issue.record("NLContextualEmbedding is not available"); return }
    var inputs: [Int: ChapterInput] = [:]
    for c in index {
        let text = try String(contentsOf: dir.appendingPathComponent(c.file), encoding: .utf8)
        inputs[c.number] = ChapterInput(chapterIndex: c.number - 1, plainText: text)
    }
    let stats = ctrl.prepareBook(index.compactMap { inputs[$0.number] })

    var lines = ["book,chapter,sentence,reference,verdict,distance,shared,rare,rare_noun,rare_adj,rare_verb,same_clause_shared,soft,phrase_words,ref_words,phrase"]
    for c in index {
        let file = runDir.appendingPathComponent(String(format: "ch%02d.csv", c.number))
        guard let input = inputs[c.number], let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
        let rows = CSVRows.parse(text.replacingOccurrences(of: "\u{FEFF}", with: ""))
        guard let head = rows.first else { continue }
        func col(_ name: String) -> Int? { head.firstIndex(of: name) }
        guard let iU = col("underlined"), let iS = col("sentence"), let iP = col("phrase"), let iR = col("reference") else { continue }
        let links = rows.dropFirst().filter { $0.count > iU && $0[iU] == "yes" }
        guard !links.isEmpty else { continue }
        let chapter = await ctrl.prepare(input, bookStats: stats)
        for row in links {
            guard let si = Int(row[iS]), let ri = Int(row[iR]), let s = chapter.sentence(si), let r = chapter.sentence(ri) else { continue }
            let phrase = row[iP]
            let range = (s.text as NSString).range(of: phrase)
            guard range.location != NSNotFound else { continue }
            let verdict = verdicts["\(c.number)|\(si)|\(phrase)|\(ri)"] ?? "unlabelled"
            let inPhrase = ChapterTokenVectors.contentTokens(s).filter { NSIntersectionRange($0.range, range).length > 0 }
            let refContent = ChapterTokenVectors.contentTokens(r)
            let refLemmas = Set(refContent.map(\.lemma))
            let shared = Set(inPhrase.map(\.lemma)).intersection(refLemmas)
            let rare = shared.filter { stats.isRare($0) }
            func rareOf(_ cls: String) -> Int { Set(inPhrase.filter { $0.wordClass == cls && rare.contains($0.lemma) }.map(\.lemma)).count }
            // The most shared lemmas found inside one event (clause) of the reference.
            let sameClause = r.events.map { e in
                Set(refContent.filter { NSIntersectionRange($0.range, e.range).length > 0 && shared.contains($0.lemma) }.map(\.lemma)).count
            }.max() ?? 0
            let novel = (s.wordVectors ?? []).filter { NSIntersectionRange($0.range, range).length > 0 && !refLemmas.contains($0.lemma) }
            let soft = novel.isEmpty ? 0 : ChapterTokenVectors.softScore(query: novel, target: r.wordVectors ?? [], stats: stats)
            lines.append([book, String(c.number), String(si), String(ri), verdict, String(si - ri), String(shared.count), String(rare.count),
                          String(rareOf("Noun")), String(rareOf("Adjective")), String(rareOf("Verb")), String(sameClause),
                          String(format: "%.4f", soft), String(inPhrase.count), String(refContent.count),
                          "\"" + phrase.replacingOccurrences(of: "\"", with: "\"\"") + "\""].joined(separator: ","))
        }
    }
    let out = Evals.root.appendingPathComponent("Eval/results/features-\(book)")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    try (lines.joined(separator: "\n") + "\n").write(to: out.appendingPathComponent("r9-links.csv"), atomically: true, encoding: .utf8)
    print("rows: \(lines.count - 1)")
}
