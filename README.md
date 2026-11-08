# UnderlineEngine v1.0.0

A Swift package for iRead. When a chapter opens, it finds the phrases a skimming reader may not follow (events such as "began to whistle", places, things, people) and underlines each one only if it can point to **the author's own earlier sentence that explains it**. Tapping an underline shows that passage. It never writes an explanation, never uses text at or after the underlined sentence, and runs on-device only (NaturalLanguage and Foundation Models).

It is the underline sibling of [TextEngine](../TextEngine): same type suffixes, same iRead data contract, a different flow (no question step). Its folders are numbered after the processes in [docs/DFD.md](docs/DFD.md) instead of layers, so the reading order shows in the tree.

Design: [docs/superpowers/specs/2026-10-30-underline-engine-design.md](docs/superpowers/specs/2026-10-30-underline-engine-design.md) · Build plan: [docs/superpowers/plans/2026-10-30-underline-engine.md](docs/superpowers/plans/2026-10-30-underline-engine.md) · Data flow: [docs/DFD.md](docs/DFD.md) · Types: [ARCHITECTURE.md](ARCHITECTURE.md)

### Start reading here
New to the code? Read in this order. The numbers are the processes in [docs/DFD.md](docs/DFD.md), which has a diagram and a step → code table for each.

1. **The public API:** [`UnderlineCtrl.swift`](Sources/UnderlineEngine/Pipeline/UnderlineCtrl.swift). `prepare` is process 1; the rest are in the two files below.
2. **One paragraph:** `pass` in [`UnderlineCtrl+Chapter.swift`](Sources/UnderlineEngine/Pipeline/UnderlineCtrl+Chapter.swift). It runs process 2 for each sentence, `evaluate` for each phrase, then process 5 (`limit`).
3. **One phrase:** `evaluate` in [`UnderlineCtrl+Evaluate.swift`](Sources/UnderlineEngine/Pipeline/UnderlineCtrl+Evaluate.swift). Process 3 (search) then process 4 (pick, guard, confirm, or the rules path).
4. **The data:** [`Shared/Models/`](Sources/UnderlineEngine/Shared/Models). `ChapterInput/` holds what goes in and the prepared chapter; `UnderlineModels.swift` and `UnderlineRecord.swift` hold what comes out.
5. **One process in depth:** open the file the DFD step table names, starting from its `…Knobs` enum at the top.

Two names look alike: `UnderlineCandidate` is a **phrase** that may get underlined (process 2); `Candidate` is an **earlier sentence** that may explain it (process 3).

### Setup
- `brew bundle` (SwiftLint), then `swift build` and `swift test`.
- Swift 6.2 tools, iOS 26 and macOS 26. No third-party packages. Imports neither iRead nor TextEngine.
- Real numbers need Apple's English language models and Apple Intelligence: run on a Mac or an iPad, not the Simulator. Without them the rules path runs.

### Pipeline
Data in and out match iRead's `BookContent` (global paragraph and sentence indexes, UTF-16 ranges; spec §6.1).

1. **Prepare** (`UnderlineCtrl.prepare`, once per chapter): check the sentences iRead sends, tag words (`NLTagger`), split each sentence into events with a causal role, embed every sentence (`NLEmbedding`). iRead splits the sentences; the harness uses `ChapterInput(plainText:)`, which splits them the same way.
2. **Detect** (`UnderlineDetector`): each sentence's events and person names, minus short or general phrases, reasons given in the same sentence ("…because…"), and names seen in the last 30 sentences (`nameGapSentences`).
3. **Search** (`CandidateScorer`, `UnderlineSearch`): ranks only sentences **before** the underlined one (`ReadBoundary`), meaning first, shared words second, plus role links and nearness. Below a floor (`minRawScore`) the phrase is dropped before any model call.
4. **Pick and confirm** (Foundation Models, one call per phrase): take search's top candidate. If it is in the phrase's own paragraph the phrase is dropped, because the reader has just read it. Otherwise the model sees only the phrase, its sentence and that one passage, and says whether it explains the phrase. Without a model, `RulesPicker` picks and confirms (shared word, same name, or role link).
5. **Limit** (`UnderlineLimiter`): at most `maxPerParagraph` per paragraph, best first, never overlapping.

`paragraphResults(in:startingAt:)` streams one result per paragraph from the reader's paragraph, then wraps: its underlines and a `UnderlineRecord` for every phrase considered (kept or dropped), so an app can show why a phrase was dropped. Records contain book text: local logs only, never analytics.

