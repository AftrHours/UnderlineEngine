import Foundation
@testable import UnderlineEngine

/// What the engine did for one golden item or one swept underline: the evaluation's subject value.
/// The expected value of a sample uses the same type, with only `underlined` and `referenceText` filled in.
struct EngineResult: Codable, Sendable {
    var underlined = false
    var phrase: String?
    var referenceSentence: Int?
    var referenceText: String?
    var path: String?
    /// Highest sentence among the candidates and prompts, for the spoiler check.
    var highestUsed: Int?
    var candidates: [Int] = []
    var pickedSentence: Int?
    var confirm: Bool?
    var confirmEvidence: String?
    var dropped: String?
    var searchMs: Int?
    var confirmMs: Int?
    /// The outcome against the golden item (golden runs only).
    var outcome: Outcome?

    /// The expected value shown in the evaluation's "Expected" column.
    static func expectation(_ gold: GoldExpected, texts: [String]) -> EngineResult {
        var r = EngineResult()
        switch gold {
        case .underline(let refs):
            r.underlined = true
            r.referenceText = zip(refs, texts).map { "S\($0) \($1)" }.joined(separator: " · or ")
        case .none(let reason):
            r.referenceText = "no underline (\(reason.rawValue))"
        }
        return r
    }

    /// The engine's result for one golden item: its underline if shown, otherwise its best matching record.
    static func from(item: ResolvedItem, underlines: ChapterUnderlines, records: [UnderlineRecord]) -> EngineResult {
        var r = EngineResult()
        let matching = records.filter { $0.sentence == item.sentence && matches($0.phrase, item.item) }
        if let u = underlines.underlines.first(where: { $0.sentence == item.sentence && matches($0.text, item.item) }) {
            r.underlined = true
            r.phrase = u.text
            r.referenceSentence = u.reference.sentence
            r.referenceText = u.reference.text
            r.path = u.decidedBy.rawValue
        }
        if let rec = matching.first(where: \.kept) ?? matching.first { r.fill(from: rec) }
        let used = records.filter { $0.sentence == item.sentence }.flatMap { $0.candidates + $0.promptSentences.filter { $0 != item.sentence } }
        r.highestUsed = used.max()
        return r
    }

    mutating func fill(from rec: UnderlineRecord) {
        phrase = phrase ?? rec.phrase
        path = path ?? rec.path?.rawValue
        candidates = rec.candidates
        pickedSentence = rec.pickedSentence
        confirm = rec.confirm?.explains
        confirmEvidence = rec.confirm?.evidence
        dropped = rec.dropped?.rawValue
        searchMs = rec.times.searchMs
        confirmMs = rec.times.confirmMs
    }
}
