import Foundation

// Same data as iRead's BookContent (spec §6.1): global indexes, ranges in UTF-16.

/// One paragraph of the chapter. `index` is iRead's global paragraph index.
public struct ParagraphInput: Sendable, Codable, Hashable {
    public let index: Int
    public let text: String

    public init(index: Int, text: String) {
        self.index = index
        self.text = text
    }
}

/// One sentence. `index` is iRead's global sentence index, `paragraph` its global paragraph index,
/// and `range` is within the paragraph's text, as iRead stores it.
public struct SentenceInput: Sendable, Codable, Hashable {
    public let index: Int
    public let paragraph: Int
    public let range: NSRange

    public init(index: Int, paragraph: Int, range: NSRange) {
        self.index = index
        self.paragraph = paragraph
        self.range = range
    }
}

/// One chapter, in the shape of iRead's `Chapter` with its paragraphs and sentences.
public struct ChapterInput: Sendable, Codable, Hashable {
    public let chapterIndex: Int
    public let paragraphs: [ParagraphInput]
    public let sentences: [SentenceInput]

    public init(chapterIndex: Int, paragraphs: [ParagraphInput], sentences: [SentenceInput]) {
        self.chapterIndex = chapterIndex
        self.paragraphs = paragraphs
        self.sentences = sentences
    }
}
