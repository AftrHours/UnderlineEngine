import Foundation
import Testing
@testable import UnderlineKit

/// `UnderlineResult` is what iRead keeps on disk and in iCloud, so its shape never changes. If one of these fails, the change
/// belongs in a new type or a new engine version, not here.
@Test func resultHasExactlyTheFieldsAnAppSaves() throws {
    let result = UnderlineResult(id: "5:10", sentence: 5, paragraph: 2, range: NSRange(location: 10, length: 4), text: "gold",
                                 kind: "thing", decidedBy: "rules",
                                 reference: .init(sentence: 1, paragraph: 0, range: NSRange(location: 3, length: 9), text: "gold coin"))
    let object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(result)) as? [String: Any])
    #expect(Set(object.keys) == ["id", "sentence", "paragraph", "range", "text", "kind", "decidedBy", "reference"])
    let reference = try #require(object["reference"] as? [String: Any])
    #expect(Set(reference.keys) == ["sentence", "paragraph", "range", "text"])
}

/// A real saved underline from iRead's bundled Sherlock seed (written by iRead's `SavedUnderline`). It must read, and write back as the same data.
@Test func anUnderlineIRaedSavedBeforeStillReadsAndWritesBackTheSame() throws {
    let saved = """
    {"id":"64:821","sentence":64,"paragraph":31,"range":[821,19],"text":"drug-created dreams","kind":"thing","decidedBy":"hand","reference":{"sentence":54,"paragraph":30,"range":[85,473],"text":"My own complete happiness."}}
    """
    let data = Data(saved.utf8)
    let result = try JSONDecoder().decode(UnderlineResult.self, from: data)
    #expect(result.id == "64:821" && result.kind == "thing" && result.decidedBy == "hand")
    #expect(result.range == NSRange(location: 821, length: 19) && result.reference.range == NSRange(location: 85, length: 473))
    let again = try JSONDecoder().decode(UnderlineResult.self, from: JSONEncoder().encode(result))
    #expect(again == result)
}
