import Foundation

/// A prompt ready to send, and every sentence index inside it (for the spoiler check, spec §5.7).
struct BuiltPrompt: Sendable, Equatable {
    let instructions: String
    let prompt: String
    let sentenceIndexes: [Int]
}

/// Builds the pick and confirm prompts for each `PromptVariant`. Pure, so tests and the record see exactly what the model sees.
enum PromptBuilder {
    static func pick(phrase: String, roleHint: String?, sentence: IndexedText, candidates: [IndexedText], variant: PromptVariant) -> BuiltPrompt {
        let prompt = """
            Sentence: \(sentence.text)
            Underlined phrase: "\(phrase)"
            \(roleHint.map { "The phrase is \($0)." } ?? "")

            Earlier sentences:
            \(numbered(candidates.map { cut($0.text) }))
            """
        return BuiltPrompt(instructions: ModelKnobs.pickInstructions[variant, default: ModelKnobs.basePick], prompt: prompt,
                           sentenceIndexes: [sentence.index] + candidates.map(\.index))
    }

    static func confirm(phrase: String, sentence: IndexedText, passage: IndexedText, variant: PromptVariant) -> BuiltPrompt {
        let prompt = """
            Sentence: \(sentence.text)
            Underlined phrase: "\(phrase)"

            Earlier passage: \(cut(passage.text))
            """
        return BuiltPrompt(instructions: ModelKnobs.confirmInstructions[variant, default: ModelKnobs.baseConfirm], prompt: prompt,
                           sentenceIndexes: [sentence.index, passage.index])
    }

    /// The phrase's role in plain words, for the pick prompt.
    static func roleHint(_ role: EventRole?) -> String? {
        switch role {
        case .reaction?: "a reaction: look for what it reacts to"
        case .attempt?: "an action: look for the goal or event that made them do it"
        case .internalResponse?: "a feeling: look for what caused it"
        case .outcome?: "a result: look for the action that led to it"
        case .goal?: "a wish or plan: look for what started it"
        case .initiatingEvent?: "an event: look for what made it possible"
        case .setting?: "a description: look for where this person, thing or place was first set up"
        case nil: nil
        }
    }

    /// At most `ModelKnobs.candidateWords` words, with "…" when cut.
    static func cut(_ text: String) -> String {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard words.count > ModelKnobs.candidateWords else { return text }
        return words.prefix(ModelKnobs.candidateWords).joined(separator: " ") + " …"
    }

    private static func numbered(_ items: [String]) -> String {
        items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
    }
}
