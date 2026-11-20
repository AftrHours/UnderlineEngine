# UnderlineEngine: experiment results

One row per full-book run. Every run was produced by the `bookRun` harness on this Mac (Apple silicon), on Project Gutenberg texts of *Little Women* and *Pride and Prejudice*. Right / partial / wrong are **Claude's verdicts**, not ground truth (see Notes).

## Data

| Book | Chapters | Paragraphs | Sentences | Words | Phrases evaluated |
|---|---|---|---|---|---|
| Little Women | 47 | 3,798 | 9,617 | 185,663 | 18,718 (20,087 before the 3-word rule) |
| Pride and Prejudice | 61 | 2,059 | 6,024 | 121,553 | 11,535 |
| Before the Coffee Gets Cold (Kawaguchi, English translation; local copy, not committed) | 4 | 2,415 | 5,237 | 55,506 | 5,797 |
| The Hobbit (Tolkien; local copy, not committed) | 19 | 1,852 | 6,124 | 95,176 | 9,142 |
| The Adventures of Sherlock Holmes | 12 stories | 2,523 | 6,887 | 104,348 | 9,767 |
| Sunrise on the Reaping (Collins; local copy, not committed) | 28 (27 + epilogue) | 3,040 | 10,861 | 112,751 | 11,572 |

Datasets: `Dataset/little-women/`, `Dataset/pride-and-prejudice/` (built by `Dataset/epub_to_chapters.py`). Verdicts: `Dataset/labels/claude-labels.csv` (Little Women, 2,536 pairs) `claude-labels-pride-and-prejudice.csv` (352 pairs) `claude-labels-before-the-coffee-gets-cold.csv` (502 pairs) and `claude-labels-the-hobbit.csv` (469 pairs); the last two are local only because they contain copyrighted excerpts. A verdict is keyed by chapter, sentence, phrase and reference, so the same pair is reused across runs.

## Target

