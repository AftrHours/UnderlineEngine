import Foundation
import Testing
@testable import UnderlineEngine

/// Retrieval recall: for every hand-picked link judged right, where does R8's own ranking (`CandidateScorer.rank`) put the
/// earlier sentence the reader linked to? Measured before any confirm rule, so a miss here means the link was never retrieved,
/// and a hit that R8 still doesn't underline was lost later (floor, pick, confirm).
///
///     python3 -I Experiments/retrieval/pairs.py little-women
///     UNDERLINE_RECALL=little-women swift test --filter retrievalRecall
///
/// The pool is what R8 searches (`ReadBoundary`: earlier sentences in the same chapter), narrowed to earlier paragraphs, the
/// hand pick's own rule (R8 drops a reference in the phrase's paragraph anyway). The query is the hand-picked phrase, with the
/// role and track of the R8 event it overlaps most (none: no role, goal track).
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

    // Stage 3, entities: people over the whole book, then each chapter's mentions (names and resolved pronouns).
    let tagged = index.map { c -> [IndexedSentence] in
        var sentences = inputs[c.number].map(ctrl.indexSvc.index) ?? []
        for i in sentences.indices { sentences[i].events = EventSplitter.events(in: sentences[i], previous: i > 0 ? sentences[i - 1] : nil) }
        return sentences
    }
    let people = EntityResolver.book(tagged)
    var mentions: [Int: [Int: [EntityMention]]] = [:]
    // Stage 5, roles: each clause's agent · predicate · patient · location, using stage 3's people.
    var roles: [Int: [Int: [RoleSet]]] = [:]
    for (c, sentences) in zip(index, tagged) {
        let m = EntityResolver.mentions(in: sentences, book: people)
        mentions[c.number] = m
        roles[c.number] = Dictionary(sentences.map { ($0.index, RoleLabeler.roles(in: $0, people: m[$0.index] ?? [])) },
                                     uniquingKeysWith: { a, _ in a })
    }
    let entityIDF = RecallEntities.idf(tagged: tagged, chapters: index.map(\.number), mentions: mentions, roles: roles)

    var rows: [RecallRow] = []
    let wanted = Set(pairs.map(\.chapter))
    for c in index where wanted.contains(c.number) {
        guard let input = inputs[c.number] else { continue }
        let chapter = await ctrl.prepare(input, bookStats: stats)
        let entities = RecallEntities(mentions: mentions[c.number] ?? [:], roles: roles[c.number] ?? [:], idf: entityIDF)
        for pair in pairs where pair.chapter == c.number {
            rows.append(recallRow(pair, input: input, chapter: chapter, ctrl: ctrl, entities: entities))
        }
    }
    print(RecallEntities.describe(people))

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
    var rankBoth: Int?          // 1-based rank in R8's ranking (both signals + bonus)
    var rankMeaning: Int?       // by vector similarity only
    var rankWords: Int?         // by IDF-weighted shared lemmas only
    var inCandidates = false    // in R8's floor + top `maxCandidates`, the set sent on to confirm
    var detected = false        // R8's Detect makes a candidate overlapping the phrase
    var distance = 0            // sentences between them
    var rankWordsPlain: Int?    // words only, this test's own IDF (the same as `rankWords` up to ties): the baseline for…
    var rankWordsEntities: Int? // …words plus entity tokens (stage 3)
    var rankBothEntities: Int?  // R8's mix with the entity-aware words signal
    var queryEntities = 0       // entity tokens in the hand-picked phrase
    var rankWordsRoles: Int?    // words + role pairs (stage 5)
    var rankWordsAll: Int?      // words + entities + role pairs
    var rankRolesOnly: Int?     // role pairs alone
    var rankBothAll: Int?       // R8's mix with words + entities + role pairs
    var queryRoles = 0          // role-pair tokens in the hand-picked phrase
    var rankWordsPlusRoles: Int? // words, plus half the role-pair score added on top (roles can only help, never dilute)
}

