#!/usr/bin/env python3
"""Check that the rendered documents contain what they are supposed to contain.

Rendering is not the same as rendering correctly. Every LaTeX route in this
project exits 0 while silently replacing characters it has no glyph for, so a
check that only looks at exit codes or at whether a file exists passes on a
broken document. This asserts on the extracted text instead.

Routes do not all support the same characters. That is a measured fact about the
toolchain rather than a bug in any one document, so the expectations differ per
route and the differences are spelled out below.

Usage:  python ci/assert-renders.py
Exit:   0 if every present output holds what that route should hold, 1 otherwise.
"""
import sys

# Windows consoles default to a legacy codepage, and these scripts print the very
# characters they are checking for. Without this, a report mentioning α dies with
# UnicodeEncodeError on Windows and takes the whole check with it.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
import pathlib
import re

# Characters the fixtures contain, and which routes can reproduce them.
#   ok     - must be present, the route supports it
#   absent - the route is known not to support it; assert it is NOT there, so
#            that a future fix is noticed rather than silently absorbed
LATEX = "latex"   # accents and maths yes; Greek and emoji dropped
TYPST = "typst"   # Greek and emoji yes; raw LaTeX environments dropped
FULL = "full"     # HTML and the browser route: everything

# Routes known not to produce output at all, with the reason. A route listed here
# is reported as a known limitation rather than a failure -- but if it starts
# working, that is reported too, because the limitation is what is documented.
# Some limitations are platform specific, so an entry can name the platforms it
# applies to. A route that fails somewhere it is not expected to still fails the
# check, and a route that starts working anywhere is reported too.
KNOWN_TO_FAIL = {
    "check-notebook-nbconvert-web.pdf": (
        {"win32"},
        "playwright drives the browser through asyncio subprocesses, which raise "
        "NotImplementedError on Windows in this Python. WebPDF export therefore "
        "does not work there; the same notebook exports fine on macOS and Linux."),
    "check-notebook-nbconvert-latex.pdf":
        "nbconvert's LaTeX template emits \\LTcaptype{none} for a markdown table, "
        "which this TeX Live rejects with \"No counter 'none' defined\". Any notebook "
        "containing a markdown table fails JupyterLab's PDF export for the same "
        "reason. Rendering the same notebook through Quarto works, table and all.",
}
KNOWN_TO_FAIL = {k: (v if isinstance(v, tuple) else (None, v))
                 for k, v in KNOWN_TO_FAIL.items()}


def is_known(name: str) -> bool:
    entry = KNOWN_TO_FAIL.get(name)
    if entry is None:
        return False
    platforms, _ = entry
    return platforms is None or sys.platform in platforms

ROUTES = {
    "check-quarto-py-latex.pdf":        ("qmd/py  -> Quarto -> LaTeX",  LATEX),
    "check-quarto-py-typst.pdf":        ("qmd/py  -> Quarto -> Typst",  TYPST),
    "check-quarto-py.html":             ("qmd/py  -> Quarto -> HTML",   FULL),
    "check-quarto-r-latex.pdf":         ("qmd/R   -> Quarto -> LaTeX",  LATEX),
    "check-quarto-r-typst.pdf":         ("qmd/R   -> Quarto -> Typst",  TYPST),
    "check-quarto-r.html":              ("qmd/R   -> Quarto -> HTML",   FULL),
    "check-notebook-quarto-latex.pdf":  ("ipynb   -> Quarto -> LaTeX",  LATEX),
    "check-notebook-quarto-typst.pdf":  ("ipynb   -> Quarto -> Typst",  TYPST),
    "check-notebook-quarto.html":       ("ipynb   -> Quarto -> HTML",   FULL),
    "check-notebook-nbconvert-latex.pdf":               ("ipynb   -> nbconvert -> LaTeX", LATEX),
    "check-notebook-nbconvert.html":              ("ipynb   -> nbconvert -> HTML",  FULL),
    "check-notebook-nbconvert-web.pdf":           ("ipynb   -> nbconvert -> WebPDF", FULL),
    "check-rmarkdown-quarto-latex.pdf": ("Rmd     -> Quarto -> LaTeX",  LATEX),
    "check-rmarkdown-quarto-typst.pdf": ("Rmd     -> Quarto -> Typst",  TYPST),
    "check-rmarkdown-quarto.html":      ("Rmd     -> Quarto -> HTML",   FULL),
    "check-rmarkdown-rmarkdown-latex.pdf":              ("Rmd     -> rmarkdown -> LaTeX", LATEX),
    "check-rmarkdown-rmarkdown.html":             ("Rmd     -> rmarkdown -> HTML",  FULL),
}

