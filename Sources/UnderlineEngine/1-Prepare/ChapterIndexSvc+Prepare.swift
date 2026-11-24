import Foundation

extension ChapterIndexSvc {
    /// Prepares the whole chapter ahead of any tap (spec §5.2): tags every sentence, splits its events, and gives each content
    /// word its contextual vector from one model pass per sentence, centred on the chapter's mean word vector and normalised
    /// (`ChapterTokenVectors.center`). Preparing ahead is not a spoiler; `ReadBoundary` decides what each tap may use.
    /// With `bookStats`, the chapter's own word counts are not made (the book's are used).
    func prepare(_ input: ChapterInput, embedding: any EmbeddingSvc, bookStats: WordStats? = nil) async -> IndexedChapter {
        var sentences = index(input)
        var raw: [Int: [(String, NSRange, [Double])]] = [:]
        for i in sentences.indices {
            sentences[i].events = EventSplitter.events(in: sentences[i], previous: i > 0 ? sentences[i - 1] : nil)
            let content = ChapterTokenVectors.contentTokens(sentences[i])
            let vectors = embedding.wordVectors(for: sentences[i].text, words: content.map(\.range))
            raw[i] = zip(content, vectors).compactMap { token, v in v.map { (token.lemma, token.range, $0) } }
        }
        ChapterTokenVectors.center(&sentences, raw: raw)
        return IndexedChapter(chapterIndex: input.chapterIndex, sentences: sentences, tagging: engine, embedding: embedding.engine,
                              wordStats: bookStats ?? WordStats(sentences: sentences))
    }
}
