import Foundation

enum RoleKnobs {
    /// A noun after one of these is where the event happens, not what it acts on.
    static let placePrepositions: Set<String> = [
        "in", "at", "into", "on", "onto", "to", "from", "near", "under", "over", "through", "across", "inside", "outside",
        "toward", "towards", "behind", "beside", "upon", "within"
    ]
}

/// One clause's semantic roles (semantic role labeling, rules only): agent · predicate · patient · location.
/// A person is their entity ID ("jo"), a thing its lemma ("letter"). `range` is the clause, within the sentence.
struct RoleSet: Sendable, Hashable {
    let agent: String?
    let predicate: String?
    let patient: String?
    let location: String?
    let range: NSRange
}

/// Roles (stage 5): labels each clause of a sentence (`EventSplitter`'s events) with who did what to what, where, from
/// NaturalLanguage's word classes and lemmas plus stage 3's people. Position rules, not a parser: the agent is the person or
/// noun before the main verb (or the previous clause's agent: "Jo sat up … and began to whistle"), the patient the first noun or
/// person after it, the location a noun after a place preposition. Pure.
enum RoleLabeler {
    static func roles(in sentence: IndexedSentence, people: [EntityMention]) -> [RoleSet] {
        let clauses = sentence.events.isEmpty
            ? [NSRange(location: 0, length: (sentence.text as NSString).length)]
            : sentence.events.map(\.range).sorted { $0.location < $1.location }
        var out: [RoleSet] = []
        var lastAgent: String?
        for (i, clause) in clauses.enumerated() {
            // The subject can sit before the event's own range ("Jo | immediately sat up"): look back to the previous clause.
            let from = i == 0 ? 0 : NSMaxRange(clauses[i - 1])
            let end = NSMaxRange(clause)
            let tokens = sentence.tokens.filter { $0.range.location >= min(from, clause.location) && $0.range.location < end }
            guard let verb = mainVerb(tokens) else { continue }
            let person: (WordToken) -> String? = { t in
                people.first { NSIntersectionRange($0.range, t.range).length > 0 }?.entity
            }

            var agent: String?
            for t in tokens[..<verb].reversed() {
                if let p = person(t) { agent = p; break }
                if t.wordClass == "Noun" { agent = t.lemma; break }
            }
            agent = agent ?? lastAgent
            lastAgent = agent

            var patient: String?, location: String?
            var inPlacePhrase = false
            for t in tokens[(verb + 1)...] {
                if t.wordClass == "Verb" { break }
                if t.wordClass == "Preposition" || t.wordClass == "Particle" {
                    inPlacePhrase = RoleKnobs.placePrepositions.contains(t.lemma)
                    continue
                }
                let value = person(t) ?? (t.wordClass == "Noun" ? t.lemma : nil)
                guard let value else { continue }
                if inPlacePhrase { if location == nil { location = value } } else if patient == nil { patient = value }
                if patient != nil, location != nil { break }
            }
            out.append(RoleSet(agent: agent, predicate: tokens[verb].lemma, patient: patient, location: location, range: clause))
        }
        return out
    }

    /// Retrieval tokens for a role set: pairs of roles, which a bag of words can't tell apart
    /// ("give>present" is not "present" and "give" anywhere in the sentence).
    static func tokens(_ r: RoleSet) -> Set<String> {
        var out = Set<String>()
        if let p = r.predicate, let o = r.patient { out.insert("pp:\(p)>\(o)") }
        if let a = r.agent, let p = r.predicate { out.insert("ap:\(a)>\(p)") }
        if let p = r.predicate, let l = r.location { out.insert("pl:\(p)>\(l)") }
        if let a = r.agent, let o = r.patient { out.insert("ao:\(a)>\(o)") }
        return out
    }

    /// The first verb that isn't a modal or a helping verb ("shall not have him" → have, "had given" → give).
    private static func mainVerb(_ tokens: [WordToken]) -> Int? {
        let verbs = tokens.indices.filter { tokens[$0].wordClass == "Verb" && !EventKnobs.modals.contains(tokens[$0].lemma) }
        for v in verbs {
            let next = tokens[(v + 1)...].first { $0.wordClass != "Adverb" && $0.lemma != "not" }
            let isHelping = ["be", "have"].contains(tokens[v].lemma) && next?.wordClass == "Verb"
            if !isHelping { return v }
        }
        return verbs.last
    }
}
