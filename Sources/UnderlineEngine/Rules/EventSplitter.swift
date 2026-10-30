import Foundation

enum EventKnobs {
    /// Verbs that introduce speech. Next to a name or subject pronoun, outside quotes, they are speech tags, not events.
    static let speechVerbs: Set<String> = [
        "say", "ask", "cry", "observe", "add", "return", "advise", "sigh", "grumble", "begin",
        "exclaim", "reply", "answer", "whisper", "call"
    ]
    static let subjectPronouns: Set<String> = ["i", "he", "she", "we", "they", "you"]
    /// Words that end one event and start the next.
    static let coordinators: Set<String> = ["and", "but", "or"]
    /// Characters that end one event and start the next.
    static let boundaryCharacters: Set<Character> = [",", ";", ":", "\u{2014}", "\u{2013}", "\"", "\u{201C}", "\u{201D}", "(", ")"]
    static let relativePronouns: Set<String> = ["who", "which", "that", "whom", "whose"]
    /// Words that open a clause and stay in its event ("where the fighting was").
    static let clauseOpeners: Set<String> = relativePronouns.union(["where", "when"])
    /// Helping verbs: never the main verb of an event.
    static let modals: Set<String> = ["shall", "will", "would", "can", "could", "may", "might", "must", "should", "ought", "do"]

    // Role detection (spec §4.3), compared with lemmas.
    static let reactionCues: Set<String> = ["immediately", "then", "suddenly", "instantly"]
    static let emotionWords: Set<String> = [
        "sigh", "sadly", "sad", "cross", "regretfully", "laugh", "cry", "weep", "smile", "frown", "angry",
        "happy", "glad", "sorry", "fear", "afraid", "blush", "groan", "tear", "contentedly", "sniff"
    ]
    static let wantVerbs: Set<String> = ["want", "wish", "plan", "mean", "hope", "intend", "long", "try"]
    static let resultVerbs: Set<String> = ["lose", "win", "fail", "succeed", "find", "manage"]
    static let stateVerbs: Set<String> = ["be", "seem", "appear", "remain", "become", "have"]
    static let placeWords: Set<String> = [
        "room", "house", "home", "town", "city", "street", "garden", "kitchen", "parlor", "school",
        "church", "here", "there", "where", "away", "door", "window", "corner"
    ]
    static let timeWords: Set<String> = [
        "day", "night", "morning", "evening", "winter", "summer", "spring", "autumn", "christmas",
        "year", "ago", "when", "today", "tomorrow", "yesterday", "week", "month", "hour"
    ]
    static let causalConnectives: Set<String> = ["because", "since"]
}

/// Splits a sentence into events, the possible "this"es of a question (spec §4.3).
/// After Labov & Waletzky: each clause with its own verb is one event.
enum EventSplitter {
    /// Event phrases in sentence order, with role and track. Names are not included.
    /// `previous` is the sentence before, used to spot a reaction to someone's speech.
    static func events(in sentence: IndexedSentence, previous: IndexedSentence? = nil) -> [EventPhrase] {
        let text = sentence.text as NSString
        let tokens = sentence.tokens
        let quoted = quoteState(tokens, in: text)
        var events: [EventPhrase] = []
        var lastEventEnd: Int?

        for chunk in chunks(tokens, in: text) {
            let verbs = chunk.filter { tokens[$0].wordClass == "Verb" && !isSpeechTag($0, tokens, quoted, sentence) }
            guard let firstVerb = verbs.first else {
                // A chunk without a verb ("thin", "and Mother") belongs to the event before it,
                // but never across a speech tag or into or out of quotation marks.
                let isTag = chunk.contains { isSpeechTag($0, tokens, quoted, sentence) }
                if let previousEnd = lastEventEnd, !isTag, quoted[chunk[0]] == quoted[previousEnd], let end = chunk.last {
                    lastEventEnd = end
                    events[events.count - 1] = extend(events[events.count - 1], to: tokens[end], in: text, sentence: sentence)
                } else {
                    lastEventEnd = nil
                }
                continue
            }
            var start = firstVerb
            if start > chunk[0], EventKnobs.reactionCues.contains(tokens[start - 1].lemma) { start -= 1 }
            // "It's", "I'm": keep the pronoun with its clitic verb.
            if start > chunk[0], tokens[start].text.first.map({ $0 == "'" || $0 == "\u{2019}" }) == true { start -= 1 }
            let opensClause = EventKnobs.clauseOpeners.contains(tokens[chunk[0]].lemma)
            if opensClause { start = chunk[0] }
            let end = chunk.last!
            let range = NSRange(location: tokens[start].range.location,
                                length: NSMaxRange(tokens[end].range) - tokens[start].range.location)
            let phraseTokens = Array(tokens[start...end])
            let subject = Array(tokens[chunk[0]..<start])
            var role = EventRoles.role(of: phraseTokens, subject: subject, isRelative: opensClause, in: sentence)
            if events.isEmpty, role == .attempt, previous.map(endsWithQuote) == true { role = .reaction }
            events.append(EventPhrase(text: text.substring(with: range), range: range, role: role,
                                      track: EventRoles.track(for: role, phrase: phraseTokens)))
            lastEventEnd = end
        }
        return events
    }

