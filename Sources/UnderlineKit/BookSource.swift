import Foundation

/// The book as the engine needs it: plain text with the app's paragraph and sentence numbering. An app type conforms to this
/// (so nothing is copied up front), and `BookText` is a ready-made value for tests and tools.
public protocol BookSource: Sendable {
    /// Any stable ID of the book. The engine keeps what it works out once per book (word counts) under it.
    var id: String { get }
    var chapterCount: Int { get }
    /// The text of chapter `index` (0-based).
    func chapterText(_ index: Int) -> ChapterText
}

/// One chapter. Indexes are the app's global ones, and a sentence's `range` is within its paragraph's text, UTF-16.
public struct ChapterText: Sendable, Hashable {
    public let paragraphs: [Paragraph]
    public let sentences: [Sentence]

    public init(paragraphs: [Paragraph], sentences: [Sentence]) {
        self.paragraphs = paragraphs
        self.sentences = sentences
    }

    public struct Paragraph: Sendable, Hashable {
        public let index: Int
        public let text: String

        public init(index: Int, text: String) {
            self.index = index
            self.text = text
        }
    }

    public struct Sentence: Sendable, Hashable {
        public let index: Int
        public let paragraph: Int
        public let range: NSRange

        public init(index: Int, paragraph: Int, range: NSRange) {
            self.index = index
            self.paragraph = paragraph
            self.range = range
        }
    }
}

/// A whole book held in memory. Handy for tests; an app should conform its own book type to `BookSource` instead.
public struct BookText: BookSource, Hashable {
    public let id: String
    public let chapters: [ChapterText]

    public var chapterCount: Int { chapters.count }

    public init(id: String, chapters: [ChapterText]) {
        self.id = id
        self.chapters = chapters
    }

    public func chapterText(_ index: Int) -> ChapterText {
        chapters[index]
    }
}
