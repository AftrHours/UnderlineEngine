import Testing
@testable import UnderlineEngine

@Test func searchableIsEverythingBeforeTheSentence() {
    #expect(ReadBoundary.searchable(before: 3, first: 0, last: 228) == [0, 1, 2])
    #expect(ReadBoundary.searchable(before: 0, first: 0, last: 228).isEmpty)
}

@Test func globalIndexesNotStartingAtZero() {
    #expect(ReadBoundary.searchable(before: 1_002, first: 1_000, last: 1_200) == [1_000, 1_001])
}

@Test func sentenceOutsideChapterHasNothingSearchable() {
    #expect(ReadBoundary.searchable(before: 300, first: 0, last: 228).isEmpty)
    #expect(ReadBoundary.searchable(before: 3, first: 10, last: 50).isEmpty)
}

@Test func emptyChapterHasNothingSearchable() {
    #expect(ReadBoundary.searchable(before: 0, first: 0, last: -1).isEmpty)
}

@Test func neverReturnsTheSentenceOrLater() {
    for s in 0...228 {
        #expect(ReadBoundary.searchable(before: s, first: 0, last: 228).allSatisfy { $0 < s })
    }
}
