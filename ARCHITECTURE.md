# UnderlineEngine architecture

A Swift package, no UI. Type suffixes follow iRead's (`EReader/iRead/ARCHITECTURE.md`) and TextEngine's, with only the layers this package needs. Folders follow the pipeline phases, so the reading order shows in the tree. They are one module, so a folder is not a dependency boundary.

## Folders

```
Sources/UnderlineEngine/
  Pipeline/          UnderlineCtrl            the flow starts and ends here: prepare, evaluate a candidate, the chapter, the stream
  1-Preprocessing/   ChapterIndexSvc          NaturalLanguage (sentences, tags, names) + events + embeddings
                     EmbeddingSvc             NLEmbedding (protocol: Apple, Unavailable)
                     SentenceSplitter, EventSplitter, EventRoles, UnderlineDetector
  2-Model/           CandidateScorer          search, before the underlined sentence only
                     UnderlineModelSvc        Foundation Models (protocol: Foundation, Unavailable) + PromptBuilder, TokenBudget
                     RulesPicker              rules pick and confirm, when there is no model
  3-Postprocessing/  UnderlineGuard, UnderlineLimiter
  Shared/            ReadBoundary, TextMatch
                     Models/                  plain data: inputs, indexed chapter, underlines, records
```

## Dependency direction

By type suffix, not by folder:

```
        Ctrl
       /    \
     Svc    Rules
       \    /
       Models
```

## The rule

- Dependencies point down: `Ctrl → Svc → Models`. `Rules` can be called from anywhere.
- A type depends on about 3 things. `UnderlineCtrl` gets `ChapterIndexSvc`, `EmbeddingSvc`, `UnderlineModelSvc`.
- A protocol only when a test needs one: `UnderlineModelSvc` (the scripted fake in tests, the rules path) and `EmbeddingSvc` (words-only search).
- Every sentence a step may use comes through `ReadBoundary.searchable(before:)`. Nothing at or after the underlined sentence is scored, sent to the model, or kept as a reference.
- The model only picks among numbered sentences or confirms one. `UnderlineGuard` checks everything it returns.
- Only the types the app needs are `public`. Names don't clash with iRead's (`IndexedSentence`, not `Sentence`).
- File name = main type; a type split over files uses `Type+Part.swift`. Tuning values live in a `…Knobs` enum at the top of the file that uses them.

## What the suffixes mean

| Suffix | Job |
|---|---|
| `Ctrl` | One use case, orchestrating services and rules. |
| `Svc` | Wraps a framework API (NaturalLanguage, Foundation Models). |
| `Rules` | Pure functions, no state, no I/O. |
| `Models` | Plain data. |

## Main flow

1. `UnderlineCtrl.prepare(ChapterInput)` → `ChapterIndexSvc.prepare` → `IndexedChapter` (sentences, tags, events, vectors).
2. Per paragraph: `UnderlineDetector.candidates` → for each, `UnderlineCtrl.evaluate`: `CandidateScorer.rank(before:)` → `UnderlineSearch.candidates` → `UnderlineModelSvc.pick` → `UnderlineGuard.checkPick` → `UnderlineGuard.isInSameParagraph` → `UnderlineModelSvc.confirm` (or `RulesPicker.decide` / `confirm`) → `UnderlineGuard.paragraphRange`.
3. `UnderlineLimiter.apply` on the paragraph's kept underlines.
4. `paragraphResults(in:startingAt:)` runs the per-paragraph pass from the reader's paragraph, then wraps. The harness runs the same pass on the golden items' paragraphs only (`underlines(paragraphsHolding:in:)`).
