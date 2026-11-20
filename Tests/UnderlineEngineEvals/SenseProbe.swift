import Foundation
import Testing
@testable import UnderlineEngine

/// For every labeled link, the shared rare words and how alike each one is in its two sentences, read by
/// `NLContextualEmbedding`. Shows whether "same word, same sense" separates right links from wrong ones before
/// confirm uses it.
///
///     UNDERLINE_SENSE_PROBE=1 swift test --filter senseProbe
///
/// Output: `Eval/results/sense-probe/pairs.csv`.
@available(macOS 27, *)
@Test(.enabled(if: ProcessInfo.processInfo.environment["UNDERLINE_SENSE_PROBE"] != nil), .timeLimit(.minutes(60)))
func senseProbe() async throws {
    let dir = Evals.root.appendingPathComponent("Dataset/little-women")
    let index = try JSONDecoder().decode([BookChapter].self, from: Data(contentsOf: dir.appendingPathComponent("index.json")))
    guard let embedding = await EmbeddingSvcContextual.make() else { Issue.record("NLContextualEmbedding is not available"); return }
    let svc = ChapterIndexSvc()
    var chapters: [Int: [Int: IndexedSentence]] = [:]
    var all: [IndexedSentence] = []
    for c in index {
        let text = try String(contentsOf: dir.appendingPathComponent(c.file), encoding: .utf8)
        let sentences = svc.index(ChapterInput(chapterIndex: c.number - 1, plainText: text))
        chapters[c.number] = Dictionary(uniqueKeysWithValues: sentences.map { ($0.index, $0) })
        all += sentences
    }
    let stats = WordStats(sentences: all)

    let labels = try String(contentsOf: Evals.root.appendingPathComponent("Dataset/labels/claude-labels.csv"), encoding: .utf8)
    var rows = [["chapter", "sentence", "phrase", "reference", "verdict", "rare_words", "min_sim", "max_sim"]]
    var seen = Set<String>()
    for line in labels.split(whereSeparator: \.isNewline).dropFirst() {
        let f = parseCSVLine(String(line))
        guard f.count >= 5, let ch = Int(f[0]), let si = Int(f[1]), let ri = Int(f[3]),
              let s = chapters[ch]?[si], let ref = chapters[ch]?[ri], seen.insert("\(ch):\(si):\(f[2]):\(ri)").inserted else { continue }
        let range = (s.text as NSString).range(of: f[2])
        guard range.location != NSNotFound else { continue }
        let phraseTokens = s.tokens.filter { NSIntersectionRange($0.range, range).length > 0 }
        let content = { (t: WordToken) in ["Noun", "Verb", "Adjective"].contains(t.wordClass) && !SearchKnobs.stopLemmas.contains(t.lemma) }
        var words: [String] = []
        var sims: [Double] = []
        for t in phraseTokens where content(t) && stats.isRare(t.lemma) && !words.contains(t.lemma) {
            guard let r = ref.tokens.first(where: { content($0) && $0.lemma == t.lemma && $0.wordClass == t.wordClass }),
                  let a = embedding.wordVector(in: s.text, at: t.range), let b = embedding.wordVector(in: ref.text, at: r.range) else { continue }
            words.append("\(t.lemma)/\(t.wordClass)")
            sims.append(2 * Cosine.similarity(a.map(Float.init), b.map(Float.init)) - 1)
        }
        rows.append([f[0], f[1], f[2], f[3], f[4], words.joined(separator: " "),
                     sims.min().map { String(format: "%.3f", $0) } ?? "", sims.max().map { String(format: "%.3f", $0) } ?? ""])
    }
    let out = Evals.root.appendingPathComponent("Eval/results/sense-probe")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    try ("\u{FEFF}" + rows.map { QualitativeCSV.line($0) }.joined(separator: "\n") + "\n")
        .write(to: out.appendingPathComponent("pairs.csv"), atomically: true, encoding: .utf8)
    print("sense probe: \(rows.count - 1) pairs → \(out.path)/pairs.csv")
}
