# UnderlineEngine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `UnderlineEngine` Swift package: it prepares a chapter and returns underlined event phrases, each with one earlier reference passage that really explains it, plus an Apple Evaluations harness that measures the mismatch rate.

**Architecture:** A port of `TextEngine`'s layers (`Models / Rules / Svc / Ctrl`), its indexing, search and harness scaffolding, with a new strict read boundary (`index < s`), a new pipeline (detect → search → pick → confirm → limit) and a new golden set. Foundation Models only ever picks or confirms among numbered sentences; guards and rules decide what is shown.

**Tech Stack:** Swift 6.2 tools, iOS 26 / macOS 26, NaturalLanguage, FoundationModels, Swift Testing (unit tests), Apple Evaluations (harness, macOS 27 / Xcode 27 as in `TextEngine`). No third-party packages.

**Spec:** `docs/superpowers/specs/2026-10-30-underline-engine-design.md` (below: "the spec"). The TextEngine spec (`~/project/iRead/TextEngine/docs/superpowers/specs/2026-10-30-text-engine-design.md`) explains the code being ported.

**Working directory for every command:** `/Users/abr/project/iRead/UnderlineEngine`. Port source: `/Users/abr/project/iRead/TextEngine` (written `$TE` below).

**Commits:** every task ends with a commit step. The package is not a git repo yet and the product owner decides when it becomes one (spec §7.1). Until they say so, **skip all commit steps** and leave files in place. Never push.

## Global Constraints

- `// swift-tools-version: 6.2`, platforms `.iOS(.v26), .macOS(.v26)`, strict concurrency. No third-party packages. No `SwiftLintPlugins` build plugin in `Package.swift`.
- The package imports neither iRead nor `TextEngine`. Everything it needs is copied (spec §3).
- Data in and out use iRead's global sentence and paragraph indexes and UTF-16 ranges. `Underline.range` and `AnswerPassage.range` are **within the paragraph**. Event ranges inside an `IndexedSentence` are within the sentence (spec §4.1, §6.1).
- **Zero spoilers:** for an underline in sentence `s`, only sentences with `index < s` may be searched, scored, or placed in any model prompt. `reference.sentence < sentence`, never equal (spec §5.1, §4.1).
- The model only picks by number among sentences it is given, quote first. It never writes a passage (spec §5.5).
- No underline unless pick **and** confirm agree and every guard passes. On the rules path the rules confirm plays that role (spec §2, §5.5).
- Only the types in spec §6 are `public`. Names must not clash with iRead's (`IndexedSentence`, not `Sentence`).
- Tuning values live in `…Knobs` enums at the top of the file that uses them. User-facing text is never shortened.
- Env flags: `UNDERLINE_EVALS`, `UNDERLINE_SWEEP`, `UNDERLINE_SWEEP_LIMIT`. Plain `swift test` runs unit tests only.
- Starting targets (\*): mismatch rate ≤ 5%, reference precision ≥ 90%, spoiler leaks = 0 (hard).

## Review Focus

Failure modes the spec implies but its examples don't spell out, most likely first. Each has a pinning test in the task named.

1. **The first sentence, and a chapter of one sentence:** nothing earlier exists, so no candidates, no model call, no crash, no underline (Tasks 3, 5, 10).
2. **A chapter whose global indexes don't start at 0** (iRead chapter 3 starts near S1000): boundary, lookups and records use global indexes only (Tasks 3, 9).
3. **The model misbehaves:** unavailable, throws `exceededContext`, returns an empty quote, a number out of range, or an earlier sentence that isn't in the candidate list. Fall back or drop; never show an unguarded pick. Embeddings unavailable means words-only search (Tasks 5, 9).
4. **A phrase that occurs twice in one sentence, or text with curly quotes and apostrophes:** the underline range must point at the event's own occurrence, in UTF-16, within the paragraph (Tasks 3, 4).
5. **Stream edge cases:** `startingAt` outside the chapter, an empty chapter, a chapter with no events, a cancelled task. The stream must end cleanly and its set must equal `allUnderlines` (Task 10).

---

## File Structure

```
UnderlineEngine/
  Package.swift, README.md, ARCHITECTURE.md, .swiftlint.yml, Brewfile, .gitignore
  Sources/UnderlineEngine/
    Models/  InputModels, IndexedChapter, EventModels, PassageModels, Candidate     (ported, trimmed)
             UnderlineModels (Underline, UnderlineKind, ChapterUnderlines, PromptVariant)
             UnderlineRecord (UnderlineRecord, DropReason, ConfirmTrace, StepTimes)
    Rules/   SentenceSplitter, EventSplitter, EventRoles, TokenBudget, TextMatch       (ported)
             ReadBoundary (new), CandidateScorer (adapted), UnderlineDetector, UnderlineGuard,
             RulesPicker, UnderlineLimiter
    Svc/     ChapterIndexSvc (+Prepare), EmbeddingSvc                                  (ported)
             UnderlineModelSvc (protocol, Unavailable), UnderlineModelSvcFoundation, PromptBuilder
    Ctrl/    UnderlineCtrl, UnderlineCtrl+Evaluate, UnderlineCtrl+Chapter
  Tests/UnderlineEngineTests/   one file per rule or service, plus TestSupport (fake model, fixtures, dataset URL)
  Tests/UnderlineEngineEvals/   EvalRuns, GoldSet, Outcome, EngineResult, GoldenEvaluation, SweepEvaluation, QualitativeCSV
                                (+ OutcomeTests, QualitativeCSVTests)
  Dataset/                      little-women-ch1.txt, underline-gold.json
  Eval/results/<kind>/          saved EvaluationResult JSON
```

## Task 1: Package scaffold and ported indexing core

