import Foundation
import Testing
@testable import UnderlineEngine

@Test func eventsOfASentenceBecomeCandidates() {
    let s = indexed("Jo immediately sat up, put her hands in her pockets, and began to whistle.")
    let found = UnderlineDetector.candidates(in: s)
    #expect(found.map(\.phrase.text).contains("immediately sat up"))
    #expect(found.map(\.phrase.text).contains("began to whistle"))
    #expect(found.allSatisfy { $0.sentence == s.index })
    #expect(found.allSatisfy { UnderlineGuard.paragraphRange(of: $0.phrase, in: s) != nil })
}

@Test func reasonInTheSameSentenceIsNotACandidate() {
    let s = indexed("Meg stayed home because it was a hard winter.")
    let because = (s.text as NSString).range(of: "because").location
    let found = UnderlineDetector.candidates(in: s)
    #expect(!found.contains { $0.phrase.range.location < because && [Track.cause, .goal].contains($0.phrase.track) })
}

@Test func oneWordEventIsDroppedButANameIsKept() {
    let s = indexed("Jo laughed.")
    let found = UnderlineDetector.candidates(in: s)
    #expect(!found.contains { $0.phrase.role != nil && $0.phrase.text.split(separator: " ").count < UnderlineKnobs.minPhraseWords })
    #expect(found.contains { $0.kind == .person && $0.phrase.text == "Jo" })
}

@Test func generalWordsOnlyPhraseIsDropped() {
    #expect(UnderlineDetector.isGeneral("did this"))
    #expect(UnderlineDetector.isGeneral("it was that"))
    #expect(!UnderlineDetector.isGeneral("began to whistle"))
}

@Test func speechTagOnlySentenceWithARecentNameHasNoCandidates() {
    let s = indexed("said Meg.")
    #expect(UnderlineDetector.candidates(in: s, recentNames: ["Meg"]).isEmpty)
}

@Test func nameSeenRecentlyIsNotACandidate() {
    let s = indexed("Jo laughed at the joke for a long time.")
    #expect(!UnderlineDetector.candidates(in: s, recentNames: ["Jo"]).contains { $0.kind == .person })
    #expect(UnderlineDetector.candidates(in: s).contains { $0.kind == .person })
}
