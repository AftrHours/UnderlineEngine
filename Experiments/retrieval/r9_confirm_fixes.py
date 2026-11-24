#!/usr/bin/env python3
"""Scores stricter confirm rules on the links R9 already makes (every one labelled), per book.

    python3 -I Experiments/retrieval/r9_confirm_fixes.py

Reads Eval/results/features-<book>/r9-links.csv (R9ConfirmFeatures.swift). A fix can only remove links, so for each rule:
right links kept, wrong links kept, and precision (right / all kept; partial counts as not right).

R9 today: points = 2 for a shared rare noun or adjective + 1 for two or more shared rare words + 1 for soft match >= 0.3;
needs 2 within 50 sentences, 3 further.
F1  two or more shared words, unless the reference is at most 5 sentences back
F2  3 points needed from 21 sentences back (2 only within 20)
F3  only a rare noun earns 2 points; a rare adjective alone earns 1
F4  soft match threshold 0.4
F5  "two or more rare words" (and F1's two shared words) must sit in one clause of the reference
"""
import csv, itertools
from pathlib import Path

root = Path(__file__).resolve().parents[2]
books = ["little-women", "the-adventures-of-sherlock-holmes", "the-hobbit"]
short = {"little-women": "LW", "the-adventures-of-sherlock-holmes": "Sherlock", "the-hobbit": "Hobbit"}
rows = []
for b in books:
    f = root / f"Eval/results/features-{b}/r9-links.csv"
    for r in csv.DictReader(open(f, encoding="utf-8")):
        for k in ("distance", "shared", "rare", "rare_noun", "rare_adj", "rare_verb", "same_clause_shared"):
            r[k] = int(r[k])
        r["soft"] = float(r["soft"])
        rows.append(r)


def rule(fixes):
    f1, f2, f3, f4, f5 = (n in fixes for n in ("F1", "F2", "F3", "F4", "F5"))
    def ok(r):
        t = 0.4 if f4 else 0.3
        if f3:
            noun_pts = 2 if r["rare_noun"] >= 1 else (1 if r["rare_adj"] >= 1 else 0)
        else:
            noun_pts = 2 if (r["rare_noun"] + r["rare_adj"]) >= 1 else 0
        two_rare = (r["same_clause_shared"] >= 2 and r["rare"] >= 2) if f5 else r["rare"] >= 2
        pts = noun_pts + (1 if two_rare else 0) + (1 if r["soft"] >= t else 0)
        d = r["distance"]
        need = (2 if d <= 20 else 3) if f2 else (2 if d <= 50 else 3)
        if pts < need:
            return False
        if f1 and d > 5:
            n_shared = r["same_clause_shared"] if f5 else r["shared"]
            if n_shared < 2:
                return False
        return True
    return ok


def score(ok):
    out = {}
    for b in books + ["all"]:
        sel = [r for r in rows if (b == "all" or r["book"] == b) and ok(r)]
        y = sum(r["verdict"] == "yes" for r in sel)
        n = sum(r["verdict"] == "no" for r in sel)
        out[b] = (len(sel), y, n, 100 * y / max(len(sel), 1))
    return out


base = score(rule(()))
unl = sum(r["verdict"] == "unlabelled" for r in rows)
print(f"links: {len(rows)} (unlabelled {unl})\n")
hdr = "| Rule | " + " | ".join(f"{short[b]} kept / right / wrong / precision" for b in books) + " | All: right kept | All: wrong removed | All precision |"
print(hdr)
print("|" + "---|" * (len(books) + 4))
results = []
for k in range(0, 6):
    for combo in itertools.combinations(["F1", "F2", "F3", "F4", "F5"], k):
        s = score(rule(combo))
        name = "R9 today" if not combo else " + ".join(combo)
        cells = [f"{s[b][0]} / {s[b][1]} / {s[b][2]} / {s[b][3]:.1f}%" for b in books]
        a = s["all"]
        kept = 100 * a[1] / base["all"][1]
        removed = 100 * (base["all"][2] - a[2]) / max(base["all"][2], 1)
        results.append((a[3], name, "| " + name + " | " + " | ".join(cells) + f" | {a[1]} ({kept:.0f}%) | {base['all'][2] - a[2]} ({removed:.0f}%) | {a[3]:.1f}% |"))
for r in sorted(results, key=lambda x: -x[0]):
    print(r[2])