    /// WordToken indexes grouped into chunks, split at boundary characters and at "and/but/or".
    private static func chunks(_ tokens: [WordToken], in text: NSString) -> [[Int]] {
        var chunks: [[Int]] = [[]]
        for i in tokens.indices {
            let gapStart = i == 0 ? 0 : NSMaxRange(tokens[i - 1].range)
            let gap = text.substring(with: NSRange(location: gapStart, length: tokens[i].range.location - gapStart))
            if gap.contains(where: EventKnobs.boundaryCharacters.contains) { chunks.append([]) }
            if EventKnobs.coordinators.contains(tokens[i].lemma) && tokens[i].wordClass == "Conjunction" {
                chunks.append([])
                continue
            }
            chunks[chunks.count - 1].append(i)
        }
        return chunks.filter { !$0.isEmpty }
    }

    /// For each token, whether it sits inside quotation marks.
    private static func quoteState(_ tokens: [WordToken], in text: NSString) -> [Bool] {
        // A straight quote opens when it follows a space, a dash or the start, and closes otherwise,
        // so a sentence that starts in the middle of someone's speech is read correctly.
        var inside = false
        var position = 0
        return tokens.map { token in
            while position < token.range.location {
                switch text.character(at: position) {
                case 0x22: inside = position == 0 || isOpeningContext(text.character(at: position - 1))
                case 0x201C: inside = true
                case 0x201D: inside = false
                default: break
                }
                position += 1
            }
            return inside
        }
    }

    private static func isOpeningContext(_ previous: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(previous) else { return false }
        return CharacterSet.whitespacesAndNewlines.contains(scalar) || "(\u{2014}\u{2013}".unicodeScalars.contains(scalar)
    }

    private static func isSpeechTag(_ i: Int, _ tokens: [WordToken], _ quoted: [Bool], _ sentence: IndexedSentence) -> Bool {
        guard tokens[i].wordClass == "Verb", EventKnobs.speechVerbs.contains(tokens[i].lemma), !quoted[i] else { return false }
        if i + 1 < tokens.count, tokens[i + 1].lemma == "to" { return false }
        let next = i + 1 < tokens.count ? i + 1 : nil
        let previous = i > 0 ? i - 1 : nil
        return [next, previous].compactMap { $0 }.contains { isPerson(tokens[$0], i: $0, in: sentence) }
    }

    private static func isPerson(_ token: WordToken, i: Int, in sentence: IndexedSentence) -> Bool {
        if EventKnobs.subjectPronouns.contains(token.text.lowercased()) { return true }
        if sentence.names.contains(where: { NSIntersectionRange($0.range, token.range).length > 0 && $0.kind == .person }) { return true }
        return i > 0 && token.wordClass == "Noun" && token.text.first?.isUppercase == true
    }

    private static func endsWithQuote(_ sentence: IndexedSentence) -> Bool {
        let trimmed = sentence.text.trimmingCharacters(in: .whitespaces)
        return trimmed.hasSuffix("\"") || trimmed.hasSuffix("\u{201D}")
    }

    private static func extend(_ event: EventPhrase, to token: WordToken, in text: NSString, sentence: IndexedSentence) -> EventPhrase {
        let range = NSRange(location: event.range.location, length: NSMaxRange(token.range) - event.range.location)
        return EventPhrase(text: text.substring(with: range), range: range, role: event.role, track: event.track)
    }
}
