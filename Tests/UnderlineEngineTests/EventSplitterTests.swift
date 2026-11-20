import Foundation
import Testing
@testable import UnderlineEngine

@Test func joSentenceHasThreeEventsWithRoles() {
    let e = EventSplitter.events(in: indexed("Jo immediately sat up, put her hands in her pockets, and began to whistle."))
    #expect(e.map(\.text) == ["immediately sat up", "put her hands in her pockets", "began to whistle"])
    #expect(e.map(\.role) == [.reaction, .attempt, .attempt])
    #expect(e.map(\.track) == [.cause, .goal, .goal])
}

@Test func speechTagsAreNeverEvents() {
    #expect(EventSplitter.events(in: indexed("said Meg, who could remember better times.")).allSatisfy { !$0.text.hasPrefix("said") })
    #expect(EventSplitter.events(in: indexed("\"I know I do,\" began Meg, in the complaining tone again.")).allSatisfy { !$0.text.hasPrefix("began Meg") })
}

@Test func stateIsSettingOnCharacterTrack() {
    let e = EventSplitter.events(in: indexed("Fifteen-year-old Jo was very tall, thin, and brown."))
    #expect(e.first?.role == .setting)
    #expect(e.first?.track == .character)
}

@Test func emotionIsInternalResponse() {
    let e = EventSplitter.events(in: indexed("And Beth looked at her rough hands with a sigh that any one could hear that time."))
    #expect(e.first?.text.hasPrefix("looked at her rough hands") == true)
    #expect(e.first?.role == .internalResponse)
}

@Test func reasonClauseAfterBecause() {
    let s = indexed("Mother proposed not having any presents this Christmas because it is going to be a hard winter for everyone; and she thinks we ought not to spend money.")
    let target = (s.text as NSString).range(of: "not having any presents this Christmas")
    let r = EventRoles.reasonClause(after: target, in: s)
    #expect(r.map { (s.text as NSString).substring(with: $0) } == "because it is going to be a hard winter for everyone")
    #expect(EventRoles.reasonClause(after: (s.text as NSString).range(of: "spend money"), in: s) == nil)
}

@Test func eventRangesAreUTF16AndRoundTrip() {
    let s = indexed("\u{201C}Don\u{2019}t\u{201D}\u{2014}Jo 😀 suddenly laughed, and ran off.")
    let e = EventSplitter.events(in: s)
    #expect(!e.isEmpty)
    for event in e { #expect((s.text as NSString).substring(with: event.range) == event.text) }
}

@Test func speechTagAfterClosingQuoteWhenSentenceStartsMidQuote() {
    let e = EventSplitter.events(in: indexed("Let's each buy what we want; I'm sure we earn it,\" cried Jo, examining the heels of her shoes."))
    #expect(!e.contains { $0.text.hasPrefix("cried") })
    #expect(e.last?.text == "examining the heels of her shoes")
}

@Test func whereClauseKeepsItsOpeningWord() {
    let e = EventSplitter.events(in: indexed("She thought of Father far away, where the fighting was."))
    #expect(e.last?.text == "where the fighting was")
    #expect(e.last?.track == .place)
}

@Test func contractionKeepsItsPronoun() {
    let e = EventSplitter.events(in: indexed("It's naughty to fret, but I do think washing dishes is the worst work."))
    #expect(e.first?.text == "It's naughty to fret")
}

@Test func mainVerbSkipsAuxiliaries() {
    let s = indexed("We shall not have him for a long time.")
    let e = EventSplitter.events(in: s)
    #expect(e.first?.role == .setting)
}

@Test func eventNeverRunsAcrossASpeechTag() {
    let e = EventSplitter.events(in: indexed("\"I know I do,\" began Meg, in the complaining tone again."))
    #expect(e.map(\.text) == ["know I do"])
}

@Test func eventNeverEndsOnAnArticle() {
    let e = EventSplitter.events(in: indexed("Both sharp voices softened to a laugh, and the \"pecking\" ended for that time."))
    #expect(e.contains { $0.text == "softened to a laugh" })
    #expect(!e.contains { $0.text.hasSuffix(" the") || $0.text.hasSuffix(" and the") })
}

@Test func eventDropsAnAdjectiveCutOffFromItsNoun() {
    let e = EventSplitter.events(in: indexed("Actors and audience turned to welcome a tall, motherly lady who smiled at them."))
    #expect(e.first?.text == "turned to welcome")
}

@Test func nounPhraseCutByACommaIsRejoinedWhenNothingElseFollows() {
    let e = EventSplitter.events(in: indexed("Actors and audience turned to welcome a tall, motherly lady."))
    #expect(e.first?.text == "turned to welcome a tall, motherly lady")
}

@Test func firstSubjectOfACoordinatedClauseIsNotGluedToTheEventBefore() {
    let e = EventSplitter.events(in: indexed("Books filled the recesses, chrysanthemums and Christmas roses bloomed in the windows."))
    #expect(e.first?.text == "filled the recesses")
    #expect(!e.contains { $0.text.contains("chrysanthemums") })
}

@Test func aListOfNounsStaysInOneEvent() {
    let e = EventSplitter.events(in: indexed("She was calling the quarters Europe, Asia, Africa, and America."))
    #expect(e.first?.text.hasSuffix("Europe, Asia, Africa, and America") == true)
}

@Test func aListThatGoesOnWithAParticipleKeepsItsItems() {
    let e = EventSplitter.events(in: indexed("Mrs. March got her wet things off, her warm slippers on, and sitting down in the easy chair, drew Amy to her lap."))
    #expect(e.first?.text.hasSuffix("her warm slippers on") == true)
}

@Test func aListThatGoesOnWithARelativeClauseKeepsItsItems() {
    let e = EventSplitter.events(in: indexed("Jo had big hands and feet, a flyaway look to her clothes, and the appearance of a girl who was shooting up into a woman."))
    #expect(e.contains { $0.text.contains("a flyaway look to her clothes") })
}
