# Current engine: R9 (2026-11-24)

R9 is the only engine in UnderlineEngine on branch `link-quality` (`Linker`, `Underliner.releaseVersion` 6; not committed yet). R8's code was removed on 2026-11-24 (it is still in tag 1.2.0, which iRead runs until its package pin moves); its analysis follows below.

## R9 configuration, stage by stage

| Stage | Folder | What R9 does | Knobs |
|---|---|---|---|
| 1 Prepare | `1-Prepare` | Splits sentences (`NLTokenizer`), tags words, lemmas, word classes and names (`NLTagger`), counts word rarity over the whole book (without names), cuts events with role, track and kind, and runs `NLContextualEmbedding` once per sentence for a contextual vector of each content word, centred on the chapter and normalised (`IndexedSentence.wordVectors`) | none |
| 2 Detect | `2-Detect` | Event phrases of 3+ words that are not only general words, and person names not seen in the last 30 sentences; an event whose reason is given in the same sentence is skipped | `minPhraseWords` 3, `nameGapSentences` 30 (same as R8) |
| 3 Search | `3-Search` | Ranks every earlier sentence of the chapter by IDF-weighted shared content lemmas (share of the phrase's word weight found in the sentence), plus the role bonuses | role-link bonus 0.10, reaction-nearby 0.30 |
| 4a Pick | `4-PickConfirm` | Evidence pick: of the top 6, candidates sharing at least one content word with the phrase, best first; candidates within 0.05 of each other go nearest first; the first one goes to verification, unless it is in the phrase's own paragraph. No minimum score, no lead over the second | `tieWindow` 0.05, top 6 |
| 4b Confirm | `4-PickConfirm` | Evidence points (`RulesPicker.evidencePoints`): a shared rare noun or adjective 2, two or more shared rare words 1, a soft lexical match ≥ 0.3 (token MaxSim of the phrase's unshared words against the reference, from `wordVectors`) 1. Needs 2 points within 20 sentences back, 3 further. A shared name counts like any shared noun | `softMatch` 0.3, `pointsNeeded` [(20, 2), (∞, 3)], rare = in ≤ 0.4% of the book's sentences |
| 5 Limit | `5-Limit` | No two overlapping underlines in a sentence (higher score wins, then the shorter phrase); kind is never used; no cap per paragraph | `maxPerParagraph` unlimited |

Output per underline is unchanged from R8 (phrase, reference sentence, `kind`, `role`, `decidedBy: rules`), so iRead's saved chapters and iCloud records keep their shape.

## R9 results (LLM-as-judge labels by Claude)

| Book | R9 underlines | R9 right | R9 precision | R8 right · precision | Run time (Mac) |
|---|---|---|---|---|---|
| Sherlock Holmes | 1,300 | 588 | 45.2% | 468 · 54.6% | 327 s |
| Little Women | 1,469 | 637 | 43.4% | 431 · 51.6% | 381 s |
| The Hobbit | 795 | 343 | 43.1% | 319 · 60.8% | 236 s |
| Before the Coffee Gets Cold | 595 | 300 | 50.4% | 266 · 48.5% | 283 s |
| Anne of Green Gables | 889 | 432 | 48.6% | – | 209 s |
| Sunrise on the Reaping | 1,192 | ≈ 563 | ≈ 47.2%† | – | 336 s |
| Pride and Prejudice | 557 | ≈ 245 | ≈ 44.0%† | – | 206 s |
| Moby-Dick | 1,806 | ≈ 662 | ≈ 36.7%† | – | 359 s |

Exact where every link is labelled; † = earlier labels plus a random sample of 150 new links (95% CI: Sunrise 43.1–51.3%, Pride and Prejudice 40.5–47.6%, Moby-Dick 29.6–43.7%). Run time is the whole book run, including preparing the book.

Silver standard found: Little Women 144 of 1,190 (12.1%; R8 7.0%), Sherlock 51 of 492 hand-seed links (R8 48), Anne 84 of 644 (13.0%).

Precision by reference distance (exact books):

| Book | ≤ 20 sentences back | further back |
|---|---|---|
| Coffee | 66.3% (282 links) | 36.1% (313) |
| Anne | 55.9% (639) | 30.0% (250) |

## What R9 fixed from R8

| R8 problem | R9 change | Effect |
|---|---|---|
| Pick refused 82% of phrases (score ≥ 0.60 and a 0.05 lead on a flat score) | Evidence pick, no score or lead | More right links on every book measured (+7% to +48%) |
| The mean-pooled sentence vector was 65% of the score (AUC 0.55) | Search on IDF-weighted shared words only | Better ranking (60% vs 53% of silver-standard links in the top 6) |
| Far references mostly wrong, no rule for them | Evidence bar rises at 20 sentences back | Far links cut by about a quarter; near links stay |
| Kind and Zwaan tracks in scoring | Computed, not scored | Small gain, iCloud fields unchanged |

## Where R9 struggles

1. **Lexical false positives**: most wrong links rest on one shared word used at a different moment ("enjoying the sunshine" ← "a ray of sunshine on Amy's forehead"); a link sharing one word is about 42% right, two 65%, three or more 74%.
2. **More pairs reach verification**: the evidence pick sends 4.5 times as many pairs (Little Women 13,242 vs 2,948), so a small share slipping through is hundreds of links.
3. **References more than 20 sentences back** are still 30–36% right, against 56–66% within 20.
4. **About a quarter of the links are partial**: the same scene one sentence off, or the same person at another moment.
5. **Rare is not specific**: abstract words that are rare by count (delicate, vague, instructive) confirm links as easily as clue words.
6. **Paraphrases and consequences are still out of reach**: 75% of Claude's silver standard fails word evidence; see `docs/constraint.md`.

## Tried on R9 and not adopted

- **Two shared words unless very near (F1)**: lifted precision offline (40.7% → 56.4%) but cut the silver standard (Little Women 14.5% → 8.9%) and made R9 equal to R8, not better. Rejected 2026-11-24.
- **Trying the 2nd and 3rd candidate (depth 2–3)**: silver-standard recall 14.5% → 15.6% for 355 more underlines; the right sentence is usually rejected by verification, not missed by pick.
- **A soft lexical match alone as evidence**: near links confirmed this way were 23% right in a real run (R9 first try); silver and wrong links overlap too much on this score.

# R8 (previous engine) and its issues

R8 is the engine in UnderlineEngine 1.2.0 and in iRead: rules-only confirm, `NLContextualEmbedding` (falls back to `NLEmbedding` after 10 s), IDF word weights from the whole book, search within the chapter. All numbers below come from `docs/result.md` (LLM-as-judge labels (Claude), every link reviewed) and the retrieval recall test on Little Women (2026-11-22).

**Terms.** Standard terms are used throughout: *feature* (a measured signal), *decision rule* (a threshold or rule that uses features), *candidate retrieval* (stage Search), *candidate selection* (stage Pick), *verification* (stage Confirm), *span detection* (stage Detect). *Silver standard* = the links Claude hand-picked while reading (made by a model, not by people, so not a gold standard). *LLM-as-judge labels* = Claude's right / partial / wrong verdicts. *Precision* = right ÷ links; *recall* = share of the silver standard found; *recall@k* = share whose linked sentence is in the top *k* candidates. *Lexical false positive* = a wrong link made because the two sentences share a word (a word echo). *IDF-weighted lexical overlap* = shared words weighted by rarity. *Mean-pooled sentence embedding* = the average of `NLContextualEmbedding`'s token vectors (R8's "meaning" score). *Token MaxSim* = each word's best contextual match in the other sentence (as in ColBERT / BERTScore); *soft lexical match* = MaxSim on the words the two sentences don't share (paraphrase). *Proximity* = how few sentences back the reference is. *Oracle experiment* = a test with ideal input (e.g. Claude's semantic roles) to find the upper bound of a method. *Ablation* = removing one part to see its effect.

## 1. Precision is about 50%: half the underlines are wrong

| Book | R8 precision |
|---|---|
| The Adventures of Sherlock Holmes (R17) | 54.6% |
| Little Women (R8, rerun) | 51.6% |
| The Hobbit (R16) | 60.8% |
| Before the Coffee Gets Cold (R15) | 48.5% |
| Target: Sherlock silver standard | 95.3% |

On Sherlock, 290 of 857 links are wrong, against 2 of 516 in the silver standard.

## 2. Most wrong links are lexical false positives

R8 links two sentences because they share a rare word, not because they describe the same moment: a phrase and an unrelated earlier sentence that both use "letter" or a character's name get linked. Confirm only checks shared-word evidence:

- a shared rare noun or adjective (in ≤ 0.4% of sentences), or
- two shared rare lemmas, or
- the same name.

Examples: `Eval/results/book-the-adventures-of-sherlock-holmes-rules-contextual/wrong-underlines.md`.

## 3. It misses most of the links in Claude's silver standard

R8 finds 6–7% of the silver standard (Little Women 6%, Sunrise 4%). It finds about as many right links as the target (4.5 vs 4.7 per 1,000 words on Sherlock), but different ones: everyday lexical false positives instead of clue-like links ("the speckled band" → Julia's dying words).

## 4. Pick and confirm throw away almost everything search finds (mostly pick, see below)

| Stage (Little Women, 1,195 silver-standard links judged right) | Still reachable |
|---|---|
| Detect makes a phrase overlapping Claude's | 88.3% |
| Search puts the linked sentence in the top 6 sent to confirm | 53.1% |
| Underlined by R8 | 7% |

Claude's silver-standard links are mostly paraphrases, consequences and feelings with no shared rare word, so confirm rejects them and keeps the lexical false positives (issue 2 from the other side).

## 5. The meaning feature is weak

`NLContextualEmbedding` alone ranks the linked sentence first 9.3% of the time (words alone 35.2%, random 2.7%). R8 gives it 65% of the score, which pulls ranking down: top 6 holds the linked sentence for 60.1% of links with words alone, 53.1% with R8's mix.

## 6. Far references are mostly wrong

A link within 20 sentences is about 72% right; one more than 100 sentences back only 30–38%. R8 treats both alike. Asking for more evidence the further back the reference is raised precision to 68–77% but cut about 40% of the right links, so it was not adopted.

## 7. Same chapter only

Searching earlier chapters with the same rules dropped precision to 25–38%: lexical false positives multiply as the pool grows. Readers often link across chapters; R8 can't.

## 8. Smaller issues

- **Gutenberg licence**: iRead feeds the licence back matter as a chapter, so each seed has 35–39 links in it.
- **Kind and tracks**: kept only so iCloud records don't change. Removing them (R22) is 0.4–1.4 points better on every book.
- **Speed**: about 400 s for the whole of Little Women on a Mac; `NLContextualEmbedding` needs downloaded assets.
- **Optimistic numbers**: the knobs were tuned on the same Claude verdicts they are scored on; no blind human review yet.

## In short

R8 measures word overlap, not "the same moment in the story". Retrieval is decent (half of Claude's silver-standard links reach confirm), but confirm only sees shared rare words, so it keeps the lexical false positives and drops the paraphrases. Pick and confirm (issues 2 and 4) are the biggest lever; the analysis below shows pick drops more than confirm.

## Tried and not helpful

- **Entities / rule-based coreference (stage 3)**: names merged, he/she → last person of that gender. Top-6 recall 60.1% → 60.0%. Pronouns point mostly at the main characters, who are in too many sentences to carry information.
- **Semantic roles from `NLTagger` (stage 5, rough SRL)**: agent · predicate · patient · location per clause. Top-6 recall 60.1% → 59.7%: a role pair matches only when both its words are already shared, so it adds nothing the words don't.
- **SRL with Claude's roles (E1, oracle)**: finds 18% of the silver standard vs R8's 10% on chapters 1–5, because Claude resolved pronouns and named things the same way. With rough roles it falls to 2%. Even ideal roles can reach at most 27–41% of the silver standard.

## Why it fails: link-level analysis (2026-11-23, Little Women)

Data: every R8 phrase of the book run (18,718), the 1,195 silver-standard links judged right, and 2,657 engine links with Claude verdicts (any run). Features per link from `Tests/UnderlineEngineEvals/LinkFeatures.swift`, compared by `Experiments/retrieval/features.py`; output `Eval/results/features-little-women/links.csv`.

### Where each phrase ends

| Outcome of R8's phrases | Phrases |
|---|---|
| Pick found no candidate good enough (`pickedNone`) | 15,439 (82%) |
| Confirm rejected the pick | 2,112 (11%) |
| Underlined | 836 (4%) |
| Other (no candidate, reference in its own paragraph) | 331 |

Of the 570 silver-standard links whose sentence reached the top 6, the engine phrase over the same words ends: **pick 389** (68%), confirm 73, underlined with the right reference 73, other 35. Even 178 links ranked **first** by search die at pick.

**Pick is the biggest gate.** It needs the top candidate's raw score ≥ 0.60 **and** a lead of ≥ 0.05 over the second. For the 389, the top score is low (median 0.56) and close to the second: 256 fail both tests, 75 only the lead, 40 only the score. The score is 65% the mean-pooled sentence embedding, which barely varies between sentences, so most sentences score about the same and the lead is rarely there.

### What separates right links from wrong ones

AUC = the chance a right link scores higher than a wrong one on that feature (0.5 = no separation; below 0.5 = wrong links score higher).

| Feature | Median: engine right | engine wrong | Claude's silver standard | AUC right vs wrong | AUC Claude vs wrong |
|---|---|---|---|---|---|
| Distance (sentences back) | 22 | 54 | 25 | 0.32 | 0.33 |
| Content words in the phrase | 2 | 2 | 4 | 0.59 | 0.79 |
| IDF sum of shared words | 7.1 | 5.7 | 4.3 | 0.68 | 0.39 |
| Token MaxSim (contextual word match) | 0.59 | 0.53 | 0.34 | 0.61 | 0.24 |
| Token MaxSim, unshared words only (paraphrase) | 0.12 | 0.00 | 0.22 | 0.53 | 0.69 |
| Mean-pooled sentence embedding cosine | 0.65 | 0.63 | 0.62 | 0.55 | 0.48 |
| Passes R8's confirm | – | – | 35.6% of silver-standard links | 0.61 | 0.42 |

1. **No single feature separates right from wrong.** The best AUCs are 0.68 (shared-word IDF) and 0.68 for proximity (1 − 0.32); 0.7 would still be weak. So no one rule, however tuned, can fix confirm; a better confirm has to combine features.
2. **Wrong links reach far.** A wrong link's reference is a median 54 sentences back, a right one 22, Claude's silver standard 25. Distance is the clearest sign of a lexical false positive.
3. **The mean-pooled sentence embedding says nothing about rightness** (AUC 0.55, silver standard 0.48), yet it is 65% of the score pick reads.
4. **Claude's silver standard links on fewer shared words, and by paraphrase.** Its links share less rare vocabulary than the engine's (IDF sum 4.3 vs 7.1) and their unshared words match the reference in meaning more (0.22 vs 0.00). Only 35.6% of them would pass R8's confirm: confirm looks for exactly the evidence Claude's silver standard relies on least.
5. **Engine phrases are short.** Claude's silver standard underlines 4 content words, the engine 2: a two-word event ("was both surprised", "seemed very heavy") carries one shared word, so it links on whatever sentence shares it.

### Single-feature rules, measured on the labelled links

| Rule | Engine right kept | Engine wrong kept | Precision | Hand links kept |
|---|---|---|---|---|
| R8's confirm (accepted links) | 851 | 611 | 49.5% | 425 |
| + token MaxSim ≥ 0.5 | 577 | 285 | 58.4% | 183 |
| + reference within 50 sentences | 594 | 277 | 58.0% | 303 |
| Rescue rejected links with soft lexical match ≥ 0.3 | +28 | +22 | 49% of the rescued | +156 |

Each filter raises precision by about 9 points but drops a third of the right links, the same trade the earlier evidence-by-distance trial (R18–R21) hit. The paraphrase rescue brings back silver-standard links at about R8's own precision.

### What a 30-link sample of wrong underlines shows

- **One shared word, different moment** (most of them): "bad effect", "heaps", "company", "chorus", "gate", "wall".
- **Same word, different sense**: "spring" (season vs liveliness), "middle", "lot".
- **A name alone**: Laurie, Jo, Beth, John, "Mother", "Marmar".
- **A phrase no reader would ask about**: "was both surprised", "Forgive me, Mother", "was one, Jo".

### So the engine fails because

1. **Pick refuses most good matches**: an absolute score dominated by a flat mean-pooled sentence embedding, plus a lead rule, so close or modest scores never get through (68% of Claude's silver-standard links that reach the top 6).
2. **Confirm asks for rare shared words**, which Claude's silver standard rarely relies on (only 36% of its links have them), and accepts any rare-lexical false positive, however far back.
3. **Detect makes short phrases** that carry one word of evidence.
4. **No single cheap feature tells right from wrong**, so fixing one rule moves precision and recall against each other.

## Features measured so far (2026-11-23)

AUC = how well the feature tells right links from wrong ones (0.50 a coin flip, 1.00 perfect; below about 0.60 is weak), shown in the direction that helps (for example "nearer is better"). **Right vs wrong**: the engine's own links judged right vs judged wrong (Little Women, 1,137 vs 1,167). **Claude vs wrong**: Claude's silver-standard links (1,195) vs the engine's wrong links. Values from `Experiments/retrieval/features.py`.

| # | Feature | Framework | In R8? | AUC right vs wrong | AUC Claude vs wrong | Verdict |
|---|---|---|---|---|---|---|
| 1 | Proximity (fewer sentences back) | `NLTokenizer` sentence numbers + Swift | small bonuses only | **0.68** | **0.67** | useful: wrong links reach far |
| 2 | Shared-word rarity (IDF sum) | `NLTagger` lemmas + Swift `WordStats` | search (35% of the score) | **0.68** | 0.61* | useful, but Claude's silver standard relies on it less |
| 3 | Soft lexical match (unshared words close in meaning) | `NLContextualEmbedding` word vectors in context + Swift | no | 0.53 | **0.69** (0.88 among links confirm rejects) | useful for finding Claude's silver-standard links |
| 4 | Phrase length (content words) | `NLTagger` word class + Swift | 3-word minimum only | 0.59 | **0.79** (partly from how the phrases were cut) | useful: short phrases make bad links |
| 5 | Rarest shared word (IDF max) | `NLTagger` + Swift | no | 0.66 | 0.62* | overlaps with #2 |
| 6 | Shared rare words (count) | `NLTagger` + Swift | confirm | 0.62 | 0.54* | weaker than #2 |
| 7 | Shared rare noun or adjective | `NLTagger` + Swift | confirm | 0.61 | 0.55* | weak |
| 8 | Token MaxSim (all words, contextual match) | `NLContextualEmbedding` word vectors + Swift | no | 0.61 | 0.76* | mixed; #3 is the useful part |
| 9 | Phrase vector vs reference | `NLContextualEmbedding` | no | 0.57 | 0.53 | weak |
| 10 | Mean-pooled sentence embedding (averaged token vectors) | `NLContextualEmbedding` (fallback `NLEmbedding`) | **search (65% of the score) and pick** | 0.55 | 0.52 | near useless |
| 11 | Same person name | `NLTagger` `.nameType` + Swift | confirm | 0.54 | 0.52 | near useless |
| 12 | Shared words outside the phrase | `NLTagger` + Swift | no | 0.53 | 0.54 | near useless |
| 13 | Reference sentence length | `NLTagger` + Swift | no | 0.52 | 0.56 | near useless |

\* Here Claude's silver-standard links score lower than the wrong links: they share fewer and less rare words than the engine's lexical false positives, so a high value points to a lexical false positive.

Tried earlier in full runs or recall tests, then dropped:

| Feature | Framework | Result |
|---|---|---|
| Word-sense check (R11) | `NLContextualEmbedding` word in context | +1.6 points, not worth the extra pass |
| Entities, rule-based coreference (stage 3) | `NLTagger` `.nameType` + Swift rules | no gain in recall |
| Semantic roles from the tagger (stage 5, rough SRL) | `NLTagger` `.lexicalClass` + `.lemma` + Swift rules | no gain in recall |
| Setting-word list (R9) | Swift word list | small gain, removed |
| Underline kind and Zwaan tracks | `NLTagger` + Swift word lists | removing them is better (R22, +0.4–1.4 points); kept only for iCloud |

Everything above runs on two Apple tools, `NLTagger`/`NLTokenizer` (words, lemmas, names) and `NLContextualEmbedding` (vectors), plus counting in Swift: no Core ML model, no Foundation Models (R8 is rules-only), no training. Claude only made the silver standards and the verdicts used to measure.

So R8's score leans on the weakest feature (#10), its confirm uses #6, #7 and #11, and two of the four useful features (#3 paraphrase, #4 phrase length) are not in the engine. No feature yet catches cause and consequence (two sentences that share neither words nor close words).
