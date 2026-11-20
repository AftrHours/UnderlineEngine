import Foundation
import FoundationModels

enum ModelKnobs {
    /// Longer references are cut to this many words. Most of Little Women's sentences fit; the old 40 cut off the part
    /// that mattered in long ones ("…the City of Destruction" in the Pilgrim's Progress sentence).
    static let candidateWords = 150
    static let options = GenerationOptions(samplingMode: .greedy)

    /// The confirm instructions: name what the phrase refers to, then pick how the passage relates to it. A category with
    /// a way out for a shared word that means something else ("onlySameWord"), and two made-up examples (not from any test
    /// book). A small model answers a narrow, concrete question better than "does it explain / is it linked".
    static let confirmInstructions = """
        A reader of a novel tapped an underlined phrase and is shown one earlier passage from the book. \
        You get the sentence, the phrase, the passage, and the words both share. \
        First say in a few words what the phrase refers to. Then choose how the passage relates to it: \
        sameThing if the passage mentions the same person, object or place; \
        sameEvent if it tells the same event or situation; \
        causeOrGoal if it tells why it happens or what it is for; \
        onlySameWord if they share a word but it means something else or refers to a different person, object or event; \
        unrelated if there is no connection.

        Example 1. Sentence: "She had lost the silver key somewhere in the garden." Phrase: "lost the silver key". \
        Passage: "Grandfather gave her a small silver key to the attic." Words in both: key. \
        Refers to: the attic key from Grandfather. Relation: sameThing.

        Example 2. Sentence: "After the dance they walked down the stairs slowly." Phrase: "walked down the stairs slowly". \
        Passage: "The children raced up the stairs after dinner." Words in both: stairs. \
        Refers to: the stairs after the dance. Relation: onlySameWord.
        """
}

@Generable
enum LinkKind: String {
    case sameThing, sameEvent, causeOrGoal, onlySameWord, unrelated

    /// The relations that make an underline.
    var isLink: Bool { self == .sameThing || self == .sameEvent || self == .causeOrGoal }
}

@Generable
struct GenConfirm {
    @Guide(description: "What the underlined phrase refers to, in a few words")
    var refersTo: String
    @Guide(description: "How the earlier passage relates to what the phrase refers to")
    var relation: LinkKind
}

/// Apple's on-device model. A new session per call, greedy sampling, guided generation.
struct UnderlineModelSvcFoundation: UnderlineModelSvc {
    var isAvailable: Bool { SystemLanguageModel.default.availability == .available }

    func confirm(phrase: String, sentence: IndexedText, passage: IndexedText, shared: [String]) async throws(ModelFailure) -> ModelConfirm {
        let built = PromptBuilder.confirm(phrase: phrase, sentence: sentence, passage: passage, shared: shared)
        let r = try await respond(built, GenConfirm.self)
        return ModelConfirm(evidence: "\(r.relation.rawValue): \(r.refersTo)", explains: r.relation.isLink, isQuote: false)
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