# (label, needles, supported-by). A check passes if ANY needle is present, which
# matters because the same character can extract differently per engine: LaTeX sets
# maths in U+1D6FD MATHEMATICAL ITALIC SMALL BETA, not U+03B2.
CHECKS = [
    ("accented latin", ["Montréal"],        {LATEX, TYPST, FULL}),
    ("degree sign",    ["°"],               {LATEX, TYPST, FULL}),
    ("en dash",        ["–"],               {LATEX, TYPST, FULL}),
    ("curly quotes",   ["“", "”"],          {LATEX, TYPST, FULL}),
    ("inline maths",   ["𝛽", "β", "unbiased"], {LATEX, TYPST, FULL}),
    ("display eqn",    ["RSS"],             {LATEX, TYPST, FULL}),
    ("aligned eqns",   ["Var"],             {LATEX, TYPST, FULL}),
    ("literal Greek",  ["α"],               {TYPST, FULL}),
    ("emoji",          ["✅", "📊"],         {TYPST, FULL}),
]


def text_of(path: pathlib.Path) -> str:
    if path.suffix == ".html":
        raw = path.read_text(encoding="utf-8", errors="replace")
        raw = re.sub(r"<(script|style).*?</\1>", " ", raw, flags=re.S)
        import html as _html
        return _html.unescape(re.sub(r"<[^>]+>", " ", raw))
    from pypdf import PdfReader
    return "\n".join(page.extract_text() or "" for page in PdfReader(str(path)).pages)


def main() -> int:
    missing, broken, ok = [], [], []

    for name, (label, kind) in ROUTES.items():
        path = pathlib.Path(name)
        if not path.exists():
            if is_known(name):
                print(f"  known    {label:<24} does not render -- see KNOWN_TO_FAIL")
                continue
            missing.append((label, name))
            print(f"  MISSING  {label:<24} {name} was not produced")
            continue
        if is_known(name):
            broken.append(f"{name}: rendered, but is listed in KNOWN_TO_FAIL -- "
                          f"the limitation may be fixed; remove it from that list")
            print(f"  FAIL     {label:<24} now renders; update KNOWN_TO_FAIL")
            continue
        try:
            body = text_of(path)
        except Exception as exc:                      # noqa: BLE001
            broken.append(f"{name}: could not be read ({exc})")
            print(f"  FAIL     {label:<24} unreadable: {exc}")
            continue

        problems = []
        for desc, needles, supported in CHECKS:
            present = any(n in body for n in needles)
            if kind in supported and not present:
                problems.append(f"missing {desc} ({needles[0]!r})")
            elif kind not in supported and present:
                problems.append(
                    f"{desc} ({needles[0]!r}) now renders -- this route was not "
                    f"expected to support it; update ci/assert-renders.py")
        if kind in (TYPST, FULL) and "\ufffd" in body:
            problems.append("contains U+FFFD, so something was dropped")

        if problems:
            broken.append(f"{name}: " + "; ".join(problems))
            print(f"  FAIL     {label:<24} " + "; ".join(problems))
        else:
            ok.append(name)
            print(f"  ok       {label:<24} {name}")

    print()
    total = len(ROUTES)

    if len(missing) == total:
        print("Nothing has been rendered yet. Run `make all` first.")
        return 1

    if missing:
        print(f"{len(missing)} of {total} routes produced no output at all:")
        for label, name in missing:
            print(f"  - {label}  (expected {name})")
        print("  These routes failed to render. Re-run `make -k all` and read the")
        print("  error for each one; `-k` keeps going so one failure does not hide")
        print("  the rest.")
        print()

    if broken:
        print(f"{len(broken)} of {total} routes rendered but the content is wrong:")
        for b in broken:
            print(f"  - {b}")
        print()

    if missing or broken:
        print(f"{len(ok)} of {total} routes are fully correct.")
        return 1

    applicable = {n: w for n, (p, w) in KNOWN_TO_FAIL.items()
                  if p is None or sys.platform in p}
    if applicable:
        print(f"{total - len(applicable)} of {total} routes rendered correctly; "
              f"{len(applicable)} known limitation(s) on this platform:")
        for name, why in applicable.items():
            print(f"  - {name}: {why}")
        return 0
    print(f"All {total} routes rendered, and each contains what it should.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
