#!/usr/bin/env python3
"""Tries verification rules offline on labelled links (Eval/results/features-<book>/links.csv, LinkFeatures.swift).

    python3 -I Experiments/retrieval/verify_rules.py little-women

Each rule gives a link evidence points and asks for more points the further back its reference is:
  +2  a shared rare noun or adjective in the phrase
  +1  two or more shared rare words in the phrase
  +1  soft lexical match (unshared phrase words close in meaning to the reference, token MaxSim) >= t
needed: n1 within 20 sentences, n2 within 50, n3 further.
For each rule: engine links kept (right / partial / wrong), precision among them, and the share of the silver standard kept.
The baseline is R9's verification today (R8's confirm without name-only links). Engine links come from many runs, so these
numbers say which rule separates better, not what a run will score.
"""
import csv, itertools, sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
book = sys.argv[1] if len(sys.argv) > 1 else "little-women"
rows = list(csv.DictReader(open(root / f"Eval/results/features-{book}/links.csv", encoding="utf-8")))
for r in rows:
    for f in ("distance", "rare_phrase", "rare_noun_adj_phrase", "soft_novel", "idf_sum_phrase"):
        r[f] = float(r[f])
engine = [r for r in rows if r["source"] == "engine"]
hand = [r for r in rows if r["source"] == "hand"]


def baseline(r):
    return r["rare_noun_adj_phrase"] >= 1 or r["rare_phrase"] >= 2


def points_rule(n1, n2, n3, t):
    def rule(r):
        pts = 2 * (r["rare_noun_adj_phrase"] >= 1) + 1 * (r["rare_phrase"] >= 2) + 1 * (r["soft_novel"] >= t)
        d = r["distance"]
        need = n1 if d <= 20 else n2 if d <= 50 else n3
        return pts >= need
    return rule


def report(name, rule):
    kept = [r for r in engine if rule(r)]
    y = sum(r["verdict"] == "yes" for r in kept)
    p = sum(r["verdict"] == "partial" for r in kept)
    n = sum(r["verdict"] == "no" for r in kept)
    h = sum(rule(r) for r in hand)
    prec = 100 * y / max(len(kept), 1)
    return (prec, y, name, f"| {name} | {y} | {p} | {n} | {prec:.1f}% | {h} ({100 * h / max(len(hand), 1):.1f}%) |")


print(f"engine links: {len(engine)} (yes {sum(r['verdict']=='yes' for r in engine)}, no {sum(r['verdict']=='no' for r in engine)}) · silver standard: {len(hand)}\n")
print("| Rule | Right kept | Partial kept | Wrong kept | Precision | Silver standard kept |")
print("|---|---|---|---|---|---|")
base = report("R9 today (rare noun/adj or 2 rare words)", baseline)
print(base[3])
results = []
for n1, n2, n3, t in itertools.product([1, 2], [2, 3], [3, 4], [0.3, 0.4]):
    if not n1 <= n2 <= n3:
        continue
    results.append(report(f"points ≥ {n1} / {n2} / {n3} (≤20 / ≤50 / further), soft ≥ {t}", points_rule(n1, n2, n3, t)))
for r in sorted(results, key=lambda x: (-x[0], -x[1])):
    print(r[3])
