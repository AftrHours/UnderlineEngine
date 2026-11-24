import Foundation
@testable import UnderlineEngine
@testable import UnderlineKit

/// A book in memory from plain-text chapters, numbered across the book like an app does.
func makeBook(_ id: String = "test-book", chapters texts: [String]) -> BookText {
    var firstParagraph = 0
    var firstSentence = 0
    var chapters: [ChapterText] = []
    for (index, text) in texts.enumerated() {
        let input = ChapterInput(chapterIndex: index, plainText: text, firstParagraph: firstParagraph, firstSentence: firstSentence)
        firstParagraph += input.paragraphs.count
        firstSentence += input.sentences.count
        chapters.append(ChapterText(paragraphs: input.paragraphs.map { .init(index: $0.index, text: $0.text) },
                                    sentences: input.sentences.map { .init(index: $0.index, paragraph: $0.paragraph, range: $0.range) }))
    }
    return BookText(id: id, chapters: chapters)
}

func datasetURL(_ name: String, file: StaticString = #filePath) -> URL {
    URL(fileURLWithPath: "\(file)")
        .deletingLastPathComponent()   // UnderlineKitTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repo root
        .appendingPathComponent("Dataset")
        .appendingPathComponent(name)
}

/// Every batch the door gives for a chapter.
func collect(_ underliner: any Underlining, chapter: Int, of book: any BookSource, from sentence: Int = 0) async -> [UnderlineBatch] {
    var out: [UnderlineBatch] = []
    for await batch in underliner.underlines(inChapter: chapter, of: book, startingAt: sentence) { out.append(batch) }
    return out
}

/// A method that is not the engine's: it underlines the first three words of every sentence but the first, pointing at the sentence before.
/// It exists to show that a new `LinkMethod` plugs in without any other code changing, and to run the contract on a second method.
struct PreviousSentenceLinker: LinkMethod {
    let name = "PreviousSentence"
    let version = 99
    let summary = "Test method"
    private let ctrl = UnderlineCtrl(embeddingSvc: EmbeddingSvcUnavailable())

    func prepare(_ chapter: ChapterInput, ofBook book: String, chapters: @escaping @Sendable () -> [ChapterInput]) async -> IndexedChapter {
        await ctrl.prepare(chapter)
    }

    func results(in chapter: IndexedChapter, startingAt sentence: Int) -> AsyncStream<ParagraphResult> {
        AsyncStream { continuation in
            let start = chapter.sentence(sentence)?.paragraph ?? chapter.sentences.first?.paragraph ?? 0
            let ordered = chapter.sentences.filter { $0.paragraph >= start } + chapter.sentences.filter { $0.paragraph < start }
            for current in ordered where current.index > chapter.first {
                guard let before = chapter.sentence(current.index - 1) else { continue }
                let words = current.text.split(separator: " ").prefix(3).joined(separator: " ")
                guard !words.isEmpty, current.text.hasPrefix(words) else { continue }
                let underline = Underline(sentence: current.index, paragraph: current.paragraph,
                                          range: NSRange(location: current.range.location, length: (words as NSString).length),
                                          text: words, kind: .action, role: nil,
                                          reference: AnswerPassage(sentence: before.index, paragraph: before.paragraph,
                                                                   range: before.range, text: before.text),
                                          decidedBy: .rules)
                continuation.yield(ParagraphResult(underlines: [underline], records: []))
            }
            continuation.finish()
        }
    }
}
