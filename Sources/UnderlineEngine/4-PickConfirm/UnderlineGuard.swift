import Foundation

/// Checks everything the model returns before it can become an underline (spec §5.5). Pure.
enum UnderlineGuard {
    /// The reference is in the phrase's own paragraph: the reader has just read it.
    static func isInSameParagraph(_ reference: IndexedSentence, as sentence: IndexedSentence) -> Bool {
        reference.paragraph == sentence.paragraph
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
