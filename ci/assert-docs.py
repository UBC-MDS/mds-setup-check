#!/usr/bin/env python3
"""Check that the documentation still describes this repository.

Every make target, fixture and ci/ script the docs name has to exist, and every link to
a section has to land on a real heading. A fixture rename that reaches the Makefile and
not the prose has already shipped here twice.

This cannot check whether a sentence is TRUE -- it catches names that have moved, not
claims that have stopped holding.

Usage:  python ci/assert-docs.py
Exit:   0 if every name the documents use resolves, 1 otherwise.
"""
import pathlib
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

import importlib.util

ROOT = pathlib.Path(__file__).resolve().parent.parent

# The fixture directory and the fixture list both come from the gate, so adding a
# fixture to render-checks/ without adding it to ROUTES fails this check.
_spec = importlib.util.spec_from_file_location(
    "assert_renders", pathlib.Path(__file__).with_name("assert-renders.py"))
_ar = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ar)
FIXTURE_DIR = _ar.FIXTURE_DIR
FIXTURES = {src for _, _, src in _ar.ROUTES.values()} | {"mds-logo.png"}
DOCS = ["README.md", "CLAUDE.md", "assignment-workflow-uv.md",
        "docs/render-matrix.md"]

failures: list[str] = []


def slug(heading: str) -> str:
    """GitHub's anchor for a heading: lowercase, punctuation dropped, spaces hyphened."""
    text = re.sub(r"<[^>]+>", "", heading).strip().lower()
    return re.sub(r"[^\w\s-]", "", text).replace(" ", "-")


_anchors: dict[pathlib.Path, set[str]] = {}


def anchors(path: pathlib.Path) -> set[str]:
    if path not in _anchors:
        _anchors[path] = {slug(h) for h in re.findall(
            r"^#{1,6}\s+(.*?)\s*$", path.read_text(encoding="utf-8"), re.M)}
    return _anchors[path]


def check(ok: bool, doc: str, what: str) -> None:
    print(f"  {'ok    ' if ok else 'FAIL  '} {doc:<24} {what}")
    if not ok:
        failures.append(f"{doc}: {what}")


def main() -> int:
    makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
    # Real targets only: a line starting at column 0 with `name:`. This ignores the ##
    # help text, so a target documented but deleted is still caught.
    targets = set(re.findall(r"^([a-zA-Z][a-zA-Z0-9_-]*):", makefile, re.M))

    for doc in DOCS:
        text = (ROOT / doc).read_text(encoding="utf-8")

        # Only inside a code span or fence. Matching bare prose would read "every make
        # target" as a target named `target`.
        named_targets = set(re.findall(r"`make ([a-z][a-z-]*)`", text))
        for block in re.findall(r"```[a-z]*\n(.*?)```", text, re.S):
            named_targets |= set(re.findall(r"^make ([a-z][a-z-]*)", block, re.M))
        for target in sorted(named_targets):
            check(target in targets, doc, f"`make {target}` is a real target")

        # The directory prefix is CAPTURED rather than stripped: a document naming a
        # fixture at the wrong path is exactly the drift this gate exists to catch. A
        # bare name is prose and resolves leniently -- but only if it is a fixture, so
        # the three scripts GitHub Pages serves stay pinned to the root.
        NAMES = (r"check-[a-z-]+\.(?:qmd|ipynb|Rmd|sh|log)"
                 r"|mds-help\.sh|mds-logo\.png|renv\.lock|uv\.lock")
        seen = set()
        for m in re.finditer(rf"(?<![\w/.-])((?:[\w.-]+/)*)({NAMES})\b", text):
            prefix, name = m.group(1), m.group(2)
            if name == "check-setup-mds.log" or (prefix, name) in seen:
                continue                      # produced at run time, not tracked
            seen.add((prefix, name))
            if prefix:
                check((ROOT / prefix / name).exists(), doc, f"`{prefix}{name}` exists")
            else:
                lenient = name in FIXTURES and (ROOT / FIXTURE_DIR / name).exists()
                check((ROOT / name).exists() or lenient, doc, f"`{name}` exists")
        for name in sorted(set(re.findall(r"\b(ci/[a-z-]+\.py)\b", text))):
            check((ROOT / name).exists(), doc, f"`{name}` exists")

        for wf in sorted(set(re.findall(r"\.github/workflows/[a-z-]+\.yml", text))):
            check((ROOT / wf).exists(), doc, f"`{wf}` exists")

        # Section links, which the docs use instead of "see section 4". A number
        # survives a rename and quietly starts pointing at the wrong place; a link
        # breaks, and this is what turns that break into a failed build.
        for where, anchor in sorted(set(re.findall(
                r"\[[^\]]*\]\(([^)#\s]*)#([^)\s]+)\)", text))):
            if where.startswith(("http://", "https://")):
                continue                      # someone else's page, not ours to check
            target = (ROOT / doc).parent / where if where else ROOT / doc
            label = f"`{where}#{anchor}`" if where else f"`#{anchor}`"
            if target.suffix != ".md" or not target.exists():
                check(False, doc, f"{label} points at a document that exists")
                continue
            check(anchor in anchors(target), doc, f"{label} points at a real heading")

    # The two documents must agree on the three commands a student runs.
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    claude = (ROOT / "CLAUDE.md").read_text(encoding="utf-8")
    for target in ("install", "all", "check"):
        check(f"make {target}" in readme and f"make {target}" in claude,
              "both", f"`make {target}` is documented in README.md and CLAUDE.md")

    print()
    if failures:
        print(f"{len(failures)} name(s) in the documentation no longer resolve:")
        for line in failures:
            print(f"  - {line}")
        print("\nUpdate the prose, or restore what it refers to.")
        return 1
    print("The documentation still describes this repository.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
