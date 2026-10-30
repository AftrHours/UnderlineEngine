# UnderlineEngine architecture

A Swift package, no UI. Layers follow iRead's (`EReader/iRead/ARCHITECTURE.md`) and TextEngine's, with only the layers this package needs.

## Folders and dependency direction

```
Sources/UnderlineEngine/
  Ctrl/     UnderlineCtrl            the use case: prepare, evaluate a candidate, the chapter, the stream
  Svc/      ChapterIndexSvc          NaturalLanguage (sentences, tags, names) + events + embeddings
            EmbeddingSvc             NLEmbedding (protocol: Apple, Unavailable)
            UnderlineModelSvc        Foundation Models (protocol: Foundation, Unavailable) + PromptBuilder
  Rules/    pure functions           boundary, detector, search, guards, rules pick/confirm, limiter
  Models/   plain data               inputs, indexed chapter, underlines, records
```

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
2. Per paragraph: `UnderlineDetector.candidates` → for each, `UnderlineCtrl.evaluate`: `CandidateScorer.rank(before:)` → `UnderlineSearch.candidates` → `UnderlineModelSvc.pick` → `UnderlineGuard.checkPick` → `UnderlineModelSvc.confirm` (or `RulesPicker.decide` / `confirm`) → `UnderlineGuard.paragraphRange`.
3. `UnderlineLimiter.apply` on the paragraph's kept underlines.
4. `allUnderlines(in:)` loops over paragraphs in order; `underlines(in:startingAt:)` uses the same per-paragraph pass from the reader's paragraph, then wraps.
