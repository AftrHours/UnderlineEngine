# UnderlineEngine: constraints

Limits of the current approach that tuning cannot remove. Each one says what the limit is, the evidence for it, and what it would take to get past it.

## 1. Word-based rules cannot judge most of the links a careful reader makes (2026-11-24)

**The limit.** The engine runs on Apple's NaturalLanguage tools and rules: `NLTagger` (words, lemmas, word classes, names), `NLContextualEmbedding` (word and sentence vectors) and counting in Swift. Every check in verification comes down to comparing words:

- shared words: are the same lemmas in both sentences?
- rare words: are those lemmas uncommon in the book?
- word vectors (soft lexical match): are the words similar in meaning?

These can tell that **the same words came back**. They cannot tell that **the same moment of the story came back**.

**Two cases word comparison cannot tell apart.**

| Case | Example | Right? |
|---|---|---|
| Same moment, different words | "Jo spent the dollar on a book" ← "Each of us has a dollar, and the army doesn't want our money" (the girls' Christmas money) | right |
| Similar words, different moment | "Jo spent the dollar on a book" ← "Meg saw money lavished on trifles at the Kings'" (another scene) | wrong |

To word vectors both earlier sentences are about equally similar (dollar ≈ money, spend ≈ lavish).

**What the silver standard needs.** The links Claude picked while reading (the silver standard) are mostly of two kinds:

- **Paraphrases**: the same thing in other words ("the dollar" ↔ "Christmas money").
- **Consequences and feelings**: the later sentence is a result of the earlier one, often with no similar words at all ("She regretted it all evening" ← "Jo snapped at Amy and slammed the door").

Making these links needs knowing that "the dollar" is the Christmas money mentioned earlier, that regret is a reaction to something that happened, and which earlier moment a sentence refers back to. That is reading comprehension, not word comparison.

**Evidence (Little Women).**

- 75% of the silver standard (892 of 1,195 links) fails R9's word evidence.
- Letting verification try more candidates (depth 2 and 3) raised silver-standard recall only from 14.5% to 15.6%: the right sentence is often among the candidates, and verification still rejects it.
- Meaning alone does not separate right from wrong: on links that fail word evidence, the soft lexical match of silver-standard links (median 0.21) overlaps heavily with that of wrong links (75th percentile 0.18). In a real run, links confirmed by a soft match alone within 20 sentences were 23% right (R9 first try, 25 of 107 sampled).
- The best rule-only versions find 7–16% of the silver standard (R8 7.0%, R9 14.5%).

**What it would take.**

1. A language model in verification, only for candidates the rules cannot judge: Foundation Models on the device (Apple Intelligence phones only, slower; release 1.1.0's model confirm scored 35%, so it needs a narrow, well-prompted use).
2. Links made offline by Claude for the books iRead bundles, shipped like the seeds (best quality, bundled books only).
3. Training a model is ruled out for now.

Until one of these, rule changes can trade precision against recall but cannot reach most of a reader's links.
