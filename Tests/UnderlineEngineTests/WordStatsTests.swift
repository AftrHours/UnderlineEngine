import Foundation
import Testing
@testable import UnderlineEngine

private func sentences(_ texts: [String]) -> [IndexedSentence] { texts.map { indexed($0) } }

@Test func aRareWordWeighsMoreThanACommonOne() {
    let stats = WordStats(sentences: sentences(["Jo wanted a lime.", "Meg wanted a hat.", "Amy wanted a book.", "Beth wanted peace."]))
    #expect(stats.idf("lime") > stats.idf("want"))
    #expect(stats.idf("want") > 0)
}

@Test func rareMeansAtMostAShareOfTheSentencesButNeverFewerThanTwo() {
    let small = WordStats(sentences: sentences(["Jo ate a lime.", "Amy liked the lime.", "Meg ate a lime too.", "Beth sang."]))
    #expect(!small.isRare("lime"))        // 3 of 4 sentences
    #expect(small.isRare("sing"))         // 1, and the floor is 2
}
