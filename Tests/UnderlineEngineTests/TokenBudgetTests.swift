import Foundation
import Testing
@testable import UnderlineEngine

@Test func budgetSubtractsReserveAndMargin() {
    #expect(TokenBudget.available(contextSize: 4096, fixedTokens: 600) == 4096 - 600 - 32 - 409)
}

@Test func fitStopsBeforeOverflowAndNeverGoesNegative() {
    let c = Array(repeating: String(repeating: "word ", count: 40), count: 6)
    #expect(TokenBudget.fit(candidates: c, budget: 130, cost: { $0.count / 3 }) == 1)
    #expect(TokenBudget.fit(candidates: c, budget: -5, cost: { $0.count / 3 }) == 0)
    #expect(TokenBudget.fit(candidates: c, budget: 10_000, cost: { $0.count / 3 }) == 6)
}

@Test func longTypedQuestionIsCountedNotTruncatedByBudget() {
    let long = String(repeating: "why ", count: 2_000)
    #expect(TokenBudget.estimate(long) == long.count / 3 + 1)
}
