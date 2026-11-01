import Foundation
import NaturalLanguage

enum TaggingKnobs {
    /// Capitalised words the fallback never treats as names.
    static let notNames: Set<String> = [
        "I", "Mr", "Mrs", "Miss", "Dr", "Oh", "Ah", "Yes", "No", "Well", "Dear", "Don't", "It's"
    ]
}

/// Tags every sentence of a chapter: lemma, word class and names (spec §5.2). Wraps NaturalLanguage.
/// Without the English models (iOS Simulator), simple rules are used instead, the same way iRead's `WordTagSvc` does.
struct ChapterIndexSvc: Sendable {
    let engine: TaggingEngine

    init(forceFallback: Bool = false) {
        engine = !forceFallback && Self.hasEnglishModels() ? .naturalLanguage : .fallback
    }

    /// Sentences come back sorted by index. Sentences with a duplicate index, a missing paragraph or a range
    /// outside their paragraph are left out instead of crashing; the first of duplicate paragraphs is kept.
    func index(_ input: ChapterInput) -> [IndexedSentence] {
        let paragraphText = Dictionary(input.paragraphs.map { ($0.index, $0.text as NSString) }, uniquingKeysWith: { first, _ in first })
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma, .nameType])
        var seen = Set<Int>()
        let valid = input.sentences.sorted { $0.index < $1.index }.filter { sentence in
            guard let paragraph = paragraphText[sentence.paragraph], sentence.range.location >= 0,
                  NSMaxRange(sentence.range) <= paragraph.length else { return false }
            return seen.insert(sentence.index).inserted
        }
        return valid.map { sentence in
            let text = paragraphText[sentence.paragraph]?.substring(with: sentence.range) ?? ""
            let (tokens, names) = engine == .naturalLanguage ? tag(text, with: tagger) : fallbackTag(text)
            return IndexedSentence(index: sentence.index, paragraph: sentence.paragraph, range: sentence.range,
                                   text: text, tokens: tokens, names: names)
        }
    }

    private func tag(_ text: String, with tagger: NLTagger) -> ([WordToken], [NameMention]) {
        tagger.string = text
        let whole = text.startIndex..<text.endIndex
        tagger.setLanguage(.english, range: whole)
        var tokens: [WordToken] = []
        tagger.enumerateTags(in: whole, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            let word = String(text[range])
            let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue ?? word
            tokens.append(WordToken(text: word, lemma: lemma.lowercased(), wordClass: tag?.rawValue ?? "Other", range: NSRange(range, in: text)))
            return true
        }
        var names: [NameMention] = []
        tagger.enumerateTags(in: whole, unit: .word, scheme: .nameType, options: [.omitPunctuation, .omitWhitespace, .joinNames]) { tag, range in
            let kind: NameKind? = switch tag {
            case .personalName?: .person
            case .placeName?: .place
            case .organizationName?: .organization
            default: nil
            }
            if let kind { names.append(NameMention(text: String(text[range]), range: NSRange(range, in: text), kind: kind)) }
            return true
        }
        return (tokens, names)
    }

    /// Capitalised words that don't start the sentence are person names; the lemma is the lowercased word.
    private func fallbackTag(_ text: String) -> ([WordToken], [NameMention]) {
        var tokens: [WordToken] = []
        var names: [NameMention] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { word, range, _, _ in
            guard let word else { return }
            let isCapitalised = word.first?.isUppercase == true
            let range = NSRange(range, in: text)
            tokens.append(WordToken(text: word, lemma: word.lowercased(), wordClass: isCapitalised ? "Noun" : "Other", range: range))
            if isCapitalised, tokens.count > 1, !TaggingKnobs.notNames.contains(word) {
                names.append(NameMention(text: word, range: range, kind: .person))
            }
        }
        return (tokens, names)
    }

    /// iRead's probe: the English models are there if "John" is tagged as a person name.
    private static func hasEnglishModels() -> Bool {
        let probe = "John walked to London."
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = probe
        tagger.setLanguage(.english, range: probe.startIndex..<probe.endIndex)
        return tagger.tag(at: probe.startIndex, unit: .word, scheme: .nameType).0 == .personalName
    }
}
