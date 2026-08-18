#!/usr/bin/env python3
"""Measure which document features survive which render route.

The table this produces goes in the README. It is generated rather than written
by hand, because a hand-maintained table of a program's behaviour drifts from the
behaviour -- which is the failure this repository exists to catch.

Run `make all` first, then `python ci/feature-matrix.py`.
"""
import pathlib, re, html, sys, importlib.util

# This prints tick and cross marks, and on Windows the redirected stdout of
# `make matrix >> "$GITHUB_STEP_SUMMARY"` is the locale codepage, not UTF-8.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass

# The reasons a route is known to fail live in assert-renders.py, which is what
# gates CI. Importing them keeps the table's footnotes and the gate's verdict
# from ever disagreeing.
_spec = importlib.util.spec_from_file_location(
    "assert_renders", pathlib.Path(__file__).with_name("assert-renders.py"))
_ar = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ar)
KNOWN_TO_FAIL = _ar.KNOWN_TO_FAIL

ROUTES = [
    # (input, rendered by, output, produced file)
    ("check-quarto-py.qmd",  "Quarto",    "LaTeX PDF", "check-quarto-py-latex.pdf"),
    ("check-quarto-py.qmd",  "Quarto",    "Typst PDF", "check-quarto-py-typst.pdf"),
    ("check-quarto-py.qmd",  "Quarto",    "HTML",      "check-quarto-py.html"),
    ("check-quarto-r.qmd",   "Quarto",    "LaTeX PDF", "check-quarto-r-latex.pdf"),
    ("check-quarto-r.qmd",   "Quarto",    "Typst PDF", "check-quarto-r-typst.pdf"),
    ("check-quarto-r.qmd",   "Quarto",    "HTML",      "check-quarto-r.html"),
    ("check-notebook.ipynb", "Quarto",    "LaTeX PDF", "check-notebook-quarto-latex.pdf"),
    ("check-notebook.ipynb", "Quarto",    "Typst PDF", "check-notebook-quarto-typst.pdf"),
    ("check-notebook.ipynb", "Quarto",    "HTML",      "check-notebook-quarto.html"),
    ("check-notebook.ipynb", "nbconvert", "LaTeX PDF", "check-notebook-nbconvert-latex.pdf"),
    ("check-notebook.ipynb", "nbconvert", "HTML",      "check-notebook-nbconvert.html"),
    ("check-notebook.ipynb", "nbconvert", "WebPDF",    "check-notebook-nbconvert-web.pdf"),
    ("check-rmarkdown.Rmd",  "Quarto",    "LaTeX PDF", "check-rmarkdown-quarto-latex.pdf"),
    ("check-rmarkdown.Rmd",  "Quarto",    "Typst PDF", "check-rmarkdown-quarto-typst.pdf"),
    ("check-rmarkdown.Rmd",  "Quarto",    "HTML",      "check-rmarkdown-quarto.html"),
    ("check-rmarkdown.Rmd",  "rmarkdown", "LaTeX PDF", "check-rmarkdown-rmarkdown-latex.pdf"),
    ("check-rmarkdown.Rmd",  "rmarkdown", "HTML",      "check-rmarkdown-rmarkdown.html"),
]

# The full feature list, not grouped: a column that always agrees is still worth
# showing, because the day it stops agreeing is the day this table earns its keep.
FEATURES = [
    ("accented latin",    (["Montréal", "naïve"],       "all")),
    ("degree sign",       (["°"],                       "all")),
    ("middot",            (["·"],                       "all")),
    ("en dash",           (["–"],                       "all")),
    ("curly quotes",      (["“", "”"],                  "any")),
    ("literal Greek",     (["α"],                       "all")),
    ("emoji",             (["✅", "📊"],                "any")),
    ("inline maths",      (["𝛽", "β", "unbiased"],      "any")),
    ("display equation",  (["RSS"],                     "any")),
    ("numbered equation", (["𝜎", "σ"],                  "any")),
    ("aligned in $$",     (["Var", "𝔼", "E["],          "any")),
    ("markdown table",    (["you want", "write this"],  "any")),
    ("image",             ([],                          "image")),
]


# The image probe lives in assert-renders.py, so the gate and this table agree
# on what "the image is there" means.
has_image = _ar.has_image


def text_of(path: pathlib.Path) -> str:
    if path.suffix == ".html":
        raw = path.read_text(encoding="utf-8", errors="replace")
        raw = re.sub(r"<(script|style).*?</\1>", " ", raw, flags=re.S)
        return html.unescape(re.sub(r"<[^>]+>", " ", raw))
    from pypdf import PdfReader
    return "\n".join(p.extract_text() or "" for p in PdfReader(str(path)).pages)


def main() -> int:
    YES, NO, NA, WARN = "✅", "❌", "—", "⚠️"
    by_ext = {}
    for route in ROUTES:
        by_ext.setdefault(pathlib.Path(route[0]).suffix, []).append(route)

    for ext, routes in by_ext.items():
        sources = sorted({src for src, _, _, _ in routes})
        # One table per extension keeps them narrow, but .qmd has two fixtures
        # (one per language), so that table needs a column saying which.
        multi = len(sources) > 1
        print(f"\n**`{ext}`**" + ("" if multi else f" — `{sources[0]}`") + "\n")
        lead = (["input"] if multi else []) + ["rendered by", "output"]
        heads = [f for f, _ in FEATURES]
        print("| " + " | ".join(lead + heads) + " |")
        print("|" + "---|" * (len(lead) + len(heads)))

        notes = []
        for src, tool, out, name in routes:
            path = pathlib.Path(name)
            row = ([f"`{src}`"] if multi else []) + [tool, out]
            if not path.exists():
                notes.append((name, tool, out))
                row[-2] = f"{tool} {WARN}"
                print("| " + " | ".join(row + [NO] * len(FEATURES)) + " |")
                continue
            body = text_of(path)
            for feat, (needles, mode) in FEATURES:
                if mode == "image":
                    hit = has_image(path)
                elif mode == "any":
                    hit = any(n in body for n in needles)
                else:
                    hit = all(n in body for n in needles)
                row.append(YES if hit else NO)
            print("| " + " | ".join(row) + " |")

        for name, tool, out in notes:
            # is_known, not a bare lookup: the WebPDF limitation is Windows-only, and
            # printing it as the explanation for a Linux failure would tell an
            # instructor that a real breakage was expected.
            _, why = (KNOWN_TO_FAIL[name] if _ar.is_known(name)
                      else (None, "this route produced no file on this platform, and it "
                                  "is not a known limitation -- something is broken."))
            print(f"\n{WARN} **{tool} → {out} produces no file at all.** {why}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
