# Retrieval stages 3 and 5 (moved out of the engine, 2026-11-22)

Stages of the clean retrieval pipeline that were built and measured, and did not raise retrieval recall on Little Women
(Recall@6, words only: 60.1%; with entities 60.0%; with roles 59.7–59.9%). See `docs/result.md`, "Retrieval recall".
They are kept here, outside the package, so the engine holds only what the next method uses. SwiftPM doesn't compile this folder.

| File | What it is | Was in |
|---|---|---|
| `EntityResolver.swift` | Stage 3, entities: book-wide person names, "Jo March" → Jo, gender from pronouns, he/she → last person of that gender | `Sources/UnderlineEngine/1-Prepare/` |
| `RoleLabeler.swift` | Stage 5, roles (semantic role labeling, rules): agent · predicate · patient · location per clause, and role-pair tokens | `Sources/UnderlineEngine/1-Prepare/` |
| `EntityResolverTests.swift`, `RoleLabelerTests.swift` | their unit tests | `Tests/UnderlineEngineTests/` |
| `RetrievalRecall+stages.swift` | the recall test with the stage 3 and 5 rankings | `Tests/UnderlineEngineEvals/RetrievalRecall.swift` |

To bring them back: copy the two sources and two tests to where they were, and replace `Tests/UnderlineEngineEvals/RetrievalRecall.swift`
with `RetrievalRecall+stages.swift` (rename it back). `RoleLabeler` uses `EventKnobs.modals` and `EventSplitter`'s events from the engine.
