import Foundation

enum EntityKnobs {
    /// Words before a surname that make it a person of its own ("Mrs. March" is not "Meg March").
    static let femaleTitles: Set<String> = ["mrs", "miss", "aunt", "lady", "madame", "mme", "mademoiselle", "mlle", "ms", "sister"]
    static let maleTitles: Set<String> = ["mr", "sir", "uncle", "lord", "master", "captain", "capt", "dr", "doctor", "colonel", "col",
                                          "father", "brother", "monsieur", "herr", "professor", "mister"]
    static let femalePronouns: Set<String> = ["she", "her", "hers", "herself"]
    static let malePronouns: Set<String> = ["he", "him", "his", "himself"]
    /// "Jo March" is "Jo" when "Jo" alone is a name this many times in the book.
    static let firstNameMinMentions = 3
    /// A name's gender needs this many pronoun votes, and this share of them.
    static let genderMinVotes = 3
    static let genderMinShare = 0.7
    /// A pronoun refers back at most this many sentences, within the chapter.
    static let pronounReach = 4
}

enum EntityGender: String, Sendable, Codable { case female, male, unknown }

/// One person in a sentence: a name, or a pronoun resolved to one. `range` is within the sentence, UTF-16.
struct EntityMention: Sendable, Hashable {
    let entity: String
    let range: NSRange
    let isPronoun: Bool
}

/// Who each name is, over the whole book: its entity and the entity's gender.
struct EntityBook: Sendable {
    /// Surface name, normalised ("jo march", "mrs march") → entity ID ("jo", "mrs march").
    let entityOf: [String: String]
    let gender: [String: EntityGender]
}

/// Entities (stage 3): names and the pronouns that point to them become one token per person, so a sentence about "she"
/// can share a word with one about "Jo". Rules only, from NaturalLanguage's person names; no coreference model. Pure.
enum EntityResolver {
    /// Learns the book's people from every sentence (chapters in order).
    static func book(_ chapters: [[IndexedSentence]]) -> EntityBook {
        var mentions: [String: Int] = [:]
        for s in chapters.joined() { for n in s.names where n.kind == .person { mentions[normalised(n.text), default: 0] += 1 } }

        var entityOf: [String: String] = [:]
        for name in mentions.keys {
            let words = name.split(separator: " ").map(String.init)
            if words.count >= 2, !isTitle(words[0]), (mentions[words[0]] ?? 0) >= EntityKnobs.firstNameMinMentions {
                entityOf[name] = words[0]
            } else {
                entityOf[name] = name
            }
        }

        // Gender: titles first; otherwise the pronouns in a sentence naming only that person, and the sentence after it.
        var votes: [String: (female: Int, male: Int)] = [:]
        for chapter in chapters {
            for (i, s) in chapter.enumerated() {
                let people = Set(s.names.filter { $0.kind == .person }.compactMap { entityOf[normalised($0.text)] })
                guard people.count == 1, let person = people.first else { continue }
                let window = [s] + (i + 1 < chapter.count ? [chapter[i + 1]] : [])
                let lower = window.flatMap(\.tokens).map { $0.text.lowercased() }
                votes[person, default: (0, 0)].female += lower.filter(EntityKnobs.femalePronouns.contains).count
                votes[person, default: (0, 0)].male += lower.filter(EntityKnobs.malePronouns.contains).count
            }
        }
        var gender: [String: EntityGender] = [:]
        for entity in Set(entityOf.values) {
            let first = entity.split(separator: " ").first.map(String.init) ?? ""
            if EntityKnobs.femaleTitles.contains(first) { gender[entity] = .female; continue }
            if EntityKnobs.maleTitles.contains(first) { gender[entity] = .male; continue }
            let v = votes[entity] ?? (0, 0)
            let total = v.female + v.male
            if total >= EntityKnobs.genderMinVotes, Double(v.female) / Double(total) >= EntityKnobs.genderMinShare { gender[entity] = .female }
            else if total >= EntityKnobs.genderMinVotes, Double(v.male) / Double(total) >= EntityKnobs.genderMinShare { gender[entity] = .male }
            else { gender[entity] = .unknown }
        }
        return EntityBook(entityOf: entityOf, gender: gender)
    }

    /// Every person mention in a chapter, by sentence index: names, and he/she/him/her… resolved to the most recent person
    /// of that gender in the last `pronounReach` sentences (earlier in the same sentence included). Unresolved pronouns are left out.
    static func mentions(in chapter: [IndexedSentence], book: EntityBook) -> [Int: [EntityMention]] {
        var out: [Int: [EntityMention]] = [:]
        var recent: [(entity: String, gender: EntityGender, sentence: Int)] = []   // most recent last
        for (position, s) in chapter.enumerated() {
            var found: [EntityMention] = []
            let names = s.names.filter { $0.kind == .person }
            // Names and pronouns in reading order.
            var events: [(NSRange, String?, EntityGender?)] = names.map { ($0.range, book.entityOf[normalised($0.text)], nil) }
            for t in s.tokens {
                let w = t.text.lowercased()
                if EntityKnobs.femalePronouns.contains(w) { events.append((t.range, nil, .female)) }
                if EntityKnobs.malePronouns.contains(w) { events.append((t.range, nil, .male)) }
            }
            for (range, entity, pronoun) in events.sorted(by: { $0.0.location < $1.0.location }) {
                if let entity {
                    found.append(EntityMention(entity: entity, range: range, isPronoun: false))
                    recent.append((entity, book.gender[entity] ?? .unknown, position))
                } else if let pronoun,
                          let hit = recent.last(where: { $0.gender == pronoun && position - $0.sentence <= EntityKnobs.pronounReach }) {
                    found.append(EntityMention(entity: hit.entity, range: range, isPronoun: true))
                }
            }
            if !found.isEmpty { out[s.index] = found }
        }
        return out
    }

    /// The entity token a sentence or phrase carries for word matching.
    static func token(_ entity: String) -> String { "@" + entity.replacingOccurrences(of: " ", with: "_") }

    /// "Mrs. March" → "mrs march".
    static func normalised(_ name: String) -> String {
        name.lowercased().split { !$0.isLetter && $0 != "'" && $0 != "\u{2019}" }.joined(separator: " ")
    }

    private static func isTitle(_ word: String) -> Bool {
        EntityKnobs.femaleTitles.contains(word) || EntityKnobs.maleTitles.contains(word)
    }
}
