# UnderlineEngine: experiment results

Task: for a phrase $p$ in a novel, return the earlier sentence it refers back to, or nothing. Every number below comes from the `bookRun` test on this Mac (Apple silicon) and is scored with LLM-as-judge labels (Claude), not human labels. Full per-run records: `docs/record.md`.

## 1. Data

| Book | Chapters | Paragraphs | Sentences | Words | Phrases $p$ evaluated |
|---|---|---|---|---|---|
| Little Women | 47 | 3,798 | 9,617 | 185,663 | 18,718 |
| Pride and Prejudice | 61 | 2,059 | 6,024 | 121,553 | 11,535 |
| The Adventures of Sherlock Holmes | 12 stories | 2,523 | 6,887 | 104,348 | 9,767 |
| Anne of Green Gables | 38 | – | – | 101,965 | – |
| Moby-Dick | 136 | – | – | 207,769 | – |
| The Hobbit ¹ | 19 | 1,852 | 6,124 | 95,176 | 9,142 |
| Before the Coffee Gets Cold ¹ | 4 | 2,415 | 5,237 | 55,506 | 5,797 |
| Sunrise on the Reaping ¹ | 28 | 3,040 | 10,861 | 112,751 | 11,572 |

¹ Copyrighted: text, labels and silver standard stay local, never committed. Texts: `Dataset/<book>/` (`Dataset/epub_to_chapters.py`). Labels: `Dataset/labels/claude-labels*.csv`, keyed by (chapter, $t$, $p$, $j$), so a label is reused whenever a run makes the same link.

## 2. Notation

- Phrase $p$ in sentence $s_t$. Candidates: earlier sentences $s_j$ of the same chapter, $j < t$, $\text{para}(j) < \text{para}(t)$. Distance $d = t - j$.
- $L(x)$: content lemmas of $x$ (nouns, verbs, adjectives; `NLTagger`; minus a stop-list). $\text{names}(x)$: person names (`NLTagger .nameType`).
- Book statistics: $N$ sentences, $\text{df}(w)$ sentences containing $w$. $\text{IDF}(w) = \ln\big(1 + N/\text{df}(w)\big)$. $\text{rare}(w) \iff \text{df}(w) \le \max(2,\ \rho N)$.
- Shared lemmas $Sh_j = L(p) \cap L(s_j)$; shared rare lemmas $R_j = \{w \in Sh_j : \text{rare}(w)\}$.
- Lexical score $W_j = \sum_{w \in Sh_j} \text{IDF}(w) \,/\, \sum_{w \in L(p)} \text{IDF}(w)$.
- Embedding score $V_j = \text{clip}_{[0,1]}\big(a\,c(e(p), e(s_j)) + b\big)$, $c = (1+\cos)/2$, $e$ = mean-pooled sentence embedding (`NLEmbedding`, or `NLContextualEmbedding` centred on the book mean); $(a, b) = (0.703, 0.295)$ for the contextual model, $(1, 0)$ otherwise.
- Token MaxSim $M_j(U) = \sum_{w \in U} \text{IDF}(w) \max_{u \in s_j} \cos(h_w, h_u) \,/\, \sum_{w \in U} \text{IDF}(w)$, $h$ = contextual token vectors centred on the chapter mean. $M^{\text{all}}_j = M_j(L(p))$, $M^{\text{new}}_j = M_j(L(p) \setminus L(s_j))$.
- Raw score $r_j = \lambda V_j + (1-\lambda) W_j$. Ranking score $S_j = \lambda \tilde V_j + (1-\lambda) \tilde W_j + \beta_j$, with $\tilde{\ }$ = min–max over the pool and $\beta_j$ = kind/track bonuses. Retrieval $K$ = top $k$ by $S$ with $r_j \ge \phi$.
- Selection $\text{P}(\tau, \delta)$: $j^* = \arg\max_K S$, kept iff $r_{j^*} \ge \tau$ and $r_{j^*} - r_{j_2} \ge \delta$.
- Verification $C_8(j) \iff \big(\exists\, w \in R_j \text{ noun/adj}\big) \vee |R_j| \ge 2 \vee \text{names}(p) \cap \text{names}(s_j) \ne \emptyset$.
- Points $\pi_j = 2\cdot\mathbb{1}[\exists\, w \in R_j \text{ noun/adj}] + \mathbb{1}[|R_j| \ge 2] + \mathbb{1}[M^{\text{new}}_j \ge 0.3]$; threshold $\theta(d) = 2$ if $d \le 50$, else $3$.
- Output: the engine's links $\hat P = \{(t, j)\}$. Silver standard $G$: links Claude picked while reading; $G^+ \subseteq G$ those labelled right.

