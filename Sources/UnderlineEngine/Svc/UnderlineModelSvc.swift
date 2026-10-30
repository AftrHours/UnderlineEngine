import Foundation

enum ModelFailure: Error, Sendable, Equatable {
    case unavailable
    case exceededContext
    case failed(String)
}

/// A sentence and its global index, as it goes into a prompt.
struct IndexedText: Sendable, Hashable {
    let index: Int
    let text: String
}

/// The pick: the quote comes first, then the candidate number (1-based, 0 = none).
struct ModelPick: Sendable, Equatable {
    let quote: String
    let candidate: Int
}

/// The confirm: the evidence comes first, then the yes/no.
struct ModelConfirm: Sendable, Equatable {
    let evidence: String
    let explains: Bool
}

/// Wraps the on-device model (spec §5.5). It only ever picks among numbered sentences or confirms one; it never searches.
protocol UnderlineModelSvc: Sendable {
    var isAvailable: Bool { get }
    var contextSize: Int { get }
    func pick(phrase: String, roleHint: String?, sentence: IndexedText, candidates: [IndexedText],
              variant: PromptVariant) async throws(ModelFailure) -> ModelPick
    func confirm(phrase: String, sentence: IndexedText, passage: IndexedText, variant: PromptVariant) async throws(ModelFailure) -> ModelConfirm
}

/// No model: every candidate uses the rules path.
struct UnderlineModelSvcUnavailable: UnderlineModelSvc {
    var isAvailable: Bool { false }
    var contextSize: Int { ModelKnobs.fallbackContextSize }

    func pick(phrase: String, roleHint: String?, sentence: IndexedText, candidates: [IndexedText],
              variant: PromptVariant) async throws(ModelFailure) -> ModelPick {
        throw .unavailable
    }

    func confirm(phrase: String, sentence: IndexedText, passage: IndexedText, variant: PromptVariant) async throws(ModelFailure) -> ModelConfirm {
        throw .unavailable
    }
}
