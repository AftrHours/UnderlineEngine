#!/usr/bin/env python3
"""Ceiling test for semantic-role matching (semantic role labeling, SRL): links later sentences to earlier ones whose
role sets (who = agent · did = predicate · what = patient · where = location) agree,
and compares the links with Claude's hand pick and with R8 on the same chapters.

    python3 -I Experiments/srl/match.py little-women 1 5          # roles Claude extracted (-roles.json)
    python3 -I Experiments/srl/match.py little-women 1 47 rough   # rough roles from Apple's tagger (-roles-rough.json)

Needs Experiments/srl/data/<book>-chNN-sentences.json (split.py) and -roles.json (extracted by Claude, EXTRACT.md).
Everything is compared at sentence level: a link is (later sentence, earlier sentence), both in the same chapter,
the earlier one in an earlier paragraph (the rule the engine and the hand pick follow).
"""
import csv, json, re, sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
book, first, last = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
suffix = f"-{sys.argv[4]}" if len(sys.argv) > 4 else ""
data = root / "Experiments/srl/data"


def norm(v):
    if not v:
        return None
    v = re.sub(r"^(the|a|an)\s+", "", str(v).strip().lower())
    return re.sub(r"\s+", " ", v) or None


def sentence_at(sentences, offset):
    for s in sentences:
        if s["start"] <= offset < s["end"] + 1:
            return s["id"]
    return None


# Matching rules, strict to loose. Each takes two role sets (dicts of normalised slots) and says whether they match.
def slots_equal(a, b):
    return {k for k in ("who", "did", "what", "where") if a[k] and a[k] == b[k]}

RULES = {
    "what+1": lambda eq: "what" in eq and len(eq) >= 2,          # same object, plus one more slot
    "2 roles (what or did)": lambda eq: len(eq) >= 2 and ({"what", "did"} & eq),
    "what only": lambda eq: "what" in eq,
    "who+did": lambda eq: {"who", "did"} <= eq,
}

totals = {name: {"links": 0, "hand_hit": 0, "any_hit": 0} for name in RULES}
hand_total = hand_yes_total = 0
r8_total = r8_hit = 0
hand_yes_pairs_all = []

for n in range(first, last + 1):
    tag = f"ch{n:02d}"
    sentences = json.loads((data / f"{book}-{tag}-sentences.json").read_text())
    roles_file = data / f"{book}-{tag}-roles{suffix}.json"
    if not roles_file.exists():
        print(f"{tag}: no roles yet")
        continue
    roles = {e["id"]: [{k: norm(f.get(k)) for k in ("who", "did", "what", "where")} for f in e["roles"]]
              for e in json.loads(roles_file.read_text())}
    para = {s["id"]: s["paragraph"] for s in sentences}
    text = (root / "Dataset" / book / f"{tag}.txt").read_text(encoding="utf-8")

    # Hand pick, mapped to sentence pairs; and which of its links were judged right.
    verdicts = {}
    with open(root / f"Dataset/labels/claude-labels-handpick-{book}.csv", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            if int(r["chapter"]) == n:
                verdicts[int(r["line"])] = r["verdict"]
    hand, hand_yes = set(), set()
    for line_no, line in enumerate((root / f"Dataset/labels/handpick-{book}/{tag}.txt").read_text(encoding="utf-8").splitlines(), 1):
        if "||" not in line:
            continue
        phrase, passage = (x.strip() for x in line.split("||", 1))
        j, i = sentence_at(sentences, text.find(phrase)), sentence_at(sentences, text.find(passage))
        if i is None or j is None:
            continue
        hand.add((j, i))
        if verdicts.get(line_no) == "yes":
            hand_yes.add((j, i))
    hand_total += len(hand)
    hand_yes_total += len(hand_yes)

    # R8 on the same chapter, mapped to the same sentence numbers by text.
    r8 = set()
    r8_csv = root / f"Eval/results/book-{book}-rules-contextual.r8/{tag}.csv"
    if r8_csv.exists():
        with open(r8_csv, encoding="utf-8-sig") as f:
            for r in csv.DictReader(f):
                if r["underlined"] != "yes":
                    continue
                j = sentence_at(sentences, text.find(r["sentence_text"][:60]))
                i = sentence_at(sentences, text.find(r["reference_text"][:60]))
                if i is not None and j is not None:
                    r8.add((j, i))
    r8_total += len(r8)
    r8_hit += len(r8 & hand_yes)

    # Role matching: for each later sentence, every earlier sentence (earlier paragraph) with a matching role set.
    for name, rule in RULES.items():
        links, any_matches = set(), set()
        for j in range(len(sentences)):
            best = None
            for i in range(j - 1, -1, -1):
                if para[i] == para[j]:
                    continue
                hit = max((len(slots_equal(a, b)) for a in roles.get(j, []) for b in roles.get(i, [])
                           if rule(slots_equal(a, b))), default=0)
                if hit:
                    any_matches.add((j, i))
                    if best is None or hit > best[0]:
                        best = (hit, i)          # most slots wins; ties go to the nearest earlier sentence
            if best:
                links.add((j, best[1]))
        totals[name]["links"] += len(links)
        totals[name]["hand_hit"] += len(links & hand_yes)
        totals[name]["any_hit"] += len(any_matches & hand_yes)

print(f"\nHand pick, judged right: {hand_yes_total} sentence pairs (of {hand_total})")
print(f"R8: {r8_total} links, {r8_hit} of them in the hand pick ({100*r8_hit/max(r8_total,1):.0f}% of R8), "
      f"finds {100*r8_hit/max(hand_yes_total,1):.0f}% of the hand pick")
for name, t in totals.items():
    print(f"roles · {name:22s}: {t['links']:4d} links, {t['hand_hit']:3d} in the hand pick "
          f"({100*t['hand_hit']/max(t['links'],1):.0f}% of links), finds {100*t['hand_hit']/max(hand_yes_total,1):.0f}% of the hand pick; "
          f"any matching earlier sentence covers {100*t['any_hit']/max(hand_yes_total,1):.0f}%")
