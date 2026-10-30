# Design: UnderlineEngine package ("tap the underline, see where the story set this up")

| | |
|---|---|
| Date | 30 October 2026 |
| Repo | `UnderlineEngine`, a new package of its own (local: `~/project/iRead/UnderlineEngine`, next to `TextEngine`). Swift 6, iOS 26 and macOS 26 |
| Deliverable | A Swift package (library `UnderlineEngine`) plus a harness on Apple's **Evaluations** framework (test target `UnderlineEngineEvals`) |
| Consumer | The iRead app (`EReader/iRead`), from a later integration round (§7.3) |
| Based on | Brainstorm of 30 Oct 2026; the `TextEngine` design (`TextEngine/docs/superpowers/specs/2026-10-30-text-engine-design.md`), referred to below as "the TextEngine spec"; PRD 0.0 and 2.1 |
| Status | Draft, waiting for approval |

Items marked **[author's call]** were not decided by the product owner. They are choices made while writing this document and may be corrected. Items marked (\*) are starting targets to be confirmed.

---

## 1. Intent and why

`TextEngine` answers a question the reader asks: tap a sentence, pick or type "why can this happen?", get the author's earlier sentence. That asks a lot of a reader who is skimming. They have to notice the confusion, tap, choose a question, and read.

`UnderlineEngine` moves the work to the engine. A reader skims a chapter and some phrases are **underlined**. The reader reads the underlined phrase first. If it confuses them, they tap it and a **popover shows the author's own earlier passage** that sets it up, with a way to jump there. No question is typed or picked.

This is for iRead's readers, who skim descriptions (PRD 0.0, aphantasia). Skimming is when the answer sits in a passage they went past quickly.

The underlined thing is an **event**, not only a character: "facing a rebel or two down South", "began to whistle", "put her hands in her pockets". A person ("the old gentleman") is one kind among several.

It keeps the principles of `TextEngine` (PRD 0.0, 2.1):
- **Point, don't generate.** The popover shows a sentence the author wrote, never AI-written text.
- **Zero spoilers.** An underline's evidence comes only from sentences before the underlined sentence (§5.1).
- **Precision over recall, more strongly than before.** The reader doesn't ask for an underline, so a wrong one is an unprompted wrong claim. **No underline is better than a mismatched popover** (§2, anti-goals).
- **On-device only.** NaturalLanguage and Apple Foundation Models. No network.

## 2. Goals, non-goals, anti-goals

### Goals (this round)
1. The input is **one chapter in iRead's `BookContent` shape**, exactly as in `TextEngine` (TextEngine spec §6.1). The output uses iRead's global indexes and UTF-16 ranges, so the app draws underlines and popovers without converting anything.
2. `prepare` returns the chapter's **underlines**: each has a phrase (an event) inside a sentence, a kind, and one **reference passage**: an earlier sentence that explains the phrase (§4).
3. An underline exists **only if** the reference passed both a pick and an independent check (§5.5). Otherwise nothing is underlined at that place.
4. Underlines can be produced **progressively**, paragraph by paragraph in reading order, so the page the reader is on is ready first (§6).
5. It works **without Foundation Models** (rules only, fewer and more cautious underlines), so it runs on any iPad and on the Simulator.
6. **Prompt engineering is measured, not guessed.** Each prompt is a named variant. The harness runs the golden set once per variant and prints one comparison table (§5.5, §8).
7. A **harness** (Apple Evaluations, §8) scores the underlines against a golden set and sweeps every sentence for human review. Its headline number is the **mismatch rate**: of the underlines shown, how many have a reference that doesn't explain the phrase.

### Done for this round
**[author's call]** The package builds, its unit tests pass, the harness runs every evaluation in §8.1, and no spoiler shows up on the golden set or the sweep. The harness reports the mismatch rate and the other §8.6 numbers for the model path and the rules path. Then comes **one tuning loop** on the reviewed golden set (§8.2): prompt variants first, then search weights, then the other knobs, stopping when the mismatch rate is at its target or when the variants and knobs listed in §10 have all been tried. If the target isn't met, the numbers go back to the product owner with what was tried, as `TextEngine` does with its search modes, rather than the target being lowered.

### Non-goals
- **App UI** (drawing underlines, popover, jump to passage, density settings). Next round (§7.3). This round builds the package and harness only. The iRead repo doesn't change.
- **Typed or picked questions.** That is `TextEngine`. This package has no suggest or interpret step.
- **Whole books and cross-chapter references.** One chapter in, one chapter searched (same as `TextEngine`, TextEngine spec §12).
- **Word meaning and knowledge from outside the book.** An event whose explanation isn't in the read text gets no underline.
- **More than one reference per underline.** One phrase, one passage. **[author's call]**
- **Languages other than English.**

### Anti-goals (failures even if everything else works)
- **A mismatched popover:** the reference doesn't explain the underlined phrase, or says something unrelated or contradictory. This is the failure the product owner named.
- **A spoiler:** any sentence at or after the underlined sentence is scored, becomes a candidate, or reaches a model prompt for that underline.
- **A model-written passage** shown as a reference.
- **An underline on a phrase that isn't in its sentence**, or whose range doesn't cover the phrase text.
- **Underline noise:** so many underlines that the reader stops trusting them (§5.6).

## 3. Constraints

- Swift 6, strict concurrency. Platforms: iOS 26, macOS 26 (macOS so the harness and tests run on a Mac).
- Foundation Models: `SystemLanguageModel.default`, guided generation (`@Generable`, `@Guide`), availability checked first. Read `contextSize` at runtime and budget prompts (TextEngine spec §5.6).
- NaturalLanguage English models are missing on the iOS Simulator. Use the same probe-and-fallback as `TextEngine`'s `ChapterIndexSvc`.
- **A separate package that imports neither iRead nor `TextEngine`.** **[author's call]** It starts self-contained: the rules and services it needs (`ReadBoundary`, `SentenceSplitter`, `EventSplitter`, `EventRoles`, `CandidateScorer`, `AnswerGuard`, `ChapterIndexSvc`, `EmbeddingSvc`, the model-service pattern) are copied from `TextEngine`, with their tests, and then change on their own. `TextEngine`'s internals aren't public, and the two will diverge. Whether to extract a shared core is decided later, once both are stable (§12).
- **The builder can read `TextEngine`.** The code to copy is at `~/project/iRead/TextEngine` (`Sources/TextEngine`, `Tests/TextEngineTests`, `Tests/TextEngineEvals`, `Dataset/`), and its spec is the file named at the top. The first phase of the plan is a **port**: copy, rename and adapt, not rebuild. The harness scaffolding already runs under `swift test` there, so it is copied, not re-proven.
- **Same data in, same data out as iRead** (TextEngine spec §6.1). This is the one hard rule about structure. How the code is organised inside is free (§7.2).
- No third-party dependencies.

## 4. Concepts

### 4.1 The underline

| Field | Meaning | Example (sentence: *"…said Jo, thinking that keeping her temper at home was a much harder task than facing a rebel or two down South."*) |
|---|---|---|
| `sentence` | Global sentence index of the underlined sentence | S153 |
| `paragraph`, `range` | Where to draw the underline: global paragraph index and UTF-16 range **within the paragraph** | the range of the phrase |
| `text` | The underlined phrase, an exact substring of the sentence | `facing a rebel or two down South` |
| `kind` | What sort of event it is (§4.2) | `place` |
| `role` | The causal role of the event, when it is an event (TextEngine spec §4.3) | `attempt` |
| `reference` | The earlier passage (`AnswerPassage`, §6): sentence, paragraph, range, text | S9: "…thinking of Father far away, where the fighting was." |
| `decidedBy` | `model` or `rules` | `model` |

The reference is **always strictly earlier** than `sentence` (`reference.sentence < sentence`), and never the same sentence. A reason inside the same sentence ("…because…") is not an underline: the reader can already see it.

### 4.2 What can be underlined

The phrase is an **event phrase** from the same splitter as `TextEngine` (verb phrases, speech tags skipped; TextEngine spec §4.3), plus names. Each one has a `kind`, taken from its role and track:

| Kind | Example phrase | Reader's likely confusion |
|---|---|---|
| `action` | began to whistle | why did they do that? |
| `reaction` | immediately sat up | what set this off? |
| `feeling` | felt cross | why do they feel this? |
| `outcome` | lost the prize | how did this come about? |
| `place` / `thing` | a rebel or two down South | what is this, where does it come from? |
| `person` | the old gentleman | who is this? |

Which kinds the engine underlines at all, and how many, is tuned with the harness (`UnderlineKnobs`, §5.6). **[author's call]** Starting set: every kind above, with `person` last because it was the weakest in the earlier rules-only experiment (`engine-checks/underlines.md`, where "the old gentleman" was linked to the wrong earlier sentence).

### 4.3 What "explains" means

A reference **explains** a phrase when a skimming reader, shown the passage after the phrase, would say "ah, that's why" or "ah, that's what that is". It must be **specific to this phrase**: it names the same person, thing, place or situation, or states the cause, goal or earlier event the phrase depends on. A passage that is merely on the same topic, or that uses similar words, does not explain it. This is the definition the model judge and the golden set both use (§8).

## 5. The pipeline

```
prepare(chapter) ─▶ IndexedChapter                    (as TextEngine: sentences, tags, events, vectors)
        │
detect  ─▶ candidate phrases per sentence            (rules: events and names worth checking)
search  ─▶ candidate earlier sentences per phrase    (rules: meaning, words, role links; boundary = before the sentence)
pick    ─▶ one reference or none                     (model: quote first, then number)
confirm ─▶ yes / no, by a separate check             (model + rules: does it explain this phrase?)
limit   ─▶ keep the best underlines per paragraph    (rules: density)
        │
        ▼
ChapterUnderlines  (Codable; produced paragraph by paragraph)
```

### 5.1 Read boundary (applies to every step)

`TextEngine` lets the boundary be `max(tapped, frontier)`, because the reader may have read past the tapped sentence. Here the engine has no tap, and underlines are computed ahead of the reader. So the boundary is simpler and stricter:

**For an underline in sentence `s`, only sentences with `index < s` may be searched, scored, or placed in any model prompt.**

Because every reference is before the sentence it explains, an underline can be shown whenever its sentence is on the page, and showing it reveals nothing the reader hasn't read. `prepare` can therefore work on the whole chapter ahead of time (indexing, tagging and embedding show the reader nothing), and each underline uses only the text before it. This costs a few answers that sit just after a phrase on the same page, which is acceptable because precision comes first. **[author's call]**

The rule lives in one pure function (`ReadBoundary`, copied from `TextEngine` and given the `< s` variant), and every step gets its sentences through it. The harness checks it from the logged candidate lists and the logged prompts (§8.6).

### 5.2 Prepare

Same as `TextEngine` (TextEngine spec §5.2): split sentences exactly like iRead's parser, tag words, split each sentence into events with roles and tracks, embed every sentence. Output: `IndexedChapter`, `Codable`, kept in memory by the app.

### 5.3 Detect (rules)

For each sentence, make **candidate phrases**: its events and names, minus speech tags and phrases that are too short or too general (`UnderlineKnobs`). Drop any candidate whose sentence contains the reason after a causal connective ("because", "since", "so that"), because the reader can already see it. A candidate is only a *possible* underline. Nothing is shown yet.

### 5.4 Search (rules, no model)

For each candidate, score the sentences before it (§5.1) as in `TextEngine` (TextEngine spec §5.5): meaning (embeddings) first, shared words second, plus role links, track hints and a nearness bonus, with the same `SearchMode` (`embed`, `words`, `both`) so the harness can compare them. Keep the top `maxCandidates`. **A candidate with no sentence above a minimum score is dropped here**, so the model is never asked about phrases the rules can't ground (`SearchKnobs`).

### 5.5 Pick and confirm (Foundation Models, with a rules path)

This is where the prompts live, and where a mismatch is stopped.

**Pick** (model). For one candidate: send the sentence, the phrase, the phrase's role in plain words (as in `TextEngine`), and the numbered earlier sentences (cut to about 40 words). Guided generation, greedy sampling, a new `LanguageModelSession` per call. The output has the **quote first, then the number**: the exact words from the chosen sentence that explain the phrase, then the sentence number (0 = none). The model never searches the chapter and never writes a passage.

**Confirm** (a separate call, a second look). A new session gets only the phrase, its sentence, and the **one** chosen passage, and answers whether the passage explains the phrase under §4.3 (yes or no, with the words that show it). It does not see the other candidates and does not see the pick's quote. Two independent calls agreeing is the first defence against a mismatch. **[author's call]**

**Guards** (pure, in `UnderlineGuard`): the chosen number was one of the candidates sent; its index is `< s`; it is not the same sentence; the quote is an exact substring of the chosen sentence (case-insensitive, normalised quotes); the phrase is an exact substring of its sentence and its range covers it. Anything that fails is "no underline".

**Rules path** (no model): keep the top candidate only when its score is at least `minRulesScore` and at least `rulesMargin` above the second, with thresholds per search mode. Set them so the rules underline little and rarely wrongly. The rules path has a **rules confirm** too, so goal 3 holds without a model: the top candidate is kept only if it also shares a content word (lemma) or the same name with the phrase, or has a matching role link (TextEngine spec §5.5). `decidedBy` is `rules`. **[author's call]**

**Prompt variants.** The instructions and prompt layout are `PromptVariant` values (for example `baseline`, `strictDefinition`, `fewShot`), each a named struct in `ModelKnobs`. `UnderlineCtrl` takes the variant as a parameter, the run info records it, and `promptComparison` (§8.1) prints one table across variants. A prompt is only changed because that table improved.

**Token budget:** as in the TextEngine spec §5.6. On `exceededContextWindowSize`, halve the candidates and retry once, then use the rules path for that candidate.

### 5.6 Limit (rules)

Density is a product choice and a knob, not a model decision. After confirm, keep at most `maxPerParagraph` underlines in each paragraph, best first, and never two overlapping phrases. Ranking is by confirm confidence, then search score. The limit is **per paragraph only**, so it doesn't depend on the order the stream runs in, and `allUnderlines` returns exactly what the stream emits. There is no per-page cap in this round: a page is a layout idea the package doesn't know. `UnderlineKnobs` holds the number. **[author's call]** The harness reports underlines per 100 sentences so it can be set from data.

### 5.7 Record

`prepare` also returns, per candidate, a `UnderlineRecord` (`Codable`): sentence, phrase, kind, the candidate indexes sent to the model, the sentence indexes inside every prompt actually sent (pick and confirm), so the spoiler check can run on what the model saw, pick result, confirm result, the path (`model` or `rules`), prompt variant, search mode that actually ran, embedding engine, outcome (kept, or why dropped: `noCandidate`, `pickedNone`, `confirmRejected`, `guardRejected`, `densityLimit`), and timings. The package stores nothing. `UnderlineModelSvc` methods take sentences **with their indexes**, and `UnderlineCtrl` writes those indexes into the record before each call, so a fake model in tests logs them the same way. **[author's call]** Records contain book text and are for local logs and research, never analytics.

## 6. Public API (shape, not final signatures)

```swift
public struct ChapterInput: Sendable { /* as TextEngine, TextEngine spec §6 and §6.1 */ }
public struct IndexedChapter: Sendable, Codable { /* as TextEngine */ }

public enum UnderlineKind: String, Sendable, Codable { case action, reaction, feeling, outcome, place, thing, person }

public struct AnswerPassage: Sendable, Codable {      // same fields as TextEngine and iRead's ContextPassage
    public let sentence: Int, paragraph: Int
    public let range: NSRange                          // within the paragraph, UTF-16
    public let text: String
}

public struct Underline: Sendable, Codable, Identifiable {
    public let sentence: Int
    public let paragraph: Int
    public let range: NSRange                          // the phrase, within the paragraph, UTF-16
    public let text: String
    public let kind: UnderlineKind
    public let reference: AnswerPassage                // always before `sentence`
    public let decidedBy: AnswerPath                   // .model / .rules
}

public struct ChapterUnderlines: Sendable, Codable { public let chapterIndex: Int; public let underlines: [Underline] }

public enum PromptVariant: String, Sendable, Codable { case baseline /* … */ }

public final class UnderlineCtrl: Sendable {
    public init(model: UnderlineModelSvc = .automatic, embedding: EmbeddingSvc = .automatic,
                search: SearchMode = .both, prompt: PromptVariant = .baseline)
    public func prepare(_ chapter: ChapterInput) async -> IndexedChapter
    public func underlines(in chapter: IndexedChapter, startingAt sentence: Int)
        -> AsyncStream<(Underline, UnderlineRecord)>        // reading order from `sentence`, then the rest
    public func allUnderlines(in chapter: IndexedChapter) async -> (ChapterUnderlines, [UnderlineRecord])   // harness and tests
}
```

`UnderlineModelSvc` is a protocol with `UnderlineModelSvcFoundation` and `UnderlineModelSvcUnavailable` (always rules). `EmbeddingSvc` is a protocol with `EmbeddingSvcApple` and `EmbeddingSvcUnavailable`. Tests and the harness can force any of them.

`underlines(in:startingAt:)` takes an `IndexedChapter`, so `prepare` has finished before it is called. It emits underlines in reading order from `startingAt`, then wraps to the start. It stops when its task is cancelled (for example when the reader leaves the chapter). The per-paragraph limit (§5.6) is applied as each paragraph finishes, and the set it emits is the same as `allUnderlines`, whatever the starting sentence. **[author's call]**

### 6.1 Data contract with iRead

Identical to the TextEngine spec §6.1: `ChapterInput` takes iRead's chapter, global paragraph and sentence indexes and UTF-16 ranges. Out: `Underline.range` and `AnswerPassage.range` are within the paragraph (UTF-16), so the app can draw the phrase and `ReadingPosition(paragraph:, charOffset: range.location)` gives the jump target for "Go to this passage". Sentence splitting for the harness's plain text must match `EPUBParseSvc`. iRead splits sentences **inside a paragraph**, so a sentence never crosses a paragraph and a phrase never crosses a sentence: the paragraph-relative `range` is always valid. Quoted speech holding several sentences is split as the parser splits it, and each sentence is checked on its own.

## 7. Repository

### 7.1 Layout (suggested)

```
UnderlineEngine/                      its own package (git repo when the product owner asks)
  Package.swift                       swift-tools-version 6.2; library UnderlineEngine
  README.md                           setup, pipeline, structure table, tuning table, harness (same sections as TextEngine's)
  ARCHITECTURE.md                     layers, suffixes, dependency rule
  .swiftlint.yml, Brewfile            copied from TextEngine
  Sources/UnderlineEngine/
    Models/   ChapterInput, IndexedChapter, Underline, UnderlineKind, AnswerPassage, UnderlineRecord, Candidate
    Rules/    ReadBoundary, SentenceSplitter, EventSplitter, EventRoles, CandidateScorer,
              UnderlineDetector, UnderlineGuard, UnderlineLimiter, RulesPicker, TokenBudget
    Svc/      ChapterIndexSvc, EmbeddingSvc (+Apple, +Unavailable), UnderlineModelSvc (+Foundation, +Unavailable)
    Ctrl/     UnderlineCtrl
  Tests/UnderlineEngineTests/         unit tests (boundary, detector, guards, limiter, ctrl with a fake model)
  Tests/UnderlineEngineEvals/         the harness (§8)
  Dataset/                            little-women-ch1.txt and the golden set (§8.2)
  Eval/results/<kind>/                saved EvaluationResult JSON per run, committed
  docs/superpowers/specs/             this document
```

### 7.2 Code structure (free)

Hard rules: the data contract (§6.1), the public API shape (§6), no imports of iRead or `TextEngine`, no third-party dependencies. Following iRead's layering and `TextEngine`'s conventions (suffix by job, dependencies point down, tuning values in `…Knobs` enums at the top of the file that uses them, `Type+Part.swift` for split types) is the default, since the same people will read both packages. Only the types the app needs are `public`. Names don't clash with the app's.

### 7.3 How iRead uses it (later round, not this round)

Added in `project.yml` as a local package beside `TextEngine`. Only `Analysis/` imports it. The app calls `prepare` when a chapter opens, consumes `underlines(in:startingAt:)` as the reader moves, draws each `Underline.range`, and on tap shows the popover with `reference.text` and a jump link. Underline taps and "this didn't help" (a later idea) are the app's to log.

## 8. Evaluation (harness)

Apple's **Evaluations** framework, in the test target `UnderlineEngineEvals`, as in `TextEngine` (TextEngine spec §8). Plain `swift test` runs the unit tests. The evaluations call the on-device model and run only with a flag. The scaffolding is copied from `TextEngine/Tests/TextEngineEvals` (`EvalRuns`, `Outcome`, `GoldSet`, `GoldenEvaluation`, `SweepEvaluation`, the model judge, result saving), where it already runs under `swift test` on this Mac. The flags become `UNDERLINE_EVALS` and `UNDERLINE_SWEEP`.

### 8.1 Running it

```
swift test                                                                  # unit tests only
UNDERLINE_EVALS=1 swift test --filter goldenEvaluation                      # golden set, model path
UNDERLINE_EVALS=1 swift test --filter rulesBaselineEvaluation               # golden set, rules only
UNDERLINE_EVALS=1 swift test --filter promptComparison                      # golden set × every PromptVariant
UNDERLINE_EVALS=1 swift test --filter searchModeComparison                  # embed vs words vs both
UNDERLINE_EVALS=1 UNDERLINE_SWEEP=1 swift test --filter sweepEvaluation     # every underline in the chapter, for review
```

Results are saved as `EvaluationResult` JSON under `Eval/results/<kind>/` and committed. The run info records prompt variant, search mode, path, judge model, embedding engine and the knobs.

**Model judge.** A `ModelJudgeEvaluator` grades whether a reference explains its phrase under §4.3 (pass or fail, with a rationale). It uses Apple's Private Cloud Compute model when a probe call answers, otherwise the on-device model, and the run info says which (as in `TextEngine`). It is a **different session from the engine's confirm step** and sees the same inputs the reader would. Its agreement with the human labels is printed on every golden run. The spoiler check never depends on a model.

### 8.2 Golden set

Little Women chapter 1 (public domain), cut once into `Dataset/little-women-ch1.txt` as in `TextEngine`. The builder drafts it, **seeded from `TextEngine`'s golden set** (`TextEngine/Dataset/little-women-ch1.json`, 30 items: its answerable items become expected underlines, its not-answerable ones become candidates for `none`), and marks every label **provisional**. The product owner reviews it before tuning starts. That review is a **gate in the plan**: building the package, the unit tests and the harness come first, with numbers reported on the provisional labels, and tuning waits for the review. **[author's call]** Each item has:
- the sentence (index **and** text), and the phrase (an exact substring);
- the expected outcome: **`underline`** with a set of acceptable reference sentence indexes (every one strictly earlier than the sentence), or **`none`** (a phrase that looks underline-worthy but whose explanation is not in the earlier text, or is in the same sentence, or comes later).

Include at least: 8 items for each of `action`, `reaction` and `place/thing`; 4 for `feeling` and `outcome`; 4 for `person`; **at least 10 `none` items**, including 3 where the explanation comes **later** in the chapter (the spoiler trap), 3 where the reason is in the **same sentence**, and 3 where a **tempting wrong passage** exists (shares words, same topic, but doesn't explain it: the mismatch trap); and sentences with **several underline-worthy phrases**, to test density and overlap. Golden items found through the sweep are added by hand over time.

### 8.3 Outcomes

Every golden item gets one outcome, best to worst:

| Outcome | When |
|---|---|
| ✅ **Underlined, right reference** | Expected `underline`, and the engine underlined that phrase with a reference in the acceptable set |
| ✅ **Correctly none** | Expected `none`, and the engine put no underline there |
| ⚠️ **Missed** (safe) | Expected `underline`, but none was made. Always with one cause: **detect miss** (phrase never a candidate), **search miss** (no acceptable sentence among the candidates), **pick miss** (it was there, the model chose none or another), **confirm rejected** (the check threw out a correct pick), **guard rejected**, or **density limit** |
| ❌ **Mismatch** | The engine underlined a phrase with a reference outside the acceptable set, or underlined an expected-`none` phrase. **The failure the product owner named** |
| ⛔ **Spoiler** | Any scored, candidate or prompted sentence with index ≥ the underlined sentence |

The cause of a miss says what to fix: detector words, search weights, the pick prompt, the confirm prompt, or the guards.

### 8.4 Report

Every run prints, from `EvaluationResult.detailed`: (1) a **summary by kind** with a count per outcome; (2) **items, worst first** (⛔, ❌, ⚠️ by cause, then ✅), each with the sentence, the phrase, the reference shown, the expected reference, the candidates sent, the pick quote, the confirm answer, and the model judge's verdict with its rationale; (3) **judge vs human labels**; (4) **changed since last run**.

### 8.5 Sweep (every sentence)

`sweepEvaluation` runs `prepare` and `allUnderlines` on the whole chapter and prints **every underline the engine would show**, with its reference, grouped by chapter position. Nobody has labelled these, so they are not scored against labels. Instead:
- the deterministic **no spoiler** check on candidates and prompts;
- the model judge's **explains / doesn't explain** verdict on every underline, with failures printed first;
- **underlines per 100 sentences**, and the share of sentences with more than one.

The product owner reviews the failures. Good and bad examples are added to the golden set.

### 8.6 Metrics

Each is an `Evaluator` in `GoldenEvaluation` (`.ignore` when it doesn't apply). Means are reported per run, per prompt variant and per search mode.

| Metric | Definition | Target for this round |
|---|---|---|
| **Mismatch rate** | Of underlines shown on the golden set, % that are ❌ (wrong reference, or an underline on a `none` item) | **≤ 5%** (\*), reported first in every run |
| Spoiler leaks | Any scored, candidate or prompted sentence with index ≥ the underlined sentence | **0, hard requirement** |
| Reference precision | Of underlines shown on `underline` items, % with a reference in the acceptable set | ≥ 90% (\*) |
| Underline recall | Of `underline` items, % underlined correctly | Measure as baseline |
| Judge pass rate | Of underlines shown, % the model judge says explain their phrase | Measure; its agreement with the human labels is printed beside it |
| Phrase accuracy | % of shown underlines whose phrase overlaps the golden phrase | Measure |
| Candidate recall | Of `underline` items, % where an acceptable sentence was in the candidates sent to the model, per search mode | Measure; separates search misses from model misses |
| Density | Underlines per 100 sentences, and per paragraph | Report; sets the `UnderlineKnobs` limits |
| Confirm agreement | Of picks the confirm step rejected, % that were actually wrong (human label) | Measure; shows whether confirm earns its cost |
| Latency | Per step and for the whole chapter, p50 and max, **on the Mac** | Report only. **[author's call]** iPad timings are checked in the integration round |

(\*) = starting targets, to be confirmed.

### 8.7 Qualitative analysis CSV

After every run (golden, rules baseline, each prompt variant and search mode, sweep), the harness writes a **CSV next to the saved JSON**, with the same base name (`Eval/results/<kind>/<name>.csv`). It is for reading in Numbers or Excel: **one column per value, one row per example**.

**Rows.** One row for **every phrase the engine considered**, kept or dropped, not only the underlines shown, because the dropped ones explain the misses. On a golden run, a golden item the engine never considered (a detect miss) also gets a row, with the engine columns empty. Rows are sorted worst outcome first (⛔, ❌, ⚠️ by cause, ✅), then by sentence. **[author's call]**

**Columns**, in this order (grouped as in the mockup of 30 Oct 2026):

| Group | Columns |
|---|---|
| Run | `run_id`, `run_kind`, `prompt_variant`, `search_mode`, `gold_id` |
| Original sentence | `sentence`, `paragraph`, `sentence_text`, `sentence_with_underline` (the phrase wrapped in `[[…]]` at its own range), `phrase`, `phrase_range` |
| NLTagger | `tagging_engine`, `words` (`word/lemma/class`, joined by ` · `), `names` (`name (kind)`), `events` (every event of the sentence with its role), `phrase_role`, `kind` |
| Search (harness) | `embedding`, `search_mode_used`, `candidates` (`S<index>:<rawScore>`, best first), `top_candidate_text` |
| Pick and confirm | `path`, `pick`, `picked_sentence`, `pick_quote`, `confirm`, `confirm_evidence` |
| Result | `underlined`, `dropped_reason`, `reference`, `reference_text`, `distance` (sentence − reference) |
| Evaluation | `expected`, `outcome`, `miss_cause`, `judge`, `judge_rationale` (empty on golden rows the judge didn't grade; sweep rows have no `expected` or `outcome`) |
| Timings | `search_ms`, `pick_ms`, `confirm_ms` |
| Your review | `reviewer_verdict`, `reviewer_note`: always empty, for the product owner to fill in |

The values come from the `UnderlineRecord`s, the `IndexedChapter` (words, names, events), the golden set, and the evaluation's outcomes and judge verdicts. The package itself is unchanged: the CSV is written by the harness only. Format: UTF-8 with a byte-order mark (so Excel shows curly quotes correctly), comma-separated, standard quoting (a field with a comma, quote or line break is quoted, inner quotes doubled), a header row. **[author's call]** `run_id`, `phrase_range`, `distance`, the timings and the two review columns were added by the author beyond the product owner's list.

## 9. Decided in the conversation

- The reader **skims**, sees an underlined phrase, reads it, and **taps it**. A **popover shows the earlier original passage** that it refers to.
- **Underline the phrase**, not the whole sentence (mockup option A).
- The underlined thing is an **event**, not only a character.
- Same architecture as `TextEngine`: the same layers, the same iRead data contract, the same read-boundary principle, and an Evaluations harness. A **new package** with a **different user flow** (underlines prepared ahead, no question step).
- **Prompt engineering in Apple Foundation Models, measured by the harness.**
- **The failure to avoid is a popover that doesn't explain the phrase or mismatches the reference.** No underline is better than a wrong one.
- **After every run, a CSV for qualitative analysis:** each value in its own column, one row per example, covering the original sentence with the underline, the NLTagger data, the harness steps, the evaluation, and the reference (§8.7).

## 10. Left to the builder

- Exact cue words, verb lists, search weights, thresholds and density numbers (`UnderlineKnobs`, `SearchKnobs`, `JudgeKnobs`), set with the harness.
- The wording and layout of every prompt variant, and which variants to try beyond `baseline`.
- How the detector decides a phrase is "too short or too general".
- Whether confirm uses the model alone or model plus a rule (such as requiring the quote to share a content word with the phrase), if the harness shows which catches more mismatches.
- Ordering for the progressive stream beyond "from the reader's sentence, then the rest".
- Whether `UnderlineCtrl` is an `actor` or a `final class` with `Sendable` internals.
- How files and types are organised inside the package (§7.2) and the console summary format.
- Splitting the golden set into a tuning half and a check half if over-fitting shows up.

## 11. Open questions

None the product owner must answer before planning. The calls marked **[author's call]** are listed for review: strict `< s` boundary, one reference per underline, a separate confirm step (with a rules equivalent), a self-contained copy of `TextEngine`'s rules, the starting kinds, a per-paragraph density limit and no per-page cap, the stream guarantees, prompt indexes carried in the record, a provisional golden set with a review gate before tuning, and the definition of "done" with one tuning loop and no lowering of the target.

## 12. Future rounds (not this round)

- **App integration:** underline drawing, popover, jump and return, density setting, a way for readers to mark "this didn't help" (§7.3).
- **Cross-chapter references and saved chapter results** (TextEngine spec §12). Saving `ChapterUnderlines` per book, chapter, parser version, prompt variant and embedding engine.
- **Shared core:** extract the code `UnderlineEngine` copied from `TextEngine` into a third package once both are stable.
- **Typed questions beside underlines:** reuse `TextEngine` for readers who want to ask about something that wasn't underlined.
