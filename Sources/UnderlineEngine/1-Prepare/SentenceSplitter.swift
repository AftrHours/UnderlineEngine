import Foundation
import NaturalLanguage

/// Splits a paragraph into sentences exactly the way iRead's `EPUBParseSvc.sentenceRanges` does,
/// so sentence indexes match the app's (spec §6.1). If iRead's parser changes, change this too.
enum SentenceSplitter {
    static func ranges(in paragraph: String) -> [NSRange] {
        // Ebooks often put a no-break space after "Mr." or "Dr.", which the tokenizer reads as a sentence end.
        // A copy with plain spaces has the same UTF-16 length, so its ranges still match the original text.
        let plain = paragraph.replacingOccurrences(of: "\u{00A0}", with: " ")
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = plain
        return tokenizer.tokens(for: plain.startIndex..<plain.endIndex).compactMap { tokenRange in
            let range = NSRange(tokenRange, in: plain)
            let token = (paragraph as NSString).substring(with: range)
            let sentence = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { return nil }
            let leadingSpaces = token.prefix(while: \.isWhitespace).utf16.count
            return NSRange(location: range.location + leadingSpaces, length: sentence.utf16.count)
        }
    }
}

extension ChapterInput {
    /// Builds a chapter from plain text: paragraphs are separated by blank lines, and wrapped lines
    /// inside a paragraph are joined with a space. Used by the harness; the app passes its own indexes.
    public init(chapterIndex: Int, plainText: String, firstParagraph: Int = 0, firstSentence: Int = 0) {
        let blocks = plainText
            .components(separatedBy: "\n")
            .split { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ") }
        var paragraphs: [ParagraphInput] = []
        var sentences: [SentenceInput] = []
        for text in blocks {
            let index = firstParagraph + paragraphs.count
            paragraphs.append(ParagraphInput(index: index, text: text))
            let start = firstSentence + sentences.count
            sentences += SentenceSplitter.ranges(in: text).enumerated().map { offset, range in
                SentenceInput(index: start + offset, paragraph: index, range: range)
            }
        }
        self.init(chapterIndex: chapterIndex, paragraphs: paragraphs, sentences: sentences)
    }
}
