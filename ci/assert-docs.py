#!/usr/bin/env python3
"""Check that the documentation still describes this repository.

Documentation drifts silently, and this project exists because silent drift is the
failure mode worth catching. Both documents name make targets, fixtures and scripts;
this asserts that every one of them exists. A fixture rename that reaches the Makefile
and not the prose is exactly the class of defect that has already shipped here twice.

What this cannot do is check whether a sentence is TRUE. It catches names that have
moved, not claims that have stopped holding, so changing behaviour still means editing
both documents by hand.

Usage:  python ci/assert-docs.py
Exit:   0 if every name the documents use resolves, 1 otherwise.
"""
import pathlib
import re
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = pathlib.Path(__file__).resolve().parent.parent
# assignment-workflow-uv.md is here because course repos are copied from what it
# describes: it names fixtures and ci/ scripts, and nothing was checking that those
# names still resolve. A rename would have broken the guide the teaching team reads
# without breaking anything that runs.
DOCS = ["README.md", "CLAUDE.md", "assignment-workflow-uv.md"]

failures: list[str] = []


def check(ok: bool, doc: str, what: str) -> None:
    print(f"  {'ok    ' if ok else 'FAIL  '} {doc:<12} {what}")
    if not ok:
        failures.append(f"{doc}: {what}")


def main() -> int:
    makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
    # Real targets only: a line starting at column 0 with `name:`. This deliberately
    # ignores the ## help text, so a target documented but deleted is still caught.
    targets = set(re.findall(r"^([a-zA-Z][a-zA-Z0-9_-]*):", makefile, re.M))

    for doc in DOCS:
        text = (ROOT / doc).read_text(encoding="utf-8")

        # Only inside a code span or a fenced block. Matching bare prose instead
        # would read "every make target, fixture and script" as a target named
        # `target`, which is the sort of false positive that gets a check disabled.
        named_targets = set(re.findall(r"`make ([a-z][a-z-]*)`", text))
        for block in re.findall(r"```[a-z]*\n(.*?)```", text, re.S):
            named_targets |= set(re.findall(r"^make ([a-z][a-z-]*)", block, re.M))
        for target in sorted(named_targets):
            check(target in targets, doc, f"`make {target}` is a real target")

        # Fixture and script filenames.
        named = set(re.findall(r"\b(check-[a-z-]+\.(?:qmd|ipynb|Rmd|sh|log))\b", text))
        named |= set(re.findall(r"\b(ci/[a-z-]+\.py)\b", text))
        named |= set(re.findall(r"\b(mds-help\.sh|mds-logo\.png|renv\.lock|uv\.lock)\b", text))
        for name in sorted(named):
            if name == "check-setup-mds.log":
                continue                      # produced at run time, not tracked
            check((ROOT / name).exists(), doc, f"`{name}` exists")

        # A workflow path is quoted in both documents.
        for wf in sorted(set(re.findall(r"\.github/workflows/[a-z-]+\.yml", text))):
            check((ROOT / wf).exists(), doc, f"`{wf}` exists")

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
