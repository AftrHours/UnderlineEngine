import Foundation
import FoundationModels

enum ModelKnobs {
    static let fallbackContextSize = 4096
    static let candidateWords = 40
    static let options = GenerationOptions(samplingMode: .greedy)

    /// What "explains" means (spec §4.3). Every variant states it.
    static let definition = """
        A passage explains the phrase only when it names the same person, thing, place or situation, \
        or gives the cause, goal or earlier event the phrase depends on. \
        A passage that only shares the topic or uses similar words does not explain it.
        """

    static let basePick = """
        A reader of a novel is skimming and sees an underlined phrase in a sentence. \
        You get the sentence, the phrase, and numbered earlier sentences from the book. \
        Pick the earlier sentence that explains the phrase. \(definition) \
        Judge only from the sentences given. First copy the exact words from the sentence you pick that explain the phrase, \
        then give its number. Answer 0 with an empty quote when none clearly explains it.
        """
    static let baseConfirm = """
        A reader of a novel tapped an underlined phrase and is shown one earlier passage from the book. \
        Decide whether the passage explains the phrase. \(definition) \
        Judge only from the text given. First copy the words from the passage that show it explains the phrase \
        (empty if none), then answer whether it explains it.
        """
    static let strict = " Be strict: if you would have to guess, or link several ideas yourself, the answer is no. A wrong link is much worse than none."
    // Worked examples are invented, not from Little Women, so the golden set never grades the model on its own examples.
    static let pickExamples = """
         Example: Sentence: "Tom slammed the door and refused to come down." Phrase: "refused to come down". \
        Earlier sentences: 1. "The house was cold that winter." 2. "His father had sold Tom's horse that morning." \
        Answer: quote "sold Tom's horse", number 2. \
        Example: Sentence: "Ann rubbed her sore feet." Phrase: "rubbed her sore feet". \
        Earlier sentences: 1. "Ben's feet were always cold." Answer: quote "", number 0, because Ben's feet don't explain Ann's.
        """
    static let confirmExamples = """
         Example: Phrase "refused to come down", passage "His father had sold Tom's horse that morning." Explains: yes. \
        Example: Phrase "rubbed her sore feet", passage "Ben's feet were always cold." Explains: no, it only shares a word.
        """

    static let pickInstructions: [PromptVariant: String] = [
        .baseline: basePick, .strictDefinition: basePick + strict, .fewShot: basePick + pickExamples
    ]
    static let confirmInstructions: [PromptVariant: String] = [
        .baseline: baseConfirm, .strictDefinition: baseConfirm + strict, .fewShot: baseConfirm + confirmExamples
    ]
}

@Generable
struct GenPick {
    // Properties are generated in order: the quote comes first, so the pick is made after quoting.
    @Guide(description: "The exact words from the chosen sentence that explain the phrase; empty if none does")
    var quote: String
    @Guide(description: "Number of the sentence that explains the phrase, or 0 if none clearly does", .range(0...20))
    var candidate: Int
}

@Generable
struct GenConfirm {
    @Guide(description: "The words from the passage that show it explains the phrase; empty if none")
    var evidence: String
    @Guide(description: "True only if the passage explains the phrase")
    var explains: Bool
}

/// Apple's on-device model. A new session per call, greedy sampling, guided generation.
struct UnderlineModelSvcFoundation: UnderlineModelSvc {
    var isAvailable: Bool { SystemLanguageModel.default.availability == .available }
    var contextSize: Int { SystemLanguageModel.default.contextSize }

    func pick(phrase: String, roleHint: String?, sentence: IndexedText, candidates: [IndexedText],
              variant: PromptVariant) async throws(ModelFailure) -> ModelPick {
        let built = PromptBuilder.pick(phrase: phrase, roleHint: roleHint, sentence: sentence, candidates: candidates, variant: variant)
        let r = try await respond(built, GenPick.self)
        return ModelPick(quote: r.quote, candidate: r.candidate)
    }

    func confirm(phrase: String, sentence: IndexedText, passage: IndexedText, variant: PromptVariant) async throws(ModelFailure) -> ModelConfirm {
        let built = PromptBuilder.confirm(phrase: phrase, sentence: sentence, passage: passage, variant: variant)
        let r = try await respond(built, GenConfirm.self)
        return ModelConfirm(evidence: r.evidence, explains: r.explains)
    }

    private func respond<T: Generable>(_ built: BuiltPrompt, _ type: T.Type) async throws(ModelFailure) -> T {
        guard isAvailable else { throw .unavailable }
        let session = LanguageModelSession(instructions: built.instructions)
        do {
            return try await session.respond(to: built.prompt, generating: type, options: ModelKnobs.options).content
        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            throw .exceededContext
        } catch {
            throw .failed(String(describing: error))
        }
    }
}
