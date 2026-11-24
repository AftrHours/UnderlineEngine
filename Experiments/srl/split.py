#!/usr/bin/env python3
"""Splits chapters of a Dataset book into numbered sentences for the semantic-role (SRL) experiment.

    python3 -I Experiments/srl/split.py little-women 1 5

Writes Experiments/srl/data/<book>-chNN-sentences.json: [{id, paragraph, start, end, text}], id local to the chapter,
start/end character offsets in the chapter file. Sentences end at . ! ? (optionally followed by a closing quote) before a space.
"""
import json, re, sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
book, first, last = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
ABBREV = ("Mr.", "Mrs.", "Dr.", "St.", "Miss.", "Ms.", "Jr.", "Sr.")
for n in range(first, last + 1):
    text = (root / "Dataset" / book / f"ch{n:02d}.txt").read_text(encoding="utf-8")
    out, para, pos = [], 0, 0
    for block in text.split("\n\n"):
        start_block = text.find(block, pos)
        pos = start_block + len(block)
        if not block.strip():
            continue
        s = 0
        for m in re.finditer(r'[.!?]["\')]*(\s+|$)', block):
            end = m.end()
            piece = block[s:end].strip()
            if piece.endswith(ABBREV) and m.end() < len(block):
                continue
            if piece:
                a = start_block + block.find(piece, s)
                out.append({"id": len(out), "paragraph": para, "start": a, "end": a + len(piece), "text": piece})
            s = end
        rest = block[s:].strip()
        if rest:
            a = start_block + block.find(rest, s)
            out.append({"id": len(out), "paragraph": para, "start": a, "end": a + len(rest), "text": rest})
        para += 1
    (root / "Experiments/srl/data" / f"{book}-ch{n:02d}-sentences.json").write_text(json.dumps(out, indent=0, ensure_ascii=False))
    print(f"ch{n:02d}: {len(out)} sentences, {para} paragraphs")
