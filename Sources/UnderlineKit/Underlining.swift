import Foundation

/// The whole conversation between an app and the engine: give it a book, get back underlines with the passage each one points
/// to. An app depends on this protocol, not on `Underliner`, so tests can use `StubUnderliner` and the engine's method can change
/// without the app noticing.
public protocol Underlining: Sendable {
    /// Saved with each chapter. When it differs from the saved one, the chapter is underlined again.
    var version: Int { get }
    /// One line for the debug sheet, e.g. "Rules only · contextual embedding".
    var summary: String { get }

    /// The chapter's underlines, paragraph by paragraph, from the paragraph holding `sentence` to the chapter's end and then from
    /// its start, so the reader's page comes first. Ends when the chapter is done, or when the consumer stops.
    func underlines(inChapter chapter: Int, of book: any BookSource, startingAt sentence: Int) -> AsyncStream<UnderlineBatch>
}
