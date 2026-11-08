import Foundation
import Testing
@testable import UnderlineEngine

@Test func unavailableServiceThrowsAndSaysSo() async {
    let svc = UnderlineModelSvcUnavailable()
    #expect(!svc.isAvailable)
    await #expect(throws: ModelFailure.unavailable) {
        try await svc.confirm(phrase: "a b", sentence: IndexedText(index: 1, text: "x"), passage: IndexedText(index: 0, text: "y"))
    }
}