## 3. Evaluation

- Label $y \in \{\text{right}, \text{partial}, \text{wrong}\}$ per link, LLM-as-judge (Claude reads $s_t$ with $p$ marked, and $s_j$). Partial = related but not the exact moment.
- Precision $= \#\text{right} / |\hat P|$ (partial counts as not right). Exact when every link is labelled; † = estimated from earlier labels plus a uniform random sample of 150 unlabelled links, with a 95% CI.
- Silver-standard recall $= |\hat P \cap G^+| / |G^+|$, matched as sentence pairs $(t, j)$.
- Retrieval recall@$k = \Pr[\text{rank}(j_{\text{gold}}) \le k]$ over $G^+$, before selection and verification.
- Feature separation: AUC $= \Pr[f(x^+) > f(x^-)]$, $x^+$ a right link, $x^-$ a wrong one (0.5 = none; < 0.5 = lower values are right).
- Bias: the thresholds were tuned on the same labels they are scored on, and Claude also made $G$; both numbers are likely optimistic. No human labels yet.

## 4. Target: the silver standard $G$

| Book | $\lvert G \rvert$ | Precision of $G$ | Wrong in $G$ | Right links / 1,000 words |
|---|---|---|---|---|
| The Adventures of Sherlock Holmes ² | 516 | **95.3%** | 2 | 4.7 |
| Little Women | 1,507 | **79.3%** | 16 | 6.4 |
| Pride and Prejudice | 788 | **81.9%** | 8 | 5.3 |
| Anne of Green Gables | 722 | **89.5%** | 4 | 6.3 |
| Moby-Dick | 1,353 | **86.8%** | 6 | 5.7 |
| Sunrise on the Reaping | 2,655 | not labelled | – | – |

² The hand seed bundled in iRead (`UnderlineSeed/048b…`); may cross chapters and was labelled by the same Claude session that made it. The others: same chapter, $\text{para}(j) < \text{para}(t)$, made by ten agents and labelled by twelve other agents; one Little Women batch was stricter (84.8% without it). Files: `Dataset/labels/handpick-<book>/`, checked by `handpick_check.py`.

## 5. Pipeline (R8, UnderlineEngine 1.2.0, in iRead)

| Stage | Function | Apple API |
|---|---|---|
| 0 Clean | drop Gutenberg header, licence, contents (not yet wired in) | Swift only |
| 1 Prepare | sentences; $L(x)$, word class, $\text{names}(x)$; $e(x)$; $\text{df}$ over the book | `NLTokenizer`, `NLTagger`, `NLContextualEmbedding` (fallback `NLEmbedding` after 10 s) |
| 2 Detect | phrases $p$: clauses of ≥ 3 words, not only general words; names unseen in the last 30 sentences | Swift only |
| 3 Retrieve | $K$: top $k = 6$ by $S_j$, $\lambda = 0.65$, $r_j \ge \phi = 0.35$ | Swift only |
| 4 Select + verify | $\text{P}(0.60, 0.05)$, then $C_8(j^*)$ with $\rho = 0.004$ | Swift only (`FoundationModels` confirm exists but is off) |
| 5 Limit | no overlapping underlines; drop $s_j$ in the same paragraph | Swift only |

No Core ML model and no training.

### R8 and R9 by stage

