// Rough semantic roles (SRL) with Apple's NaturalLanguage only (what a phone could do):
// who (agent) · did (predicate) · what (patient) · where (location) per verb.
//
//     swift Experiments/srl/rough_roles.swift little-women 1 47
//
// Reads Experiments/srl/data/<book>-chNN-sentences.json (split.py), writes <book>-chNN-roles-rough.json in the same shape
// as the roles Claude extracted, so match.py can compare them.
import Foundation
import NaturalLanguage

struct Sentence: Codable { let id: Int; let paragraph: Int; let start: Int; let end: Int; let text: String }
struct Roles: Codable { let who: String?; let did: String?; let what: String?; let `where`: String? }
struct Entry: Codable { let id: Int; let roles: [Roles] }

struct Token {
    let text: String
    let lemma: String
    let tag: NLTag?
    var person: String?   // the joined person name this word belongs to
    var place: String?
}

let skipVerbs: Set = ["be", "have", "do", "will", "would", "shall", "should", "can", "could", "may", "might", "must", "ought",
                      "say", "reply", "answer", "cry", "exclaim", "ask", "add", "continue", "return",
                      "wo", "ca", "sha", "'ll", "'d", "'s", "'re", "'ve", "'m"]
let pronouns: Set = ["he", "she", "him", "her"]
let placePrepositions: Set = ["in", "at", "into", "to", "on", "from", "through", "toward", "towards", "across", "inside"]

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let data = root.appendingPathComponent("Experiments/srl/data")
let book = CommandLine.arguments[1]
let first = Int(CommandLine.arguments[2])!, last = Int(CommandLine.arguments[3])!

func tokens(_ text: String) -> [Token] {
    let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma, .nameType])
    tagger.string = text
    var out: [Token] = []
    tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
                         options: [.omitPunctuation, .omitWhitespace]) { tag, range in
        let word = String(text[range])
        let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue ?? word
        out.append(Token(text: word, lemma: lemma.lowercased(), tag: tag))
        return true
    }
    // Names, joined ("Mrs. March"), marked on the words they cover.
    var names: [(String, NLTag, Range<String.Index>)] = []
    tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType,
                         options: [.omitPunctuation, .omitWhitespace, .joinNames]) { tag, range in
        if let tag, tag == .personalName || tag == .placeName { names.append((String(text[range]).lowercased(), tag, range)) }
        return true
    }
    var searchFrom = text.startIndex
    for i in out.indices {
        guard let r = text.range(of: out[i].text, range: searchFrom..<text.endIndex) else { continue }
        searchFrom = r.upperBound
        for (name, tag, range) in names where range.contains(r.lowerBound) {
            if tag == .personalName { out[i].person = name } else { out[i].place = name }
        }
    }
    return out
}

var lastPerson: String?
for n in first...last {
    let tag = String(format: "ch%02d", n)
    let sentences = try JSONDecoder().decode([Sentence].self,
                                             from: Data(contentsOf: data.appendingPathComponent("\(book)-\(tag)-sentences.json")))
    lastPerson = nil
    var entries: [Entry] = []
    for sentence in sentences {
        let toks = tokens(sentence.text)
        var roles: [Roles] = []
        for (v, tok) in toks.enumerated() where tok.tag == .verb && !skipVerbs.contains(tok.lemma) {
            // who: the nearest person (or he/she → the last person named) before the verb, back to the previous verb.
            var who: String?
            var k = v - 1
            while k >= 0, toks[k].tag != .verb || skipVerbs.contains(toks[k].lemma) {
                if let p = toks[k].person { who = p; break }
                if pronouns.contains(toks[k].text.lowercased()) { who = lastPerson; break }
                k -= 1
            }
            // what and where: forward, up to the next real verb.
            var what: String?, place: String?
            var j = v + 1
            // "grumbled Jo": a name right after the verb is its subject when none came before.
            if who == nil, j < toks.count, let p = toks[j].person { who = p; j += 1 }
            while j < toks.count, !(toks[j].tag == .verb && !skipVerbs.contains(toks[j].lemma)) {
                let t = toks[j]
                if what == nil, let p = t.person { what = p }
                if what == nil, t.tag == .noun, t.place == nil { what = t.lemma }
                if place == nil, placePrepositions.contains(t.text.lowercased()) {
                    for m in (j + 1)..<min(j + 4, toks.count) where toks[m].tag == .noun || toks[m].place != nil {
                        place = toks[m].place ?? toks[m].lemma
                        break
                    }
                }
                j += 1
            }
            roles.append(Roles(who: who, did: tok.lemma, what: what, where: place))
        }
        if let p = toks.last(where: { $0.person != nil })?.person { lastPerson = p }
        entries.append(Entry(id: sentence.id, roles: roles))
    }
    let encoder = JSONEncoder()
    try encoder.encode(entries).write(to: data.appendingPathComponent("\(book)-\(tag)-roles-rough.json"))
    print("\(tag): \(sentences.count) sentences, \(entries.reduce(0) { $0 + $1.roles.count }) role sets")
}
