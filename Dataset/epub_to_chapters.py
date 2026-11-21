#!/usr/bin/env python3
"""Split a Project Gutenberg EPUB into one plain-text file per chapter, for the engine's harness.

    python3 Dataset/epub_to_chapters.py Dataset/little-women.epub Dataset/little-women

Output: <out>/ch01.txt, ch02.txt, ... (one paragraph per block, blank line between, straight quotes, the same shape as
little-women-ch1.txt) and <out>/index.json (number, title, file, paragraphs, words). A chapter is a <div class="chapter"> whose <h2> or <h3>
starts with CHAPTER (Little Women), or else an <h2> with a CHAPTER_<roman> anchor (illustrated editions: Pride and Prejudice).
"""
import html, json, re, sys, zipfile
from pathlib import Path

def text_of(fragment: str) -> str:
    fragment = re.sub(r"<br\s*/?>", " ", fragment)
    fragment = re.sub(r"<[^>]+>", "", fragment)
    fragment = html.unescape(fragment)
    fragment = (fragment.replace("“", '"').replace("”", '"').replace("‘", "'").replace("’", "'")
                .replace(" ", " "))
    return re.sub(r"\s+", " ", fragment).strip()

def spine_files(z: zipfile.ZipFile) -> list[str]:
    opf_name = next(n for n in z.namelist() if n.endswith(".opf"))
    opf = z.read(opf_name).decode("utf-8")
    base = opf_name.rsplit("/", 1)[0] + "/" if "/" in opf_name else ""
    manifest = dict(re.findall(r'<item[^>]*?id="([^"]+)"[^>]*?href="([^"]+)"', opf))
    manifest.update({i: h for h, i in re.findall(r'<item[^>]*?href="([^"]+)"[^>]*?id="([^"]+)"', opf)})
    return [base + manifest[i] for i in re.findall(r'<itemref[^>]*?idref="([^"]+)"', opf) if i in manifest]

def chapters(path: str):
    out = []
    with zipfile.ZipFile(path) as z:
        for name in spine_files(z):
            if name not in z.namelist():
                continue
            body = z.read(name).decode("utf-8")
            for block in re.split(r'<div class="chapter"', body)[1:]:
                heading = re.search(r"<h[23][^>]*>(.*?)</h[23]>", block, re.S)
                if not heading or not text_of(heading.group(1)).upper().startswith("CHAPTER"):
                    continue
                paragraphs = [t for t in (text_of(p) for p in re.findall(r"<p[^>]*>(.*?)</p>", block, re.S)) if t]
                out.append((text_of(heading.group(1)), paragraphs))
    return out or chapters_by_anchor(path) or chapters_by_file(path) or chapters_by_roman(path)

def is_caption(text: str) -> bool:
    """An illustration's caption ("When the Party entered", quoted with no closing punctuation), its copyright line, or the
    printer's imprint."""
    return (text.startswith("[Copyright") or text.startswith("CHISWICK PRESS")
            or re.fullmatch(r'"[A-Z][^".!?,;:—]*"', text) is not None)

def chapters_by_anchor(path: str):
    """Illustrated Gutenberg editions (Pride and Prejudice): no chapter divs, and the heading is an image. A chapter starts at
    an <h2> holding an anchor id="CHAPTER_<roman>"; figures and their captions are dropped."""
    out = []
    with zipfile.ZipFile(path) as z:
        body = "".join(z.read(n).decode("utf-8") for n in spine_files(z) if n in z.namelist())
    body = re.sub(r'<div class="caption"(?:(?!<h2|<div).)*?</div>', "", body, flags=re.S)
    body = re.sub(r'<div class="figcenter"(?:(?!<h2|<div).)*?</div>', "", body, flags=re.S)
    parts = re.split(r'<a id="(CHAPTER_[IVXLC]+)"\s*/>', body, flags=re.I)
    for i in range(1, len(parts) - 1, 2):
        block = parts[i + 1].split("</h2>", 1)[-1]
        block = re.split(r'<h2|<div class="footnotes"|START: FULL LICENSE|\*\*\* END OF', block)[0]
        paragraphs = [t for t in (text_of(p) for p in re.findall(r"<p[^>]*>(.*?)</p>", block, re.S)) if t and not is_caption(t)]
        out.append((parts[i].replace("_", " ").upper(), paragraphs))
    return out

