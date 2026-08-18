#!/usr/bin/env python3
"""Measure which document features survive which render route.

The table this produces goes in the README. It is generated rather than written
by hand, because a hand-maintained table of a program's behaviour drifts from the
behaviour -- which is the failure this repository exists to catch.

Run `make all` first, then `python ci/feature-matrix.py`.
"""
import pathlib, re, html, sys

# (input file, what renders it, output format, produced file). The input matters:
# the same output format behaves differently depending on which toolchain made it,
# which a table of features against output format alone would hide.
ROUTES = [
    ("check-quarto.qmd",     "Quarto",    "LaTeX PDF", "check-quarto-latex.pdf"),
    ("check-quarto.qmd",     "Quarto",    "Typst PDF", "check-quarto-typst.pdf"),
    ("check-quarto.qmd",     "Quarto",    "HTML",      "check-quarto.html"),
    ("check-quarto-r.qmd",   "Quarto",    "LaTeX PDF", "check-quarto-r-latex.pdf"),
    ("check-quarto-r.qmd",   "Quarto",    "Typst PDF", "check-quarto-r-typst.pdf"),
    ("check-quarto-r.qmd",   "Quarto",    "HTML",      "check-quarto-r.html"),
    ("check-notebook.ipynb", "nbconvert", "LaTeX PDF", "check-notebook.pdf"),
    ("check-notebook.ipynb", "nbconvert", "HTML",      "check-notebook.html"),
    ("check-notebook.ipynb", "nbconvert", "WebPDF",    "check-notebook-web.pdf"),
    ("check-rmarkdown.Rmd",  "rmarkdown", "LaTeX PDF", "check-rmarkdown.pdf"),
    ("check-rmarkdown.Rmd",  "rmarkdown", "HTML",      "check-rmarkdown.html"),
]

# Grouped so the table stays readable. The five typographic characters always
# agree with each other, so they are one column; anything that ever differs gets
# its own. (label, needles, mode)
FEATURES = [
    ("typography",        (["Montréal", "°", "·", "–", "“"],  "all")),
    ("literal Greek",     (["α"],                             "all")),
    ("emoji",             (["✅", "📊"],                      "any")),
    ("inline + display maths", (["𝛽", "β", "unbiased"],       "any")),
    ("aligned in $$",     (["Var", "𝔼", "E["],                "any")),
    ("markdown table",    (["you want", "write this"],        "any")),
    ("image",             ([],                                "image")),
]


def has_image(path: pathlib.Path) -> bool:
    """An image is not text, so it needs a different probe per output type."""
    if path.suffix == ".html":
        raw = path.read_text(encoding="utf-8", errors="replace")
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
        raw = path.read_text(encoding="utf-8", errors="replace")
        raw = re.sub(r"<(script|style).*?</\1>", " ", raw, flags=re.S)
        return html.unescape(re.sub(r"<[^>]+>", " ", raw))
    from pypdf import PdfReader
    return "\n".join(p.extract_text() or "" for p in PdfReader(str(path)).pages)


def main() -> int:
    rows = []
    for src, tool, out, name in ROUTES:
        p = pathlib.Path(name)
        if not p.exists():
            rows.append((src, tool, out, None))
            continue
        rows.append((src, tool, out, text_of(p)))

    heads = [f for f, _ in FEATURES]
    print("| input | rendered by | output | " + " | ".join(heads) + " |")
    print("|" + "---|" * (len(heads) + 3))
    for src, tool, out, body in rows:
        if body is None:
            note = "**did not render**"
            print(f"| `{src}` | {tool} | {out} | " +
                  " | ".join([note] + ["—"] * (len(FEATURES) - 1)) + " |")
            continue
        cells = []
        for feat, (needles, mode) in FEATURES:
            if mode == "image":
                name = dict(((s2, t2, o2), n2) for s2, t2, o2, n2 in
                            [(a, b, c, d) for a, b, c, d in ROUTES])[(src, tool, out)]
                hit = has_image(pathlib.Path(name))
            elif mode == "any":
                hit = any(n in body for n in needles)
            else:
                hit = all(n in body for n in needles)
            cells.append("yes" if hit else "**no**")
        print(f"| `{src}` | {tool} | {out} | " + " | ".join(cells) + " |")
    return 0


if __name__ == "__main__":
    sys.exit(main())
