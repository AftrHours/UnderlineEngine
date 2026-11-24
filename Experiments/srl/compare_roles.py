#!/usr/bin/env python3
"""How close a set of roles is to Claude's ideal roles, sentence by sentence.

    python3 -I Experiments/srl/compare_roles.py little-women 1 fm      # -roles-fm.json against -roles.json
    python3 -I Experiments/srl/compare_roles.py little-women 1 rough

Per sentence it compares the set of people (who), actions (did, first word) and things (what, last word) the two labelings
name. Agreement = shared ÷ named by the ideal (recall) and shared ÷ named by the other (precision), over the chapter.
"""
import json, pathlib, re, sys

root = pathlib.Path(__file__).resolve().parents[2]
data = root / "Experiments/srl/data"
book, n, variant = sys.argv[1], int(sys.argv[2]), sys.argv[3]
tag = f"ch{n:02d}"
sentences = {s["id"]: s["text"] for s in json.loads((data / f"{book}-{tag}-sentences.json").read_text())}
ideal = {e["id"]: e["roles"] for e in json.loads((data / f"{book}-{tag}-roles.json").read_text())}
other = {e["id"]: e["roles"] for e in json.loads((data / f"{book}-{tag}-roles-{variant}.json").read_text())}
PRONOUNS = {"i", "you", "he", "she", "it", "we", "they", "him", "her", "them", "me", "us"}

def words(v):
    return re.sub(r"^(the|a|an|her|his|their|my|our)\s+", "", (v or "").lower().strip()).split()

def slot(roles, key):
    out = set()
    for r in roles:
        w = words(r.get(key))
        if not w:
            continue
        if key == "who":
            out.add(" ".join(w).replace("mrs.", "mrs").replace("mr.", "mr"))
        elif key == "did":
            out.add(w[0])
        else:
            out.add(w[-1].rstrip("s"))   # head noun, crude plural
    return out

print(f"{book} {tag}: {variant} against Claude's ideal roles, {len(sentences)} sentences")
print(f"  sentences with events: ideal {sum(1 for v in ideal.values() if v)}, {variant} {sum(1 for v in other.values() if v)}")
print(f"  role sets: ideal {sum(len(v) for v in ideal.values())}, {variant} {sum(len(v) for v in other.values())}")
for key, name in (("who", "who (agent)"), ("did", "did (predicate)"), ("what", "what (patient)"), ("where", "where (location)")):
    shared = got = want = 0
    for i in sentences:
        a, b = slot(ideal.get(i, []), key), slot(other.get(i, []), key)
        shared += len(a & b); want += len(a); got += len(b)
    r = shared / want if want else 0
    p = shared / got if got else 0
    print(f"  {name:18s}: {shared:4d} shared · ideal names {want:4d} · {variant} names {got:4d} · "
          f"recall {100 * r:5.1f}% · precision {100 * p:5.1f}%")
pron = sum(1 for v in other.values() for r in v if (r.get("who") or "").lower() in PRONOUNS)
print(f"  pronouns left as who: {pron}")
