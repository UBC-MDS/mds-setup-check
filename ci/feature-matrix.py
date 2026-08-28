#!/usr/bin/env python3
"""Measure which document features survive which render route.

The table goes in docs/render-matrix.md, generated rather than hand-written because a
hand-maintained table of a program's behaviour drifts from the behaviour.

Run `make all` first, then `python ci/feature-matrix.py`.
"""
import pathlib, re, html, sys, importlib.util

# On Windows the redirected stdout of `make matrix >> "$GITHUB_STEP_SUMMARY"` is the
# locale codepage, not UTF-8, and this prints tick and cross marks.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass

# Imported from the gate so the footnotes and the verdict cannot disagree.
_spec = importlib.util.spec_from_file_location(
    "assert_renders", pathlib.Path(__file__).with_name("assert-renders.py"))
_ar = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ar)
KNOWN_TO_FAIL = _ar.KNOWN_TO_FAIL

# Routes and features are derived from the gate, not restated. They used to be two
# hand-kept lists and drifted, leaving a published table more forgiving than the gate.
_PRETTY = {"LaTeX": "LaTeX PDF", "Typst": "Typst PDF"}

ROUTES = []
for _name, (_label, _kind, _src) in _ar.ROUTES.items():
    _, _tool, _out = (part.strip() for part in _label.split("->"))
    ROUTES.append((_src, _tool, _PRETTY.get(_out, _out), _name, _kind))

# (label, needles, supported-by, source marker). The marker decides whether a fixture
# is asked about a feature at all -- a document with no markdown table is not failing
# to render one. The supported set is carried through rather than discarded, which is
# what lets a cell say "never meant to do that" rather than "broken".
FEATURES = [(desc, needles, supported, marker)
            for desc, needles, supported, marker in _ar.CHECKS]
FEATURES.append(("image", [], _ar.IMAGE_ROUTES, "mds-logo.png"))

# Reused from the gate so both agree on what "the image is there", "the fixture
# contains it" and the fixture directory join mean.
has_image = _ar.has_image
source_text = _ar.source_text
fixture = _ar.fixture
FIXTURE_DIR = _ar.FIXTURE_DIR


def text_of(path: pathlib.Path) -> str:
    if path.suffix == ".html":
        raw = path.read_text(encoding="utf-8", errors="replace")
        raw = re.sub(r"<(script|style).*?</\1>", " ", raw, flags=re.S)
        return html.unescape(re.sub(r"<[^>]+>", " ", raw))
    from pypdf import PdfReader
    return "\n".join(p.extract_text() or "" for p in PdfReader(str(path)).pages)


def main() -> int:
    # Four outcomes, not two. A cross used to mean both "broken" and "never going to
    # survive this route", which are opposite readings: one is a bug to chase, the
    # other is a reason to pick a different route.
    YES = "✅"    # present, and this route is expected to reproduce it
    BYDES = "⬜"  # absent, and this route is NOT expected to -- by design, not a fault
    NO = "❌"     # absent, but this route WAS expected to: something is broken
    NEW = "❗"    # present, but this route was not expected to: the gate is out of date
    NA = "—"      # the fixture does not contain the construct at all
    WARN = "⚠️"   # the route produced no file at all; see the note under the table

    print("Legend: "
          f"{YES} works · "
          f"{BYDES} not supported by this route, by design · "
          f"{NO} **broken** -- expected here and missing · "
          f"{NEW} unexpectedly present, the gate needs updating · "
          f"{NA} the fixture does not contain it · "
          f"{WARN} no file produced")

    def icon(present: bool, expected: bool) -> str:
        if present:
            return YES if expected else NEW
        return NO if expected else BYDES

    by_ext = {}
    for route in ROUTES:
        by_ext.setdefault(pathlib.Path(route[0]).suffix, []).append(route)

    for ext, routes in by_ext.items():
        sources = sorted({r[0] for r in routes})
        # .qmd has two fixtures, one per language, so that table needs a column.
        multi = len(sources) > 1
        print(f"\n**`{ext}`**"
              + ("" if multi else f" — `{FIXTURE_DIR}/{sources[0]}`") + "\n")
        lead = (["input"] if multi else []) + ["rendered by", "output"]
        heads = [f for f, _, _, _ in FEATURES]
        print("| " + " | ".join(lead + heads) + " |")
        print("|" + "---|" * (len(lead) + len(heads)))

        notes = []
        for src, tool, out, name, kind in routes:
            path = fixture(name)
            row = ([f"`{FIXTURE_DIR}/{src}`"] if multi else []) + [tool, out]
            written = source_text(src)
            # A dash means the fixture does not contain the construct, which is a
            # different statement from a cross.
            applies = [marker in written for _, _, _, marker in FEATURES]
            expected = [_ar.supports(sup, kind, name) for _, _, sup, _ in FEATURES]
            if not path.exists():
                # Nothing was produced, so cells point at the note under the table
                # rather than carrying crosses -- but only for a DOCUMENTED
                # limitation, so "❌ means something is broken right now" stays true.
                notes.append((name, tool, out))
                row[-2] = f"{tool} {WARN}"
                blank = WARN if _ar.is_known(name) else NO
                print("| " + " | ".join(row + [
                    (blank if e else BYDES) if a else NA
                    for a, e in zip(applies, expected)]) + " |")
                continue
            body = text_of(path)
            for (feat, needles, _, _), applicable, exp in zip(FEATURES, applies, expected):
                if not applicable:
                    row.append(NA)
                elif not needles:                       # the image
                    row.append(icon(has_image(path), exp))
                else:
                    row.append(icon(any(n in body for n in needles), exp))
            print("| " + " | ".join(row) + " |")

        for name, tool, out in notes:
            # is_known, not a bare lookup: the WebPDF limitation is Windows-only, so
            # printing it for a Linux failure would excuse a real breakage.
            _, why = (KNOWN_TO_FAIL[name] if _ar.is_known(name)
                      else (None, "this route produced no file on this platform, and it "
                                  "is not a known limitation -- something is broken."))
            print(f"\n{WARN} **{tool} → {out} produces no file at all.** {why}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