| Stage | R8 | R9 | Different? |
|---|---|---|---|
| 1 Prepare | Split sentences, tag words, compute a mean-pooled sentence vector, count word rarity over the book, and cut events with role, track and kind. | The same, plus contextual vectors for each content word, computed when a chapter's links are first verified (for the soft lexical match). | Small addition |
| 2 Detect | Event phrases of 3+ words, plus names not seen in the last 30 sentences. | The same. | No |
| 3 Retrieve | Score = 0.65 × sentence-vector similarity + 0.35 × shared rare words + role bonuses + Zwaan track bonuses; must clear a floor; top 6. | Score = shared rare words + role bonuses; no sentence vector and no Zwaan bonuses; top 6. | Yes |
| 4 Select + verify | Selection takes only the top candidate, and only if its score is at least 0.60 and 0.05 ahead of the second. Verification accepts a shared rare noun or adjective, two shared rare words, or the same name. | Selection takes, of the top 6, any candidate sharing a content word, nearer first when scores are close, with no minimum score or lead. Verification counts evidence points (rare noun or adjective 2, two rare words 1, soft lexical match 1) and needs 2 within 20 sentences, 3 further; a shared name counts like any shared noun. | Yes, the biggest change |
| 5 Limit | No overlapping underlines; on a full tie, kind decides. | The same, but kind never decides. | Tiny |

R8 decides mostly in selection (strict: most phrases stop there) and verifies leniently; R9 lets almost everything through selection and decides in verification, with evidence that gets stricter with distance. Stages 1, 2 and 5 are practically the same, so the whole difference in output comes from stages 3 and 4.

## 6. Ablation: main versions

