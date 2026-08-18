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
import pathlib
import re

# Characters the fixtures contain, and which routes can reproduce them.
#   ok     - must be present, the route supports it
#   absent - the route is known not to support it; assert it is NOT there, so
#            that a future fix is noticed rather than silently absorbed
LATEX = "latex"
FULL = "full"

ROUTES = {
    "check-quarto-latex.pdf":  ("Quarto -> LaTeX",      LATEX),
    "check-notebook.pdf":      ("nbconvert -> LaTeX",   LATEX),
    "check-rmarkdown.pdf":     ("rmarkdown -> LaTeX",   LATEX),
    "check-quarto-typst.pdf":  ("Quarto -> Typst",      FULL),
    "check-quarto-r-latex.pdf": ("Quarto R -> LaTeX",   LATEX),
    "check-quarto-r-typst.pdf": ("Quarto R -> Typst",   FULL),
    "check-quarto-r.html":     ("Quarto R -> HTML",     FULL),
    "check-notebook-web.pdf":  ("nbconvert -> Chromium", FULL),
    "check-quarto.html":       ("Quarto -> HTML",       FULL),
    "check-notebook.html":     ("nbconvert -> HTML",    FULL),
    "check-rmarkdown.html":    ("rmarkdown -> HTML",    FULL),
}

# (label, string, supported-by)
CHECKS = [
    ("accented latin", "Montréal", {LATEX, FULL}),
    ("degree sign",    "°C",       {LATEX, FULL}),
    ("en dash",        "–",        {LATEX, FULL}),
    ("literal Greek",  "α",        {FULL}),
    ("emoji",          "✅",       {FULL}),
]


def text_of(path: pathlib.Path) -> str:
    if path.suffix == ".html":
        raw = path.read_text(errors="replace")
        raw = re.sub(r"<(script|style).*?</\1>", " ", raw, flags=re.S)
        import html as _html
        return _html.unescape(re.sub(r"<[^>]+>", " ", raw))
    from pypdf import PdfReader
    return "\n".join(page.extract_text() or "" for page in PdfReader(str(path)).pages)


def main() -> int:
    failures, checked = [], 0
    for name, (label, kind) in ROUTES.items():
        path = pathlib.Path(name)
        if not path.exists():
            print(f"  skip   {label:<24} {name} not produced")
            continue
        checked += 1
        try:
            body = text_of(path)
        except Exception as exc:                      # noqa: BLE001
            failures.append(f"{name}: could not read ({exc})")
            print(f"  FAIL   {label:<24} unreadable: {exc}")
            continue

        problems = []
        for desc, needle, supported in CHECKS:
            present = needle in body
            if kind in supported and not present:
                problems.append(f"missing {desc} ({needle!r})")
            elif kind not in supported and present:
                problems.append(
                    f"{desc} ({needle!r}) now renders -- this route was not "
                    f"expected to support it; update ci/assert-renders.py")
        # A replacement character means a glyph was dropped, whatever it was.
        if kind == FULL and "�" in body:
            problems.append("contains U+FFFD, so something was dropped")

        if problems:
            failures.append(f"{name}: " + "; ".join(problems))
            print(f"  FAIL   {label:<24} " + "; ".join(problems))
        else:
            print(f"  ok     {label:<24} {name}")

    print()
    if checked == 0:
        print("No rendered output found. Run `make -k all` first.")
        return 1
    if failures:
        print(f"{len(failures)} of {checked} rendered output(s) failed.")
        return 1
    print(f"All {checked} rendered output(s) contain what they should.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
