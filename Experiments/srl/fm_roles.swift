// Semantic roles (SRL) from Apple's on-device Foundation Models: who (agent) · did (predicate) · what (patient) · where (location),
// pronouns resolved and the same thing named the same way, as Claude did for the ideal labels (EXTRACT.md).
//
//     swift Experiments/srl/fm_roles.swift little-women 1 1
//
// Reads Experiments/srl/data/<book>-chNN-sentences.json (split.py); writes <book>-chNN-roles-fm.json in the same shape as
// the ideal roles, so match.py can compare them (`python3 -I Experiments/srl/match.py little-women 1 1 fm`).
// One call per paragraph, with the previous paragraph as context. Greedy sampling.
import Foundation
import FoundationModels

@Generable
struct Event {
    @Guide(description: "Who does it: a character's name, never a pronoun. Resolve he, she, they, I, you to the name. Empty if nobody.")
    var who: String
    @Guide(description: "The action as a base-form verb or short verb phrase, like give, burn, play piano.")
    var did: String
    @Guide(description: "What the action is done to, as a short noun phrase worded the same way every time it comes up. Empty if nothing.")
    var what: String
    @Guide(description: "Where it happens, a short place name. Empty if not said.")
    var place: String
}

@Generable
struct SentenceEvents {
    @Guide(description: "The sentence number given in the prompt")
    var number: Int
    @Guide(description: "The events the sentence states, 0 to 4", .maximumCount(4))
    var events: [Event]
}

@Generable
struct ParagraphEvents {
    @Guide(description: "One entry per numbered sentence, in order")
    var sentences: [SentenceEvents]
}

struct Sentence: Codable { let id: Int; let paragraph: Int; let text: String }
struct Roles: Codable { let who: String?; let did: String?; let what: String?; let `where`: String? }
struct Entry: Codable { let id: Int; let roles: [Roles] }

let instructions = """
    You label the events in sentences of a novel (semantic role labeling). For each numbered sentence, list the events it \
    states: who did it, the action, what it was done to, and where. Use characters' names, never pronouns: work out who \
    "she", "he", "I" or "you" is from the context. Name the same person, object or place with exactly the same words every \
    time. A speech tag alone ("said Meg") is not an event; what the speaker says they do or want can be. Leave a field \
    empty when the sentence doesn't say it.
    """

let args = CommandLine.arguments
let book = args[1], from = Int(args[2])!, to = Int(args[3])!
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let data = root.appendingPathComponent("Experiments/srl/data")

guard SystemLanguageModel.default.availability == .available else {
    print("Foundation Models not available: \(SystemLanguageModel.default.availability)")
    exit(1)
}

func clean(_ s: String) -> String? {
    let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    return t.isEmpty || ["none", "nobody", "nothing", "n/a", "-"].contains(t.lowercased()) ? nil : t
}

for n in from...to {
    let tag = String(format: "ch%02d", n)
    let sentences = try JSONDecoder().decode([Sentence].self, from: Data(contentsOf: data.appendingPathComponent("\(book)-\(tag)-sentences.json")))
    let paragraphs = Dictionary(grouping: sentences, by: \.paragraph).sorted { $0.key < $1.key }.map(\.value)
    var roles: [Int: [Roles]] = [:]
    var failures = 0
    let clock = ContinuousClock(), start = clock.now
    for (p, paragraph) in paragraphs.enumerated() {
        let context = p > 0 ? paragraphs[p - 1].map(\.text).joined(separator: " ") : ""
        let numbered = paragraph.enumerated().map { "\($0.offset + 1). \($0.element.text)" }.joined(separator: "\n")
        let prompt = (context.isEmpty ? "" : "Context (the paragraph before, don't label it):\n\(context)\n\n") + "Sentences to label:\n\(numbered)"
        do {
            let session = LanguageModelSession(instructions: instructions)
            let out = try await session.respond(to: prompt, generating: ParagraphEvents.self, options: GenerationOptions(samplingMode: .greedy)).content
            for s in out.sentences where (1...paragraph.count).contains(s.number) {
                roles[paragraph[s.number - 1].id] = s.events.compactMap { e in
                    guard let did = clean(e.did) else { return nil }
                    return Roles(who: clean(e.who), did: did, what: clean(e.what), where: clean(e.place))
                }
            }
        } catch {
            failures += 1
            print("  paragraph \(paragraph[0].paragraph): \(error)")
        }
        if p % 10 == 0 { print("  \(tag) paragraph \(p + 1)/\(paragraphs.count)") }
    }
    let entries = sentences.map { Entry(id: $0.id, roles: roles[$0.id] ?? []) }
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(entries).write(to: data.appendingPathComponent("\(book)-\(tag)-roles-fm.json"))
    print("\(tag): \(sentences.count) sentences, \(paragraphs.count) calls, \(failures) failed, "
          + "\(entries.reduce(0) { $0 + $1.roles.count }) role sets, \(clock.now - start)")
}