Precision per book. "–" = not run. \* = the seed bundled with iRead 1.1.0 (iRead's own text split, licence included), not a `bookRun`.

| Version | Definition | Sherlock | Little Women | Hobbit | Coffee | Sunrise | Pride and Prejudice | Anne | Moby-Dick |
|---|---|---|---|---|---|---|---|---|---|
| **Release 1.1.0** | $e$ = `NLEmbedding`; IDF ≡ 1; $\text{P}(\tau, \delta)$, then Foundation Models yes/no instead of $C_8$; ≤ 1 link per paragraph | – | 24.8%\* | 36.2% | 35.3% | – | 45.1%\* | 27.5%\* | 24.5%\* |
| **R8** (shipped) | $e$ = `NLContextualEmbedding`; $\lambda = 0.65$, $k = 6$, $\phi = 0.35$; $\text{P}(0.60, 0.05)$; $C_8$, $\rho = 0.004$; $\beta_j \ne 0$ | 54.6% | 51.6% | 60.8% | 48.5% | – | – | – | – |
| **R22** (not shipped) | R8 with $\beta_j = 0$ | 55.0% | 53.0% | 61.5% | 49.2% | 42.4% | – | – | – |
| **R9** (with the distance fix) | $\lambda = 0$; $K$ = top 6 with $W_j > 0$, ties within 0.05 to larger $j$; no $\text{P}$; first $j \in K$ with $\pi_j \ge \theta(d)$, $\theta = 2$ for $d \le 20$, 3 further | 45.2% | 43.4% | 43.1% | 50.4% | ≈ 47.2%† | ≈ 44.0%† | 48.6% | ≈ 36.7%† |
| **$G$** (target) | picked by Claude while reading | 95.3% | 79.3% | – | – | – | 81.9% | 89.5% | 86.8% |

| Change | Effect |
|---|---|
| Release → R8 | FM yes/no → $C_8$, `NLEmbedding` → `NLContextualEmbedding`, IDF ≡ 1 → book IDF: precision +14 to +25 points (Hobbit, Coffee) |
| R8 → R22 | $\beta_j \to 0$: +0.4 to +1.4 points on every book; +39 right, −5 wrong over four books; 92% of links unchanged. Not shipped: iRead stores the kind in iCloud records |
| R8 → R9 before the distance fix (Little Women, every link labelled) | $\lvert \hat P \rvert$ 836 → 1,980; #right 431 → 775; #partial 129 → 443; #wrong 276 → 762; precision 0.516 → 0.391; silver-standard recall 0.070 → 0.145. By $d$: ≤ 20 sentences 0.487 (1,035 links), 21–50 0.303 (687), > 50 0.244 (258). Without $\text{P}$, 4.5× as many pairs reach verification |
| R8 → R9 before the distance fix (Sherlock, every link labelled) | $\lvert \hat P \rvert$ 857 → 1,609; #right 468 → 682; #partial 99 → 363; #wrong 290 → 564; precision 0.546 → 0.424. By $d$: ≤ 20 sentences 0.491 (640 links), 21–50 0.393 (453), > 50 0.368 (516) |
| R8 → R9 before the distance fix (Hobbit, every link labelled) | $\lvert \hat P \rvert$ 525 → 1,026; #right 319 → 420; #partial 86 → 273; #wrong 120 → 333; precision 0.608 → 0.409. By $d$: ≤ 20 sentences 0.508 (492 links), 21–50 0.360 (331), > 50 0.251 (203) |
| R9 distance fix ($\theta$: 2 points within 50 → within 20) | Removes only links: Little Women 1,980 → 1,469 (right 775 → 637, 43.4%), Sherlock 1,609 → 1,300 (682 → 588, 45.2%), Hobbit 1,026 → 795 (420 → 343, 43.1%). Against R8: more right links on every book measured (Little Women 637 vs 431, Sherlock 588 vs 468, Hobbit 343 vs 319, Coffee 300 vs 266) at 8–17 points lower precision except Coffee (50.4% vs 48.5%). † = estimated from earlier labels plus a random sample of 150 new links (95% CI: Sunrise 43.1–51.3%, Pride and Prejudice 40.5–47.6%, Moby-Dick 29.6–43.7%) |
| R8 vs $G$ | silver-standard recall of R8: 0.06 (Little Women); of R22: 0.04 (Sunrise). The engine and $G$ contain mostly different links |

## 7. Where links are lost (Little Women)

Retrieval recall@$k$ of $G^+$ (1,195 links; pool median 109 sentences, $d$ median 25):

| Ranking | @1 | @3 | @6 | @10 | @20 | @50 |
|---|---|---|---|---|---|---|
| $S_j$ (R8) | 28.6% | 44.2% | 53.1% | 59.9% | 67.9% | 81.9% |
| $V_j$ only | 9.3% | 17.2% | 24.5% | 32.6% | 45.4% | 69.7% |
| $W_j$ only | 35.2% | 50.3% | 60.1% | 67.6% | 75.8% | 86.1% |
| BM25 ($k_1 = 1.2$, $b = 0.75$) | 33.1% | 48.4% | 58.5% | 65.8% | 75.6% | 86.1% |
| $M^{\text{all}}_j$ only | 32.1% | 46.6% | 55.6% | 63.1% | 73.1% | 84.6% |
| $\tfrac12 \tilde W_j + \tfrac12 \tilde M^{\text{all}}_j$ | 36.4% | 51.8% | 60.7% | 66.9% | 75.1% | 86.2% |
| random | 2.7% | 6.7% | 11.6% | 17.1% | 29.0% | 54.6% |

| Stage | Share of $G^+$ still reachable |
|---|---|
| Detect produces a $p$ overlapping the silver-standard phrase | 88.3% |
| $j_{\text{gold}} \in K$ | 53.1% |
| both | 47.7% |
| $(t, j_{\text{gold}}) \in \hat P$ (R8) | 7% |

- Most of the loss is in selection + verification (47.7% → 7%), not retrieval.
- $V_j$ is the weakest signal and lowers recall when mixed in ($W_j$ alone beats $S_j$ by 7 points at @6). But dropping it alone ($\lambda = 0$ with R8's untuned words-mode $\text{P}(0.50, 0.15)$) lowered end-to-end precision.
- Entity resolution (he/she → last person of that gender) and rule-based semantic roles added to $W_j$ changed @6 by ≤ 0.4 points.

## 8. Feature analysis for verification (Little Women)

2,657 labelled engine links (1,137 right · 353 partial · 1,167 wrong) and 1,195 links of $G^+$. `Tests/UnderlineEngineEvals/LinkFeatures.swift`, `Experiments/retrieval/features.py`.

| Feature $f$ | Median, right | Median, wrong | Median, $G^+$ | AUC right vs wrong |
|---|---|---|---|---|
| $d$ | 22 | 54 | 25 | **0.32** |
| $\sum_{w \in Sh_j} \text{IDF}(w)$ | 7.1 | 5.7 | 4.3 | 0.68 |
| $\mathbb{1}[R_j \ne \emptyset]$ | 1 | 0 | 0 | 0.62 |
| $M^{\text{all}}_j$ | 0.59 | 0.53 | 0.34 | 0.61 |
| $c(e(p), e(s_j))$ | 0.61 | 0.57 | 0.56 | 0.57 |
| $c(e(s_t), e(s_j))$ | 0.65 | 0.63 | 0.62 | 0.55 |
| $\mathbb{1}[\text{names}(p) \cap \text{names}(s_j) \ne \emptyset]$ | 0 | 0 | 0 | 0.54 |
| $M^{\text{new}}_j$ | 0.12 | 0.00 | 0.22 | 0.53 |
| $\lvert (L(s_t) \setminus L(p)) \cap L(s_j) \rvert$ | 0 | 0 | 0 | 0.53 |

- $d$ separates best; embedding, name and outside-phrase features are near chance (0.53–0.57).
- $C_8$ rejects 64% of $G^+$: silver-standard links share fewer and commoner lemmas ($\sum \text{IDF}$ 4.3 vs 7.1) and have higher $M^{\text{new}}_j$ (0.22 vs 0.12).

Verification rules scored offline on the same links (so optimistic):

| Rule | Right | Partial | Wrong | Precision | Share of $G^+$ accepted |
|---|---|---|---|---|---|
| $C_8$ | 851 | 258 | 611 | 49.5% | 35.6% |
| $C_8 \wedge (d \le 50 \vee M^{\text{all}} \ge 0.6)$ | 738 | 180 | 362 | 57.7% | 27.6% |
| $C_8 \vee d \le 20$ | 1,020 | 301 | 745 | 49.4% | 64.4% |
| $\big(C_8 \wedge (d \le 50 \vee M^{\text{all}} \ge 0.6)\big) \vee d \le 20$ | 907 | 223 | 496 | 55.8% | 56.4% |

In full runs on The Hobbit and Sherlock Holmes the last rule did not generalise: links added by $d \le 20$ alone were about 25% right, and the far filter removed right links with wrong ones. $d$ helps only together with lexical evidence.

## 9. Oracle experiment E1: semantic role labelling (Little Women ch. 1–5)

Each sentence as role tuples (agent, predicate, patient, location); link $s_t \to s_j$ iff the patients match and one more role matches (nearest, most roles first).

| Roles from | $\lvert \hat P \rvert$ | Precision | Silver-standard recall |
|---|---|---|---|
| Claude (pronouns resolved, consistent naming) | 311 | 46.6% (145 right) | 0.18 |
| `NLTagger` rules (rough) | 95 | not labelled | 0.04 |
| R8, same chapters | 97 | 51.5% (50 right) | 0.10 |

- With ideal roles: ~3× R8's right links at similar precision, and only 14 links shared with R8. No equal-role rule can reach more than 27–41% of $G^+$ (most silver-standard links are paraphrases or consequences).
- With rough roles the gain disappears (whole book: recall 0.02 vs R8 0.07): it needs coreference and consistent naming, which `NLTagger` does not give. `Experiments/srl/`.

## 10. Bundled seeds in iRead (counts only, not labelled)

| Book | Seed 1.1.0 | Seed 1.2.0 (R8) | Same link in both |
|---|---|---|---|
| Little Women | 1,826 (Foundation Models) | 892 | 130 |
| Pride and Prejudice | 284 (rules) | 201 | 65 |
| Anne of Green Gables | 1,020 (Foundation Models) | 643 | 138 |
| Moby-Dick | 1,175 (Foundation Models) | 744 | 134 |
| Sherlock Holmes | 516 (hand) | 516 (hand) | 516 |

The 1.1.0 seeds are fully labelled (precision in §6, marked \*); the 1.2.0 seeds are not. Both put 35–39 links per book in the Gutenberg licence, which iRead parses as a chapter. Pride and Prejudice's EPUB is split into 472 parts, so the within-part search finds few links.

## 11. Runtime (Little Women, Mac)

Total = whole test including Prepare; Processing = retrieval + selection + verification.

| Run | Total (s) | Prepare (s) | Processing (s) | s / chapter | ms / sentence | ms / word (total) |
|---|---|---|---|---|---|---|
| R1 | 225 | ≈ 0 | 226 | 4.8 | 23.5 | 1.21 |
| R2 | 233 | 59 | 174 | 3.7 | 18.1 | 1.26 |
| R3 | 243 | 61 | 182 | 3.9 | 18.9 | 1.31 |
| R5 | 230 | 60 | 170 | 3.6 | 17.7 | 1.24 |
| R6 | 375 | 111 | 264 | 5.6 | 27.5 | 2.02 |
| R7 | 377 | 112 | 265 | 5.6 | 27.6 | 2.03 |
| R8 | 400 | 117 | 283 | 6.0 | 29.4 | 2.15 |
| RC (1.1.0, Coffee) | 3,280 | – | 3,280 | 820.1 | 626.4 | 59.10 |
| RH (1.1.0, Hobbit) | 4,431 | – | 4,431 | 233.2 | 723.6 | 46.56 |

## 12. R8 parameters

| Symbol | Value | Code |
|---|---|---|
| $\lambda$ | 0.65 | `SearchKnobs.embedWeight` |
| $k$, $\phi$ | 6, 0.35 | `SearchKnobs.maxCandidates`, `minRawScore[.both]` |
| $(a, b)$ | 0.703, 0.295 | `SearchKnobs.similarityScale[.contextual]` |
| $\rho$ | 0.004 (min 2 sentences) | `WordKnobs.rareShare`, `rareMin` |
| $\tau$, $\delta$ | 0.60, 0.05 | `JudgeKnobs.minScore[.both]`, `margin[.both]` |
| $\beta_j$ | track hint 0.10, cause nearby 0.15 / $(1+d)$, role link 0.10, reaction nearby 0.30 / $(1+d)$ | `SearchKnobs` |
| min $\lvert p \rvert$, name gap | 3 words, 30 sentences | `UnderlineKnobs` |
| paragraph cap | none | `UnderlineKnobs.maxPerParagraph` |
| verification | rules only ($C_8$) | `ModelChoice.rulesOnly` |

## 13. Notes

- R8 rerun through the public API (2026-11-19): 836 links, 431 right, 129 partial, 276 wrong (51.6%); 826 identical to the first run. The thresholds were chosen with a 360-setting sweep (`Eval/results/rules-parameter-sweep-contextual/`).
- R8 kept $\beta_j$ and the kind (R22 is better) because iRead stores `kind` in iCloud chapters and shared ratings; the restored engine reproduces R15 exactly (549 of 549 links).
- Sunrise (R26, R22 engine): 812 links, 42.4%; 111 of them in $G$ (counted right without review), the other 701 labelled by four Claude agents.
- RH and RC ran the 1.1.0 tag with `UnderlineCtrl(model: .automatic)`, as the app did; 135 of their links are shorter than 3 words, 101 of those wrong.
- iRead pins UnderlineEngine 1.2.0 (R8, rules only, `NLContextualEmbedding`, book-level df).
