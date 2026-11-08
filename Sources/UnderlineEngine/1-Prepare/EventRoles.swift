import Foundation

/// The causal role of an event (Trabasso & van den Broek), the track it maps to, and cue words (spec §4.3).
enum EventRoles {
    /// `phrase` is the event's tokens, `subject` the tokens before it in the same clause.
    static func role(of phrase: [WordToken], subject: [WordToken], isRelative: Bool, in sentence: IndexedSentence) -> EventRole {
        let lemmas = phrase.map(\.lemma)
        let mainVerb = mainVerb(of: phrase)
        if lemmas.contains(where: EventKnobs.reactionCues.contains) { return .reaction }
        if lemmas.contains(where: EventKnobs.emotionWords.contains) { return .internalResponse }
        if EventKnobs.wantVerbs.contains(mainVerb) { return .goal }
        if EventKnobs.resultVerbs.contains(mainVerb) { return .outcome }
        if isRelative || EventKnobs.stateVerbs.contains(mainVerb) { return .setting }
        if hasThingSubject(subject, in: sentence) { return .initiatingEvent }
        return .attempt
    }

    /// The track a role maps to, after Zwaan's event-indexing model (spec §4.2).
    static func track(for role: EventRole, phrase: [WordToken]) -> Track {
        switch role {
        case .setting:
            let lemmas = Set(phrase.map(\.lemma))
            if !lemmas.isDisjoint(with: EventKnobs.placeWords) { return .place }
            if !lemmas.isDisjoint(with: EventKnobs.timeWords) { return .time }
            return .character
        case .goal, .attempt: return .goal
        case .initiatingEvent, .internalResponse, .reaction, .outcome: return .cause
        }
    }

    /// The reason clause after `target` in the same sentence ("…because it is going to be a hard winter"),
    /// up to the next `;` `.` `!` `?` or closing quote. `nil` when there's none (spec §4.3, `explainedHere`).
    /// The connective must come before `stopAt` (the start of the next event), so a reason that belongs to a later
    /// event ("…and began to whistle because…") is never given for an earlier one.
    static func reasonClause(after target: NSRange, in sentence: IndexedSentence, stopAt: Int? = nil) -> NSRange? {
        let text = sentence.text as NSString
        let stops = CharacterSet(charactersIn: ";.!?\u{201D}\"")
        let targetEnd = NSMaxRange(target)
        for (i, token) in sentence.tokens.enumerated() where token.range.location >= targetEnd {
            if let stopAt, token.range.location >= stopAt { return nil }
            let gap = text.substring(with: NSRange(location: targetEnd, length: token.range.location - targetEnd))
            if gap.rangeOfCharacter(from: stops) != nil { return nil }
            let word = token.text.lowercased()
            let afterComma = i > 0 && text.substring(with: NSRange(location: NSMaxRange(sentence.tokens[i - 1].range),
                                                                  length: token.range.location - NSMaxRange(sentence.tokens[i - 1].range))).contains(",")
            let isSoThat = word == "so" && i + 1 < sentence.tokens.count && sentence.tokens[i + 1].text.lowercased() == "that"
            guard EventKnobs.causalConnectives.contains(word) || isSoThat || (word == "for" && afterComma) else { continue }
            let rest = NSRange(location: token.range.location, length: text.length - token.range.location)
            let stop = text.rangeOfCharacter(from: stops, options: [], range: rest)
            let end = stop.location == NSNotFound ? text.length : stop.location
            let clause = text.substring(with: NSRange(location: token.range.location, length: end - token.range.location))
            let trimmed = clause.trimmingCharacters(in: .whitespaces)
            return NSRange(location: token.range.location, length: (trimmed as NSString).length)
        }
        return nil
    }

    /// The first verb that isn't a helping verb: "shall not have him" → "have", "is going to be" → "go".
    private static func mainVerb(of phrase: [WordToken]) -> String {
        let verbs = phrase.enumerated().filter { $0.element.wordClass == "Verb" }
        for (offset, verb) in verbs where !EventKnobs.modals.contains(verb.lemma) {
            let rest = phrase[(offset + 1)...].prefix { $0.wordClass == "Adverb" || $0.lemma == "not" }
            let next = phrase.dropFirst(offset + 1 + rest.count).first
            let isHelping = ["be", "have"].contains(verb.lemma) && next?.wordClass == "Verb"
            if !isHelping { return verb.lemma }
        }
        return verbs.last?.element.lemma ?? ""
    }

    /// The clause's subject is a thing, not a person ("the fire broke out", "a letter came").
    private static func hasThingSubject(_ subject: [WordToken], in sentence: IndexedSentence) -> Bool {
        let nouns = subject.filter { $0.wordClass == "Noun" || $0.wordClass == "Pronoun" }
        guard !nouns.isEmpty else { return false }
        let hasPerson = nouns.contains { noun in
            EventKnobs.subjectPronouns.contains(noun.text.lowercased())
                || sentence.names.contains { NSIntersectionRange($0.range, noun.range).length > 0 }
                || noun.text.first?.isUppercase == true
        }
        return !hasPerson
    }
}
