import Foundation
import Testing
import NaturalLanguage
@testable import UnderlineEngine

/// Retrieval recall: for every hand-picked link judged right, where does the engine's ranking (`CandidateScorer.rank`) put the
/// earlier sentence the reader linked to? Measured before any confirm rule, so a miss here means the link was never retrieved,
/// and a hit the engine still doesn't underline was lost later (pick, confirm).
///
///     python3 -I Experiments/retrieval/pairs.py little-women
///     UNDERLINE_RECALL=little-women swift test --filter retrievalRecall
///
/// The pool is what the engine searches (`ReadBoundary`: earlier sentences in the same chapter), narrowed to earlier paragraphs,
/// the hand pick's own rule (the engine drops a reference in the phrase's paragraph anyway). The query is the hand-picked
/// phrase, with the role and track of the event it overlaps most (none: no role, goal track).
///
/// Output: `Eval/results/recall-<book>/summary.md` and `pairs.csv`.
@available(macOS 27, *)
@Test(.enabled(if: ProcessInfo.processInfo.environment["UNDERLINE_RECALL"] != nil), .timeLimit(.minutes(120)))
func retrievalRecall() async throws {
    let book = ProcessInfo.processInfo.environment["UNDERLINE_RECALL"]!
    let dir = Evals.root.appendingPathComponent("Dataset/\(book)")
    let index = try JSONDecoder().decode([BookChapter].self, from: Data(contentsOf: dir.appendingPathComponent("index.json")))
    let pairsFile = Evals.root.appendingPathComponent("Experiments/retrieval/data/\(book)-pairs.json")
    let pairs = try JSONDecoder().decode([RecallPair].self, from: Data(contentsOf: pairsFile))

    let ctrl = await UnderlineCtrl.make(embedding: .contextual)
    guard ctrl.embeddingEngine == .contextual else { Issue.record("NLContextualEmbedding is not available"); return }
    // Each chapter numbered from 0, like the book run, so the hand pick's chapters line up.
    var inputs: [Int: ChapterInput] = [:]
    for c in index {
        let text = try String(contentsOf: dir.appendingPathComponent(c.file), encoding: .utf8)
        inputs[c.number] = ChapterInput(chapterIndex: c.number - 1, plainText: text)
    }
    let stats = ctrl.prepareBook(index.compactMap { inputs[$0.number] })

    // The search experiments (RecallRankers.swift): BM25 needs the mean sentence length, soft words its own model handle.
    let allSentences = index.compactMap { inputs[$0.number] }.flatMap { ctrl.indexSvc.index($0) }
    let avgLength = Double(allSentences.map { RecallRankers.contentTokens($0).count }.reduce(0, +)) / Double(max(allSentences.count, 1))
    guard let model = NLContextualEmbedding(language: .english), (try? model.load()) != nil else {
        Issue.record("NLContextualEmbedding could not load"); return
    }

    var rows: [RecallRow] = []
    let wanted = Set(pairs.map(\.chapter))
    for c in index where wanted.contains(c.number) {
        guard let input = inputs[c.number] else { continue }
        let chapter = await ctrl.prepare(input, bookStats: stats)
        let tokenVectors = EvalTokenVectors(chapter, model: model)
        for pair in pairs where pair.chapter == c.number {
            rows.append(recallRow(pair, input: input, chapter: chapter, ctrl: ctrl, stats: stats, avgLength: avgLength,
                                  tokenVectors: tokenVectors))
        }
    }

    let out = Evals.root.appendingPathComponent("Eval/results/recall-\(book)")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    try RecallReport.csv(rows).write(to: out.appendingPathComponent("pairs.csv"), atomically: true, encoding: .utf8)
    let summary = RecallReport.summary(rows, book: book)
    try summary.write(to: out.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
    print(summary)
}

struct RecallPair: Decodable {
    let chapter: Int
    let line: Int
    let phrase: String
    let passage: String
}

struct RecallRow {
    let pair: RecallPair
    var status = "ok"           // ok · phrase not found · passage not found · same paragraph · not earlier
    var pool = 0
    var rankEngine: Int?        // 1-based rank in the engine's ranking (shared rare words + role bonuses)
    var rankWords: Int?         // by IDF-weighted shared lemmas only
    var rankBM25: Int?          // BM25 over content lemmas (no context)
    var rankSoft: Int?          // soft words: contextual token max-similarity, IDF-weighted
    var rankWordsSoft: Int?     // words only + soft words, half each (min–max scaled)
    var inCandidates = false    // among the candidates pick orders (top `maxCandidates` sharing a word)
    var detected = false        // Detect makes a candidate overlapping the phrase
    var distance = 0            // sentences between them
}

@available(macOS 27, *)
private func recallRow(_ pair: RecallPair, input: ChapterInput, chapter: IndexedChapter, ctrl: UnderlineCtrl, stats: WordStats,
                       avgLength: Double, tokenVectors: EvalTokenVectors) -> RecallRow {
    var row = RecallRow(pair: pair)
    guard let (later, phraseRange) = RecallText.locate(pair.phrase, in: input, chapter: chapter) else { row.status = "phrase not found"; return row }
    guard let (earlier, _) = RecallText.locate(pair.passage, in: input, chapter: chapter) else { row.status = "passage not found"; return row }
    guard earlier.index < later.index else { row.status = "not earlier"; return row }
    guard earlier.paragraph < later.paragraph else { row.status = "same paragraph"; return row }
    row.distance = later.index - earlier.index

    let overlap = later.events.max { NSIntersectionRange($0.range, phraseRange).length < NSIntersectionRange($1.range, phraseRange).length }
    let event = overlap.flatMap { NSIntersectionRange($0.range, phraseRange).length > 0 ? $0 : nil }
    let phrase = EventPhrase(text: pair.phrase, range: phraseRange, role: event?.role, track: event?.track ?? .goal)
    let candidate = UnderlineCandidate(sentence: later.index, phrase: phrase, kind: UnderlineKind.of(phrase))
    row.detected = UnderlineDetector.candidates(in: later, recentNames: UnderlineCtrl.recentNames(before: later.index, in: chapter))
        .contains { NSIntersectionRange($0.phrase.range, phraseRange).length > 0 }

    let query = SearchQuery.make(candidate: candidate, in: later, tagger: ctrl.indexSvc)
    let paragraphOf = Dictionary(chapter.sentences.map { ($0.index, $0.paragraph) }, uniquingKeysWith: { a, _ in a })
    let ranking = CandidateScorer.rank(query, in: chapter, before: later.index).filter { (paragraphOf[$0.sentence] ?? .max) < later.paragraph }
    row.pool = ranking.count
    func rank(_ ordered: [Candidate]) -> Int? { ordered.firstIndex { $0.sentence == earlier.index }.map { $0 + 1 } }
    row.rankEngine = rank(ranking)
    row.rankWords = rank(ranking.sorted { ($0.rawWords, $0.sentence) > ($1.rawWords, $1.sentence) })
    let pool = ranking.compactMap { chapter.sentence($0.sentence) }
    let bm25 = RecallRankers.bm25(query.lemmas, pool: pool, stats: stats, avgLength: avgLength)
    row.rankBM25 = rank(ranking.sorted { (bm25[$0.sentence] ?? 0, $0.sentence) > (bm25[$1.sentence] ?? 0, $1.sentence) })
    // The phrase's content words, read in the later sentence.
    let queryWords = (tokenVectors.words[later.index] ?? []).filter { NSIntersectionRange($0.range, phraseRange).length > 0 }
    let soft = Dictionary(uniqueKeysWithValues: ranking.map { ($0.sentence, tokenVectors.softScore(query: queryWords, sentence: $0.sentence, stats: stats)) })
    row.rankSoft = rank(ranking.sorted { (soft[$0.sentence] ?? 0, $0.sentence) > (soft[$1.sentence] ?? 0, $1.sentence) })
    func scaled(_ d: [Int: Double]) -> [Int: Double] {
        guard let lo = d.values.min(), let hi = d.values.max(), hi > lo else { return d.mapValues { _ in 0 } }
        return d.mapValues { ($0 - lo) / (hi - lo) }
    }
    let words = scaled(Dictionary(uniqueKeysWithValues: ranking.map { ($0.sentence, $0.rawWords) }))
    let softScaled = scaled(soft)
    let mixed = Dictionary(uniqueKeysWithValues: words.keys.map { ($0, 0.5 * (words[$0] ?? 0) + 0.5 * (softScaled[$0] ?? 0)) })
    row.rankWordsSoft = rank(ranking.sorted { (mixed[$0.sentence] ?? 0, $0.sentence) > (mixed[$1.sentence] ?? 0, $1.sentence) })
    row.inCandidates = RulesPicker.evidenceOrder(ranking).contains { $0.sentence == earlier.index }
    return row
}

enum RecallText {
    /// The sentence holding the start of `snippet` (its first 60 characters, whitespace and quotes loosened), and the snippet's
    /// range inside that sentence (clipped to it).
    static func locate(_ snippet: String, in input: ChapterInput, chapter: IndexedChapter) -> (IndexedSentence, NSRange)? {
        let probe = String(snippet.prefix(60))
        let pattern = probe.split(whereSeparator: \.isWhitespace)
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: "\\s+")
            .replacingOccurrences(of: "\"", with: "[\"\u{201C}\u{201D}]")
            .replacingOccurrences(of: "'", with: "['\u{2018}\u{2019}]")
        guard !pattern.isEmpty, let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        for paragraph in input.paragraphs {
            let text = paragraph.text as NSString
            guard let match = regex.firstMatch(in: paragraph.text, range: NSRange(location: 0, length: text.length)) else { continue }
            let start = match.range.location
            guard let sentence = chapter.sentences.first(where: {
                $0.paragraph == paragraph.index && $0.range.location <= start && start < NSMaxRange($0.range)
            }) else { continue }
            let local = start - sentence.range.location
            let length = min((snippet as NSString).length, sentence.range.length - local)
            return (sentence, NSRange(location: local, length: max(length, 1)))
        }
        return nil
    }
}

