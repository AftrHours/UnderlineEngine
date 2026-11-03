# UnderlineEngine

A Swift package for iRead. When a chapter opens, it finds the phrases a skimming reader may not follow (events such as "began to whistle", places, things, people) and underlines each one only if it can point to **the author's own earlier sentence that explains it**. Tapping an underline shows that passage. It never writes an explanation, never uses text at or after the underlined sentence, and runs on-device only (NaturalLanguage and Foundation Models).

It is the underline sibling of [TextEngine](../TextEngine): same type suffixes, same iRead data contract, a different flow (no question step). Its folders follow the pipeline phases instead of layers, so the reading order shows in the tree.

Design: [docs/superpowers/specs/2026-10-30-underline-engine-design.md](docs/superpowers/specs/2026-10-30-underline-engine-design.md) · Build plan: [docs/superpowers/plans/2026-10-30-underline-engine.md](docs/superpowers/plans/2026-10-30-underline-engine.md)

### Setup
- `brew bundle` (SwiftLint), then `swift build` and `swift test`.
- Swift 6.2 tools, iOS 26 and macOS 26. No third-party packages. Imports neither iRead nor TextEngine.
- Real numbers need Apple's English language models and Apple Intelligence: run on a Mac or an iPad, not the Simulator. Without them the rules path runs.

### Pipeline
Data in and out match iRead's `BookContent` (global paragraph and sentence indexes, UTF-16 ranges; spec §6.1).

1. **Prepare** (`UnderlineCtrl.prepare`, once per chapter): split sentences exactly like iRead's parser, tag words (`NLTagger`), split each sentence into events with a causal role, embed every sentence (`NLEmbedding`).
2. **Detect** (`UnderlineDetector`): each sentence's events and person names, minus short or general phrases, reasons given in the same sentence ("…because…"), and names seen in the last 20 sentences.
3. **Search** (`CandidateScorer`, `UnderlineSearch`): ranks only sentences **before** the underlined one (`ReadBoundary`), meaning first, shared words second, plus role links and nearness. Below a floor (`minRawScore`) the phrase is dropped before any model call.
4. **Pick** (Foundation Models): the model picks one numbered candidate, quoting it first. `UnderlineGuard` rejects a number not offered, a sentence not earlier, or a quote not in the pick.
5. **Confirm** (Foundation Models, a separate session): sees only the phrase, its sentence and the one picked passage, and says whether it explains the phrase. Both must agree. Without a model, `RulesPicker` picks and confirms (shared word, same name, or role link).
6. **Limit** (`UnderlineLimiter`): at most `maxPerParagraph` per paragraph, best first, never overlapping.

`allUnderlines(in:)` returns every underline and a `UnderlineRecord` for every phrase considered (kept or dropped). `underlines(in:startingAt:)` streams them from the reader's paragraph, then wraps; it gives the same set. `paragraphResults(in:startingAt:)` streams the same paragraphs with every record, so an app can show why a phrase was dropped. Records contain book text: local logs only, never analytics.

### Structure
| Folder | What's in it |
|---|---|
| `Sources/UnderlineEngine/Pipeline` | `UnderlineCtrl`, where the flow starts and ends: prepare, one candidate (`+Evaluate`), the chapter and the stream (`+Chapter`) |
| `Sources/UnderlineEngine/1-Preprocessing` | Prepare and Detect: `ChapterIndexSvc` (NaturalLanguage), `EmbeddingSvc`, `SentenceSplitter`, `EventSplitter`, `EventRoles`, `UnderlineDetector` |
| `Sources/UnderlineEngine/2-Model` | Search, Pick and Confirm: `CandidateScorer`, `UnderlineModelSvc` (Foundation Models), `PromptBuilder`, `RulesPicker`, `TokenBudget` |
| `Sources/UnderlineEngine/3-Postprocessing` | Guards and Limit: `UnderlineGuard`, `UnderlineLimiter` |
| `Sources/UnderlineEngine/Shared` | `ReadBoundary`, `TextMatch`, and `Models/`: `ChapterInput`, `IndexedChapter`, `EventPhrase`, `Underline`, `UnderlineKind`, `ChapterUnderlines`, `PromptVariant`, `UnderlineRecord`, `AnswerPassage`, `Candidate`, `KnobSnapshot` |
| `Tests/UnderlineEngineTests` | Unit tests, with a scripted `FakeUnderlineModel` |
| `Tests/UnderlineEngineEvals` | The harness (Apple Evaluations) and the qualitative CSV |
| `Dataset/` | Little Women chapter 1 and the golden set `underline-gold.json` |
| `Eval/results/` | Saved `EvaluationResult` JSON and a CSV per run |

