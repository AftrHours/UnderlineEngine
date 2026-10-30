import Foundation
import Testing
@testable import UnderlineEngine

/// A file in the repo's `Dataset/` folder.
func datasetURL(_ name: String, file: StaticString = #filePath) -> URL {
    URL(fileURLWithPath: "\(file)").deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Dataset").appendingPathComponent(name)
}

func loadGold() throws -> GoldSet {
    try JSONDecoder().decode(GoldSet.self, from: Data(contentsOf: datasetURL("underline-gold.json")))
}

@Test func goldSetInvariants() async throws {
    let gold = try loadGold()
    let text = try String(contentsOf: datasetURL("little-women-ch1.txt"), encoding: .utf8)
    let ch = await ChapterIndexSvc().prepare(ChapterInput(chapterIndex: 0, plainText: text), embedding: EmbeddingSvcUnavailable())
    #expect(Set(gold.items.map(\.id)).count == gold.items.count)
    for item in gold.items {
        #expect(ch.sentence(item.sentence.index)?.text == item.sentence.text, "\(item.id): sentence text")
        #expect(TextMatch.normalized(item.sentence.text).contains(TextMatch.normalized(item.phrase)), "\(item.id): phrase")
        if case .underline(let refs) = item.expected {
            #expect(!refs.isEmpty && refs.allSatisfy { $0 < item.sentence.index }, "\(item.id): references must be earlier")
        }
        #expect(item.provisional || item.note != nil, "\(item.id): reviewed items keep their note")
    }
    let count = { (kinds: [UnderlineKind]) in gold.items.filter { kinds.contains($0.kind) }.count }
    #expect(count([.action]) >= 8)
    #expect(count([.reaction]) >= 8)
    #expect(count([.place, .thing]) >= 8)
    #expect(count([.feeling]) >= 4)
    #expect(count([.outcome]) >= 4)
    #expect(count([.person]) >= 4)
    let reasons = gold.items.compactMap { item -> NoneReason? in if case .none(let r) = item.expected { r } else { nil } }
    #expect(reasons.count >= 10)
    #expect(reasons.filter { $0 == .explanationLater }.count >= 3)
    #expect(reasons.filter { $0 == .sameSentence }.count >= 3)
    #expect(reasons.filter { $0 == .temptingWrongPassage }.count >= 3)
    #expect(Dictionary(grouping: gold.items, by: \.sentence.index).values.filter { $0.count >= 2 }.count >= 3)
}

@Test func draftedItemsAreProvisional() throws {
    #expect(try loadGold().items.allSatisfy(\.provisional))
}
