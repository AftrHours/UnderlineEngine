import Foundation

enum CleanKnobs {
    /// A paragraph naming any of these is publisher boilerplate, not story (Project Gutenberg's header, footer and licence).
    static let boilerplateMarkers = [
        "project gutenberg", "gutenberg-tm", "gutenberg™", "electronic work", "literary archive foundation", "gutenberg.org"
    ]
    /// A chapter is back or front matter, and dropped whole, when at least this many of its paragraphs are boilerplate…
    static let boilerplateMinParagraphs = 3
    /// …and they are at least this share of its paragraphs. Story chapters have none.
    static let boilerplateMinShare = 0.2
    /// Headings are only looked for in a chapter's first paragraphs: a short capitalised line later on is story ("JO.").
    static let headingZone = 3
    static let headingMaxWords = 12
    /// A chapter made mostly of heading lines is a table of contents.
    static let contentsMinParagraphs = 5
    static let contentsMinShare = 0.6
}

/// Why a paragraph was left out of the story.
enum CleanReason: String, Sendable, Codable {
    case boilerplateChapter, beforeStart, afterEnd, marker, heading, contents
}

/// Clean (stage 0): leaves out what isn't story before anything is tagged, so it can be neither underlined nor linked to.
/// Content only, because chapters reach the engine without titles. Paragraphs and their sentences are removed; every index
/// that stays is unchanged, so the app's numbering, saved underlines and iCloud records are untouched. Pure.
enum StoryCleaner {
    static func clean(_ input: ChapterInput) -> ChapterInput {
        let dropped = droppedParagraphs(input)
        guard !dropped.isEmpty else { return input }
        return ChapterInput(chapterIndex: input.chapterIndex,
                            paragraphs: input.paragraphs.filter { dropped[$0.index] == nil },
                            sentences: input.sentences.filter { dropped[$0.paragraph] == nil })
    }

    /// Every paragraph left out, by index, with the reason.
    static func droppedParagraphs(_ input: ChapterInput) -> [Int: CleanReason] {
        let paragraphs = input.paragraphs
        guard !paragraphs.isEmpty else { return [:] }
        var dropped: [Int: CleanReason] = [:]

        // The markers first, because a chapter can hold the story's last pages and the licence after them.
        // "*** START OF THE PROJECT GUTENBERG EBOOK …": everything up to it is header.
        if let start = paragraphs.lastIndex(where: { isMarker($0.text, "start") }) {
            for p in paragraphs[..<start] { dropped[p.index] = .beforeStart }
            dropped[paragraphs[start].index] = .marker
        }
        // "*** END OF THE PROJECT GUTENBERG EBOOK …": everything from it on is footer.
        if let end = paragraphs.firstIndex(where: { isMarker($0.text, "end") }) {
            dropped[paragraphs[end].index] = .marker
            for p in paragraphs[(end + 1)...] { dropped[p.index] = .afterEnd }
        }

        // What's left is a licence or a table of contents with no marker, dropped whole, or story.
        let rest = paragraphs.filter { dropped[$0.index] == nil }
        guard !rest.isEmpty else { return dropped }
        let boilerplate = rest.filter { isBoilerplate($0.text) }.count
        if boilerplate >= CleanKnobs.boilerplateMinParagraphs, Double(boilerplate) / Double(rest.count) >= CleanKnobs.boilerplateMinShare {
            for p in rest { dropped[p.index] = .boilerplateChapter }
            return dropped
        }
        let headings = rest.filter { isHeading($0.text) }.count
        if headings >= CleanKnobs.contentsMinParagraphs, Double(headings) / Double(rest.count) >= CleanKnobs.contentsMinShare {
            for p in rest { dropped[p.index] = .contents }
            return dropped
        }
        for p in rest where isBoilerplate(p.text) { dropped[p.index] = .marker }

        // The chapter's own heading lines at its top ("PART 1", "CHAPTER ONE PLAYING PILGRIMS").
        // A Title Case line right after one counts too ("CHAPTER II." then "Matthew Cuthbert Is Surprised").
        var afterHeading = false
        for p in paragraphs.filter({ dropped[$0.index] == nil }).prefix(CleanKnobs.headingZone) {
            guard isHeading(p.text) || (afterHeading && isTitleLine(p.text)) else { break }
            dropped[p.index] = .heading
            afterHeading = true
        }
        return dropped
    }

    static func isBoilerplate(_ text: String) -> Bool {
        let lower = text.lowercased()
        return CleanKnobs.boilerplateMarkers.contains { lower.contains($0) }
    }

    /// "*** START OF THE PROJECT GUTENBERG EBOOK …" / "*** END OF THIS PROJECT GUTENBERG EBOOK …".
    static func isMarker(_ text: String, _ kind: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        return lower.hasPrefix("***") && lower.contains("\(kind) of") && lower.contains("gutenberg")
    }

    /// A heading line: "CHAPTER ONE PLAYING PILGRIMS", "Chapter 3. The Laurence Boy", "PART 1", "XII.", "A SCANDAL IN BOHEMIA".
    /// Short, no sentence inside it, and either named as a chapter/part/book or written without lowercase letters.
    static func isHeading(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty, words.count <= CleanKnobs.headingMaxWords else { return false }
        if trimmed.contains(where: { "?!\u{201C}\u{201D}\"".contains($0) }) { return false }
        let first = words[0].lowercased().trimmingCharacters(in: .punctuationCharacters)
        if ["epilogue", "prologue"].contains(first), words.count <= 3 { return true }
        if ["chapter", "part", "book", "volume"].contains(first), words.count > 1, isNumber(String(words[1])) { return true }
        let letters = trimmed.filter(\.isLetter)
        return !letters.isEmpty && !letters.contains(where: \.isLowercase)
    }

    /// "Matthew Cuthbert Is Surprised", "The Bend in the Road": short, ends on a letter, every word of four letters or more capitalised.
    static func isTitleLine(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = trimmed.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty, words.count <= CleanKnobs.headingMaxWords, trimmed.last?.isLetter == true else { return false }
        let long = words.filter { $0.filter(\.isLetter).count >= 4 }
        return !long.isEmpty && long.allSatisfy { $0.first?.isUppercase == true }
    }

    private static let numberWords: Set<String> = [
        "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen",
        "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty", "thirty", "forty", "fifty", "sixty", "seventy",
        "eighty", "ninety", "hundred", "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth",
        "tenth", "last"
    ]

    /// "3", "XII.", "one", "forty-six", "First".
    private static func isNumber(_ word: String) -> Bool {
        let w = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        guard let head = w.split(separator: "-").first.map(String.init), !head.isEmpty else { return false }
        return head.allSatisfy(\.isNumber) || head.allSatisfy({ "ivxlcdm".contains($0) }) || numberWords.contains(head)
    }
}
