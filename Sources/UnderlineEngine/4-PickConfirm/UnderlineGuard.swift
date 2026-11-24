import Foundation

/// Checks a picked reference and the phrase before they become an underline (spec §5.5). Pure.
enum UnderlineGuard {
    /// The reference is in the phrase's own paragraph: the reader has just read it.
    static func isInSameParagraph(_ reference: IndexedSentence, as sentence: IndexedSentence) -> Bool {
        reference.paragraph == sentence.paragraph
    }

    /// Too thin to be a reference: three words or fewer ("Jo!", "Only see!"), or a short speech tag ("cried Amy.", "asked Meg.").
    static func isStub(_ sentence: IndexedSentence) -> Bool {
        if sentence.tokens.count <= 3 { return true }
        guard sentence.tokens.count <= 6, let first = sentence.tokens.first else { return false }
        return first.wordClass == "Verb" && EventKnobs.speechVerbs.contains(first.lemma)
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