**Files:**
- Create: `Package.swift`, `.swiftlint.yml`, `Brewfile`, `.gitignore`, `Dataset/little-women-ch1.txt`
- Create (copied from `$TE`, module renamed): `Models/InputModels.swift`, `Models/IndexedChapter.swift`, `Rules/SentenceSplitter.swift`, `Rules/EventSplitter.swift`, `Rules/EventRoles.swift`, `Rules/TokenBudget.swift`, `Svc/ChapterIndexSvc.swift`, `Svc/ChapterIndexSvc+Prepare.swift`, `Svc/EmbeddingSvc.swift`
- Create (trimmed copies): `Models/EventModels.swift` (only `Track`, `EventRole`, `EventPhrase` from `QuestionModels.swift`), `Models/PassageModels.swift` (only `SearchMode`, `AnswerPath`, `AnswerPassage` from `AnswerModels.swift`), `Rules/TextMatch.swift` (only `TextMatch` from `QuestionGuard.swift`), `Models/Candidate.swift` (as is)
- Tests (copied, module renamed): `SentenceSplitterTests`, `EventSplitterTests`, `ChapterIndexSvcTests`, `PrepareTests`, `TokenBudgetTests`, plus `TestSupport.swift`

**Interfaces:**
- Produces: `ChapterInput(chapterIndex:plainText:firstParagraph:firstSentence:)`, `ChapterIndexSvc.prepare(_:embedding:) async -> IndexedChapter`, `IndexedChapter.sentence(_:) -> IndexedSentence?`, `EventSplitter.events(in:previous:)`, `EmbeddingSvc` (`EmbeddingSvcApple`, `EmbeddingSvcUnavailable`), `TextMatch.normalized(_:)`, `Track`, `EventRole`, `EventPhrase`, `SearchMode`, `AnswerPath`, `AnswerPassage`. All as in `$TE` (spec §6.1 of the TextEngine spec).

- [ ] **Step 1: Write `Package.swift`**: library `UnderlineEngine`; targets `UnderlineEngine`, test target `UnderlineEngineTests`, test target `UnderlineEngineEvals`, both depending on `UnderlineEngine`. Copy `.swiftlint.yml`, `Brewfile`, `.gitignore` from `$TE`.
- [ ] **Step 2: Copy the sources and tests** in the Files list from `$TE/Sources/TextEngine` and `$TE/Tests/TextEngineTests`. Replace `@testable import TextEngine` with `@testable import UnderlineEngine`. Cut `QuestionModels.swift`, `AnswerModels.swift` and `QuestionGuard.swift` down to the types listed. Cut `datasetURL` in `TestSupport.swift` to keep working (it points at `Dataset/`). Copy `$TE/Dataset/little-women-ch1.txt` to `Dataset/`.
- [ ] **Step 3: Run `swift build`**. Expected: builds. Fix only missing-symbol errors by trimming what the copied files reference (the ported core references none of the dropped question types).
- [ ] **Step 4: Run `swift test`**. Expected: the ported tests pass (same counts as in `$TE` for those files).
- [ ] **Step 5: Commit** `feat: scaffold UnderlineEngine and port the indexing core`.

## Task 2: Underline models, kind mapping, knobs

**Files:**
- Create: `Sources/UnderlineEngine/Models/UnderlineModels.swift`, `Models/UnderlineRecord.swift`
- Test: `Tests/UnderlineEngineTests/UnderlineKindTests.swift`

**Interfaces:**
- Produces:
  - `public enum UnderlineKind: String, Sendable, Codable, Hashable, CaseIterable { case action, reaction, feeling, outcome, place, thing, person }` with `static func of(_ phrase: EventPhrase) -> UnderlineKind`.
  - `public struct Underline: Sendable, Codable, Hashable, Identifiable` with `sentence: Int, paragraph: Int, range: NSRange, text: String, kind: UnderlineKind, role: EventRole?, reference: AnswerPassage, decidedBy: AnswerPath` and `id: String` = `"\(sentence):\(range.location)"`.
  - `public struct ChapterUnderlines: Sendable, Codable { chapterIndex: Int; underlines: [Underline] }`.
  - `public enum PromptVariant: String, Sendable, Codable, CaseIterable { case baseline, strictDefinition, fewShot }`.
  - `public enum DropReason: String, Sendable, Codable { case noCandidate, pickedNone, confirmRejected, guardRejected, densityLimit }`.
  - `public struct ConfirmTrace: Sendable, Codable, Hashable { explains: Bool; evidence: String? }`.
  - `public struct StepTimes: Sendable, Codable, Hashable { var searchMs, pickMs, confirmMs: Int? }`.
  - `public struct UnderlineRecord: Sendable, Codable` with `chapterIndex, sentence, phrase: String, kind, path: AnswerPath?, promptVariant: PromptVariant?, searchModeUsed: SearchMode?, embedding: EmbeddingEngine, candidates: [Int], promptSentences: [Int], pickedSentence: Int?, quote: String?, confirm: ConfirmTrace?, kept: Bool, dropped: DropReason?, times: StepTimes` (spec §5.7).

