import Foundation
import Testing
@testable import UnderlineEngine

private func chapter(_ paragraphs: [String], first: Int = 100) -> ChapterInput {
    ChapterInput(chapterIndex: 4, plainText: paragraphs.joined(separator: "\n\n"), firstParagraph: first, firstSentence: first * 10)
}

@Test func storyChapterIsUnchanged() {
    let input = chapter([
        "\"Christmas won't be Christmas without any presents,\" grumbled Jo, lying on the rug.",
        "\"It's so dreadful to be poor!\" sighed Meg, looking down at her old dress.",
        "JO.",
        "Beth said nothing."
    ])
    #expect(StoryCleaner.clean(input) == input)
}

@Test func headingLinesAtTheTopAreDroppedAndIndexesKept() {
    let input = chapter(["PART 1", "CHAPTER ONE PLAYING PILGRIMS", "Jo grumbled on the rug.", "Meg sighed."])
    let clean = StoryCleaner.clean(input)
    #expect(clean.paragraphs.map(\.index) == [102, 103])
    #expect(clean.sentences.map(\.index) == input.sentences.filter { $0.paragraph >= 102 }.map(\.index))
    #expect(StoryCleaner.droppedParagraphs(input) == [100: .heading, 101: .heading])
}

@Test func titleCaseLineAfterAHeadingIsDropped() {
    let input = chapter(["CHAPTER II.", "Matthew Cuthbert Is Surprised", "Matthew Cuthbert and the sorrel mare jogged comfortably.",
                         "He Said Nothing"])
    #expect(StoryCleaner.droppedParagraphs(input) == [100: .heading, 101: .heading])
    #expect(StoryCleaner.droppedParagraphs(chapter(["Matthew Cuthbert Is Surprised", "He went home."])).isEmpty)
}

@Test func headingsInMixedCaseAreDropped() {
    #expect(StoryCleaner.isHeading("Chapter 3. The Laurence Boy"))
    #expect(StoryCleaner.isHeading("CHAPTER XXXVIII. The Bend in the Road"))
    #expect(StoryCleaner.isHeading("XII."))
    #expect(StoryCleaner.isHeading("A SCANDAL IN BOHEMIA"))
    #expect(!StoryCleaner.isHeading("Part of the fun was the waiting."))
    #expect(!StoryCleaner.isHeading("\"OH!\""))
    #expect(!StoryCleaner.isHeading("She laughed."))
}

@Test func endMarkerDropsTheFooterAfterTheLastStoryParagraph() {
    let input = chapter([
        "Jo looked at the harvest and smiled.",
        "THE END",
        "*** END OF THE PROJECT GUTENBERG EBOOK LITTLE WOMEN ***",
        "Updated editions will replace the previous one."
    ])
    let dropped = StoryCleaner.droppedParagraphs(input)
    #expect(dropped[100] == nil)
    #expect(dropped[102] == .marker)
    #expect(dropped[103] == .afterEnd)
}

@Test func startMarkerDropsTheHeader() {
    let input = chapter([
        "The Project Gutenberg eBook of Little Women",
        "Title: Little Women",
        "*** START OF THE PROJECT GUTENBERG EBOOK LITTLE WOMEN ***",
        "Jo grumbled on the rug, and Meg sighed over her old dress."
    ])
    #expect(StoryCleaner.clean(input).paragraphs.map(\.index) == [103])
}

@Test func licenceChapterIsDroppedWhole() {
    let input = chapter([
        "THE FULL PROJECT GUTENBERG™ LICENSE",
        "PLEASE READ THIS BEFORE YOU DISTRIBUTE OR USE THIS WORK",
        "To protect the Project Gutenberg™ mission of promoting the free distribution of electronic works, you agree to comply.",
        "Section 1. General Terms of Use and Redistributing Project Gutenberg™ electronic works",
        "1.A. By reading or using any part of this Project Gutenberg™ electronic work, you indicate that you have read this license.",
        "1.B. \"Project Gutenberg\" is a registered trademark.",
        "Most people start at our website which has the main PG search facility: www.gutenberg.org."
    ])
    let clean = StoryCleaner.clean(input)
    #expect(clean.paragraphs.isEmpty)
    #expect(clean.sentences.isEmpty)
}

@Test func tableOfContentsIsDroppedWhole() {
    let input = chapter(["CONTENTS", "CHAPTER I. Loomings.", "CHAPTER II. The Carpet-Bag.", "CHAPTER III. The Spouter-Inn.",
                         "CHAPTER IV. The Counterpane.", "CHAPTER V. Breakfast."])
    #expect(StoryCleaner.clean(input).paragraphs.isEmpty)
}

@Test func oneMentionOfGutenbergInAStoryChapterDropsOnlyThatParagraph() {
    let input = chapter(["Jo grumbled.", "Meg sighed.", "Produced by volunteers for Project Gutenberg.", "Beth smiled.", "Amy sniffed."])
    #expect(StoryCleaner.droppedParagraphs(input) == [102: .marker])
}
