#!/usr/bin/env python3
"""Fail if a document uses a construct that some PDF route drops silently.

Every route exits 0 while discarding what it cannot set, so "it rendered" is not
evidence it rendered correctly. The three rules come from ../assignment-workflow-uv.md:

  1. Maths goes inside $...$ or $$...$$. A bare \\begin{equation} or \\begin{align} is
     forwarded untranslated, so Typst renders nothing. Use
     $$\\begin{aligned}...\\end{aligned}$$ and number with Quarto's {#eq-label}.

  2. Nothing outside maths starts with a backslash. \\textbf{}, \\emph{}, \\footnote{}
     and tabular reach the LaTeX PDF and vanish from Typst and HTML.

  3. Greek is \\alpha, not a literal character, and emoji are avoided in anything
     destined for a LaTeX PDF. $$ is not a shield: \\text{} switches back to text.

This checks the SOURCE, not the output, on purpose. A construct that is dropped
silently leaves no trace in the PDF to assert on -- the sentence around it is still
grammatical, which is exactly why these reach students.

Usage:  python lint-portability.py lab1.ipynb [more files...]
Exit:   0 if every file is portable, 1 otherwise.
"""
import json
import pathlib
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

GREEK = re.compile(r"[\u0370-\u03ff\u1f00-\u1fff]")
EMOJI = re.compile("[" "\U0001f300-\U0001faff" "\u2600-\u27bf" "\u2b00-\u2bff" "\ufe0f" "]")
# A backslash command, but not an escaped punctuation mark such as \_ or \$.
COMMAND = re.compile(r"\\[a-zA-Z]+")
MATHS = re.compile(r"\$\$.*?\$\$|\$[^$\n]+?\$", re.S)
FENCE = re.compile(r"^[ \t]*(```|~~~).*?^[ \t]*\1", re.S | re.M)
INLINE_CODE = re.compile(r"`[^`\n]+`")


def markdown_of(path: pathlib.Path) -> list[tuple[str, str]]:
    """(where, text) for every prose region of a document."""
    raw = path.read_text(encoding="utf-8")
    if path.suffix == ".ipynb":
        cells = json.loads(raw)["cells"]
        return [(f"cell {i}", "".join(c["source"]))
                for i, c in enumerate(cells) if c["cell_type"] == "markdown"]
    # .qmd/.Rmd/.md: the whole file is prose apart from its chunks, and the fenced
    # blocks are stripped below, so one region is enough.
    return [("document", raw)]


def blank(match: re.Match) -> str:
    """Replace a region with spaces, so later offsets still line up."""
    return re.sub(r"[^\n]", " ", match.group(0))


def check(path: pathlib.Path) -> list[str]:
    problems = []
    for where, text in markdown_of(path):
        # Code is exempt: `\begin{align}` in backticks is talked about, not typeset.
        prose = INLINE_CODE.sub(blank, FENCE.sub(blank, text))
        maths_only = "".join(m.group(0) for m in MATHS.finditer(prose))
        outside = MATHS.sub(blank, prose)

        for m in re.finditer(r"\\begin\{(\w+)\}", outside):
            problems.append(
                f"{where}: raw \\begin{{{m.group(1)}}} outside maths. Typst renders "
                f"nothing here. Write $$\\begin{{aligned}}...\\end{{aligned}}$$, and "
                f"$$ ... $$ {{#eq-label}} if you need a number.")

        for m in COMMAND.finditer(outside):
            if m.group(0) in (r"\begin", r"\end"):
                continue                       # already reported above
            problems.append(
                f"{where}: {m.group(0)} outside maths. Raw LaTeX reaches the LaTeX "
                f"PDF and is dropped by Typst. Use markdown instead.")

        for pattern, name, fix in (
                (GREEK, "a literal Greek letter", r"write it as maths, e.g. $\alpha$"),
                (EMOJI, "an emoji", "render with Typst, HTML or WebPDF, not LaTeX")):
            for m in pattern.finditer(outside):
                problems.append(f"{where}: {name} ({m.group(0)!r}) in prose. "
                                f"LaTeX has no glyph for it and drops it silently -- {fix}.")
            # Inside maths too: \text{} and \mathrm{} put the character back under the
            # same limitation, inside an equation that otherwise typesets perfectly.
            for m in pattern.finditer(maths_only):
                problems.append(f"{where}: {name} ({m.group(0)!r}) inside maths. "
                                f"$$ is not a shield -- {fix}.")
    return problems


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    failures = 0
    for name in argv:
        path = pathlib.Path(name)
        problems = check(path)
        if problems:
            failures += len(problems)
            print(f"{path}: {len(problems)} problem(s)")
            for p in problems:
                print(f"  {p}")
        else:
            print(f"{path}: ok, every construct survives every route")
    if failures:
        print(f"\n{failures} construct(s) would be dropped by at least one PDF route.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
