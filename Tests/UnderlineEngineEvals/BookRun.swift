import Foundation
import Testing
@testable import UnderlineEngine

/// One line of `Dataset/<book>/index.json`, made by `Dataset/epub_to_chapters.py`.
struct BookChapter: Decodable {
    let number: Int
    let title: String
    let file: String
    let paragraphs: Int
    let words: Int
}

/// "1-10", "5" or "1-3,7" as a set of chapter numbers; everything when nil.
func chapterNumbers(_ spec: String?, count: Int) -> Set<Int> {
    guard let spec, !spec.isEmpty else { return Set(1...max(count, 1)) }
    var numbers = Set<Int>()
    for part in spec.split(separator: ",") {
        let ends = part.split(separator: "-").compactMap { Int($0) }
        if ends.count == 2 { numbers.formUnion(ends[0]...max(ends[0], ends[1])) } else if let n = ends.first { numbers.insert(n) }
    }
    return numbers
}

/// Runs the engine over the chapters of a book and writes a report and a CSV per chapter, plus a summary.
/// Without Foundation Models by default (the rules path), with no judge, so it is quick.
///
///     UNDERLINE_BOOK=little-women swift test --filter bookRun                          # every chapter
///     UNDERLINE_BOOK=little-women UNDERLINE_BOOK_CHAPTERS=1-5 swift test --filter bookRun
///     UNDERLINE_BOOK_MODEL=1 …                                                         # Foundation Models confirm
///
/// Output: `Eval/results/book-<book>-<rules|model>/`: `chNN.md`, `chNN.csv`, `summary.md`, `summary.csv`.
@available(macOS 27, *)
@Test(.enabled(if: ProcessInfo.processInfo.environment["UNDERLINE_BOOK"] != nil), .timeLimit(.minutes(240)))
func bookRun() async throws {
    let env = ProcessInfo.processInfo.environment
    let book = env["UNDERLINE_BOOK"]!
    let dir = Evals.root.appendingPathComponent("Dataset/\(book)")
    let index = try JSONDecoder().decode([BookChapter].self, from: Data(contentsOf: dir.appendingPathComponent("index.json")))
    let wanted = chapterNumbers(env["UNDERLINE_BOOK_CHAPTERS"], count: index.count)
    // UNDERLINE_BOOK_EMBEDDING=contextual: NLContextualEmbedding through the same public API the app uses.
    let contextual = env["UNDERLINE_BOOK_EMBEDDING"] == "contextual"
    let ctrl = await UnderlineCtrl.make(model: env["UNDERLINE_BOOK_MODEL"] != nil ? .automatic : .rulesOnly,
                                        embedding: contextual ? .contextual : .automatic)
    if contextual, ctrl.embeddingEngine != .contextual { Issue.record("NLContextualEmbedding is not available"); return }
    // Word rarity from the whole book by default; UNDERLINE_BOOK_STATS=chapter keeps each chapter's own counts.
    let chapterStats = env["UNDERLINE_BOOK_STATS"] == "chapter"
    let kind = "book-\(book)-\(ctrl.usesModel ? "model" : "rules")\(chapterStats ? "-chapterstats" : "")"
        + (env["UNDERLINE_BOOK_EMBEDDING"] == "contextual" ? "-contextual" : "")
    let out = Evals.root.appendingPathComponent("Eval/results/\(kind)")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

    let clock = ContinuousClock()
    var inputs: [Int: ChapterInput] = [:]
    for c in index {
        let text = try String(contentsOf: dir.appendingPathComponent(c.file), encoding: .utf8)
        inputs[c.number] = ChapterInput(chapterIndex: c.number - 1, plainText: text)
    }
    // Book-wide word rarity (and the contextual centre) by default; UNDERLINE_BOOK_STATS=chapter keeps each chapter's own.
    let bookStats = ctrl.prepareBook(index.compactMap { inputs[$0.number] })
    var prepared: [Int: IndexedChapter] = [:]
    for c in index where wanted.contains(c.number) {
        prepared[c.number] = await ctrl.prepare(inputs[c.number]!, bookStats: chapterStats ? nil : bookStats)
    }
    var summary: [[String]] = []
    var totals = (sentences: 0, phrases: 0, underlines: 0)
    for c in index where wanted.contains(c.number) {
        let start = clock.now
        let chapter = prepared[c.number]!
        let (shown, records) = await ctrl.underlines(paragraphsHolding: Set(chapter.sentences.map(\.index)), in: chapter)
        let leaks = records.filter { r in r.candidates.contains { $0 >= r.sentence } || r.promptSentences.contains { $0 > r.sentence } }
        #expect(leaks.isEmpty, "chapter \(c.number): spoiler in \(leaks.map { "S\($0.sentence) \"\($0.phrase)\"" })")

        let name = String(format: "ch%02d", c.number)
        let run = RunInfo(runID: "\(book)-\(name)", runKind: kind, searchMode: ctrl.searchMode.rawValue)
        let rows = QualitativeReport.rows(run: run, chapter: chapter, records: records,
                                          gold: nil, outcomes: [:], judge: [:])
        _ = try Evals.saveQualitative(rows, run: run, beside: out.appendingPathComponent("\(name).json"))

        let reasons = Dictionary(grouping: records.compactMap { $0.dropped?.rawValue }, by: { $0 }).mapValues(\.count)
            .sorted { ($1.value, $0.key) < ($0.value, $1.key) }.map { "\($0.key) \($0.value)" }.joined(separator: " · ")
        let seconds = Double((clock.now - start) / .milliseconds(1)) / 1000
        summary.append(["\(c.number)", c.title, "\(chapter.sentences.count)", "\(records.count)", "\(shown.underlines.count)",
                        String(format: "%.1f", 100 * Double(shown.underlines.count) / Double(max(chapter.sentences.count, 1))), reasons])
        totals.sentences += chapter.sentences.count
        totals.phrases += records.count
        totals.underlines += shown.underlines.count
        print(String(format: "%@ · %d sentences · %d phrases · %d underlines · %.1f s", name, chapter.sentences.count, records.count,
                     shown.underlines.count, seconds))
    }

    let head = ["chapter", "title", "sentences", "phrases", "underlines", "per_100_sentences", "dropped_by"]
    let csv = ([head] + summary).map { QualitativeCSV.line($0) }.joined(separator: "\n") + "\n"
    try ("\u{FEFF}" + csv).write(to: out.appendingPathComponent("summary.csv"), atomically: true, encoding: .utf8)
    var md = ["# \(kind)", "", "| Chapter | Title | Sentences | Phrases | Underlines | Per 100 | Dropped by |", "|---|---|---|---|---|---|---|"]
    md += summary.map { "| " + $0.map(QualitativeReport.cell).joined(separator: " | ") + " |" }
    md.append("| | **Total** | **\(totals.sentences)** | **\(totals.phrases)** | **\(totals.underlines)** | "
              + String(format: "**%.1f**", 100 * Double(totals.underlines) / Double(max(totals.sentences, 1))) + " | |")
    try (md.joined(separator: "\n") + "\n").write(to: out.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
    print("summary: \(out.appendingPathComponent("summary.md").path)")
}
