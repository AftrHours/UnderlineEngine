import Foundation

public enum GuardReject: String, Sendable, Codable, Hashable {
    case outOfRange, notEarlier, quoteNotInPick, phraseNotInSentence
}

/// What the guard made of the model's pick.
public enum PickCheck: Sendable, Codable, Hashable {
    case accepted(Int)
    /// The model said none of the candidates explains the phrase.
    case none
    case rejected(GuardReject)
}

/// Checks everything the model returns before it can become an underline (spec §5.5). Pure.
enum UnderlineGuard {
    /// `pick` is 1-based into `sent`; 0 means "none". The quote must come from the picked sentence,
    /// and the picked sentence must be before the underlined one.
    static func checkPick(pick: Int, quote: String, sent: [Candidate], chapter: IndexedChapter, sentence: Int) -> PickCheck {
        if pick == 0 { return .none }
        guard sent.indices.contains(pick - 1) else { return .rejected(.outOfRange) }
        let chosen = sent[pick - 1].sentence
        guard chosen < sentence else { return .rejected(.notEarlier) }
        let normalizedQuote = TextMatch.normalized(quote)
        guard !normalizedQuote.isEmpty, let text = chapter.sentence(chosen)?.text,
              TextMatch.normalized(text).contains(normalizedQuote) else { return .rejected(.quoteNotInPick) }
        return .accepted(chosen)
    }

    /// The phrase's range within the paragraph, or `nil` unless the sentence text at the phrase's own range is the phrase.
    static func paragraphRange(of phrase: EventPhrase, in sentence: IndexedSentence) -> NSRange? {
        let text = sentence.text as NSString
        guard phrase.range.location != NSNotFound, phrase.range.length > 0,
              NSMaxRange(phrase.range) <= text.length,
              text.substring(with: phrase.range) == phrase.text else { return nil }
        return NSRange(location: sentence.range.location + phrase.range.location, length: phrase.range.length)
    }
}