Mapping (author's call, spec §4.2): a name (role `nil`) → `person`; `reaction` → `reaction`; `internalResponse` → `feeling`; `outcome` → `outcome`; `setting` with track `place` → `place`, other `setting` → `thing`; `attempt`, `goal`, `initiatingEvent` → `action`.

- [ ] **Step 1: Write the failing tests** `kindMapsFromRoleAndTrack` (one `#expect` per mapping row above, using `EventPhrase(text:range:role:track:)`) and `underlineAndRecordRoundTripThroughJSON` (encode, decode, `==` for `Underline`).
- [ ] **Step 2: Run** `swift test --filter UnderlineKindTests`. Expected: FAIL, types not defined.
- [ ] **Step 3: Implement** the types above in the two files (`Codable` synthesized).
- [ ] **Step 4: Run** the same filter. Expected: PASS.
- [ ] **Step 5: Commit** `feat: underline models and kind mapping`.

## Task 3: Strict read boundary and guards

**Files:**
- Create: `Rules/ReadBoundary.swift`, `Rules/UnderlineGuard.swift`
- Test: `Tests/UnderlineEngineTests/ReadBoundaryTests.swift`, `UnderlineGuardTests.swift`

**Interfaces:**
- Produces:
  - `ReadBoundary.searchable(before sentence: Int, first: Int, last: Int) -> [Int]`: `first..<sentence`, or `[]` when `sentence` is outside `first...last` or the chapter is empty.
  - `enum GuardReject: String, Sendable, Codable, Hashable { case outOfRange, notEarlier, quoteNotInPick, phraseNotInSentence }`.
  - `enum PickCheck: Sendable, Codable, Hashable { case accepted(Int), none, rejected(GuardReject) }`.
  - `UnderlineGuard.checkPick(pick: Int, quote: String, sent: [Candidate], chapter: IndexedChapter, sentence: Int) -> PickCheck`: `pick` is 1-based into `sent`, 0 = none; accepted only if the number is in range, the chosen sentence index `< sentence`, and the normalised quote (via `TextMatch`) is a substring of the chosen sentence.
  - `UnderlineGuard.paragraphRange(of phrase: EventPhrase, in sentence: IndexedSentence) -> NSRange?`: `nil` unless the substring of `sentence.text` at `phrase.range` equals `phrase.text`; otherwise `NSRange(location: sentence.range.location + phrase.range.location, length: phrase.range.length)`.

- [ ] **Step 1: Write the failing tests.** `ReadBoundaryTests`: `searchable(before: 3, first: 0, last: 228) == [0, 1, 2]`; `before: 0` → `[]`; `before: 1_002, first: 1_000, last: 1_200` → `[1_000, 1_001]`; `before: 300, first: 0, last: 228` → `[]`; `before: 3, first: 10, last: 50` → `[]`; empty chapter (`last: -1`) → `[]`; for every `s` in `0...228` no returned index is `>= s`. `UnderlineGuardTests`: pick 0 → `.none`; pick out of range → `.rejected(.outOfRange)`; a candidate whose sentence index equals or exceeds `sentence` → `.rejected(.notEarlier)`; a quote not in the chosen sentence, or empty → `.rejected(.quoteNotInPick)`; a curly-quote quote matching a straight-quote sentence → `.accepted`; `paragraphRange` for a phrase occurring twice in one sentence returns the occurrence at the event's own range (build the sentence by hand with two identical phrases and ranges), and returns `nil` when `phrase.text` doesn't match the text at its range.
- [ ] **Step 2: Run** `swift test --filter ReadBoundaryTests` and `--filter UnderlineGuardTests`. Expected: FAIL.
- [ ] **Step 3: Implement** both files to the signatures above.
- [ ] **Step 4: Run** both filters. Expected: PASS.
- [ ] **Step 5: Commit** `feat: strict read boundary and underline guards`.

## Task 4: Detector

**Files:**
- Create: `Rules/UnderlineDetector.swift` (holds `UnderlineKnobs` at the top)
- Test: `Tests/UnderlineEngineTests/UnderlineDetectorTests.swift`

**Interfaces:**
- Consumes: `IndexedSentence.events`, `IndexedSentence.names`, `EventRoles.reasonClause(after:in:stopAt:)`, `UnderlineKind.of`.
- Produces:
  - `enum UnderlineKnobs { static let minPhraseWords = 2; static let generalWords: Set<String>; static let maxPerParagraph = 2; static let kindOrder: [UnderlineKind] }` (starting values; `person` last in `kindOrder`).
  - `struct UnderlineCandidate: Sendable, Hashable { let sentence: Int; let phrase: EventPhrase; let kind: UnderlineKind }`.
  - `UnderlineDetector.candidates(in sentence: IndexedSentence) -> [UnderlineCandidate]`: its events and person names (a name becomes an `EventPhrase` with `role: nil`, `track: .character`), minus: phrases under `minPhraseWords` words (names exempt), phrases made only of `generalWords` ("this", "that", "it"…), and any event with a reason clause after it in the same sentence (`reasonClause` non-nil, for `cause` and `goal` tracks).

- [ ] **Step 1: Write the failing tests** using `indexed(_:)` from `TestSupport`: `"Jo immediately sat up, put her hands in her pockets, and began to whistle."` → candidate texts include `"immediately sat up"` and `"began to whistle"`, every candidate's `sentence` equals the sentence index; a sentence `"Meg stayed home because it was a hard winter."` → no candidate with a `cause` or `goal` track starting before `because`; a one-word event is dropped but a one-word person name is kept; a speech-tag-only sentence (`"said Meg."`) → `[]`; every candidate's `paragraphRange` (Task 3) is non-nil.
- [ ] **Step 2: Run** `swift test --filter UnderlineDetectorTests`. Expected: FAIL.
- [ ] **Step 3: Implement** the detector as filters over the sentence's existing events and names.
- [ ] **Step 4: Run** the filter. Expected: PASS.
- [ ] **Step 5: Commit** `feat: underline detector`.

## Task 5: Search before a sentence

**Files:**
- Modify (ported): `Rules/CandidateScorer.swift` (from `$TE`), `Models/Candidate.swift`
- Test: `Tests/UnderlineEngineTests/CandidateScorerTests.swift` (adapt `$TE`'s)

**Interfaces:**
- Consumes: `ReadBoundary.searchable(before:first:last:)`, `UnderlineCandidate`.
- Produces:
  - `SearchKnobs` as in `$TE` plus `static let minRawScore: [SearchMode: Double]` (the floor below which a candidate is dropped before any model call; starting values `embed` 0.425, `words` 0.25, `both` 0.35, half of `$TE`'s rules-judge minimums).
  - `SearchQuery.make(candidate: UnderlineCandidate, in sentence: IndexedSentence, embedding: any EmbeddingSvc, tagger: ChapterIndexSvc) -> SearchQuery`: text is the phrase; `track`, `role`, `names` (person names inside the phrase), `reactionCue` from the phrase.
  - `CandidateScorer.rank(_ q: SearchQuery, in ch: IndexedChapter, before sentence: Int, mode: SearchMode) -> SearchResult`: replaces `tapped:frontier:`; the pool is `ReadBoundary.searchable(before:)`; the distance bonus uses `abs(sentence - s.index)`.
  - `UnderlineSearch.candidates(_ result: SearchResult) -> [Candidate]`: the top `SearchKnobs.maxCandidates` with `rawScore >= minRawScore[modeUsed]`; empty means "no underline here".

- [ ] **Step 1: Write the failing tests.** Port `$TE`'s scorer tests to the new signature, and add: for `s` in `0..<chapter.sentences.count` every `ranking` sentence is `< s` and `highestScored < s` (Little Women chapter 1 prepared with `EmbeddingSvcUnavailable`); the first sentence returns an empty ranking and `candidates(_:)` is `[]`; a pool where every `rawScore` is below the floor yields `[]`; with `EmbeddingSvcUnavailable`, `modeUsed == .words`.
- [ ] **Step 2: Run** `swift test --filter CandidateScorerTests`. Expected: FAIL (signature).
- [ ] **Step 3: Implement** the changes above by editing the copy; keep the weights and bonuses as in `$TE`.
- [ ] **Step 4: Run** the filter. Expected: PASS.
- [ ] **Step 5: Commit** `feat: search only before the underlined sentence`.

## Task 6: Prompts and the model service

**Files:**
- Create: `Svc/PromptBuilder.swift`, `Svc/UnderlineModelSvc.swift`, `Svc/UnderlineModelSvcFoundation.swift`
- Test: `Tests/UnderlineEngineTests/PromptBuilderTests.swift`, `UnderlineModelSvcTests.swift`

**Interfaces:**
- Produces:
  - `struct IndexedText: Sendable, Hashable { let index: Int; let text: String }`.
  - `enum ModelFailure: Error, Sendable, Equatable { case unavailable, exceededContext, failed(String) }`.
  - `struct ModelPick: Sendable, Equatable { let quote: String; let candidate: Int }` (0 = none). `struct ModelConfirm: Sendable, Equatable { let evidence: String; let explains: Bool }`.
  - `protocol UnderlineModelSvc: Sendable { var isAvailable: Bool { get }; var contextSize: Int { get }; func pick(phrase: String, roleHint: String?, sentence: IndexedText, candidates: [IndexedText], variant: PromptVariant) async throws(ModelFailure) -> ModelPick; func confirm(phrase: String, sentence: IndexedText, passage: IndexedText, variant: PromptVariant) async throws(ModelFailure) -> ModelConfirm }`.
  - `UnderlineModelSvcUnavailable` (every call throws `.unavailable`); `UnderlineModelSvcFoundation`.
  - `enum PromptBuilder { static func pick(phrase:roleHint:sentence:candidates:variant:) -> (instructions: String, prompt: String, sentenceIndexes: [Int]); static func confirm(...) -> same }`: pure; `sentenceIndexes` lists every sentence in the prompt, the underlined one included.
  - `enum ModelKnobs` (at the top of `UnderlineModelSvcFoundation.swift`): `candidateWords = 40`, `GenerationOptions(samplingMode: .greedy)`, and per-`PromptVariant` instruction text. `baseline` states the §4.3 definition once; `strictDefinition` adds "answer none when the passage only shares the topic"; `fewShot` adds two worked examples taken from Little Women (one explains, one only shares words).
  - `@Generable` types `GenPick { quote first, then candidate: Int, range 0...20 }` and `GenConfirm { evidence first, then explains: Bool }` (properties generate in order, as in `$TE`'s `GenVerdict`).

- [ ] **Step 1: Write the failing tests.** `PromptBuilderTests`: for each `PromptVariant`, `pick(...)` with candidates S3, S7 and underlined sentence S9 returns `sentenceIndexes == [9, 3, 7]` and the prompt contains each text and no other text; every candidate text is cut to `ModelKnobs.candidateWords` words with `…`; `confirm(...)` contains exactly the phrase, the underlined sentence and the one passage (not any other candidate); the instructions differ between the three variants. `UnderlineModelSvcTests`: `UnderlineModelSvcUnavailable().pick(...)` throws `ModelFailure.unavailable`; `isAvailable == false`.
- [ ] **Step 2: Run** `swift test --filter PromptBuilderTests` and `--filter UnderlineModelSvcTests`. Expected: FAIL.
- [ ] **Step 3: Implement** the builder and services. For the Foundation service, copy the session handling from `$TE`'s `QuestionModelSvcFoundation` (`respond`, `cut`, new `LanguageModelSession` per call, `exceededContextWindowSize` → `.exceededContext`).
- [ ] **Step 4: Run** both filters. Expected: PASS. (The Foundation service is exercised by the harness in Task 13.)
- [ ] **Step 5: Commit** `feat: underline prompts and model service`.

## Task 7: Rules path (pick and confirm)

**Files:**
- Create: `Rules/RulesPicker.swift`
- Test: `Tests/UnderlineEngineTests/RulesPickerTests.swift`

**Interfaces:**
- Consumes: `Candidate`, `SearchKnobs.contentLemmas`, `SearchKnobs.roleLinks`.
- Produces:
  - `enum JudgeKnobs { static let minScore: [SearchMode: Double]; static let margin: [SearchMode: Double] }` (values from `$TE`'s `JudgeKnobs`).
  - `RulesPicker.decide(_ ranking: [Candidate], mode: SearchMode) -> Int?`: as `$TE`'s `RulesJudge.decide`.
  - `RulesPicker.confirm(phrase: EventPhrase, in sentence: IndexedSentence, reference: IndexedSentence) -> Bool`: true only if the reference shares a content lemma with the phrase, or contains the same person name, or has an event whose role is in `SearchKnobs.roleLinks[phrase.role]`.

- [ ] **Step 1: Write the failing tests:** `decide` returns `nil` for an empty ranking, for a top score under `minScore`, and for a margin under `margin`, and returns the top sentence when both pass; `confirm` is true for `"began to whistle"` against a reference containing "whistle", true for a name phrase against a reference containing the name, false for a topically close reference with no shared lemma, name or role link.
- [ ] **Step 2: Run** `swift test --filter RulesPickerTests`. Expected: FAIL.
- [ ] **Step 3: Implement** both functions.
- [ ] **Step 4: Run** the filter. Expected: PASS.
- [ ] **Step 5: Commit** `feat: rules pick and rules confirm`.

## Task 8: Limiter

**Files:**
- Create: `Rules/UnderlineLimiter.swift`
- Test: `Tests/UnderlineEngineTests/UnderlineLimiterTests.swift`

**Interfaces:**
- Consumes: `Underline`, `UnderlineKnobs.maxPerParagraph`, `UnderlineKnobs.kindOrder`.
- Produces:
  - `struct KeptUnderline: Sendable { let underline: Underline; let score: Double }`.
  - `UnderlineLimiter.apply(_ kept: [KeptUnderline], maxPerParagraph: Int) -> (kept: [KeptUnderline], dropped: [String])` (dropped are `Underline.id`s): per paragraph, rank by `score` descending (ties: earlier sentence, then earlier `range.location`, then `kindOrder`), take greedily, skip an underline whose range overlaps an already taken one in the same sentence, stop at `maxPerParagraph`; return survivors in sentence order. Order-independent by construction (spec §5.6; ranking by search score because confirm is yes/no, author's call).

- [ ] **Step 1: Write the failing tests:** three underlines in one paragraph with `maxPerParagraph: 2` keeps the two highest scores and drops the third's id; two overlapping ranges in one sentence keep only the higher score; underlines in different paragraphs don't compete; shuffling the input array gives the same `kept` and `dropped` (run with several fixed permutations); a tie on score keeps the earlier sentence.
- [ ] **Step 2: Run** `swift test --filter UnderlineLimiterTests`. Expected: FAIL.
- [ ] **Step 3: Implement** `apply`.
- [ ] **Step 4: Run** the filter. Expected: PASS.
- [ ] **Step 5: Commit** `feat: per-paragraph underline limiter`.

## Task 9: Controller, one candidate through the pipeline

**Files:**
- Create: `Ctrl/UnderlineCtrl.swift`, `Ctrl/UnderlineCtrl+Evaluate.swift`
- Modify: `Tests/UnderlineEngineTests/TestSupport.swift` (add `FakeUnderlineModel`, `fixtureChapter()`)
- Test: `Tests/UnderlineEngineTests/UnderlineCtrlTests.swift`

**Interfaces:**
- Consumes: Tasks 2–8.
- Produces:
  - `public enum ModelChoice { case automatic, rulesOnly }`, `public enum EmbeddingChoice { case automatic, none }`.
  - `public final class UnderlineCtrl: Sendable` with `public convenience init(model: ModelChoice = .automatic, embedding: EmbeddingChoice = .automatic, search: SearchMode = .both, prompt: PromptVariant = .baseline)`, internal `init(modelSvc:embeddingSvc:indexSvc:search:prompt:)`, `public var usesModel: Bool`, `public func prepare(_ chapter: ChapterInput) async -> IndexedChapter`.
  - `func evaluate(_ candidate: UnderlineCandidate, in chapter: IndexedChapter) async -> (KeptUnderline?, UnderlineRecord)`: detect is the caller's job. Steps: search (`before: candidate.sentence`); empty → record `dropped: .noCandidate`, no model call. Model path: fit candidates to `TokenBudget`, `pick`, `UnderlineGuard.checkPick` (`.none` → `.pickedNone`, `.rejected` → `.guardRejected`), then `confirm` on that one passage only (`explains == false` → `.confirmRejected`); on `.exceededContext` halve the candidates and retry once, then use the rules path for this candidate; any other model error → rules path. Rules path: `RulesPicker.decide`, then `RulesPicker.confirm`; failures map to `.pickedNone` / `.confirmRejected`. The kept `Underline` gets `range` from `UnderlineGuard.paragraphRange` (nil → `.guardRejected`). The record's `promptSentences` is the union of `PromptBuilder` `sentenceIndexes` for every call made, computed **before** the call.
  - Test doubles: `FakeUnderlineModel: UnderlineModelSvc` with scripted `pick` and `confirm` results, an optional scripted error, and a `calls` log of `(kind, sentenceIndexes)`. `fixtureChapter()` prepares this text with `EmbeddingSvcUnavailable`: `Father had gone away to the war. Meg sewed by the fire. Beth played the old piano. Amy drew a small picture. Jo said she would face the war like Father.`

- [ ] **Step 1: Write the failing tests** (`UnderlineCtrlTests`): `acceptedPickAndConfirmKeepsUnderline` (phrase in S4 `face the war like Father`, fake picks the S0 candidate and confirms → `Underline.reference.sentence == 0`, `decidedBy == .model`, `kept == true`); `spoilerNeverReachesAPrompt` (for every candidate in the fixture, every index in the fake's `calls` and in `record.promptSentences` is `<= candidate.sentence` and the candidate sentence is the only one equal to it; every `record.candidates` entry is `< candidate.sentence`); `pickNoneDropsWithPickedNone`; `confirmNoDropsWithConfirmRejected`; `pickOfSentenceNotInCandidatesDropsWithGuardRejected` (fake returns number 9); `emptyQuoteDropsWithGuardRejected`; `firstSentenceMakesNoModelCall` (`calls.isEmpty`, `dropped == .noCandidate`); `exceededContextHalvesThenFallsBackToRules`; `unavailableModelUsesRulesPathWithDecidedByRules`; `chapterNotStartingAtZero` (prepare the same text with `firstSentence: 1_000`, same assertions with shifted indexes).
- [ ] **Step 2: Run** `swift test --filter UnderlineCtrlTests`. Expected: FAIL.
- [ ] **Step 3: Implement** `UnderlineCtrl` and `evaluate`; keep the token-budget retry in a private helper as in `$TE`'s `AskCtrl+Answer.judgeWithModel`.
- [ ] **Step 4: Run** the filter. Expected: PASS.
- [ ] **Step 5: Commit** `feat: underline controller, one candidate`.

## Task 10: Controller, whole chapter, stream and `allUnderlines`

**Files:**
- Create: `Ctrl/UnderlineCtrl+Chapter.swift`
- Test: `Tests/UnderlineEngineTests/UnderlineChapterTests.swift`

**Interfaces:**
- Consumes: `UnderlineCtrl.evaluate`, `UnderlineDetector.candidates`, `UnderlineLimiter.apply`.
- Produces:
  - `public func allUnderlines(in chapter: IndexedChapter) async -> (ChapterUnderlines, [UnderlineRecord])`: paragraph by paragraph in order; per paragraph evaluate every candidate, apply the limiter, mark limiter drops as `dropped: .densityLimit` and `kept: false` in the returned records (all records returned, kept or not).
  - `public func underlines(in chapter: IndexedChapter, startingAt sentence: Int) -> AsyncStream<(Underline, UnderlineRecord)>`: starts at the paragraph holding `sentence` (the first paragraph when `sentence` is outside the chapter), goes to the end, wraps to the start, emits each paragraph's survivors in sentence order, finishes after the last paragraph, and ends when its task is cancelled.

- [ ] **Step 1: Write the failing tests:** `streamSetEqualsAllUnderlines` (collect the stream from sentence 0, from the middle, and from a sentence outside the chapter; compare sets of `Underline.id` and references with `allUnderlines`); `streamStartsAtThePagesParagraph` (first emitted underline's paragraph is `>=` the start paragraph, later ones wrap); `limitIsPerParagraphAndOrderIndependent` (a paragraph with more candidates than `maxPerParagraph` yields the same survivors from every start); `densityDropsAppearInRecords`; `emptyChapterFinishesImmediately`; `chapterWithNoEventsYieldsNothing`; `cancellationStopsTheStream` (cancel the consuming task after the first element; the stream ends without hanging and the fake model sees no further calls after cancellation); a one-sentence chapter yields no underline and no model call.
- [ ] **Step 2: Run** `swift test --filter UnderlineChapterTests`. Expected: FAIL.
- [ ] **Step 3: Implement** both functions; the stream is a thin wrapper over a shared per-paragraph pass so the two cannot disagree. Check `Task.isCancelled` between candidates.
- [ ] **Step 4: Run** the filter, then `swift test` for the whole package. Expected: PASS.
- [ ] **Step 5: Commit** `feat: whole-chapter underlines and progressive stream`.

## Task 11: Golden set format and outcome classifier

**Files:**
- Create: `Tests/UnderlineEngineEvals/GoldSet.swift`, `Outcome.swift`, `EngineResult.swift` (adapted from `$TE/Tests/TextEngineEvals`), `OutcomeTests.swift`
- Create: `Dataset/underline-gold.json` (one valid item, so the loader test runs)

**Interfaces:**
- Produces (test-target types):
  - `GoldItem: Codable` with `id: String, sentence: GoldRef, phrase: String, kind: UnderlineKind, expected: GoldExpected, provisional: Bool, note: String?`; `GoldRef { index: Int; text: String }` as in `$TE`.
  - `GoldExpected: Codable { case underline(references: [Int]); case none(NoneReason) }`, `NoneReason: String, Codable { case explanationLater, sameSentence, temptingWrongPassage, noExplanation }`; `isAnswerable` true for `.underline`.
  - `GoldItem.resolve(in chapter: IndexedChapter) -> ResolvedItem?`: finds the sentence by index and checks its text equals `sentence.text` (else relocates by text); `phrase` must be a substring.
  - `enum MissCause: String, Codable { case detectMiss, searchMiss, pickMiss, confirmRejected, guardRejected, densityLimit }`.
  - `enum Outcome: Comparable, Codable { case spoiler, mismatch, missed(MissCause), underlinedRight, correctlyNone }` (worst first as listed; spec §8.3).
  - `OutcomeClassifier.classify(_ item: ResolvedItem, underlines: ChapterUnderlines, records: [UnderlineRecord]) -> Outcome`.
  - `EngineResult` (Codable): `underlined: Bool, referenceSentence: Int?, referenceText: String?, path: String?, highestUsed: Int?, candidates: [Int], pickedSentence: Int?, rejectedAs: String?, dropped: String?, ranking: [Int]`, plus `static func from(item:underlines:records:) -> EngineResult`.

Classifier rules: any index in `record.candidates` or `record.promptSentences` that is `>= item sentence` → `.spoiler`. Expected `underline`: an underline with overlapping phrase text and a reference in `references` → `.underlinedRight`; overlapping underline with a reference outside the set → `.mismatch`; none → `.missed` with the cause from the matching record (`noCandidate` → `.detectMiss` if no record for the phrase, else `.searchMiss`; `.pickedNone` → `.pickMiss` unless an accepted reference was in `candidates` and the set is disjoint from `candidates` → `.searchMiss`; `.confirmRejected`, `.guardRejected`, `.densityLimit` map directly). Expected `none`: an overlapping underline → `.mismatch`; otherwise `.correctlyNone`.

- [ ] **Step 1: Write the failing tests** (`OutcomeTests`, synthetic records, no model): one test per outcome and per `MissCause`; `spoilerBeatsEverything` (a record whose `promptSentences` holds the item's own sentence index plus one earlier is fine, holding a later index is `.spoiler`); `goldItemJSONRoundTrip`; `resolveRelocatesByTextWhenIndexShifts`; `resolveFailsWhenPhraseNotInSentence`.
- [ ] **Step 2: Run** `swift test --filter OutcomeTests`. Expected: FAIL.
- [ ] **Step 3: Implement** the types, adapting `$TE`'s `GoldSet`, `Outcome`, `EngineResult` (drop question, track, suggestion and whichPart parts).
- [ ] **Step 4: Run** the filter. Expected: PASS.
- [ ] **Step 5: Commit** `feat(evals): gold set format and outcome classifier`.

## Task 12: Draft the golden set (provisional)

**Files:**
- Create/modify: `Dataset/underline-gold.json`
- Test: `Tests/UnderlineEngineEvals/GoldSetInvariantsTests.swift`

**Interfaces:**
- Consumes: `GoldItem`, `Dataset/little-women-ch1.txt`, `$TE/Dataset/little-women-ch1.json` (30 items; `tap`, `question.target`, `expected.indexes`).

Content rules (spec §8.2): seed from the `$TE` items: each answerable item becomes `underline` (sentence = its tap, phrase = its `question.target`, references = its expected indexes); each not-answerable item whose reason is "nothing earlier" becomes a `none` candidate. Hand-read the chapter for the rest. Totals: ≥ 8 each for `action`, `reaction`, `place`+`thing` combined; ≥ 4 each for `feeling`, `outcome`, `person`; ≥ 10 `none` items, of which ≥ 3 `explanationLater`, ≥ 3 `sameSentence`, ≥ 3 `temptingWrongPassage`; at least 3 sentences with two or more items (several phrases). Every item `provisional: true`, with a one-line `note` saying why the references are right (or why `none`).

- [ ] **Step 1: Write the failing test** `goldSetInvariants`: loads both files; every item's `sentence.text` equals the chapter sentence at its index; the phrase is a substring; every reference index `< sentence.index`; counts meet the totals above; every item has `provisional == true`; ids unique.
- [ ] **Step 2: Run** `swift test --filter GoldSetInvariantsTests`. Expected: FAIL (too few items).
- [ ] **Step 3: Draft the items** to meet the counts, using sentence indexes from preparing the chapter (print them once with a throwaway test or `swift test` helper; do not commit the helper).
- [ ] **Step 4: Run** the filter. Expected: PASS.
- [ ] **Step 5: Commit** `feat(evals): provisional golden set for Little Women chapter 1`.

## Task 13: Golden evaluation and report

**Files:**
- Create: `Tests/UnderlineEngineEvals/EvalRuns.swift`, `GoldenEvaluation.swift` (adapted from `$TE`); create `Sources/UnderlineEngine/Models/KnobSnapshot.swift` (copy from `$TE`, add `maxPerParagraph` and `promptVariant`) so run info records them

**Interfaces:**
- Consumes: `UnderlineCtrl`, `OutcomeClassifier`, `EngineResult`, the `Evaluations` framework (`Evaluation`, `Evaluator`, `ModelJudgeEvaluator`, `Metric`, `EvaluationResult`) exactly as `$TE`'s harness uses them.
- Produces: `EvalMetric` names for every row of spec §8.6 (`mismatch rate`, `no spoiler`, `reference precision`, `underline recall`, `explains the phrase` (judge), `phrase accuracy`, `candidate recall`, `underlines per 100 sentences`, `confirm agreement`, step latencies); `Evals.enabled` reading `UNDERLINE_EVALS`; `Evals.load(model:search:prompt:)`; `Evals.report(...)` printing the four sections of spec §8.4 (summary by kind, items worst first with sentence / phrase / reference shown / expected / candidates / pick quote / confirm answer / judge rationale, judge vs human labels, changed since last run), **mismatch rate first**; `@Test goldenEvaluation()` and `@Test rulesBaselineEvaluation()` with `.enabled(if: Evals.enabled)`.

The model judge is a different session from the confirm step; its pass/fail text is the §4.3 definition ("the passage names the same person, thing, place or situation, or gives the cause, goal or earlier event the phrase depends on; same topic or similar words is a fail").

- [ ] **Step 1: Copy and adapt** `$TE`'s `EvalRuns.swift` and `GoldenEvaluation.swift` per the Interfaces: samples come from `GoldItem`; the subject runs `allUnderlines` **once per chapter** (cached) and reads each item's `EngineResult` from it; the judge only grades rows where an underline was made.
- [ ] **Step 2: Run** `swift build --build-tests`. Expected: builds.
- [ ] **Step 3: Run** `swift test` (no flag). Expected: all unit tests pass, evaluations skipped.
- [ ] **Step 4: Run** `UNDERLINE_EVALS=1 swift test --filter rulesBaselineEvaluation`. Expected: prints the report with mismatch rate first; saves JSON under `Eval/results/golden-rules/`; "no spoiler" is 100%.
- [ ] **Step 5: Run** `UNDERLINE_EVALS=1 swift test --filter goldenEvaluation` (on a Mac with Apple Intelligence). Expected: same report for the model path; saves under `Eval/results/golden-model/`; "no spoiler" 100%. If it fails on a spoiler, stop and fix the cause before going on.
- [ ] **Step 6: Commit** `feat(evals): golden evaluation and report`.

## Task 14: Comparisons

**Files:**
- Modify: `Tests/UnderlineEngineEvals/EvalRuns.swift`

**Interfaces:**
- Produces: `@Test promptComparison()` (golden set once per `PromptVariant.allCases`, one table: mismatch rate, reference precision, underline recall, judge pass rate, underlines per 100 sentences) and `@Test searchModeComparison()` (once per `SearchMode`, adds candidate recall); both `.enabled(if: Evals.enabled)`, saved under `Eval/results/prompt-<variant>/` and `Eval/results/search-<mode>/`. If `embed` or `both` doesn't beat `words` on candidate recall, the test prints that line first (the TextEngine rule: results go back to the product owner before more tuning, spec §8.1).

- [ ] **Step 1: Implement** both tests as loops over the existing golden run.
- [ ] **Step 2: Run** `UNDERLINE_EVALS=1 swift test --filter promptComparison` then `--filter searchModeComparison`. Expected: each prints one table and saves JSON.
- [ ] **Step 3: Commit** `feat(evals): prompt and search-mode comparisons`.

## Task 15: Sweep

**Files:**
- Create: `Tests/UnderlineEngineEvals/SweepEvaluation.swift` (adapted from `$TE`)
- Modify: `EvalRuns.swift`

**Interfaces:**
- Produces: `@Test sweepEvaluation()` with `.enabled(if: Evals.sweepEnabled)` (needs `UNDERLINE_SWEEP=1`; `UNDERLINE_SWEEP_LIMIT=60` sweeps only the first 60 sentences). Runs `allUnderlines` over the chapter and prints **every underline that would be shown**, grouped by position, with its reference. Metrics: deterministic no-spoiler check on candidates and prompts, the model judge's explains / doesn't verdict on every underline (failures printed first with the rationale), underlines per 100 sentences, share of sentences with more than one. Saved under `Eval/results/sweep/`.

- [ ] **Step 1: Implement** by adapting `$TE`'s sweep (one row per underline instead of per suggested question).
- [ ] **Step 2: Run** `UNDERLINE_EVALS=1 UNDERLINE_SWEEP=1 UNDERLINE_SWEEP_LIMIT=60 swift test --filter sweepEvaluation`. Expected: prints judge failures first, then the rest; no spoiler failures.
- [ ] **Step 3: Commit** `feat(evals): sweep of every underline`.

## Task 16: Qualitative analysis CSV

**Files:**
- Create: `Tests/UnderlineEngineEvals/QualitativeCSV.swift`, `Tests/UnderlineEngineEvals/QualitativeCSVTests.swift`
- Modify: `Tests/UnderlineEngineEvals/EvalRuns.swift` (write the CSV after every run)

**Interfaces:**
- Consumes: `UnderlineRecord`, `IndexedChapter`, `ResolvedItem`, `Outcome`, `MissCause`, the judge `Metric` per sample, `Evals.save` (Tasks 11–15).
- Produces:
  - `struct QualitativeRow: Sendable` with one `String` property per column of spec §8.7, in that order, and `static let header: [String]` listing the column names exactly as in spec §8.7.
  - `enum QualitativeCSV { static func rows(run: RunInfo, chapter: IndexedChapter, records: [UnderlineRecord], gold: [ResolvedItem]?, outcomes: [String: Outcome], judge: [String: (verdict: String, rationale: String)]) -> [QualitativeRow]; static func encode(_ rows: [QualitativeRow]) -> String }`, where `RunInfo { runID, runKind, promptVariant, searchMode }` and the dictionaries are keyed by `"\(sentence):\(phrase)"`.
  - `Evals.saveCSV(_ rows: [QualitativeRow], beside json: URL) throws -> URL` (same base name, `.csv`).

- [ ] **Step 1: Write the failing tests** (`QualitativeCSVTests`, synthetic records and a fixture chapter, no model): `headerMatchesSpecOrder` (`QualitativeRow.header` equals the §8.7 column list, first `run_id`, last `reviewer_note`); `quotesCommasQuotesAndLineBreaks` (a sentence containing `,`, `"` and `\n` is wrapped in quotes with inner quotes doubled); `startsWithByteOrderMark` (`encode` output begins with `"\u{FEFF}"`); `underlineMarkedAtItsOwnRange` (a sentence with the phrase twice gets `[[…]]` only around the event's range); `wordsColumnFormat` (`"Jo/Jo/PersonalName · sat/sit/Verb"` style); `droppedPhraseHasRowWithReason` (`underlined == "no"`, `dropped_reason == "confirmRejected"`); `goldItemWithoutRecordGetsDetectMissRow`; `rowsSortedWorstFirst` (⛔ before ❌ before ⚠️ before ✅, then by sentence); `reviewColumnsAlwaysEmpty`; `sweepRowsHaveNoExpectedOrOutcome`.
- [ ] **Step 2: Run** `swift test --filter QualitativeCSVTests`. Expected: FAIL.
- [ ] **Step 3: Implement** `QualitativeCSV` and `saveCSV`; call `saveCSV` right after each `Evals.save` in `goldenEvaluation`, `rulesBaselineEvaluation`, `promptComparison`, `searchModeComparison` and `sweepEvaluation`.
- [ ] **Step 4: Run** the filter. Expected: PASS.
- [ ] **Step 5: Run** `UNDERLINE_EVALS=1 swift test --filter rulesBaselineEvaluation`, then open the new `.csv` beside the JSON in `Eval/results/golden-rules/` in Numbers. Expected: one row per considered phrase plus one per unmatched golden item, columns in §8.7 order, curly quotes shown correctly.
- [ ] **Step 6: Commit** `feat(evals): qualitative analysis CSV after every run`.

## Task 17: README and ARCHITECTURE

**Files:**
- Create: `README.md`, `ARCHITECTURE.md`

- [ ] **Step 1: Write `README.md`** with the same sections as `$TE/README.md`: one-paragraph description, setup (`brew bundle`, `swift build`, `swift test`, Apple Intelligence and the Simulator note), the pipeline (prepare, detect, search, pick, confirm, limit), the structure table, the tuning table (`EventKnobs`, `UnderlineKnobs`, `SearchKnobs`, `JudgeKnobs`, `ModelKnobs` with their files), the harness commands from spec §8.1, where results are saved, and the qualitative CSV (where it lands, its column groups, the two review columns).
- [ ] **Step 2: Write `ARCHITECTURE.md`**: layers, suffix table and the dependency rule, adapted from `$TE`/iRead (no VM or Repo layers here).
- [ ] **Step 3: Verify** every command and file name in the README exists (`swift build` and the filters named all run). Expected: no stale names.
- [ ] **Step 4: Commit** `docs: README and ARCHITECTURE`.

## Task 18: Review gate and first numbers

**Files:** none changed.

- [ ] **Step 1: Run the full set once** on the provisional golden set: `swift test`, then `UNDERLINE_EVALS=1 swift test --filter goldenEvaluation`, `rulesBaselineEvaluation`, `promptComparison`, `searchModeComparison`.
- [ ] **Step 2: Stop and hand over** to the product owner: the paths of `Dataset/underline-gold.json`, the saved reports and their qualitative CSVs, the mismatch rate and judge agreement per run, and the list of items with the weakest labels. Do not tune until they have reviewed the golden set (spec §8.2). Meanwhile nothing else in the plan depends on tuning.
- [ ] **Step 3: Apply their corrections** to `underline-gold.json`, set `provisional: false` on reviewed items, run `swift test --filter GoldSetInvariantsTests` (update it to allow reviewed items). Expected: PASS.

## Task 19: Tuning loop (after the review)

**Files:** the knobs named below; saved results under `Eval/results/`.

- [ ] **Step 1: Tune prompts first.** Change one `PromptVariant`'s instructions in `ModelKnobs`, run `promptComparison`, keep the change only if the mismatch rate improves without dropping reference precision.
- [ ] **Step 2: Tune search weights** (`embedWeight`, `wordsWeight`, bonuses, `minRawScore`) with `searchModeComparison`, one value at a time.
- [ ] **Step 3: Tune the remaining knobs** (detector words, `JudgeKnobs`, `maxPerParagraph`) one at a time, reading the report's "changed since last run" section.
- [ ] **Step 4: Stop** when the mismatch rate is at or under 5% on the reviewed set, or when every prompt variant and knob group above has been tried. If the target is not met, send the product owner the numbers and what was tried; don't lower the target (spec "Done for this round").
- [ ] **Step 5: Commit** each kept change separately (`tune: <knob> <old> -> <new>`), with the saved result JSON.
