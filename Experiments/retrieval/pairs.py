#!/usr/bin/env python3
"""Hand-picked links judged right, as JSON for the recall test (Tests/UnderlineEngineEvals/RetrievalRecall.swift).

    python3 -I Experiments/retrieval/pairs.py little-women

Writes Experiments/retrieval/data/<book>-pairs.json: [{chapter, line, phrase, passage}], verdict "yes" only.
"""
import csv, json, pathlib, sys

root = pathlib.Path(__file__).resolve().parents[2]
book = sys.argv[1]
rows = csv.DictReader(open(root / f"Dataset/labels/claude-labels-handpick-{book}.csv", encoding="utf-8"))
pairs = [{"chapter": int(r["chapter"]), "line": int(r["line"]), "phrase": r["phrase"], "passage": r["passage"]}
         for r in rows if r["verdict"] == "yes"]
out = root / f"Experiments/retrieval/data/{book}-pairs.json"
out.write_text(json.dumps(pairs, indent=0, ensure_ascii=False))
print(f"{len(pairs)} pairs → {out.relative_to(root)}")
