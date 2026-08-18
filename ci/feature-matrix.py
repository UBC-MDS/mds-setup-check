#!/usr/bin/env python3
"""Measure which document features survive which render route.

The table this produces goes in the README. It is generated rather than written
by hand, because a hand-maintained table of a program's behaviour drifts from the
behaviour -- which is the failure this repository exists to catch.

Run `make all` first, then `python ci/feature-matrix.py`.
"""
import pathlib, re, html, sys

ROUTES = [
    ("Quarto -> LaTeX",      "check-quarto-latex.pdf"),
    ("Quarto -> Typst",      "check-quarto-typst.pdf"),
    ("Quarto -> HTML",       "check-quarto.html"),
    ("Quarto R -> LaTeX",    "check-quarto-r-latex.pdf"),
    ("Quarto R -> Typst",    "check-quarto-r-typst.pdf"),
    ("Quarto R -> HTML",     "check-quarto-r.html"),
    ("nbconvert -> LaTeX",   "check-notebook.pdf"),
    ("nbconvert -> HTML",    "check-notebook.html"),
    ("nbconvert -> WebPDF",  "check-notebook-web.pdf"),
    ("rmarkdown -> LaTeX",   "check-rmarkdown.pdf"),
    ("rmarkdown -> HTML",    "check-rmarkdown.html"),
]

# label -> (needles, mode). "any" passes if any needle is present.
FEATURES = [
    ("accented latin",        (["Montréal", "naïve"],            "all")),
    ("degree sign",           (["°"],                            "all")),
    ("middot separator",      (["·"],                            "all")),
    ("en dash",               (["–"],                            "all")),
    ("curly quotes",          (["“", "”"],                       "any")),
    ("literal Greek",         (["α"],                            "all")),
    ("emoji",                 (["✅", "📊"],                     "any")),
    ("inline maths",          (["𝛽", "β", "^"],                  "any")),
    ("display equation",      (["RSS", "∑", "sum"],              "any")),
    ("numbered equation",     (["𝜎", "σ", "1"],                  "any")),
    ("aligned equations",     (["Var", "𝔼", "E["],               "any")),
    ("markdown table",        (["you want", "write this"],        "all")),
    ("embedded image",        ([],                                "image")),
]


def has_image(path: pathlib.Path) -> bool:
    """An image is not text, so it needs a different probe per output type."""
    if path.suffix == ".html":
        raw = path.read_text(errors="replace")
        return "mds-logo.png" in raw or "data:image" in raw
    from pypdf import PdfReader
    for page in PdfReader(str(path)).pages:
        res = page.get("/Resources") or {}
        if "/XObject" in res:
            xo = res["/XObject"].get_object()
            if any(o.get_object().get("/Subtype") == "/Image" for o in xo.values()):
                return True
    return False


def text_of(path: pathlib.Path) -> str:
    if path.suffix == ".html":
        raw = path.read_text(errors="replace")
        raw = re.sub(r"<(script|style).*?</\1>", " ", raw, flags=re.S)
        return html.unescape(re.sub(r"<[^>]+>", " ", raw))
    from pypdf import PdfReader
    return "\n".join(p.extract_text() or "" for p in PdfReader(str(path)).pages)


def main() -> int:
    texts = {}
    for label, name in ROUTES:
        p = pathlib.Path(name)
        if not p.exists():
            print(f"missing output: {name} -- run `make all` first", file=sys.stderr)
            return 1
        texts[label] = text_of(p)

    width = max(len(f) for f, _ in FEATURES)
    print("| feature | " + " | ".join(l for l, _ in ROUTES) + " |")
    print("|" + "---|" * (len(ROUTES) + 1))
    for feat, (needles, mode) in FEATURES:
        cells = []
        for label, _ in ROUTES:
            t = texts[label]
            if mode == "image":
                hit = has_image(pathlib.Path(dict(ROUTES)[label]))
            elif mode == "any":
                hit = any(n in t for n in needles)
            else:
                hit = all(n in t for n in needles)
            cells.append("yes" if hit else "**no**")
        print(f"| {feat} | " + " | ".join(cells) + " |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
