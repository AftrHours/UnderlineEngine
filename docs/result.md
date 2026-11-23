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
| Anne of Green Gables | 38 | – | – | 101,965 | – (not run yet) |
| Moby-Dick | 136 (135 + epilogue) | – | – | 207,769 | – (not run yet) |

Datasets: `Dataset/little-women/`, `Dataset/pride-and-prejudice/` (built by `Dataset/epub_to_chapters.py`). Verdicts: `Dataset/labels/claude-labels.csv` (Little Women, 2,536 pairs) `claude-labels-pride-and-prejudice.csv` (352 pairs) `claude-labels-before-the-coffee-gets-cold.csv` (502 pairs) and `claude-labels-the-hobbit.csv` (469 pairs); the last two are local only because they contain copyrighted excerpts. A verdict is keyed by chapter, sentence, phrase and reference, so the same pair is reused across runs.

## Target

The goal is the **Sherlock Holmes seed that Claude made by hand** for iRead (`EReader/iRead/App/Resources/UnderlineSeed/048b…`, row the Sherlock hand pick below). It is what a careful reader would underline: scene-specific clues ("Black Jack of Ballarat" → "So and so, of Ballarat", "the speckled band" → Julia's dying words, "the twelve-mile drive" → "only seven miles"), not repeated everyday phrases.

| Measure | Target (hand pick, hand seed) | R8 (R17, current) | Gap (current) |
|---|---|---|---|
| Precision (right ÷ links) | **95%** (aim ≥ 90%) | 54.6% | −40 points |
| Wrong links | 2 of 516 (0.4%) | 290 of 857 (34%) | 288 too many |
| Right links per 1,000 words | 4.7 | 4.5 | about equal |
| All links per 1,000 words | 4.9 | 8.2 | +3.3 (noise) |
| Overlap with the target | 516 | 50 identical pairs | 466 target links missed |

So R8 already finds about as many right links as the target, but different ones, and buries them under word echoes. Closing the gap means two things, in this order:

1. **Drop the echoes**: confirm that the phrase and the reference describe the same event or clue, not only that they share a rare word (see the three kinds of wrong links in `Eval/results/book-the-adventures-of-sherlock-holmes-rules-contextual/wrong-underlines.md`).
2. **Pick the links a reader would ask about**: prefer clue-like phrases (names of things, places, objects, numbers) over generic actions, so the overlap with the target rises.


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
| R15 | Before the Coffee Gets Cold | **R8 configuration (current)** | identical to R8, no tuning | 549 | 266 | 95 | 188 | 549 (all) | **48.5%** exact |
| RC | Before the Coffee Gets Cold | **Release 1.1.0 engine as the app runs it** | as RH | 1,289 | 455 | 217 | 617 | 1,289 (all) | **35.3%** exact |
| Release seed | Little Women | **Release 1.1.0 seed bundled in iRead** (Foundation Models, iRead's text split) | iRead commit `1e94ca8`, engine 4 | 1,826 | 453 | 241 | 1,132 | 1,826 (all) | **24.8%** exact (27 links in the Gutenberg licence) |
| Release seed | Pride and Prejudice | same, made by rules (no Apple Intelligence when made) | same | 284 | 128 | 78 | 78 | 284 (all) | **45.1%** exact (16 in the licence) |
| Release seed | Anne of Green Gables | same as Little Women | same | 1,020 | 280 | 182 | 558 | 1,020 (all) | **27.5%** exact (28 in the licence) |
| Release seed | Moby-Dick | same as Little Women | same | 1,175 | 288 | 217 | 670 | 1,175 (all) | **24.5%** exact (27 in the licence) |
| R16 | The Hobbit | **R8 configuration (current)** | identical to R8, no tuning | 525 | 319 | 86 | 120 | 525 (all) | **60.8%** exact |
| RH | The Hobbit | **Release 1.1.0 engine as the app runs it**: Foundation Models confirm, NLEmbedding, per-chapter search | no IDF · no word statistics · names 1+ words · 1 per paragraph · model confirms the top candidate | 1,009 | 365 | 172 | 472 | 1,009 (all) | **36.2%** exact |
| R17 | The Adventures of Sherlock Holmes | **R8 configuration (current)** on a story collection | identical to R8, no tuning; compared with the iRead seed Claude made by hand (516 links) | 857 | 468 | 99 | 290 | 857 (all) | **54.6%** exact; 50 links identical to the hand seed |
| Hand pick | The Adventures of Sherlock Holmes | **iRead seed made by hand by Claude** (not an engine run) | 516 links chosen while reading; 15 are shorter than 3 words | 516 | 492 | 22 | 2 | 516 (all) | **95.3%** (reviewed by Claude, who also made it, so likely optimistic) |
| R22 | The Adventures of Sherlock Holmes | **R8 without the underline kind and Zwaan's event-indexing tracks** (best measured; reverted for the release, see Notes) | removed: `UnderlineKind`, `Track`, the track-hint bonus (place / time / goal words) and the cause-nearby bonus; a name still searches only sentences that mention it | 871 | 479 | 99 | 293 | 871 (all) | **55.0%** exact (R8: 54.6%) |
| R23 | Little Women | same as R22 | identical | 851 | 451 | 130 | 270 | 851 (all) | **53.0%** exact (R8: 51.6%) |
| R24 | The Hobbit | same as R22 | identical | 535 | 329 | 86 | 120 | 535 (all) | **61.5%** exact (R8: 60.8%) |
| R25 | Before the Coffee Gets Cold | same as R22 | identical | 537 | 264 | 87 | 186 | 537 (all) | **49.2%** exact (R8: 48.5%) |
| R26 | Sunrise on the Reaping | same as R22 | identical, no tuning; compared with links Claude hand-picked for the whole book (hand pick, 2,655 links) | 812 | 344 | 198 | 270 | 812 (all) | **42.4%** exact; 111 links identical to the hand-pick, 206 more on a hand-picked phrase with a different reference |
| Hand pick | Sunrise on the Reaping | **Links hand-picked by Claude while reading** (not an engine run) | every chapter read in full; each link = phrase + earlier sentence in the same chapter, text-checked | 2,655 | – | – | – | – | not reviewed (used as the reference set, not scored) |
| Hand pick | Little Women | **Links hand-picked by Claude while reading** (not an engine run) | same rules as the Sunrise hand pick: every chapter read in full; phrase + earlier passage in an earlier paragraph of the same chapter; text-checked by `Dataset/labels/handpick_check.py` | 1,507 | 1,195 | 296 | 16 | 1,507 (all) | **79.3%** exact (84.8% without the strictest reviewer, see Notes); R8 finds 92 of them (6%), and 94 of R8's 836 links (11%) are identical to one |
| Hand pick | Pride and Prejudice | same as the Little Women hand pick | identical | 788 | 645 | 135 | 8 | 788 (all) | **81.9%** exact |
| Hand pick | Anne of Green Gables | same as the Little Women hand pick | identical | 722 | 646 | 72 | 4 | 722 (all) | **89.5%** exact |
| Hand pick | Moby-Dick | same as the Little Women hand pick | identical | 1,353 | 1,175 | 172 | 6 | 1,353 (all) | **86.8%** exact |
| E1 | Little Women ch1–5 | **Entity semantic-role matching (SRL), ceiling test** (not an engine: roles labelled by Claude) | each sentence's events labelled with semantic roles, who (agent) · did (predicate) · what (patient) · where (location), names and pronouns resolved by Claude; a later sentence links to the earlier sentence (earlier paragraph, same chapter) whose roles have the same *what* plus one more equal role, most slots then nearest | 311 | 145 | 88 | 78 | 311 (all) | **46.6%** exact (R8 on the same chapters: 97 links, 51.5%); finds 18% of the hand pick (R8 10%) |


### Ablation: main versions

Each row changes one stage from the row above it. Precision = right ÷ underlines (Claude's verdicts, every link reviewed); "–" = not run on that book. \* = measured on the seed iRead bundled with release 1.1.0 (its own text split of the EPUB, including the Project Gutenberg licence at the end), not a harness run.

| Version | Method | Parameters | Sherlock | Little Women | Hobbit | Coffee | Sunrise | Pride and Prejudice | Anne of Green Gables | Moby-Dick |
|---|---|---|---|---|---|---|---|---|---|---|
| **Release 1.1.0** (previous app engine) | Foundation Models confirm · NLEmbedding · per-chapter search | no IDF · no word statistics · names 1+ words · 1 underline per paragraph · the model confirms the top candidate | – | 24.8%* | 36.2% | 35.3% | – | 45.1%* | 27.5%* | 24.5%* |
| **R8** (UnderlineEngine 1.2.0, in the app) | Rules confirm · NLContextualEmbedding · IDF word weights · book-level word statistics | score = 0.65 meaning + 0.35 shared rare words · floor 0.35 · top 6 · pick at 0.60, margin 0.05 · confirm needs a shared rare noun/adjective (≤ 0.4% of sentences), 2 rare lemmas or the same name · phrases 3+ words · no paragraph cap · underline kind and Zwaan tracks (place / time / goal / cause bonuses) | 54.6% | 51.6% | 60.8% | 48.5% | – | – | – | – |
| **R22** (best measured, not shipped) | R8 minus the underline kind and Zwaan's event-indexing tracks | same as R8, without the track-hint and cause-nearby bonuses; ties broken by score, then position | 55.0% | 53.0% | 61.5% | 49.2% | 42.4% | – | – | – |
| **Hand pick** (Claude, target, not an engine) | Claude reads each chapter and links a phrase to the earlier passage it recalls | no thresholds; any phrase length; Sherlock's seed may cross chapters, the others stay in the chapter (passage in an earlier paragraph) | 95.3% | 79.3% | – | – | – | 81.9% | 89.5% | 86.8% |

- **Release → R8:** rules with rare-word evidence replace the model confirm; precision goes up 14–25 points on the two books both were run on.
- **R8 → R22:** removing the kind and the tracks adds 0.4–1.4 points on every book (39 more right links, 5 fewer wrong across the four books; 92% of underlines unchanged).
- **R8 / R22 → hand-pick:** a careful reader's links are right 79–95% of the time against 49–62% for the engine (on Little Women 79.3% vs 51.6%), and the two pick mostly different links: R8 finds 6% of the Little Women hand-pick, R22 4% of Sunrise's. The hand-pick numbers are Claude judging Claude's picks, so likely optimistic; one Little Women reviewer was stricter (84.8% without that batch).
- R8 has not been run yet on Pride and Prejudice, Anne of Green Gables or Moby-Dick.

#### Bundled seeds in iRead: release 1.1.0 vs 1.2.0 (R8) — counts only, **not reviewed**

Unlike the rows above, these are **not** reviewed runs. They are the seeds iRead ships for its sample books, made by each engine on iRead's own parse of the EPUBs (old: iRead commit `1e94ca8`, engine 4; new: `e126f75`, engine 5, exported from a phone with "Underline whole book"). Same engine code as the measured runs, but a different text split from `Dataset/`, so the counts differ from R8's runs.

| Book | Old seed (1.1.0) | New seed (1.2.0, R8) | Same link in both |
|---|---|---|---|
| Little Women | 1,826 (Foundation Models) | 892 (rules) | 130 |
| Pride and Prejudice | 284 (rules) | 201 (rules) | 65 |
| Anne of Green Gables | 1,020 (Foundation Models) | 643 (rules) | 138 |
| Moby Dick | 1,175 (Foundation Models) | 744 (rules) | 134 |
| Sherlock Holmes | 516 (hand) | 516 (hand, relabelled to engine 5) | 516 |

- 1.2.0 underlines 30–51% less than 1.1.0 and keeps only about 15–20% of its links. Pride and Prejudice stays low (201) because this EPUB is split into 472 parts and the engine searches within a part.
- **Old seeds (1.1.0) are now fully reviewed** (2026-11-21, 565 verdicts reused from identical earlier links, 3,740 reviewed by eleven Claude agents; `Dataset/labels/claude-labels-seed-1.1.0-<book>.csv`): Little Women 24.8%, Pride and Prejudice 45.1%, Anne 27.5%, Moby-Dick 24.5% right, in line with the book runs of release 1.1.0 (RH 36.2%, RC 35.3%). The new R8 seeds are still not reviewed. Both the old and the new seeds underline text in the Project Gutenberg licence at the end of each book (new seeds: 35–39 links per book), because iRead treats that back matter as a chapter.
- To measure them: review a sample of each seed (about 100 links per book per version gives roughly ±10 points).

### Retrieval recall: R8's search, before confirm (2026-11-22)

For each hand-picked link judged right, where R8's own ranking (`CandidateScorer.rank`) puts the earlier sentence the reader linked to. The query is the hand-picked phrase; the pool is the earlier paragraphs of the same chapter (median 109 sentences, the linked one a median 25 sentences back). Little Women, 1,195 links, all usable. `Tests/UnderlineEngineEvals/RetrievalRecall.swift`, `Eval/results/recall-little-women/`.

| Ranking | @1 | @3 | @6 | @10 | @20 | @50 |
|---|---|---|---|---|---|---|
| R8 (vector + words + bonus) | 28.6% | 44.2% | 53.1% | 59.9% | 67.9% | 81.9% |
| Meaning only (`NLContextualEmbedding`) | 9.3% | 17.2% | 24.5% | 32.6% | 45.4% | 69.7% |
| Words only (IDF lemmas) | 35.2% | 50.3% | 60.1% | 67.6% | 75.8% | 86.1% |
| Random | 2.7% | 6.7% | 11.6% | 17.1% | 29.0% | 54.6% |

| Stage | Hand-picked links still reachable |
|---|---|
| Detect makes a phrase overlapping the reader's | 88.3% |
| Search puts the linked sentence in the top 6 sent to confirm | 53.1% |
| Both | 47.7% |
| Underlined by R8 (book run) | 7% |

- Most of the loss is after search: R8 brings about half of the reader's links to confirm, and confirm and pick drop nearly all of them.
- The vector is the weak signal: alone it is near random at the top, and mixed in at 0.65 it pulls the word signal down (35.2% → 28.6% at @1).
- Caveat: the hand pick was made by Claude, which may favour links that share words, so the words-only ranking may be flattered somewhat.

**Stage 3, entities (2026-11-22).** `EntityResolver` (rules on NaturalLanguage's person names; moved to `Experiments/retrieval/stages/`): "Jo March" → Jo, titled names kept apart ("Mrs. March"), gender per name from the pronouns after it, and he/she/him/her → the last person of that gender within 4 sentences. Each sentence gets one token per person, counted like a rare word.

| Ranking | @1 | @3 | @6 | @10 | @20 | @50 |
|---|---|---|---|---|---|---|
| Words only | 35.2% | 50.3% | 60.1% | 67.6% | 75.8% | 86.1% |
| Words + entities | 34.1% | 50.5% | 60.0% | 66.9% | 75.3% | 86.5% |
| R8 mix with words + entities | 28.2% | 44.7% | 53.0% | 59.6% | 68.0% | 82.3% |

- No gain: 41% of the hand-picked phrases carry a person token, but names were already content lemmas (the tagger lemmatises "Jo" to "jo"), so the stage only adds resolved pronouns and merged full names, and those point mostly at the main characters, who are in so many sentences that sharing them says little.
- The tagger's person names are noisy ("because thou", "cake", "beyond"), and some genders come out wrong (Antonio, Apollyon female), but fixing that would not change the result above: the people a reader links on are the frequent ones.

**Stage 5, roles (2026-11-22).** `RoleLabeler` (rules; moved to `Experiments/retrieval/stages/`): for each clause of `EventSplitter`, agent = the person (stage 3) or noun before the main verb, else the previous clause's agent; predicate = the main verb's lemma; patient = the first noun or person after it; location = a noun after a place preposition. Each clause gives role pairs as tokens (predicate>patient, agent>predicate, predicate>location, agent>patient), weighted by IDF. 80.5% of the hand-picked phrases get at least one pair.

| Ranking | @1 | @3 | @6 | @10 | @20 | @50 |
|---|---|---|---|---|---|---|
| Words only | 35.2% | 50.3% | 60.1% | 67.6% | 75.8% | 86.1% |
| Words + roles | 34.1% | 49.9% | 59.7% | 67.6% | 75.6% | 86.0% |
| Words + ½ roles on top (roles can only add) | 35.1% | 50.0% | 59.9% | 67.6% | 75.6% | 86.0% |
| Words + entities + roles | 33.6% | 49.7% | 59.5% | 66.4% | 75.1% | 86.5% |
| R8 mix with words + entities + roles | 27.9% | 43.8% | 52.3% | 58.9% | 67.4% | 82.1% |
| Roles only | 6.3% | 12.5% | 20.7% | 26.7% | 38.1% | 57.0% |

- No gain, in any mix. Role pairs alone find something (20.7% at @6, against 11.6% random), but nothing the shared words don't already find: a clause pair matches only when both words of it are shared, and then the word signal has already ranked that sentence high.
- This fits E1: with Claude's ideal roles, SRL found links words missed because Claude resolved pronouns and named the same thing the same way across paraphrases ("Christmas presents"). Rules on NaturalLanguage tags can do neither, so their roles are a rearrangement of the same words.
- Stages 3 and 5 were moved out of the engine to `Experiments/retrieval/stages/` with their tests and the recall test that measured them. Retrieval on the phone is at its limit with these tools: the remaining levers are the search mix (words alone beat R8's mix by 7 points at @6) and what happens after search (confirm keeps about 7 of the 48% that reach it).

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
- **Parameter sweep** (360 settings, `Eval/results/rules-parameter-sweep-contextual/sweep.csv`) is not a full run; it was used to choose R7. R8 rerun through the public app API on 2026-11-19 gives 836 underlines, 431 right, 129 partial, 276 wrong (**51.6%**), with 826 identical to the first R8 run.
- **R22–R25 (2026-11-20).** Removing the underline kind changed nothing (every underline identical on four books). Removing Zwaan's event-indexing tracks (and the two search bonuses built on them) changed 7–11% of the underlines: across the four books 39 more right links and 5 fewer wrong ones, precision up 0.4–1.4 points on every book. Kept.
- **Back to R8 for the release (2026-11-20).** The underline kind and the tracks are back in the engine, because iRead stores `kind` in each reader's iCloud chapters and in the shared ratings, and the release must not touch that. The restored engine was checked on Before the Coffee Gets Cold: 549 of 549 underlines identical to R15 (`Eval/results/book-before-the-coffee-gets-cold-rules-contextual.r8-restored-check/`). R22 (+0.4–1.4 points) can follow once the iCloud records can change.
- **Hand picks for the four public-domain books (2026-11-21).** Made like the Sunrise hand pick: Claude read every chapter (ten agents in parallel) and wrote `phrase || earlier passage` lines in `Dataset/labels/handpick-<book>/chNN.txt`, same chapter only, the passage in an earlier paragraph, both strings unique in the chapter; `Dataset/labels/handpick_check.py` passes on every chapter (4,370 links, 0 bad). Density: Little Women 8.1, Pride and Prejudice 6.5, Anne 7.1, Moby-Dick 6.5 links per 1,000 words; chapters whose callbacks point to earlier chapters came out sparse, because cross-chapter links were left out. Anne and Moby-Dick were split for the first time (`epub_to_chapters.py` now splits a file at each "Chapter" heading when it holds several, as Moby-Dick's EPUB does; the other books split exactly as before). All 4,370 links were then reviewed by twelve other Claude agents (fresh, not the pickers) with the usual rubric: Little Women 79.3%, Pride and Prejudice 81.9%, Anne 89.5%, Moby-Dick 86.8% right; only 34 links (0.8%) were judged wrong, the rest of the misses are partial (same topic, a different moment, or a passage one sentence off). One Little Women reviewer (chapters 38–47) also marked a link partial when its passage is only the line just above, which the others did not; its batch scored 58% against 84–85% for the other three, so Little Women is 84.8% without it. Claude reviewing Claude's picks is likely optimistic, as for the Sherlock hand pick (95.3%). Verdicts: `Dataset/labels/claude-labels-handpick-<book>.csv`. On Little Women, R8 and the hand-pick overlap little (6% of the hand links found), the same pattern as Sunrise (4%): the engine and a careful reader pick mostly different links.
- **E1, entity semantic-role (SRL) ceiling test (2026-11-22).** The mentor's Subject–Verb–Object–Place idea, which in NLP is semantic role labeling (SRL: agent · predicate · patient · location), tried with the best possible labels: Claude labelled 1,690 role sets in Little Women chapters 1–5 (`Experiments/srl/`), resolving pronouns and keeping names and objects worded the same. Matching on the same patient (object) plus one more role gave 311 links, 46.6% right, against R8's 97 links at 51.5%: about three times as many right links (145 vs 50) at a similar precision. The patient (object) role carries it; "same person + same verb" alone found half as much. But it reaches few of a careful reader's links: 18% of the hand pick (R8 10%), and no rule that needs an equal role can ever reach more than 27–41% of them, because most hand-picked links are paraphrases, consequences or feelings with no role in common. SRL matching and R8 share only 14 links, so they find different things (together 25% of the hand pick). Caveats: links here are sentence to sentence (R8 underlines a phrase), the roles are ideal (a phone version, without pronoun resolution, would do worse), and it is five chapters of one book.
- **E1 with rough SRL (2026-11-22), not reviewed.** The same matching on roles labelled only with Apple's NaturalLanguage, what a phone can do (`Experiments/srl/rough_roles.swift`: predicate = each verb's lemma; agent = the nearest person name before it, he/she = the last person named; patient = the first noun or name after it; location = a noun after in/at/into/to; 4 seconds for the whole book). On chapters 1–5 the same rule (same patient plus one more role) makes 95 links and finds 4% of the hand pick, against 18% with Claude's roles and 10% for R8. On the whole book it makes 795 links and finds 2% of the hand pick (R8: 832 links, 7%); only 4% of its links coincide with a hand-picked one (R8 10%). Loosening to "same patient only" finds 8% but makes 3,396 links. Most of the ceiling's gain comes from what a tagger can't do: resolving pronouns and naming the same thing the same way ("Christmas presents" vs "present"/"Christmas"). Precision not measured; counts only.
- **R26 and the Sunrise hand pick (2026-11-20), Sunrise on the Reaping.** A new, modern, first-person book, imported locally (copyrighted; text, labels and hand-picks stay local). The R22 engine, untouched, scores **42.4%**, its lowest book (others 49–62%). Claude hand-picked 2,655 links over all 28 chapters (`Dataset/labels/handpick-sunrise/`); R26 reproduces only 111 of them exactly (4%), so the engine and a reader pick mostly different links. Of the 206 R26 links that land on a hand-picked phrase but point elsewhere, 72 were still right. The 111 identical links were counted right without review; the other 701 were reviewed by four Claude subagents with the usual rubric (not by the main session, so slightly less consistent with the other books). Many wrong links share one common word or name (the narrator's name, everyday nouns). Verdicts: `Dataset/labels/claude-labels-sunrise-on-the-reaping.csv`. The release 1.1.0 run on this book is still in progress; its row will follow.
- **RH** and **RC** were produced from a separate worktree at tag `1.1.0` with a small runner (`ReleaseBookRun.swift`) that calls `UnderlineCtrl(model: .automatic)` exactly as the app does, on the same chapter texts as R16 and R15. Their runtime is one figure (prepare and model calls together); 135 of its underlines are shorter than 3 words, and 101 of those are wrong.
- **iRead app** still uses the release 1.1.0 engine (Little Women seed ≈10% right in a 40-item sample) and does not yet use NLContextual, book-level word statistics or rules-only.
