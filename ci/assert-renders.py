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
LATEX = "latex"   # accents and maths yes; Greek and emoji dropped
TYPST = "typst"   # Greek and emoji yes; \begin{align} dropped
FULL = "full"     # HTML and the browser route: everything

# Routes known not to produce output at all, with the reason. A route listed here
# is reported as a known limitation rather than a failure -- but if it starts
# working, that is reported too, because the limitation is what is documented.
KNOWN_TO_FAIL = {
    "check-notebook.pdf":
        "nbconvert's LaTeX template emits \\LTcaptype{none} for a markdown table, "
        "which this TeX Live rejects with \"No counter 'none' defined\". Any notebook "
        "containing a markdown table fails JupyterLab's PDF export for the same reason.",
}

ROUTES = {
    "check-quarto-latex.pdf":  ("Quarto -> LaTeX",      LATEX),
    "check-notebook.pdf":      ("nbconvert -> LaTeX",   LATEX),
    "check-rmarkdown.pdf":     ("rmarkdown -> LaTeX",   LATEX),
    "check-quarto-typst.pdf":  ("Quarto -> Typst",      TYPST),
    "check-quarto-r-latex.pdf": ("Quarto R -> LaTeX",   LATEX),
    "check-quarto-r-typst.pdf": ("Quarto R -> Typst",   TYPST),
    "check-quarto-r.html":     ("Quarto R -> HTML",     FULL),
    "check-notebook-web.pdf":  ("nbconvert -> Chromium", FULL),
    "check-quarto.html":       ("Quarto -> HTML",       FULL),
    "check-notebook.html":     ("nbconvert -> HTML",    FULL),
    "check-rmarkdown.html":    ("rmarkdown -> HTML",    FULL),
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
    ("aligned eqns",   ["Var"],             {LATEX, FULL}),
    ("literal Greek",  ["α"],               {TYPST, FULL}),
    ("emoji",          ["✅", "📊"],         {TYPST, FULL}),
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
    missing, broken, ok = [], [], []

    for name, (label, kind) in ROUTES.items():
        path = pathlib.Path(name)
        if not path.exists():
            if name in KNOWN_TO_FAIL:
                print(f"  known    {label:<24} does not render -- see KNOWN_TO_FAIL")
                continue
            missing.append((label, name))
            print(f"  MISSING  {label:<24} {name} was not produced")
            continue
        if name in KNOWN_TO_FAIL:
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

    known = len(KNOWN_TO_FAIL)
    if known:
        print(f"{total - known} of {total} routes rendered correctly; "
              f"{known} is a known limitation:")
        for name, why in KNOWN_TO_FAIL.items():
            print(f"  - {name}: {why}")
        return 0
    print(f"All {total} routes rendered, and each contains what it should.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