The goal is the **Sherlock Holmes seed that Claude made by hand** for iRead (`EReader/iRead/App/Resources/UnderlineSeed/048b…`, row HS below). It is what a careful reader would underline: scene-specific clues ("Black Jack of Ballarat" → "So and so, of Ballarat", "the speckled band" → Julia's dying words, "the twelve-mile drive" → "only seven miles"), not repeated everyday phrases.

| Measure | Target (HS, hand seed) | R8 (R17, current) | R8 + evidence by distance (R18, not adopted) | Gap (current) |
|---|---|---|---|---|
| Precision (right ÷ links) | **95%** (aim ≥ 90%) | 54.6% | 74.0% | −40 points |
| Wrong links | 2 of 516 (0.4%) | 290 of 857 (34%) | 58 of 381 (15%) | 288 too many |
| Right links per 1,000 words | 4.7 | 4.5 | 2.7 | about equal |
| All links per 1,000 words | 4.9 | 8.2 | 3.7 | +3.3 (noise) |
| Overlap with the target | 516 | 50 identical pairs | 25 identical pairs | 466 target links missed |

So R8 already finds about as many right links as the target, but different ones, and buries them under word echoes. Closing the gap means two things, in this order:

1. **Drop the echoes**: confirm that the phrase and the reference describe the same event or clue, not only that they share a rare word (see the three kinds of wrong links in `Eval/results/book-the-adventures-of-sherlock-holmes-rules-contextual/wrong-underlines.md`).
2. **Pick the links a reader would ask about**: prefer clue-like phrases (names of things, places, objects, numbers) over generic actions, so the overlap with the target rises.

**Step 1 tried (R18–R21).** A true event check (same character in both sentences, same verb) did not separate right from wrong links: same character 52% right vs 54% without. What did is distance: a link within 20 sentences is 72% right, one more than 100 sentences back only 30–38%, unless it shares several rare words. So the confirm now asks for more shared evidence the further back the reference is (`JudgeKnobs.evidenceByDistance`). Precision rose on every book (Sherlock 55 → 74%, Little Women 52 → 68%, Hobbit 61 → 77%, Coffee 49 → 70%) and wrong links fell 70–80%, but it also removed about 40% of the right links and half of the links shared with the target. The rule was tuned on the same verdicts it is scored on, so these gains are optimistic. **Not adopted (2026-11-20):** it drops too many right underlines; the engine stays on R8. Next: step 2, finding the clue-like links the target has and the engine misses, so the count of right links rises instead of falling.

Caveat: the target was reviewed by Claude, who also made it, so 95% is likely optimistic. Verdicts: `Dataset/labels/claude-labels-sherlock-hand-seed.csv`. Right links per 1,000 words for R8 on the other books: Little Women 2.3, The Hobbit 3.4, Before the Coffee Gets Cold 4.8.

## Results

Right / partial / wrong count the run's underlines. **Every run is fully reviewed**: each underline in every run has a verdict, so every precision below is exact (precision = right ÷ underlines; partial counts as not right).

| Run | Book | Method | Parameters (change from the previous run) | Underlines | Right | Partial | Wrong | Reviewed | Precision |
|---|---|---|---|---|---|---|---|---|---|
| R1 | Little Women | Rules · NLEmbedding · unweighted shared words | minScore 0.70 · margin 0.05 · old confirm (shared content word or role link) · names 1+ words (30-sentence gap) · 1 per paragraph · no word statistics | 986 | 364 | 97 | 525 | 986 (all) | **36.9%** exact |
| R2 | Little Women | R1 + IDF | R1 + IDF word weights (`ln(1+N/df)`), book-level statistics | 485 | 280 | 39 | 166 | 485 (all) | **57.7%** exact |
| R3 | Little Women | R2 + rare-word confirm + stub ban | R2 + confirm: rare noun/adjective (≤ 0.85%), two rare lemmas, or same name · references of ≤ 3 tokens or a speech tag dropped | 367 | 235 | 24 | 108 | 367 (all) | **64.0%** exact (includes name-only links) |
| R5 | Little Women | R3 + 3-word minimum, NLEmbedding | R3 + `minPhraseWords` 3 for names | 271 | 153 | 24 | 94 | 271 (all) | **56.5%** exact |
| R6 | Little Women | R5 with NLContextual | R5 + NLC (mean-pooled tokens, centred on 1/5 of the book, scale 0.703 / 0.295) | 349 | 206 | 39 | 104 | 349 (all) | **59.0%** exact |
| R7 | Little Women | R6 + knobs from the parameter sweep | minScore 0.60 · rare share 0.4% | 684 | 360 | 106 | 218 | 684 (all) | **52.6%** exact |
| R8 | Little Women | R7 without the paragraph cap ← **current** | `maxPerParagraph` unlimited (overlaps still prevented) | 831 | 432 | 129 | 270 | 831 (all) | **52.0%** exact |
| R9 | Little Women | R8 + time/place/body word list (removed) | ]~80 setting words cannot confirm on their own | 782 | 423 | 126 | 233 | 782 (all) | **54.1%** exact |
| R10 | Little Women | R8 + phrase vector read in its full sentence (removed) | query vector = phrase tokens from the whole-sentence embedding | 1,064 | 470 | 186 | 408 | 1,064 (all) | **44.2%** exact; worse than R8 at 28% more underlines |
| R11 | Little Women | R8 + in-context word sense check (removed) | `minWordSense` 0.85 (cosine of the shared rare word's in-context vectors) | 768 | 412 | 125 | 231 | 768 (all) | **53.6%** exact |
| R12 | Pride and Prejudice | R11 configuration on a second book | identical to R11, no tuning | 352 | 210 | 60 | 82 | 352 (all) | **59.7%** exact |
| R13 | Before the Coffee Gets Cold | R11 configuration on a modern translated novel | identical to R11, no tuning | 502 | 253 | 91 | 158 | 502 (all) | **50.4%** exact |
| R15 | Before the Coffee Gets Cold | **R8 configuration (current)** | R13 without the sense check | 549 | 266 | 95 | 188 | 549 (all) | **48.5%** exact |
| RC | Before the Coffee Gets Cold | **Release 1.1.0 engine as the app runs it** | as RH | 1,289 | 455 | 217 | 617 | 1,289 (all) | **35.3%** exact |
| R14 | The Hobbit | R11 configuration on a fantasy novel | identical to R11, no tuning | 469 | 291 | 78 | 100 | 469 (all) | **62.0%** exact |
| R16 | The Hobbit | **R8 configuration (current)** | R14 without the sense check | 525 | 319 | 86 | 120 | 525 (all) | **60.8%** exact |
| RH | The Hobbit | **Release 1.1.0 engine as the app runs it**: Foundation Models confirm, NLEmbedding, per-chapter search | no IDF · no word statistics · names 1+ words · 1 per paragraph · model confirms the top candidate | 1,009 | 365 | 172 | 472 | 1,009 (all) | **36.2%** exact |
| R17 | The Adventures of Sherlock Holmes | **R8 configuration (current)** on a story collection | identical to R8, no tuning; compared with the iRead seed Claude made by hand (516 links) | 857 | 468 | 99 | 290 | 857 (all) | **54.6%** exact; 50 links identical to the hand seed |
| HS | The Adventures of Sherlock Holmes | **iRead seed made by hand by Claude** (not an engine run) | 516 links chosen while reading; 15 are shorter than 3 words | 516 | 492 | 22 | 2 | 516 (all) | **95.3%** (reviewed by Claude, who also made it, so likely optimistic) |
| R18 | The Adventures of Sherlock Holmes | R8 + evidence scaled by distance (tried, not adopted) | a reference < 20 sentences back needs 1 point, < 100 needs 2, older needs 3; 1 point per shared rare lemma, +1 for any shared ordinary content word | 381 | 282 | 41 | 58 | 381 (all) | **74.0%** exact; 25 links identical to the hand seed |
| R19 | Little Women | same as R18 | identical | 435 | 294 | 58 | 83 | 435 (all) | **67.6%** exact |
| R20 | The Hobbit | same as R18 | identical | 292 | 224 | 35 | 33 | 292 (all) | **76.7%** exact |
| R21 | Before the Coffee Gets Cold | same as R18 | identical | 208 | 146 | 30 | 32 | 208 (all) | **70.2%** exact |
| R22 | The Adventures of Sherlock Holmes | **R8 without the underline kind and Zwaan's event-indexing tracks** (best measured; reverted for the release, see Notes) | removed: `UnderlineKind`, `Track`, the track-hint bonus (place / time / goal words) and the cause-nearby bonus; a name still searches only sentences that mention it | 871 | 479 | 99 | 293 | 871 (all) | **55.0%** exact (R8: 54.6%) |
| R23 | Little Women | same as R22 | identical | 851 | 451 | 130 | 270 | 851 (all) | **53.0%** exact (R8: 51.6%) |
| R24 | The Hobbit | same as R22 | identical | 535 | 329 | 86 | 120 | 535 (all) | **61.5%** exact (R8: 60.8%) |
| R25 | Before the Coffee Gets Cold | same as R22 | identical | 537 | 264 | 87 | 186 | 537 (all) | **49.2%** exact (R8: 48.5%) |
| R26 | Sunrise on the Reaping | same as R22 | identical, no tuning; compared with links Claude hand-picked for the whole book (HP, 2,655 links) | 812 | 344 | 198 | 270 | 812 (all) | **42.4%** exact; 111 links identical to the hand-pick, 206 more on a hand-picked phrase with a different reference |
| HP | Sunrise on the Reaping | **Links hand-picked by Claude while reading** (not an engine run) | every chapter read in full; each link = phrase + earlier sentence in the same chapter, text-checked | 2,655 | – | – | – | – | not reviewed (used as the reference set, not scored) |
| R27 | Before the Coffee Gets Cold | R8 + **cross-chapter search** (tried, not adopted) | search, pick and confirm read every earlier chapter too (`earlier:`), sentences numbered across the book; otherwise R8 | 653 | 251 | 85 | 317 | 653 (all) | **38.4%** exact (R8: 48.5%); 311 links into an earlier chapter, 19.3% right |
| R28 | The Hobbit | same as R27 | identical | 851 | 231 | 103 | 517 | 851 (all) | **27.1%** exact (R8: 60.8%); 571 into an earlier chapter, 8.1% right |
| R29 | The Adventures of Sherlock Holmes | same as R27 | identical | 1,240 | 316 | 87 | 837 | 1,240 (all) | **25.5%** exact (R8: 54.6%); 761 into an earlier chapter, 0.7% right |


### Ablation: main versions

Each row changes one stage from the row above it. Precision = right ÷ underlines (Claude's verdicts); "–" = not run on that book.

| Version | Method | Parameters | Sherlock | Little Women | Hobbit | Coffee | Sunrise |
|---|---|---|---|---|---|---|---|
| **Release 1.1.0** (in the app today) | Foundation Models confirm · NLEmbedding · per-chapter search | no IDF · no word statistics · names 1+ words · 1 underline per paragraph · the model confirms the top candidate | – | – | 36.2% (RH) | 35.3% (RC) | running |
| **R8** (current, release candidate) | Rules confirm · NLContextualEmbedding · IDF word weights · book-level word statistics | score = 0.65 meaning + 0.35 shared rare words · floor 0.35 · top 6 · pick at 0.60, margin 0.05 · confirm needs a shared rare noun/adjective (≤ 0.4% of sentences), 2 rare lemmas or the same name · phrases 3+ words · no paragraph cap · underline kind and Zwaan tracks (place / time / goal / cause bonuses) | 54.6% (R17) | 51.6% (R8 rerun) | 60.8% (R16) | 48.5% (R15) | – |
| **R22** (best measured, not shipped) | R8 minus the underline kind and Zwaan's event-indexing tracks | same as R8, without the track-hint and cause-nearby bonuses; ties broken by score, then position | 55.0% (R22) | 53.0% (R23) | 61.5% (R24) | 49.2% (R25) | 42.4% (R26) |
| **Claude hand-pick** (target, not an engine) | Claude reads each chapter and links a phrase to the earlier sentence it recalls | no thresholds; any phrase length; same chapter only | 95.3% (HS, 516 links) | – | – | – | 2,655 links (HP, used as reference, not scored) |

- **Release → R8:** rules with rare-word evidence replace the model confirm; precision goes up 14–25 points on the two books both were run on.
- **R8 → R22:** removing the kind and the tracks adds 0.4–1.4 points on every book (39 more right links, 5 fewer wrong across the four books; 92% of underlines unchanged).
- **R22 → hand-pick:** the gap is still about 40 points on Sherlock, and R22 reproduces only 4% of the Sunrise hand-pick.

## Runtime

**Total** = the whole test, including preparing every chapter (tagging, embedding, word statistics). **Processing** = the sum of the chapters' underline time (search, pick, confirm). Per-chapter, paragraph, sentence and word figures use processing time, except the last column.

| Run | Total (s) | Prepare (s) | Processing (s) | s / chapter | ms / paragraph | ms / sentence | ms / word | ms / word (total) |
|---|---|---|---|---|---|---|---|---|
| R1 | 225 | ≈0 (no word statistics) | 226 | 4.8 | 60 | 23.5 | 1.22 | 1.21 |
| R2 | 233 | 59 | 174 | 3.7 | 46 | 18.1 | 0.94 | 1.26 |
| R3 | 243 | 61 | 182 | 3.9 | 48 | 18.9 | 0.98 | 1.31 |
| R5 | 230 | 60 | 170 | 3.6 | 45 | 17.7 | 0.92 | 1.24 |
| R6 | 375 | 111 | 264 | 5.6 | 70 | 27.5 | 1.42 | 2.02 |
| R7 | 377 | 112 | 265 | 5.6 | 70 | 27.6 | 1.43 | 2.03 |
| R8 | 400 | 117 | 283 | 6.0 | 75 | 29.4 | 1.52 | 2.15 |
| R9 | 376 | 112 | 265 | 5.6 | 70 | 27.6 | 1.43 | 2.03 |
| R10 | 415 | 106 | 309 | 6.6 | 81 | 32.1 | 1.66 | 2.24 |
| R11 | 529 | 110 | 419 | 8.9 | 110 | 43.6 | 2.26 | 2.85 |
| R12 | 214 | 81 | 133 | 2.2 | 65 | 22.1 | 1.09 | 1.76 |
| R13 | 295 | 51 | 243 | 60.9 | 101 | 46.5 | 4.39 | 5.31 |
| R14 | 239 | 64 | 175 | 9.2 | 94 | 28.5 | 1.84 | 2.51 |
| RC | 3280 | – | 3280 | 820.1 | 1358 | 626.4 | 59.10 | 59.10 |
| RH | 4431 | – | 4431 | 233.2 | 2393 | 723.6 | 46.56 | 46.56 |

## Knobs of R22 (R8 is the same plus the track-hint bonus 0.10 and cause-nearby bonus 0.15, and the underline kind)

| Knob | Value | File |
|---|---|---|
| `UnderlineKnobs.minPhraseWords` | 3 (names too) | `2-Detect/UnderlineDetector.swift` |
| `UnderlineKnobs.nameGapSentences` | 30 | same |
| `UnderlineKnobs.maxPerParagraph` | unlimited (`Int.max`) | same |
| `SearchKnobs.embedWeight` / `wordsWeight` | 0.65 / 0.35 | `3-Search/CandidateScorer.swift` |
| `SearchKnobs.minRawScore[.both]` | 0.35 | same |
| `SearchKnobs.maxCandidates` | 6 | same |
| `SearchKnobs.similarityScale[.contextual]` | a 0.703 · b 0.295 | same |
| `WordKnobs.rareShare` / `rareMin` | 0.4% / 2 sentences | `3-Search/WordStats.swift` |
| `JudgeKnobs.minScore[.both]` / `margin[.both]` | 0.60 / 0.05 | `4-PickConfirm/RulesPicker.swift` |
| `ModelChoice` default | `.rulesOnly` (Foundation Models optional via `.automatic`) | `Pipeline/UnderlineCtrl.swift` |
| Embedding (harness) | `NLContextualEmbedding`, phrase text only | `1-Prepare/EmbeddingSvc.swift` |
| `WordStats` (harness) | whole book | `Tests/UnderlineEngineEvals/BookRun.swift` |

## Notes

- **Reviewer.** Every verdict is Claude's, reading the underlined sentence and its reference. The rules knobs were tuned against the same verdicts, so rules precision may be slightly optimistic. No blind human review yet.
- **Partial** = the reference is related but not exact, or only partly explains the phrase.
- **Parameter sweep** (360 settings, `Eval/results/rules-parameter-sweep-contextual/sweep.csv`) and the word-sense probe (`Eval/results/sense-probe/pairs.csv`) are not full runs; they were used to choose R7 and R11. R8 is the current configuration again; rerun through the public app API on 2026-11-19 it gives 836 underlines, 431 right, 129 partial, 276 wrong (**51.6%**), with 826 identical to the first R8 run. R11's sense check was removed again: it dropped 39 wrong links but also 20 right ones, a 1.6-point gain not worth the extra model pass. R12–R14 were run with the R11 configuration (sense check on).
- **R22–R25 (2026-11-20).** Removing the underline kind changed nothing (every underline identical on four books). Removing Zwaan's event-indexing tracks (and the two search bonuses built on them) changed 7–11% of the underlines: across the four books 39 more right links and 5 fewer wrong ones, precision up 0.4–1.4 points on every book. Kept.
- **Back to R8 for the release (2026-11-20).** The underline kind and the tracks are back in the engine, because iRead stores `kind` in each reader's iCloud chapters and in the shared ratings, and the release must not touch that. The restored engine was checked on Before the Coffee Gets Cold: 549 of 549 underlines identical to R15 (`Eval/results/book-before-the-coffee-gets-cold-rules-contextual.r8-restored-check/`). R22 (+0.4–1.4 points) can follow once the iCloud records can change.
- **R27–R29, cross-chapter search (2026-11-20, not adopted).** The engine was given an option to search earlier chapters (`paragraphResults(…, earlier:)`, harness `UNDERLINE_BOOK_SCOPE=book`); it was removed again the same day after these results, so the engine searches the current chapter only. With R8's scores and thresholds unchanged, it adds 19–62% more underlines but precision falls on every book (Coffee 48.5 → 38.4%, Hobbit 60.8 → 27.1%, Sherlock 54.6 → 25.5%) and even the count of right links drops (Hobbit 319 → 231, Sherlock 468 → 316): a word echo in an earlier chapter often outranks the right reference in the same chapter. Only 19% (Coffee), 8% (Hobbit) and 0.7% (Sherlock, separate stories) of the cross-chapter links are right. The 1,691 new links were reviewed by five Claude subagents with the usual rubric; the others keep their R8 verdicts. Little Women not reviewed. Cross-chapter links need stronger evidence than same-chapter ones (for example only a shared rare name or object, the key-point idea), not the same search over a bigger pool.
- **R26 and HP (2026-11-20), Sunrise on the Reaping.** A new, modern, first-person book, imported locally (copyrighted; text, labels and hand-picks stay local). The R22 engine, untouched, scores **42.4%**, its lowest book (others 49–62%). Claude hand-picked 2,655 links over all 28 chapters (`Dataset/labels/handpick-sunrise/`); R26 reproduces only 111 of them exactly (4%), so the engine and a reader pick mostly different links. Of the 206 R26 links that land on a hand-picked phrase but point elsewhere, 72 were still right. The 111 identical links were counted right without review; the other 701 were reviewed by four Claude subagents with the usual rubric (not by the main session, so slightly less consistent with the other books). Many wrong links share one common word or name (the narrator's name, everyday nouns). Verdicts: `Dataset/labels/claude-labels-sunrise-on-the-reaping.csv`. The release 1.1.0 run on this book is still in progress; its row will follow.
- **RH** and **RC** were produced from a separate worktree at tag `1.1.0` with a small runner (`ReleaseBookRun.swift`) that calls `UnderlineCtrl(model: .automatic)` exactly as the app does, on the same chapter texts as R14 and R13. Their runtime is one figure (prepare and model calls together); 135 of its underlines are shorter than 3 words, and 101 of those are wrong.
- **iRead app** still uses the release 1.1.0 engine (Little Women seed ≈10% right in a 40-item sample) and does not yet use NLContextual, book-level word statistics or rules-only.