def chapters_by_file(path: str):
    """One chapter per spine file whose first heading starts with "Chapter" (The Hobbit): the title is that heading and the
    one after it ("Chapter I AN UNEXPECTED PARTY"). Story collections (Sherlock Holmes) use a numbered heading instead:
    "I. A SCANDAL IN BOHEMIA"."""
    out = []
    with zipfile.ZipFile(path) as z:
        for name in spine_files(z):
            if name not in z.namelist():
                continue
            body = z.read(name).decode("utf-8")
            headings = [text_of(h) for h in re.findall(r"<h[1-4][^>]*>(.*?)</h[1-4]>", body, re.S)]
            headings = [h for h in headings if h]
            if not headings:
                continue
            if sum(h.lower().startswith("chapter") for h in headings) > 1:
                # Several chapters in one file (Moby-Dick): split at every heading that starts with "Chapter" or "Epilogue".
                parts = re.split(r"(<h[1-4][^>]*>.*?</h[1-4]>)", body, flags=re.S)
                title, paragraphs = None, []
                for part in parts:
                    heading = re.fullmatch(r"<h[1-4][^>]*>(.*?)</h[1-4]>", part, re.S)
                    if heading:
                        text = text_of(heading.group(1))
                        if text.lower().startswith(("chapter", "epilogue")):
                            if title:
                                out.append((title, paragraphs))
                            title, paragraphs = text, []
                    elif title:
                        paragraphs += [t for t in (text_of(x) for x in re.findall(r"<p[^>]*>(.*?)</p>", part, re.S)) if t]
                if title:
                    out.append((title, paragraphs))
                continue
            if headings[0].lower().startswith("chapter"):
                title = " ".join(headings[:2])
            elif re.match(r"[IVXLC]+\. ", headings[0]):  # story collections: "I. A SCANDAL IN BOHEMIA"
                title = headings[0]
            else:
                continue
            paragraphs = [t for t in (text_of(p) for p in re.findall(r"<p[^>]*>(.*?)</p>", body, re.S)) if t]
            out.append((title, paragraphs))
    return out

def chapters_by_roman(path: str):
    """Calibre conversions with no headings (Before the Coffee Gets Cold): a chapter starts at a paragraph that is only a
    Roman numeral, followed by the chapter title. The table of contents (numerals in a row) and the back matter
    ("About the Author", "Copyright", "Notes") are skipped."""
    with zipfile.ZipFile(path) as z:
        body = "".join(z.read(n).decode("utf-8") for n in spine_files(z) if n in z.namelist())
    paragraphs = [t for t in (text_of(p) for p in re.findall(r"<p[^>]*>(.*?)</p>", body, re.S)) if t]
    roman = re.compile(r"[IVXLC]+")
    out, current = [], None
    for i, t in enumerate(paragraphs):
        next_text = paragraphs[i + 1] if i + 1 < len(paragraphs) else ""
        if roman.fullmatch(t) and not roman.fullmatch(next_text):
            if current:
                out.append(current)
            current = (f"{t} {next_text}", [])
            continue
        if current is None:
            continue
        if t in ("About the Author", "Copyright", "Notes", "Acknowledgements"):
            if current[1]:
                break
            current = None  # a table-of-contents entry, not a chapter
            continue
        if current[1] or t != current[0].split(" ", 1)[1]:
            current[1].append(t)
    if current:
        out.append(current)
    return out

if __name__ == "__main__":
    epub, target = sys.argv[1], Path(sys.argv[2])
    target.mkdir(parents=True, exist_ok=True)
    index = []
    for number, (title, paragraphs) in enumerate(chapters(epub), start=1):
        file = f"ch{number:02d}.txt"
        (target / file).write_text("\n\n".join(paragraphs) + "\n", encoding="utf-8")
        index.append({"number": number, "title": title, "file": file, "paragraphs": len(paragraphs),
                      "words": sum(len(p.split()) for p in paragraphs)})
    (target / "index.json").write_text(json.dumps(index, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{len(index)} chapters, {sum(c['words'] for c in index)} words -> {target}")
