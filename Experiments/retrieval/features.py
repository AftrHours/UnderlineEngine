#!/usr/bin/env python3
"""Which link features separate right links from wrong ones? Reads Eval/results/features-<book>/links.csv (LinkFeatures.swift).

    python3 -I Experiments/retrieval/features.py little-women

Groups: engine links judged yes / partial / no, and hand-picked links judged right ("hand"). For each feature: medians per
group and AUC (the chance a random right link scores higher than a random wrong one; 0.5 = no separation, below 0.5 = wrong
links score higher). Then the two confirm questions: among links R8's confirm accepts, which feature drops wrong ones; among
links it rejects (older runs with a looser confirm), which feature would rescue right ones.
"""
import csv, statistics, sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
book = sys.argv[1] if len(sys.argv) > 1 else "little-women"
rows = list(csv.DictReader(open(root / f"Eval/results/features-{book}/links.csv", encoding="utf-8")))
features = ["distance", "phrase_words", "ref_words", "shared_phrase", "shared_sentence_only", "rare_phrase", "rare_noun_adj_phrase",
            "rare_sentence_only", "idf_sum_phrase", "idf_max_phrase", "same_name", "r8_confirm", "soft", "soft_novel",
            ]
for r in rows:
    for f in features:
        r[f] = float(r[f])


def group(source, verdict=None, where=lambda r: True):
    return [r for r in rows if r["source"] == source and (verdict is None or r["verdict"] == verdict) and where(r)]


def auc(pos, neg, f):
    if not pos or not neg:
        return float("nan")
    neg_sorted = sorted(r[f] for r in neg)
    import bisect
    total = 0.0
    for p in pos:
        lo = bisect.bisect_left(neg_sorted, p[f])
        hi = bisect.bisect_right(neg_sorted, p[f])
        total += lo + 0.5 * (hi - lo)
    return total / (len(pos) * len(neg))


yes, partial, no, hand = group("engine", "yes"), group("engine", "partial"), group("engine", "no"), group("hand")
print(f"rows: engine yes {len(yes)} · partial {len(partial)} · no {len(no)} · hand {len(hand)}\n")
print("| Feature | yes | partial | no | hand | AUC yes vs no | AUC hand vs no |")
print("|---|---|---|---|---|---|---|")
for f in features:
    med = lambda g: statistics.median(r[f] for r in g) if g else float("nan")
    print(f"| {f} | {med(yes):.2f} | {med(partial):.2f} | {med(no):.2f} | {med(hand):.2f} | {auc(yes, no, f):.2f} | {auc(hand, no, f):.2f} |")

acc = lambda r: r["r8_confirm"] == 1
for title, where in (("accepted by R8's confirm", acc), ("rejected by R8's confirm", lambda r: not acc(r))):
    y, n = group("engine", "yes", where), group("engine", "no", where)
    h = group("hand", where=where)
    print(f"\n## Links {title}: engine yes {len(y)} · no {len(n)} · hand {len(h)}")
    print("| Feature | AUC yes vs no | AUC hand vs no |")
    print("|---|---|---|")
    for f in features:
        print(f"| {f} | {auc(y, n, f):.2f} | {auc(h, n, f):.2f} |")

print("\n## Hand-picked right links: share R8's confirm accepts")
print(f"{100 * sum(acc(r) for r in hand) / max(len(hand), 1):.1f}% of {len(hand)}")


def rule_table(name, feature, thresholds, base):
    """Precision and counts if `feature >= t` is required (filter) or allowed (rescue) on top of `base` links."""
    print(f"\n## {name}")
    print("| Threshold | engine yes kept | engine no kept | precision (yes ÷ yes+partial+no) | hand kept |")
    print("|---|---|---|---|---|")
    for t in thresholds:
        sel = lambda g: [r for r in g if base(r) and r[feature] >= t]
        y, p, n, h = sel(yes), sel(partial), sel(no), sel(hand)
        prec = len(y) / max(len(y) + len(p) + len(n), 1)
        print(f"| {feature} ≥ {t} | {len(y)} | {len(n)} | {100 * prec:.1f}% | {len(h)} |")


for r in rows:
    r["neg_distance"] = -r["distance"]
for f, ts in (("soft", [0.0, 0.3, 0.4, 0.5, 0.6]), ("soft_novel", [0.0, 0.2, 0.3, 0.4]),
              ("neg_distance", [-1000, -100, -50, -20])):
    rule_table(f"Filter on accepted links: {f}", f, ts, acc)
    rule_table(f"Rescue among rejected links: {f}", f, ts, lambda r: not acc(r))
