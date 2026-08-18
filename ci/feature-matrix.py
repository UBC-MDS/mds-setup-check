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

# Routes and features are both derived from the gate rather than restated here.
# They used to be two hand-kept lists, and they drifted: the gate stopped accepting
# "unbiased" as evidence of inline maths because it is the prose beside the equation,
# and this table went on accepting it for months. A published table that is more
# forgiving than the gate it illustrates is worse than no table.
_PRETTY = {"LaTeX": "LaTeX PDF", "Typst": "Typst PDF"}

ROUTES = []
for _name, (_label, _kind, _src) in _ar.ROUTES.items():
    _, _tool, _out = (part.strip() for part in _label.split("->"))
    ROUTES.append((_src, _tool, _PRETTY.get(_out, _out), _name))

# The full feature list, not grouped: a column that always agrees is still worth
# showing, because the day it stops agreeing is the day this table earns its keep.
# (label, needles, source marker). The marker is what decides whether a fixture is
# asked about a feature at all -- a document with no markdown table is not failing
# to render one.
FEATURES = [(desc, needles, marker) for desc, needles, _, marker in _ar.CHECKS]
FEATURES.append(("image", [], "mds-logo.png"))

# The image probe and the source reader both live in assert-renders.py, so the gate
# and this table agree on what "the image is there" and "the fixture contains it" mean.
has_image = _ar.has_image
source_text = _ar.source_text


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
        heads = [f for f, _, _ in FEATURES]
        print("| " + " | ".join(lead + heads) + " |")
        print("|" + "---|" * (len(lead) + len(heads)))

        notes = []
        for src, tool, out, name in routes:
            path = pathlib.Path(name)
            row = ([f"`{src}`"] if multi else []) + [tool, out]
            written = source_text(src)
            # A dash means the fixture does not contain the construct, which is a
            # different statement from a cross. Without the distinction the
            # table-only fixture would read as a row of failures.
            applies = [marker in written for _, _, marker in FEATURES]
            if not path.exists():
                notes.append((name, tool, out))
                row[-2] = f"{tool} {WARN}"
                print("| " + " | ".join(
                    row + [NO if a else NA for a in applies]) + " |")
                continue
            body = text_of(path)
            for (feat, needles, _), applicable in zip(FEATURES, applies):
                if not applicable:
                    row.append(NA)
                elif not needles:                       # the image
                    row.append(YES if has_image(path) else NO)
                else:
                    row.append(YES if any(n in body for n in needles) else NO)
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