### Structure
| Folder | What's in it |
|---|---|
| `Sources/UnderlineEngine/Pipeline` | `UnderlineCtrl`, where the flow starts and ends: prepare, one candidate (`+Evaluate`), the chapter and the stream (`+Chapter`) |
| `Sources/UnderlineEngine/1-Prepare` | DFD process 1: `ChapterIndexSvc` (NaturalLanguage), `EmbeddingSvc`, `SentenceSplitter`, `EventSplitter`, `EventRoles` |
| `Sources/UnderlineEngine/2-Detect` | DFD process 2: `UnderlineDetector` |
| `Sources/UnderlineEngine/3-Search` | DFD process 3: `CandidateScorer`, `UnderlineSearch` |
| `Sources/UnderlineEngine/4-PickConfirm` | DFD process 4: `UnderlineModelSvc` (Foundation Models), `PromptBuilder`, `UnderlineGuard`, `RulesPicker` |
| `Sources/UnderlineEngine/5-Limit` | DFD process 5: `UnderlineLimiter` |
| `Sources/UnderlineEngine/Shared` | `ReadBoundary` and `Models/`: `ChapterInput`, `IndexedChapter`, `EventPhrase`, `Underline`, `UnderlineKind`, `ChapterUnderlines`, `UnderlineRecord`, `AnswerPassage`, `Candidate`, `KnobSnapshot` |
| `Tests/UnderlineEngineTests` | Unit tests, with a scripted `FakeUnderlineModel` |
| `Tests/UnderlineEngineEvals` | The harness (Apple Evaluations) and the qualitative report |
| `Dataset/` | Little Women chapter 1 and the golden set `underline-gold.json` |
| `Eval/results/` | Saved `EvaluationResult` JSON and a Markdown report per run. Created by the harness on your machine and ignored by git |

### Tuning
Knobs sit at the top of the file that uses them. Change a value, run the harness, read the report.

| Knobs | File | Tunes |
|---|---|---|
| `EventKnobs` | `1-Prepare/EventSplitter.swift` | speech verbs, reaction cues, emotion/want/result/state verbs, place and time words |
| `UnderlineKnobs` | `2-Detect/UnderlineDetector.swift` | `minPhraseWords`, `generalWords`, `nameGapSentences`, `maxPerParagraph`, `kindOrder` |
| `SearchKnobs` | `3-Search/CandidateScorer.swift` | `embedWeight`, `wordsWeight`, bonuses, role links, `maxCandidates`, `minRawScore` |
| `JudgeKnobs` | `4-PickConfirm/RulesPicker.swift` | rules-pick thresholds per search mode |
| `ModelKnobs` | `4-PickConfirm/UnderlineModelSvcFoundation.swift` | the "explains" definition, confirm instructions, sampling, passage length |

### Harness (Apple Evaluations)
The `UnderlineEngineEvals` test target, on Apple's **Evaluations** framework (Xcode 27, macOS 27). Plain `swift test` runs only the unit tests; the evaluations call the on-device model and need a flag:
```
UNDERLINE_EVALS=1 swift test --filter goldenEvaluation          # golden set, model path
UNDERLINE_EVALS=1 swift test --filter rulesBaselineEvaluation   # golden set, rules only
UNDERLINE_EVALS=1 swift test --filter searchModeComparison      # embed vs words vs both (the app always uses both)
UNDERLINE_EVALS=1 UNDERLINE_SWEEP=1 swift test --filter sweepEvaluation   # every underline in the chapter (UNDERLINE_SWEEP_LIMIT=60 for the first 60 sentences)
```
- **Golden set:** `Dataset/underline-gold.json` (67 items, provisional until the product owner reviews them). Each item is a phrase in a sentence with either the acceptable earlier references or `none` with a reason (`explanationLater`, `sameSentence`, `temptingWrongPassage`, `noExplanation`).
- **Outcomes:** ⛔ spoiler, ❌ mismatch, ⚠️ missed (detect, search, pick, confirm, guard, density or explained in paragraph), ✅ underlined with the right reference, ✅ correctly none. The **mismatch rate** (of underlines shown, how many point at the wrong passage) comes first in every report.
- **Model judge:** a `ModelJudgeEvaluator` grades whether each shown reference explains its phrase (Private Cloud Compute when it answers, otherwise the on-device model). Its agreement with the human labels is printed. The spoiler check never depends on a model.
- **Output:** the report (headline numbers, summary by kind, items worst first, judge agreement, changes since the last run) and the full `EvaluationResult` under `Eval/results/<kind>/`.

### Qualitative report
Every run also writes a Markdown report next to its saved result (`Eval/results/<kind>/<name>.md`), worst first (spec §8.7):

- **Summary:** phrases considered, underlines shown, judge pass and fail, golden outcomes (golden runs only), and phrases not underlined by reason.
- **Underlined:** one section per underline shown. The sentence with the phrase in bold, the reference and its distance, kind and role, candidates with scores, the confirm evidence, the judge's verdict, timings, and the NLTagger output (folded). Each ends with boxes to tick (`right`, `wrong passage`, `shouldn't be underlined`) and a `Note:` line for your review.
- **Not underlined:** a table of every other phrase with its reason and top candidate, plus expected and outcome on golden runs.

Nothing reads the ticks back; the report is for reading and reviewing by hand.
