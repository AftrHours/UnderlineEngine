import Foundation
import FoundationModels

enum ModelKnobs {
    static let candidateWords = 40
    static let options = GenerationOptions(samplingMode: .greedy)

    /// What "explains" means (spec §4.3). The confirm prompt states it.
    static let definition = """
        A passage explains the phrase only when it names the same person, thing, place or situation, \
        or gives the cause, goal or earlier event the phrase depends on. \
        A passage that only shares the topic or uses similar words does not explain it.
        """

    static let confirmInstructions = """
        A reader of a novel tapped an underlined phrase and is shown one earlier passage from the book. \
        Decide whether the passage explains the phrase. \(definition) \
        Judge only from the text given. First copy the words from the passage that show it explains the phrase \
        (empty if none), then answer whether it explains it.
        """
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

    func confirm(phrase: String, sentence: IndexedText, passage: IndexedText) async throws(ModelFailure) -> ModelConfirm {
        let built = PromptBuilder.confirm(phrase: phrase, sentence: sentence, passage: passage)
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