enum RecallReport {
    static let ks = [1, 3, 6, 10, 20, 50]

    static func summary(_ rows: [RecallRow], book: String) -> String {
        let ok = rows.filter { $0.status == "ok" }
        func pct(_ n: Int, _ d: Int) -> String { d == 0 ? "–" : String(format: "%.1f%%", 100 * Double(n) / Double(d)) }
        func atK(_ ranks: [Int?], _ k: Int) -> String { pct(ranks.filter { ($0 ?? .max) <= k }.count, ranks.count) }
        let pools = ok.map(\.pool).sorted()
        let distances = ok.map(\.distance).sorted()
        var s = "# Retrieval recall, \(book) (engine ranking, before confirm)\n\n"
        s += "Hand-picked links judged right: \(rows.count). Usable: \(ok.count).\n"
        for status in Set(rows.map(\.status)).subtracting(["ok"]).sorted() {
            s += "- \(status): \(rows.filter { $0.status == status }.count)\n"
        }
        s += "\nPool (earlier sentences in earlier paragraphs of the chapter): median \(pools.isEmpty ? 0 : pools[pools.count / 2]), "
        s += "max \(pools.last ?? 0). Distance to the linked sentence: median \(distances.isEmpty ? 0 : distances[distances.count / 2]) sentences.\n\n"
        s += "| Ranking | " + ks.map { "@\($0)" }.joined(separator: " | ") + " |\n|---|" + ks.map { _ in "---|" }.joined() + "\n"
        for (name, ranks) in [("Engine (words + role bonuses)", ok.map(\.rankEngine)),
                              ("Words only (IDF lemmas)", ok.map(\.rankWords)), ("BM25 (lemmas, no context)", ok.map(\.rankBM25)),
                              ("Soft words (contextual token max-similarity)", ok.map(\.rankSoft)),
                              ("Words + soft words (half each)", ok.map(\.rankWordsSoft))] {
            s += "| \(name) | " + ks.map { atK(ranks, $0) }.joined(separator: " | ") + " |\n"
        }
        s += "| Random (pool size) | " + ks.map { k in
            ok.isEmpty ? "–" : String(format: "%.1f%%", 100 * ok.map { $0.pool == 0 ? 0 : min(1, Double(k) / Double($0.pool)) }.reduce(0, +) / Double(ok.count))
        }.joined(separator: " | ") + " |\n\n"
        s += "- Among pick's candidates (top \(SearchKnobs.maxCandidates) sharing a word): \(pct(ok.filter(\.inCandidates).count, ok.count))\n"
        s += "- Detect makes a candidate overlapping the hand-picked phrase: \(pct(ok.filter(\.detected).count, ok.count))\n"
        s += "- Both (detected and in the candidate set): \(pct(ok.filter { $0.detected && $0.inCandidates }.count, ok.count))\n"
        return s
    }

    static func csv(_ rows: [RecallRow]) -> String {
        func q(_ v: String) -> String { "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        func n(_ v: Int?) -> String { v.map(String.init) ?? "" }
        var out = "chapter,line,status,pool,distance,rank_engine,rank_words,rank_bm25,rank_soft,rank_words_soft,in_candidates,detected,phrase,passage\n"
        for r in rows {
            out += [String(r.pair.chapter), String(r.pair.line), r.status, String(r.pool), String(r.distance), n(r.rankEngine),
                    n(r.rankWords), n(r.rankBM25), n(r.rankSoft), n(r.rankWordsSoft), r.inCandidates ? "yes" : "no", r.detected ? "yes" : "no",
                    q(r.pair.phrase), q(r.pair.passage)].joined(separator: ",") + "\n"
        }
        return out
    }
}

