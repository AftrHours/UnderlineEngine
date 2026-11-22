# UnderlineEngine: the modular design

Goal: an app gives the engine a book and gets back underlines with the passage each one points to. Nothing else crosses the line,
so a new method (a new embedding, tracks removed, key-point linking, cross-chapter search) is built, measured and released in this
package, and the app only moves its version pin.

```
App (iRead)                              UnderlineKit (the door)              UnderlineEngine (inside)
───────────                              ───────────────────────              ────────────────────────
UnderlineRepo ──depends on──► protocol Underlining ◄──implements── Underliner ──runs one──► protocol LinkMethod
 (save / iCloud only)           underlines(inChapter:of:startingAt:)                          ├─ Linker        (released)
                                version, summary                                              ├─ KeyPointLinker  (idea, not built)
AppContainer injects:                                                                         └─ …
 • Underliner.make(.release)  in the app                                       each method is built from the stages
 • StubUnderliner             in tests                                         Prepare → Detect → Search → Pick/Confirm → Limit
```

## What crosses the door

| Direction | Type | Notes |
|---|---|---|
| in | `BookSource` (protocol), `BookText` (value for tests) | plain text with the app's paragraph and sentence numbers; the app's book type conforms, nothing is copied up front |
| out | `UnderlineBatch` → `[UnderlineResult]` + `[ConsideredPhrase]` | one batch per paragraph, reader's paragraph first |
| out | `version`, `summary` | the app saves `version` with each chapter; `summary` is one line for a debug sheet |

`UnderlineResult` is **frozen**: `id, sentence, paragraph, range, text, kind, decidedBy, reference{sentence, paragraph, range, text}`.
These are the fields iRead keeps on disk and in iCloud. They are never renamed, retyped or removed; a field a method no longer fills
keeps a fixed value. `FrozenShapeTests` checks the field names and reads a real saved underline.

## SOLID, as used here

| | How |
|---|---|
| **S** | The app's repo only saves, loads and syncs. `Underliner` only runs a method. Each pipeline stage keeps one job. |
| **O** | A new method is a new type that conforms to `LinkMethod`. `Underliner`, the door and the app do not change. |
| **L** | Every method keeps the same promises, checked by one shared contract (`ContractTests`): references are earlier sentences in the same chapter, texts sit at their ranges, ids are unique, same input gives same output, empty chapters give nothing, results start at the reader's paragraph. A second, unrelated test method passes the same contract. |
| **I** | The app sees `Underlining`: one function and two read-only values. Records, scores and the book run's types stay behind it. |
| **D** | The app depends on the `Underlining` protocol; `AppContainer` injects `Underliner` or `StubUnderliner`. Inside, methods depend on `EmbeddingSvc` and `UnderlineModelSvc` protocols, as before. |

Not done on purpose: a protocol for every helper, a plugin system, dynamic loading. There are two seams, `Underlining` (app ↔ engine)
and `LinkMethod` (engine ↔ methods).

## Versions

`LinkMethod.version` is saved with every chapter. When a method's output changes, raise it (R8 is 5; the next method that changes the
output takes 6) and every chapter saved by an older one is worked out again, with no change in the app. Never lower it.
A new method ships as `.release` only after it has been measured against R8 on the books in `Dataset/` and reviewed.

## What is not done yet

1. The engine's old `public` API (`UnderlineCtrl`, `ChapterInput`, `UnderlineRecord`, …) is still public, so 1.2.0 apps keep building.
   It becomes `package` in a later release, once the app uses only `UnderlineKit`. Until then the door is a convention the compiler
   does not yet enforce.
2. Done in iRead on `Engine-kit` (`7052b3d`): iRead talks to `Underlining`, and `ModelCheckSvc` is gone.
3. Done: the book run (`bookRun`) runs a `LinkMethod` the way `Underliner` does for the app: the book goes in as a `BookSource`,
   each chapter through `Underliner.input`, then `prepare(_:ofBook:chapters:)` and `results(in:startingAt:)`. The method is chosen
   by name (`UNDERLINE_METHOD`, default `r8`); a new method is added to `BookRunMethods` to be measured like R8. Only the sentence
   numbering differs (each chapter from 0, so the labels keep matching), and `sentenceNumberingDoesNotChangeTheUnderlines` checks
   that this changes no underline.
