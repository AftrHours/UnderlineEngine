import Foundation
@testable import UnderlineEngine

/// Why an expected underline wasn't made; says what to fix (spec §8.3).
enum MissCause: String, Codable, Hashable, Sendable, CaseIterable {
    case detectMiss, searchMiss, pickMiss, confirmRejected, guardRejected, densityLimit, modelFailed, explainedInParagraph

    var label: String {
        switch self {
        case .detectMiss: "detect miss"
        case .searchMiss: "search miss"
        case .pickMiss: "pick miss"
        case .confirmRejected: "confirm rejected"
        case .guardRejected: "guard rejected"
        case .densityLimit: "density limit"
        case .modelFailed: "model failed"
        case .explainedInParagraph: "explained in paragraph"
        }
    }
}

/// One outcome per golden item, worst first (spec §8.3).
enum Outcome: Codable, Hashable, Sendable, Comparable {
    case spoiler, mismatch, missed(MissCause), underlinedRight, correctlyNone

    var rank: Int {
        switch self {
        case .spoiler: 0
        case .mismatch: 1
        case .missed(let c): 2 + (MissCause.allCases.firstIndex(of: c) ?? 0)
        case .underlinedRight: 20
        case .correctlyNone: 21
        }
    }

    var label: String {
        switch self {
        case .spoiler: "⛔ spoiler"
        case .mismatch: "❌ mismatch"
        case .missed(let c): "⚠️ missed (\(c.label))"
        case .underlinedRight: "✅ underlined, right reference"
        case .correctlyNone: "✅ correctly none"
        }
    }

    var isGood: Bool { rank >= 20 }

    static let all: [Outcome] = [.spoiler, .mismatch] + MissCause.allCases.map(Outcome.missed) + [.underlinedRight, .correctlyNone]

    static func < (a: Outcome, b: Outcome) -> Bool { a.rank < b.rank }
}

/// Whether an engine phrase is the golden item's phrase. A person item matches only the name itself. Otherwise the engine
/// phrase may cover the golden phrase, or sit inside it when it's at least half its length, so a name inside a longer
/// golden phrase ("Marmee" in "Let Marmee think…") is a different underline.
func matches(_ enginePhrase: String, _ item: GoldItem) -> Bool {
    let e = TextMatch.normalized(enginePhrase), g = TextMatch.normalized(item.phrase)
    guard !e.isEmpty, !g.isEmpty else { return false }
    if item.kind == .person { return e == g }
    return e.contains(g) || (g.contains(e) && e.count * 2 >= g.count)
}

enum OutcomeClassifier {
    static func classify(_ item: ResolvedItem, underlines: ChapterUnderlines, records: [UnderlineRecord]) -> Outcome {
        let s = item.sentence
        let inSentence = records.filter { $0.sentence == s }
        if inSentence.contains(where: { $0.candidates.contains { $0 >= s } || $0.promptSentences.contains { $0 > s } }) { return .spoiler }
        let shown = underlines.underlines.first { $0.sentence == s && matches($0.text, item.item) }
        guard item.item.expected.isAnswerable else { return shown == nil ? .correctlyNone : .mismatch }
        if let shown { return item.references.contains(shown.reference.sentence) ? .underlinedRight : .mismatch }

        let matching = inSentence.filter { matches($0.phrase, item.item) }
        guard let record = matching.first(where: \.kept) ?? matching.first else { return .missed(.detectMiss) }
        let refInCandidates = !Set(record.candidates).isDisjoint(with: item.references)
        switch record.dropped {
        case .noCandidate?: return .missed(.searchMiss)
        case .pickedNone?: return .missed(refInCandidates ? .pickMiss : .searchMiss)
        case .confirmRejected?: return .missed(.confirmRejected)
        case .guardRejected?: return .missed(.guardRejected)
        case .densityLimit?: return .missed(.densityLimit)
        case .modelFailed?: return .missed(.modelFailed)
        case .explainedInParagraph?: return .missed(.explainedInParagraph)
        case nil: return .missed(.detectMiss)
        }
    }
}
