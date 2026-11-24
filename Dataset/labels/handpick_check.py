#!/usr/bin/env python3
"""Checks Claude's hand-picked links for one book chapter (or all chapters).

    python3 -I Dataset/labels/handpick_check.py <book> [NN ...]

Reads Dataset/labels/handpick-<book>/chNN.txt: one link per line, "phrase || earlier passage", both copied exactly from
Dataset/<book>/chNN.txt. A link is good when each string occurs exactly once in the chapter, the passage starts before the phrase, and the passage is
in an earlier paragraph (paragraphs are separated by a blank line).
Prints each chapter's link count and every bad line (phrase position, passage position; -1 = not found).
"""
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
book = sys.argv[1]
picks = root / "labels" / f"handpick-{book}"
chapters = sys.argv[2:] or sorted(p.stem[2:] for p in picks.glob("ch*.txt"))
total = bad_total = 0
for n in chapters:
    n = f"{int(n):02d}"
    text = (root / book / f"ch{n}.txt").read_text(encoding="utf-8")
    pick_file = picks / f"ch{n}.txt"
    if not pick_file.exists():
        print(f"ch{n}: no hand-pick file")
        continue
    bad, count = [], 0
    for line in pick_file.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        count += 1
        if "||" not in line:
            bad.append((line, "no ||"))
            continue
        phrase, ref = (x.strip() for x in line.split("||", 1))
        p, r = text.find(phrase), text.find(ref)
        if p < 0 or r < 0 or r >= p:
            bad.append((phrase[:60], ref[:60], p, r))
        elif text.count(phrase) > 1 or text.count(ref) > 1:
            bad.append((phrase[:60], ref[:60], "not unique: make the text longer"))
        elif "\n\n" not in text[r:p]:
            bad.append((phrase[:60], ref[:60], "same paragraph"))
    total += count
    bad_total += len(bad)
    print(f"ch{n}: {count} links, {len(bad)} bad")
    for b in bad:
        print("  ", b)
print(f"TOTAL {total} links, {bad_total} bad")
