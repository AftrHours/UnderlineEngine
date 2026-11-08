import Foundation

/// How much of the model's context window is left for candidates (PRD 2.1 §5.3 B, spec §5.6).
enum TokenBudget {
    static let outputReserve = 32
    static let marginFraction = 0.10

    /// `contextSize − fixed − output reserve − 10% margin`.
    static func available(contextSize: Int, fixedTokens: Int) -> Int {
        contextSize - fixedTokens - outputReserve - Int(Double(contextSize) * marginFraction)
    }

    /// How many best-first candidates fit in `budget`.
    static func fit(candidates: [String], budget: Int, cost: (String) -> Int) -> Int {
        var used = 0
        for (i, candidate) in candidates.enumerated() {
            used += cost(candidate)
            if used > budget { return i }
        }
        return candidates.count
    }

    /// About 3 characters per token, rounded up. `SystemLanguageModel.tokenCount` needs iOS 26.4, so this estimate is used.
    static func estimate(_ text: String) -> Int {
        text.count / 3 + 1
    }
}
