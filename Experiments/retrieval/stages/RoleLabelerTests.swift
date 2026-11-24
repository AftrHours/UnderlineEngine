import Foundation
import Testing
@testable import UnderlineEngine

private func people(_ s: IndexedSentence, _ map: [String: String]) -> [EntityMention] {
    map.map { word, entity in EntityMention(entity: entity, range: (s.text as NSString).range(of: word), isPronoun: word.first?.isLowercase == true) }
}

@Test func agentPredicatePatientLocation() {
    let s = indexed("Jo burned the manuscript in the stove.")
    let r = RoleLabeler.roles(in: s, people: people(s, ["Jo": "jo"]))
    #expect(r.first?.agent == "jo")
    #expect(r.first?.predicate == "burn")
    #expect(r.first?.patient == "manuscript")
    #expect(r.first?.location == "stove")
}

@Test func pronounAgentIsTheResolvedPerson() {
    let s = indexed("She gave the slippers to Marmee.")
    let r = RoleLabeler.roles(in: s, people: people(s, ["She": "jo", "Marmee": "marmee"]))
    #expect(r.first?.agent == "jo")
    #expect(r.first?.predicate == "give")
    #expect(r.first?.patient == "slipper")
}

@Test func helpingVerbIsSkipped() {
    let s = indexed("Meg had bought a new dress.")
    let r = RoleLabeler.roles(in: s, people: people(s, ["Meg": "meg"]))
    #expect(r.first?.predicate == "buy")
    #expect(r.first?.patient == "dress")
}

@Test func laterClauseKeepsTheAgent() {
    let s = indexed("Jo immediately sat up, put her hands in her pockets, and began to whistle.")
    let r = RoleLabeler.roles(in: s, people: people(s, ["Jo": "jo"]))
    #expect(r.count >= 2)
    #expect(r.allSatisfy { $0.agent == "jo" })
    #expect(r.contains { $0.predicate == "put" && $0.patient == "hand" && $0.location == "pocket" })
}

@Test func roleTokensArePairs() {
    let r = RoleSet(agent: "jo", predicate: "burn", patient: "manuscript", location: "stove", range: NSRange(location: 0, length: 1))
    #expect(RoleLabeler.tokens(r) == ["pp:burn>manuscript", "ap:jo>burn", "pl:burn>stove", "ao:jo>manuscript"])
}
