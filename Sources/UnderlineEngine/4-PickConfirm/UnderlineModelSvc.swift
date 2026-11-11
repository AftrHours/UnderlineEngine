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

/// The confirm: the evidence comes first, then the yes/no.
struct ModelConfirm: Sendable, Equatable {
    let evidence: String
    let explains: Bool
}

/// Wraps the on-device model (spec §5.5). It only confirms one earlier sentence that search found; it never searches or picks.
protocol UnderlineModelSvc: Sendable {
    var isAvailable: Bool { get }
    func confirm(phrase: String, sentence: IndexedText, passage: IndexedText) async throws(ModelFailure) -> ModelConfirm
}

/// No model: every candidate uses the rules path.
struct UnderlineModelSvcUnavailable: UnderlineModelSvc {
    var isAvailable: Bool { false }

    func confirm(phrase: String, sentence: IndexedText, passage: IndexedText) async throws(ModelFailure) -> ModelConfirm {
        throw .unavailable
    }
}
