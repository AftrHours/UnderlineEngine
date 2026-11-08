import Foundation

/// A prompt ready to send, and every sentence index inside it (for the spoiler check, spec §5.7).
struct BuiltPrompt: Sendable, Equatable {
    let instructions: String
    let prompt: String
    let sentenceIndexes: [Int]
}

/// Builds the confirm prompt. Pure, so tests and the record see exactly what the model sees.
enum PromptBuilder {
    static func confirm(phrase: String, sentence: IndexedText, passage: IndexedText) -> BuiltPrompt {
        let prompt = """
            Sentence: \(sentence.text)
            Underlined phrase: "\(phrase)"

            Earlier passage: \(cut(passage.text))
            """
        return BuiltPrompt(instructions: ModelKnobs.confirmInstructions, prompt: prompt,
                           sentenceIndexes: [sentence.index, passage.index])
    }

    /// At most `ModelKnobs.candidateWords` words, with "…" when cut.
    static func cut(_ text: String) -> String {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard words.count > ModelKnobs.candidateWords else { return text }
        return words.prefix(ModelKnobs.candidateWords).joined(separator: " ") + " …"
    }
}
