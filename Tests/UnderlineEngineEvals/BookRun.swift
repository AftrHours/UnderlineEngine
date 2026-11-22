import Foundation
import Testing
@testable import UnderlineEngine
@testable import UnderlineKit

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

/// Runs one `LinkMethod` over the chapters of a book the way an app does, and writes a report and a CSV per chapter, plus a summary.
/// The book goes in as a `BookSource`, each chapter through `Underliner.input` (the mapping `UnderlineKit` uses), then
/// `prepare(_:ofBook:chapters:)` and `results(in:startingAt:)`, the same two calls `Underliner` makes for the app. Only the
/// sentence numbering differs: here each chapter starts at 0 (so the labels in `Dataset/labels/` keep matching), the app numbers
/// across the book; no decision depends on it, because search only ever looks inside the chapter (`BookRunNumberingTests`).
///
///     UNDERLINE_BOOK=little-women UNDERLINE_BOOK_EMBEDDING=contextual swift test --filter bookRun   # R8, every chapter
///     UNDERLINE_BOOK=little-women UNDERLINE_BOOK_CHAPTERS=1-5 …                                       # a range
///     UNDERLINE_METHOD=r8 …                                                                           # the method, by name
///
/// Output: `Eval/results/book-<book>-<method>[-contextual]/`: `chNN.md`, `chNN.csv`, `summary.md`, `summary.csv`.
@available(macOS 27, *)
@Test(.enabled(if: ProcessInfo.processInfo.environment["UNDERLINE_BOOK"] != nil), .timeLimit(.minutes(240)))
func bookRun() async throws {
    let env = ProcessInfo.processInfo.environment
    let book = env["UNDERLINE_BOOK"]!
    if env["UNDERLINE_BOOK_MODEL"] != nil || env["UNDERLINE_BOOK_STATS"] != nil {
        let message = "UNDERLINE_BOOK_MODEL and UNDERLINE_BOOK_STATS ran UnderlineCtrl directly; the book run now runs a LinkMethod "
            + "(UNDERLINE_METHOD). Use commit 2c793f9 or earlier for those runs."
        Issue.record(Comment(rawValue: message))
        return
    }
    let dir = Evals.root.appendingPathComponent("Dataset/\(book)")
    let index = try JSONDecoder().decode([BookChapter].self, from: Data(contentsOf: dir.appendingPathComponent("index.json")))
    let wanted = chapterNumbers(env["UNDERLINE_BOOK_CHAPTERS"], count: index.count)
    let contextual = env["UNDERLINE_BOOK_EMBEDDING"] == "contextual"
    let methodName = env["UNDERLINE_METHOD"] ?? "r8"
    guard let method = await BookRunMethods.make(methodName, embedding: contextual ? .contextual : .automatic) else {
        Issue.record("Unknown UNDERLINE_METHOD \(methodName); known: \(BookRunMethods.names.joined(separator: ", "))")
        return
    }
    let kind = "book-\(book)-\(methodName)" + (contextual ? "-contextual" : "")
    let out = Evals.root.appendingPathComponent("Eval/results/\(kind)")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

    // The book as an app hands it over: plain text with paragraph and sentence numbers.
    var chapters: [ChapterText] = []
    for c in index {
        let text = try String(contentsOf: dir.appendingPathComponent(c.file), encoding: .utf8)
        chapters.append(BookRunSource.chapterText(ChapterInput(chapterIndex: c.number - 1, plainText: text)))
    }
    let source = BookText(id: book, chapters: chapters)
    let clock = ContinuousClock()
    var summary: [[String]] = []
    var totals = (sentences: 0, phrases: 0, underlines: 0)
    for c in index where wanted.contains(c.number) {
        let start = clock.now
        // The two calls Underliner makes for the app.
        let chapter = await method.prepare(Underliner.input(c.number - 1, of: source), ofBook: source.id) {
            (0..<source.chapterCount).map { Underliner.input($0, of: source) }
        }
        if contextual, chapter.embedding != .contextual { Issue.record("NLContextualEmbedding is not available"); return }
        var shown: [Underline] = []
        var records: [UnderlineRecord] = []
        for await paragraph in method.results(in: chapter, startingAt: chapter.first) {
            shown += paragraph.underlines
            records += paragraph.records
        }
        let leaks = records.filter { r in r.candidates.contains { $0 >= r.sentence } || r.promptSentences.contains { $0 > r.sentence } }
        #expect(leaks.isEmpty, "chapter \(c.number): spoiler in \(leaks.map { "S\($0.sentence) \"\($0.phrase)\"" })")

        let name = String(format: "ch%02d", c.number)
        let run = RunInfo(runID: "\(book)-\(name)", runKind: kind, searchMode: SearchMode.both.rawValue)
        let rows = QualitativeReport.rows(run: run, chapter: chapter, records: records,
                                          gold: nil, outcomes: [:], judge: [:])
        _ = try Evals.saveQualitative(rows, run: run, beside: out.appendingPathComponent("\(name).json"))

        let reasons = Dictionary(grouping: records.compactMap { $0.dropped?.rawValue }, by: { $0 }).mapValues(\.count)
            .sorted { ($1.value, $0.key) < ($0.value, $1.key) }.map { "\($0.key) \($0.value)" }.joined(separator: " · ")
        let seconds = Double((clock.now - start) / .milliseconds(1)) / 1000
        summary.append(["\(c.number)", c.title, "\(chapter.sentences.count)", "\(records.count)", "\(shown.count)",
                        String(format: "%.1f", 100 * Double(shown.count) / Double(max(chapter.sentences.count, 1))), reasons])
        totals.sentences += chapter.sentences.count
        totals.phrases += records.count
        totals.underlines += shown.count
        print(String(format: "%@ · %d sentences · %d phrases · %d underlines · %.1f s", name, chapter.sentences.count, records.count,
                     shown.count, seconds))
    }

    let head = ["chapter", "title", "sentences", "phrases", "underlines", "per_100_sentences", "dropped_by"]
    let csv = ([head] + summary).map { QualitativeCSV.line($0) }.joined(separator: "\n") + "\n"
    try ("\u{FEFF}" + csv).write(to: out.appendingPathComponent("summary.csv"), atomically: true, encoding: .utf8)
    var md = ["# \(kind)", "", "Method: \(method.name) (version \(method.version)) · \(method.summary)", "", "| Chapter | Title | Sentences | Phrases | Underlines | Per 100 | Dropped by |", "|---|---|---|---|---|---|---|"]
    md += summary.map { "| " + $0.map(QualitativeReport.cell).joined(separator: " | ") + " |" }
    md.append("| | **Total** | **\(totals.sentences)** | **\(totals.phrases)** | **\(totals.underlines)** | "
              + String(format: "**%.1f**", 100 * Double(totals.underlines) / Double(max(totals.sentences, 1))) + " | |")
    try (md.joined(separator: "\n") + "\n").write(to: out.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
    print("summary: \(out.appendingPathComponent("summary.md").path)")
}

/// The methods a book run can measure, by name. A new `LinkMethod` is added here to be measured like R8.
enum BookRunMethods {
    static let names = ["r8"]

    static func make(_ name: String, embedding: EmbeddingChoice) async -> (any LinkMethod)? {
        switch name {
        case "r8": await Linker.make(embedding: embedding)
        default: nil
        }
    }
}

/// Turns a chapter split by `ChapterInput(plainText:)` into the `ChapterText` an app would hand over.
enum BookRunSource {
    static func chapterText(_ input: ChapterInput) -> ChapterText {
        ChapterText(paragraphs: input.paragraphs.map { ChapterText.Paragraph(index: $0.index, text: $0.text) },
                    sentences: input.sentences.map { ChapterText.Sentence(index: $0.index, paragraph: $0.paragraph, range: $0.range) })
    }
}
