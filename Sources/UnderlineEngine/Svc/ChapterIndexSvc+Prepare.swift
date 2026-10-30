import Foundation

extension ChapterIndexSvc {
    /// Prepares the whole chapter ahead of any tap (spec §5.2): tags every sentence, splits its events and embeds it.
    /// Preparing ahead is not a spoiler; `ReadBoundary` decides what each tap may use.
    func prepare(_ input: ChapterInput, embedding: any EmbeddingSvc) async -> IndexedChapter {
        var sentences = index(input)
        for i in sentences.indices {
            sentences[i].events = EventSplitter.events(in: sentences[i], previous: i > 0 ? sentences[i - 1] : nil)
            sentences[i].vector = embedding.vector(for: sentences[i].text)
        }
        return IndexedChapter(chapterIndex: input.chapterIndex, sentences: sentences, tagging: engine, embedding: embedding.engine)
    }
}