@available(macOS 27, *)
private func recallRow(_ pair: RecallPair, input: ChapterInput, chapter: IndexedChapter, ctrl: UnderlineCtrl,
                       entities: RecallEntities) -> RecallRow {
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

    let query = SearchQuery.make(candidate: candidate, in: later, embedding: ctrl.embeddingSvc, tagger: ctrl.indexSvc)
    let result = CandidateScorer.rank(query, in: chapter, before: later.index, mode: .both)
    let paragraphOf = Dictionary(chapter.sentences.map { ($0.index, $0.paragraph) }, uniquingKeysWith: { a, _ in a })
    let ranking = result.ranking.filter { (paragraphOf[$0.sentence] ?? .max) < later.paragraph }
    row.pool = ranking.count
    func rank(_ ordered: [Candidate]) -> Int? { ordered.firstIndex { $0.sentence == earlier.index }.map { $0 + 1 } }
    row.rankBoth = rank(ranking)
    row.rankMeaning = rank(ranking.sorted { ($0.rawMeaning, $0.sentence) > ($1.rawMeaning, $1.sentence) })
    row.rankWords = rank(ranking.sorted { ($0.rawWords, $0.sentence) > ($1.rawWords, $1.sentence) })
    // Stage 3: the same words signal with each sentence's entity tokens added, then R8's mix with it.
    let sentenceOf = Dictionary(chapter.sentences.map { ($0.index, $0) }, uniquingKeysWith: { a, _ in a })
    let queryPlain = query.lemmas
    let queryPeople = entities.tokens(in: later.index, overlapping: phraseRange)
    row.queryEntities = queryPeople.count
    let plain = ranking.map { entities.words(query: queryPlain, sentence: sentenceOf[$0.sentence]!, withEntities: false) }
    let withPeople = ranking.map { entities.words(query: queryPlain.union(queryPeople), sentence: sentenceOf[$0.sentence]!, withEntities: true) }
    let queryRoles = entities.roleTokens(in: later.index, overlapping: phraseRange)
    row.queryRoles = queryRoles.count
    let withRoles = ranking.map { entities.words(query: queryPlain.union(queryRoles), sentence: sentenceOf[$0.sentence]!, withEntities: false, withRoles: true) }
    let withAll = ranking.map { entities.words(query: queryPlain.union(queryPeople).union(queryRoles), sentence: sentenceOf[$0.sentence]!,
                                               withEntities: true, withRoles: true) }
    let rolesOnly = ranking.map { entities.words(query: queryRoles, sentence: sentenceOf[$0.sentence]!, withEntities: false, withRoles: true,
                                                 withLemmas: false) }
    func rank(by scores: [Double]) -> Int? {
        let order = ranking.indices.sorted { (scores[$0], ranking[$0].sentence) > (scores[$1], ranking[$1].sentence) }
        return order.firstIndex { ranking[$0].sentence == earlier.index }.map { $0 + 1 }
    }
    row.rankWordsPlain = rank(by: plain)
    row.rankWordsEntities = rank(by: withPeople)
    let meaning = RecallEntities.scaled(ranking.map(\.rawMeaning)), words = RecallEntities.scaled(withPeople)
    row.rankBothEntities = rank(by: ranking.indices.map {
        SearchKnobs.embedWeight * meaning[$0] + SearchKnobs.wordsWeight * words[$0] + ranking[$0].bonus
    })
    row.rankWordsRoles = rank(by: withRoles)
    row.rankWordsPlusRoles = rank(by: ranking.indices.map { plain[$0] + 0.5 * rolesOnly[$0] })
    row.rankWordsAll = rank(by: withAll)
    row.rankRolesOnly = queryRoles.isEmpty ? nil : rank(by: rolesOnly)
    let wordsAll = RecallEntities.scaled(withAll)
    row.rankBothAll = rank(by: ranking.indices.map {
        SearchKnobs.embedWeight * meaning[$0] + SearchKnobs.wordsWeight * wordsAll[$0] + ranking[$0].bonus
    })
    row.inCandidates = UnderlineSearch.candidates(SearchResult(ranking: ranking, modeUsed: result.modeUsed, highestScored: result.highestScored))
        .contains { $0.sentence == earlier.index }
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
        var s = "# Retrieval recall, \(book) (R8 ranking, before confirm)\n\n"
        s += "Hand-picked links judged right: \(rows.count). Usable: \(ok.count).\n"
        for status in Set(rows.map(\.status)).subtracting(["ok"]).sorted() {
            s += "- \(status): \(rows.filter { $0.status == status }.count)\n"
        }
        s += "\nPool (earlier sentences in earlier paragraphs of the chapter): median \(pools.isEmpty ? 0 : pools[pools.count / 2]), "
        s += "max \(pools.last ?? 0). Distance to the linked sentence: median \(distances.isEmpty ? 0 : distances[distances.count / 2]) sentences.\n\n"
        s += "| Ranking | " + ks.map { "@\($0)" }.joined(separator: " | ") + " |\n|---|" + ks.map { _ in "---|" }.joined() + "\n"
        for (name, ranks) in [("R8 (both + bonus)", ok.map(\.rankBoth)), ("Meaning only (vector)", ok.map(\.rankMeaning)),
                              ("Words only (IDF lemmas)", ok.map(\.rankWords)),
                              ("Words only, this test's IDF", ok.map(\.rankWordsPlain)),
                              ("**Words + entities (stage 3)**", ok.map(\.rankWordsEntities)),
                              ("**R8 mix with words + entities**", ok.map(\.rankBothEntities)),
                              ("**Words + roles (stage 5)**", ok.map(\.rankWordsRoles)),
                              ("**Words + ½ roles on top**", ok.map(\.rankWordsPlusRoles)),
                              ("**Words + entities + roles**", ok.map(\.rankWordsAll)),
                              ("**R8 mix with words + entities + roles**", ok.map(\.rankBothAll)),
                              ("Roles only (phrases with roles; misses count as not found)", ok.map(\.rankRolesOnly))] {
            s += "| \(name) | " + ks.map { atK(ranks, $0) }.joined(separator: " | ") + " |\n"
        }
        s += "| Random (pool size) | " + ks.map { k in
            ok.isEmpty ? "–" : String(format: "%.1f%%", 100 * ok.map { $0.pool == 0 ? 0 : min(1, Double(k) / Double($0.pool)) }.reduce(0, +) / Double(ok.count))
        }.joined(separator: " | ") + " |\n\n"
        s += "- In R8's candidate set (floor + top \(SearchKnobs.maxCandidates), what goes on to confirm): \(pct(ok.filter(\.inCandidates).count, ok.count))\n"
        s += "- R8's Detect makes a candidate overlapping the hand-picked phrase: \(pct(ok.filter(\.detected).count, ok.count))\n"
        s += "- Phrases with at least one role pair: \(pct(ok.filter { $0.queryRoles > 0 }.count, ok.count))\n"
        s += "- Phrases with at least one entity token (a name or a resolved pronoun): \(pct(ok.filter { $0.queryEntities > 0 }.count, ok.count))\n"
        s += "- Both (detected and in the candidate set): \(pct(ok.filter { $0.detected && $0.inCandidates }.count, ok.count))\n"
        return s
    }

    static func csv(_ rows: [RecallRow]) -> String {
        func q(_ v: String) -> String { "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        func n(_ v: Int?) -> String { v.map(String.init) ?? "" }
        var out = "chapter,line,status,pool,distance,rank_both,rank_meaning,rank_words,rank_words_entities,rank_both_entities,query_entities,in_candidates,detected,phrase,passage\n"
        for r in rows {
            out += [String(r.pair.chapter), String(r.pair.line), r.status, String(r.pool), String(r.distance), n(r.rankBoth),
                    n(r.rankMeaning), n(r.rankWords), n(r.rankWordsEntities), n(r.rankBothEntities), String(r.queryEntities), r.inCandidates ? "yes" : "no", r.detected ? "yes" : "no",
                    q(r.pair.phrase), q(r.pair.passage)].joined(separator: ",") + "\n"
        }
        return out
    }
}

