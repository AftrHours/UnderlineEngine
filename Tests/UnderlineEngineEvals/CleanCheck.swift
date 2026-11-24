import Foundation
import Testing
@testable import UnderlineEngine

/// What Clean (stage 0, `StoryCleaner`) leaves out of real books, so every dropped paragraph can be checked by eye.
///
///     python3 -I Experiments/clean/chapters.py epub <path>.epub <book>     # chapters as iRead reads the EPUB
///     python3 -I Experiments/clean/chapters.py dataset <book>             # Dataset chapters (already clean: should lose nothing)
///     UNDERLINE_CLEAN_CHECK=1 swift test --filter cleanCheck
///
/// Reads every `Experiments/clean/data/*.json`; writes `Eval/results/clean/summary.md` and `dropped.md` (each dropped paragraph).
@available(macOS 27, *)
@Test(.enabled(if: ProcessInfo.processInfo.environment["UNDERLINE_CLEAN_CHECK"] != nil))
func cleanCheck() throws {
    let dir = Evals.root.appendingPathComponent("Experiments/clean/data")
    let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    var summary = "# Clean check: what stage 0 leaves out\n\n"
    summary += "| Source | Chapters | Paragraphs | Chapters dropped whole | Paragraphs dropped | By reason |\n|---|---|---|---|---|---|\n"
    var dropped = "# Every paragraph Clean leaves out\n"
    for file in files {
        let chapters = try JSONDecoder().decode([CleanChapter].self, from: Data(contentsOf: file))
        var paragraphs = 0, droppedCount = 0, wholeChapters = 0
        var reasons: [CleanReason: Int] = [:]
        dropped += "\n## \(file.deletingPathExtension().lastPathComponent)\n"
        for c in chapters {
            let input = ChapterInput(chapterIndex: c.chapter - 1, plainText: c.paragraphs.joined(separator: "\n\n"))
            let out = StoryCleaner.droppedParagraphs(input)
            paragraphs += input.paragraphs.count
            droppedCount += out.count
            if !input.paragraphs.isEmpty, out.count == input.paragraphs.count { wholeChapters += 1 }
            for (_, r) in out { reasons[r, default: 0] += 1 }
            guard !out.isEmpty else { continue }
            if out.count == input.paragraphs.count {
                let reason = out.values.first!.rawValue
                dropped += "- ch\(c.chapter) **whole chapter** (\(reason), \(out.count) paragraphs): \(String(input.paragraphs[0].text.prefix(80)))\n"
            } else {
                for p in input.paragraphs where out[p.index] != nil {
                    dropped += "- ch\(c.chapter) ¶\(p.index) \(out[p.index]!.rawValue): \(String(p.text.prefix(100)))\n"
                }
            }
        }
        let byReason = reasons.sorted { $0.value > $1.value }.map { "\($0.key.rawValue) \($0.value)" }.joined(separator: ", ")
        summary += "| \(file.deletingPathExtension().lastPathComponent) | \(chapters.count) | \(paragraphs) | \(wholeChapters) | \(droppedCount) | \(byReason) |\n"
    }
    let out = Evals.root.appendingPathComponent("Eval/results/clean")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    try summary.write(to: out.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
    try dropped.write(to: out.appendingPathComponent("dropped.md"), atomically: true, encoding: .utf8)
    print(summary)
}

struct CleanChapter: Decodable {
    let chapter: Int
    let paragraphs: [String]
}
