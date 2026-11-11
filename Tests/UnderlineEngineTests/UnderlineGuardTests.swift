import Foundation
import Testing
@testable import UnderlineEngine

@Test func paragraphRangeUsesTheEventsOwnOccurrence() {
    let text = "She ran home, and then she ran home again."
    let second = (text as NSString).range(of: "ran home", options: .backwards)
    let sentence = IndexedSentence(index: 4, paragraph: 1, range: NSRange(location: 10, length: (text as NSString).length),
                                   text: text, tokens: [], names: [])
    let phrase = EventPhrase(text: "ran home", range: second, role: .attempt, track: .goal)
    #expect(UnderlineGuard.paragraphRange(of: phrase, in: sentence) == NSRange(location: 10 + second.location, length: second.length))
}

@Test func paragraphRangeIsNilWhenTextDoesNotMatchItsRange() {
    let text = "She ran home."
    let sentence = IndexedSentence(index: 0, paragraph: 0, range: NSRange(location: 0, length: 13), text: text, tokens: [], names: [])
    let phrase = EventPhrase(text: "walked home", range: NSRange(location: 4, length: 8), role: .attempt, track: .goal)
    #expect(UnderlineGuard.paragraphRange(of: phrase, in: sentence) == nil)
    let past = EventPhrase(text: "home", range: NSRange(location: 20, length: 4), role: .attempt, track: .goal)
    #expect(UnderlineGuard.paragraphRange(of: past, in: sentence) == nil)
}
