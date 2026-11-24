import Foundation
import NaturalLanguage
import Testing
@testable import UnderlineEngine

/// Feature analysis for confirm (2026-11-23): for every labelled link of a book, the evidence a rules confirm could look at,
/// so right and wrong links can be compared feature by feature (`Experiments/retrieval/features.py`). Not a training set.
///
///     UNDERLINE_FEATURES=little-women swift test --filter linkFeatures
///
/// Links: the engine links with a Claude verdict (`Dataset/labels/claude-labels.csv`, any run, deduplicated) and the
/// hand-picked links judged right (`Experiments/retrieval/data/<book>-pairs.json`). Output: `Eval/results/features-<book>/links.csv`.
@available(macOS 27, *)
@Test(.enabled(if: ProcessInfo.processInfo.environment["UNDERLINE_FEATURES"] != nil), .timeLimit(.minutes(120)))
func linkFeatures() async throws {
    let book = ProcessInfo.processInfo.environment["UNDERLINE_FEATURES"]!
    let dir = Evals.root.appendingPathComponent("Dataset/\(book)")
    let index = try JSONDecoder().decode([BookChapter].self, from: Data(contentsOf: dir.appendingPathComponent("index.json")))
    let labelsName = book == "little-women" ? "claude-labels.csv" : "claude-labels-\(book).csv"
    let labels = try LinkFeatureInput.engineLinks(Evals.root.appendingPathComponent("Dataset/labels/\(labelsName)"))
    let pairs = try JSONDecoder().decode([RecallPair].self, from: Data(contentsOf: Evals.root.appendingPathComponent("Experiments/retrieval/data/\(book)-pairs.json")))

    let ctrl = await UnderlineCtrl.make(embedding: .contextual)
    guard ctrl.embeddingEngine == .contextual else { Issue.record("NLContextualEmbedding is not available"); return }
    guard let model = NLContextualEmbedding(language: .english), (try? model.load()) != nil else { Issue.record("no model"); return }
    var inputs: [Int: ChapterInput] = [:]
    for c in index {
        let text = try String(contentsOf: dir.appendingPathComponent(c.file), encoding: .utf8)
        inputs[c.number] = ChapterInput(chapterIndex: c.number - 1, plainText: text)
    }
    let stats = ctrl.prepareBook(index.compactMap { inputs[$0.number] })

    var lines = [LinkFeatureRow.header]
    for c in index {
        guard let input = inputs[c.number] else { continue }
        let engine = labels.filter { $0.chapter == c.number }
        let hand = pairs.filter { $0.chapter == c.number }
        guard !engine.isEmpty || !hand.isEmpty else { continue }
        let chapter = await ctrl.prepare(input, bookStats: stats)
        let vectors = EvalTokenVectors(chapter, model: model)
        for link in engine {
            guard let s = chapter.sentence(link.sentence), let r = chapter.sentence(link.reference) else { continue }
            let range = (s.text as NSString).range(of: link.phrase)
            guard range.location != NSNotFound else { continue }
            lines.append(LinkFeatureRow.make(source: "engine", verdict: link.verdict, chapter: c.number, phrase: link.phrase,
                                             range: range, s: s, r: r, stats: stats, vectors: vectors, ctrl: ctrl).line)
        }
        for pair in hand {
            guard let (s, range) = RecallText.locate(pair.phrase, in: input, chapter: chapter),
                  let (r, _) = RecallText.locate(pair.passage, in: input, chapter: chapter), r.index < s.index else { continue }
            lines.append(LinkFeatureRow.make(source: "hand", verdict: "yes", chapter: c.number, phrase: pair.phrase,
                                             range: range, s: s, r: r, stats: stats, vectors: vectors, ctrl: ctrl).line)
        }
        print("ch\(c.number): \(engine.count) engine, \(hand.count) hand")
    }
    let out = Evals.root.appendingPathComponent("Eval/results/features-\(book)")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    try (lines.joined(separator: "\n") + "\n").write(to: out.appendingPathComponent("links.csv"), atomically: true, encoding: .utf8)
    print("rows: \(lines.count - 1)")
}

enum LinkFeatureInput {
    struct Link { let chapter: Int; let sentence: Int; let phrase: String; let reference: Int; let verdict: String }

