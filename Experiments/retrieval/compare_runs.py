#!/usr/bin/env python3
"""Compares two book runs of the same book: underline counts, how many already have a Claude verdict (and how those split),
how many links the two runs share, and how many land on a hand-picked link judged right (as sentence pairs).

    python3 -I Experiments/retrieval/compare_runs.py little-women book-little-women-rules-contextual.r8 book-little-women-r8-words-contextual

Verdicts: Dataset/labels/claude-labels.csv (Little Women), keyed by chapter, sentence, phrase, reference.
Hand pick: Dataset/labels/handpick-<book>/chNN.txt with verdicts in claude-labels-handpick-<book>.csv; sentence numbers from
Experiments/srl/data/<book>-chNN-sentences.json (split.py).
"""
import csv, json, sys
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parents[2]
book, run_a, run_b = sys.argv[1], sys.argv[2], sys.argv[3]
labels_file = root / ("Dataset/labels/claude-labels.csv" if book == "little-women" else f"Dataset/labels/claude-labels-{book}.csv")
verdict = {}
with open(labels_file, encoding="utf-8") as f:
    for r in csv.DictReader(f):
        verdict[(int(r["chapter"]), int(r["sentence"]), r["phrase"], int(r["reference"]))] = r["verdict"]


def sentence_at(sentences, offset):
    if offset < 0:
        return None
    for s in sentences:
        if s["start"] <= offset < s["end"]:
            return s["id"]
    return None


def load(run):
    links = {}  # (chapter, sentence, phrase, reference) -> (sentence_text, reference_text)
    for path in sorted((root / "Eval/results" / run).glob("ch*.csv")):
        n = int(path.stem[2:])
        with open(path, encoding="utf-8-sig") as f:
            for r in csv.DictReader(f):
                if r["underlined"] == "yes":
                    links[(n, int(r["sentence"]), r["phrase"], int(r["reference"]))] = (r["sentence_text"], r["reference_text"])
    return links


def hand_pairs(n):
    tag = f"ch{n:02d}"
    sfile = root / f"Experiments/srl/data/{book}-{tag}-sentences.json"
    hfile = root / f"Dataset/labels/handpick-{book}/{tag}.txt"
    if not sfile.exists() or not hfile.exists():
        return None, None, set()
    sentences = json.loads(sfile.read_text())
    text = (root / "Dataset" / book / f"{tag}.txt").read_text(encoding="utf-8")
    yes = set()
    with open(root / f"Dataset/labels/claude-labels-handpick-{book}.csv", encoding="utf-8") as f:
        ok = {int(r["line"]) for r in csv.DictReader(f) if int(r["chapter"]) == n and r["verdict"] == "yes"}
    for line_no, line in enumerate(hfile.read_text(encoding="utf-8").splitlines(), 1):
        if "||" in line and line_no in ok:
            phrase, passage = (x.strip() for x in line.split("||", 1))
            j, i = sentence_at(sentences, text.find(phrase)), sentence_at(sentences, text.find(passage))
            if i is not None and j is not None:
                yes.add((j, i))
    return sentences, text, yes


a, b = load(run_a), load(run_b)
chapters = sorted({k[0] for k in a} | {k[0] for k in b})
hand_yes_total = 0
hits = Counter()
for n in chapters:
    sentences, text, yes = hand_pairs(n)
    hand_yes_total += len(yes)
    if sentences is None:
        continue
    for name, links in (("a", a), ("b", b)):
        pairs = set()
        for k, (st, rt) in links.items():
            if k[0] != n:
                continue
            j, i = sentence_at(sentences, text.find(st[:60])), sentence_at(sentences, text.find(rt[:60]))
            if i is not None and j is not None:
                pairs.add((j, i))
        hits[name] += len(pairs & yes)

for name, run, links in (("a", run_a, a), ("b", run_b, b)):
    v = Counter(verdict.get(k, "unreviewed") for k in links)
    print(f"{run}: {len(links)} underlines · verdicts yes {v['yes']} partial {v['partial']} no {v['no']} "
          f"unreviewed {v['unreviewed']} · hand pick found {hits[name]} of {hand_yes_total} "
          f"({100 * hits[name] / max(hand_yes_total, 1):.1f}%)")
shared = set(a) & set(b)
print(f"shared links: {len(shared)} · only in {run_a}: {len(set(a) - set(b))} · only in {run_b}: {len(set(b) - set(a))}")
only_b = set(b) - set(a)
v = Counter(verdict.get(k, "unreviewed") for k in only_b)
print(f"new links in {run_b}: yes {v['yes']} partial {v['partial']} no {v['no']} unreviewed {v['unreviewed']}")