### Tuning
Knobs sit at the top of the file that uses them. Change a value, run the harness, read the report.

| Knobs | File | Tunes |
|---|---|---|
| `EventKnobs` | `1-Preprocessing/EventSplitter.swift` | speech verbs, reaction cues, emotion/want/result/state verbs, place and time words |
| `UnderlineKnobs` | `1-Preprocessing/UnderlineDetector.swift` | `minPhraseWords`, `generalWords`, `nameGapSentences`, `maxPerParagraph`, `kindOrder` |
| `SearchKnobs` | `2-Model/CandidateScorer.swift` | `embedWeight`, `wordsWeight`, bonuses, role links, `maxCandidates`, `minRawScore` |
| `JudgeKnobs` | `2-Model/RulesPicker.swift` | rules-pick thresholds per search mode |
| `ModelKnobs` | `2-Model/UnderlineModelSvcFoundation.swift` | the "explains" definition, pick and confirm instructions per `PromptVariant`, sampling, candidate length |

### Harness (Apple Evaluations)
The `UnderlineEngineEvals` test target, on Apple's **Evaluations** framework (Xcode 27, macOS 27). Plain `swift test` runs only the unit tests; the evaluations call the on-device model and need a flag:
```
UNDERLINE_EVALS=1 swift test --filter goldenEvaluation          # golden set, model path
UNDERLINE_EVALS=1 swift test --filter rulesBaselineEvaluation   # golden set, rules only
UNDERLINE_EVALS=1 swift test --filter promptComparison          # golden set × every PromptVariant
UNDERLINE_EVALS=1 swift test --filter searchModeComparison      # embed vs words vs both
UNDERLINE_EVALS=1 UNDERLINE_SWEEP=1 swift test --filter sweepEvaluation   # every underline in the chapter (UNDERLINE_SWEEP_LIMIT=60 for the first 60 sentences)
```
- **Golden set:** `Dataset/underline-gold.json` (67 items, provisional until the product owner reviews them). Each item is a phrase in a sentence with either the acceptable earlier references or `none` with a reason (`explanationLater`, `sameSentence`, `temptingWrongPassage`, `noExplanation`).
- **Outcomes:** ⛔ spoiler, ❌ mismatch, ⚠️ missed (detect, search, pick, confirm, guard or density), ✅ underlined with the right reference, ✅ correctly none. The **mismatch rate** (of underlines shown, how many point at the wrong passage) comes first in every report.
- **Model judge:** a `ModelJudgeEvaluator` grades whether each shown reference explains its phrase (Private Cloud Compute when it answers, otherwise the on-device model). Its agreement with the human labels is printed. The spoiler check never depends on a model.
- **Output:** the report (headline numbers, summary by kind, items worst first, judge agreement, changes since the last run) and the full `EvaluationResult` under `Eval/results/<kind>/`.

### Qualitative analysis CSV
Every run also writes a CSV next to its saved result (`Eval/results/<kind>/<name>.csv`), for Numbers or Excel: one row per phrase the engine considered (kept or dropped), plus one per golden item it never considered, worst outcome first. Columns, in groups (spec §8.7): run · original sentence (with the phrase in `[[…]]`) · NLTagger (words as `word/lemma/class`, names, events with roles, kind) · search (candidates with scores) · pick and confirm · result (the reference and its distance) · evaluation (expected, outcome, miss cause, judge) · timings · **`reviewer_verdict` and `reviewer_note`, empty for you to fill in**. UTF-8 with a byte-order mark, so curly quotes show correctly in Excel.