    /// Rows of a labels CSV (chapter, sentence, phrase, reference, verdict, …), deduplicated on the first four.
    static func engineLinks(_ url: URL) throws -> [Link] {
        let text = try String(contentsOf: url, encoding: .utf8)
        var seen = Set<String>()
        var out: [Link] = []
        for fields in CSVRows.parse(text).dropFirst() where fields.count >= 5 {
            guard let c = Int(fields[0]), let s = Int(fields[1]), let r = Int(fields[3]) else { continue }
            guard seen.insert("\(c)|\(s)|\(fields[2])|\(r)").inserted else { continue }
            out.append(Link(chapter: c, sentence: s, phrase: fields[2], reference: r, verdict: fields[4]))
        }
        return out
    }
}

/// A small RFC 4180 reader (quoted fields, doubled quotes, newlines inside quotes).
enum CSVRows {
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
        var chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n")).makeIterator()
        var pending: Character? = nil
        while let ch = pending ?? chars.next() {
            pending = nil
            if quoted {
                if ch == "\"" {
                    if let next = chars.next() { if next == "\"" { field.append("\"") } else { quoted = false; pending = next } } else { quoted = false }
                } else { field.append(ch) }
            } else if ch == "\"" { quoted = true }
            else if ch == "," { row.append(field); field = "" }
            else if ch == "\n" { row.append(field); rows.append(row); row = []; field = "" }
            else { field.append(ch) }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }
}

@available(macOS 27, *)
struct LinkFeatureRow {
    static let header = "source,verdict,chapter,distance,phrase_words,ref_words,shared_phrase,shared_sentence_only,rare_phrase,"
        + "rare_noun_adj_phrase,rare_sentence_only,idf_sum_phrase,idf_max_phrase,same_name,r8_confirm,soft,soft_novel,phrase"
    let line: String

    static func make(source: String, verdict: String, chapter: Int, phrase: String, range: NSRange, s: IndexedSentence,
                     r: IndexedSentence, stats: WordStats, vectors: EvalTokenVectors, ctrl: UnderlineCtrl) -> LinkFeatureRow {
        let inPhrase = { (t: WordToken) in NSIntersectionRange(t.range, range).length > 0 }
        let phraseTokens = RecallRankers.contentTokens(s).filter(inPhrase)
        let sentenceTokens = RecallRankers.contentTokens(s)
        let refLemmas = Set(RecallRankers.contentTokens(r).map(\.lemma))
        let sharedPhrase = Set(phraseTokens.map(\.lemma)).intersection(refLemmas)
        let sharedSentence = Set(sentenceTokens.map(\.lemma)).intersection(refLemmas)
        let sentenceOnly = sharedSentence.subtracting(sharedPhrase)
        let rarePhrase = sharedPhrase.filter { stats.isRare($0) }
        let rareNounAdj = Set(phraseTokens.filter { $0.wordClass != "Verb" && rarePhrase.contains($0.lemma) }.map(\.lemma))
        let idfs = sharedPhrase.map { stats.idf($0) }
        let names = s.names.filter { $0.kind == .person && NSIntersectionRange($0.range, range).length > 0 }.map(\.text)
        let sameName = names.contains { n in r.names.contains { $0.text == n } }
        // R8's confirm, measured as a feature: a shared rare noun or adjective, two shared rare words, or the same name.
        let confirm = !rareNounAdj.isEmpty || rarePhrase.count >= 2 || sameName

        let query = (vectors.words[s.index] ?? []).filter { NSIntersectionRange($0.range, range).length > 0 }
        let soft = vectors.softScore(query: query, sentence: r.index, stats: stats)
        let novel = query.filter { !refLemmas.contains($0.lemma) }
        let softNovel = novel.isEmpty ? 0 : vectors.softScore(query: novel, sentence: r.index, stats: stats)

        func f(_ x: Double) -> String { String(format: "%.4f", x) }
        let fields: [String] = [source, verdict, String(chapter), String(s.index - r.index), String(phraseTokens.count),
                                String(RecallRankers.contentTokens(r).count), String(sharedPhrase.count), String(sentenceOnly.count),
                                String(rarePhrase.count), String(rareNounAdj.count), String(sentenceOnly.filter { stats.isRare($0) }.count),
                                f(idfs.reduce(0, +)), f(idfs.max() ?? 0), sameName ? "1" : "0", confirm ? "1" : "0",
                                f(soft), f(softNovel),
                                "\"" + phrase.replacingOccurrences(of: "\"", with: "\"\"") + "\""]
        return LinkFeatureRow(line: fields.joined(separator: ","))
    }
}
