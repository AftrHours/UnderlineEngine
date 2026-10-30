import Foundation
@testable import UnderlineEngine

/// The golden set: hand-labelled phrases for one chapter (spec §8.2).
struct GoldSet: Codable, Sendable {
    var chapter: String
    var items: [GoldItem]
}

/// A sentence by index and text, so items stay valid if sentence splitting changes.
struct GoldRef: Codable, Hashable, Sendable {
    let index: Int
    let text: String
}

/// Why an underline-worthy-looking phrase should get no underline.
enum NoneReason: String, Codable, Hashable, Sendable {
    case explanationLater, sameSentence, temptingWrongPassage, noExplanation
}

enum GoldExpected: Codable, Hashable, Sendable {
    /// Underline it, with one of these earlier sentences as the reference.
    case underline(references: [Int])
    case none(NoneReason)

    var isAnswerable: Bool {
        if case .underline = self { return true }
        return false
    }

    private enum Key: String, CodingKey { case kind, references, reason }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "underline": self = .underline(references: try c.decode([Int].self, forKey: .references))
        case "none": self = .none(try c.decode(NoneReason.self, forKey: .reason))
        case let other: throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "unknown kind \(other)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Key.self)
        switch self {
        case .underline(let r): try c.encode("underline", forKey: .kind); try c.encode(r, forKey: .references)
        case .none(let reason): try c.encode("none", forKey: .kind); try c.encode(reason, forKey: .reason)
        }
    }
}

struct GoldItem: Codable, Hashable, Sendable {
    let id: String
    let sentence: GoldRef
    /// An exact substring of the sentence.
    let phrase: String
    let kind: UnderlineKind
    let expected: GoldExpected
    /// Drafted by the builder, not yet reviewed by the product owner (spec §8.2).
    let provisional: Bool
    let note: String?

    /// Finds the sentence by index, or by exact text if the index moved; the phrase must be in it.
    /// `nil` for a stale item. Reference indexes are kept as written (as in TextEngine).
    func resolve(in chapter: IndexedChapter) -> ResolvedItem? {
        let wanted = sentence.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let index = chapter.sentence(sentence.index)?.text == wanted ? sentence.index : chapter.sentences.first { $0.text == wanted }?.index
        guard let index, let text = chapter.sentence(index)?.text,
              TextMatch.normalized(text).contains(TextMatch.normalized(phrase)) else { return nil }
        let references: [Int] = if case .underline(let r) = expected { r } else { [] }
        return ResolvedItem(item: self, sentence: index, references: references)
    }
}

struct ResolvedItem: Codable, Hashable, Sendable {
    let item: GoldItem
    let sentence: Int
    let references: [Int]
}