/// Stage 3 in the recall test: each sentence's content lemmas plus its entity tokens, with IDF over both.
struct RecallEntities {
    let mentions: [Int: [EntityMention]]
    let roles: [Int: [RoleSet]]
    let idf: [String: Double]

    func roleTokens(in sentence: Int, overlapping range: NSRange? = nil) -> Set<String> {
        Set((roles[sentence] ?? []).filter { range == nil || NSIntersectionRange($0.range, range!).length > 0 }.flatMap(RoleLabeler.tokens))
    }

    func tokens(in sentence: Int, overlapping range: NSRange? = nil) -> Set<String> {
        Set((mentions[sentence] ?? []).filter { range == nil || NSIntersectionRange($0.range, range!).length > 0 }
            .map { EntityResolver.token($0.entity) })
    }

    /// Shared tokens ÷ query tokens, weighted by IDF, as `CandidateScorer` does for lemmas.
    func words(query: Set<String>, sentence: IndexedSentence, withEntities: Bool, withRoles: Bool = false, withLemmas: Bool = true) -> Double {
        var have = withLemmas ? SearchQuery.contentLemmas(sentence.tokens) : []
        if withEntities { have.formUnion(tokens(in: sentence.index)) }
        if withRoles { have.formUnion(roleTokens(in: sentence.index)) }
        let weight: (String) -> Double = { idf[$0] ?? 1 }
        let total = query.reduce(0) { $0 + weight($1) }
        return total <= 0 ? 0 : have.intersection(query).reduce(0) { $0 + weight($1) } / total
    }

    static func idf(tagged: [[IndexedSentence]], chapters: [Int], mentions: [Int: [Int: [EntityMention]]],
                    roles: [Int: [Int: [RoleSet]]]) -> [String: Double] {
        var counts: [String: Int] = [:]
        var total = 0
        for (number, sentences) in zip(chapters, tagged) {
            for s in sentences {
                total += 1
                let people = Set((mentions[number]?[s.index] ?? []).map { EntityResolver.token($0.entity) })
                let pairs = Set((roles[number]?[s.index] ?? []).flatMap(RoleLabeler.tokens))
                for t in SearchQuery.contentLemmas(s.tokens).union(people).union(pairs) { counts[t, default: 0] += 1 }
            }
        }
        return counts.mapValues { log(1 + Double(max(total, 1)) / Double(max($0, 1))) }
    }

    static func scaled(_ values: [Double]) -> [Double] {
        guard let low = values.min(), let high = values.max(), high > low else { return values.map { _ in 0 } }
        return values.map { ($0 - low) / (high - low) }
    }

    static func describe(_ book: EntityBook) -> String {
        let byEntity = Dictionary(grouping: book.entityOf, by: \.value).mapValues { $0.map(\.key).sorted() }
        return "Entities: " + byEntity.keys.sorted().prefix(60).map { "\($0) [\(book.gender[$0]?.rawValue ?? "?")] ← \(byEntity[$0]!.joined(separator: " | "))" }
            .joined(separator: "\n  ")
    }
}
