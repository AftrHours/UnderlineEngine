#!/usr/bin/env python3
"""Chapters for the Clean check (Tests/UnderlineEngineEvals/CleanCheck.swift), from an EPUB or a Dataset book.

    python3 -I Experiments/clean/chapters.py epub path/to/book.epub little-women   # one chapter per spine file, as iRead reads it
    python3 -I Experiments/clean/chapters.py dataset little-women                 # Dataset/<book>/chNN.txt

Writes Experiments/clean/data/<source>-<book>.json: [{chapter, paragraphs: [text]}]. The EPUB split is close to iRead's EPUBKit
(spine order, block elements end a paragraph) but splits per file, not per table-of-contents entry; good enough to find noise.
"""
import html, json, pathlib, re, sys, zipfile, posixpath

root = pathlib.Path(__file__).resolve().parents[2]
BLOCK = r"</?(?:p|div|section|article|header|footer|blockquote|li|tr|br|h[1-6])\b[^>]*>"

def epub(path):
    z = zipfile.ZipFile(path)
    container = z.read("META-INF/container.xml").decode()
    opf_path = re.search(r'full-path="([^"]+)"', container).group(1)
    opf = z.read(opf_path).decode("utf-8")
    manifest = {m.group(1): m.group(2) for m in re.finditer(r'<item\b[^>]*\bid="([^"]+)"[^>]*\bhref="([^"]+)"', opf)}
    manifest.update({m.group(2): m.group(1) for m in re.finditer(r'<item\b[^>]*\bhref="([^"]+)"[^>]*\bid="([^"]+)"', opf)})
    chapters = []
    for idref in re.findall(r'<itemref\b[^>]*\bidref="([^"]+)"', opf):
        href = manifest.get(idref)
        if not href:
            continue
        text = z.read(posixpath.normpath(posixpath.join(posixpath.dirname(opf_path), href))).decode("utf-8", "replace")
        body = text.split("<body", 1)[-1].split(">", 1)[-1]
        paras = []
        for block in re.split(BLOCK, body):
            s = re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", block))).strip()
            if s:
                paras.append(s)
        if paras:
            chapters.append({"chapter": len(chapters) + 1, "paragraphs": paras})
    return chapters

def dataset(book):
    out = []
    for f in sorted((root / "Dataset" / book).glob("ch*.txt")):
        blocks = re.split(r"\n\s*\n", f.read_text(encoding="utf-8"))
        out.append({"chapter": int(f.stem[2:]), "paragraphs": [" ".join(l.strip() for l in b.splitlines()).strip() for b in blocks if b.strip()]})
    return out

kind = sys.argv[1]
if kind == "epub":
    chapters, book = epub(sys.argv[2]), sys.argv[3]
else:
    book = sys.argv[2]
    chapters = dataset(book)
out = root / f"Experiments/clean/data/{kind}-{book}.json"
out.write_text(json.dumps(chapters, ensure_ascii=False))
print(f"{kind} {book}: {len(chapters)} chapters, {sum(len(c['paragraphs']) for c in chapters)} paragraphs")
