#!/usr/bin/env python3
"""Check the claims assignment-workflow-uv.md makes about this repository.

That document names this repository as the reference implementation for MDS
assignment repos, and section 3 lists what such a repo must contain. Course repos
are copied from this one, so if these stop being true every repo derived from it
inherits the problem, quietly.

Each check names the section it defends, so a failure says what broke rather than
only that something did.

Usage:  python ci/assert-contract.py
Exit:   0 if the contract holds, 1 otherwise.
"""
import pathlib
import re
import sys

# Windows consoles default to a legacy codepage, and these scripts print the very
# characters they are checking for. Without this, a report mentioning α dies with
# UnicodeEncodeError on Windows and takes the whole check with it.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
import tomllib

FAIL = []


def check(ok: bool, section: str, claim: str, detail: str = "") -> None:
    if ok:
        print(f"  ok     §{section}  {claim}")
    else:
        print(f"  FAIL   §{section}  {claim}" + (f" -- {detail}" if detail else ""))
        FAIL.append(claim)


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent
    pyproject = tomllib.loads((root / "pyproject.toml").read_text(encoding="utf-8"))
    deps = pyproject["project"]["dependencies"]
    names = {d.split(">=")[0].split("[")[0].split("==")[0].strip() for d in deps}

    # §3: four deliberate choices, each with a stated reason
    check("jupyterlab" in names, "3",
          "jupyterlab is a real dependency, not a dev one",
          "server extensions only work in the same prefix as the kernel")
    check("ipykernel" in names, "3",
          "ipykernel is listed explicitly",
          "so `uv sync --no-dev` still leaves a Python kernel")
    check("otter-grader" in names, "3",
          "otter-grader is a real dependency",
          "students write `import otter` in their notebooks")
    check(pyproject.get("tool", {}).get("uv", {}).get("package") is False, "3",
          "package = false")

    # §3: the rest of the repo contract
    check((root / "uv.lock").exists(), "3", "uv.lock is committed")
    gitignore = (root / ".gitignore").read_text(encoding="utf-8")
    check(".venv" in gitignore, "3", ".gitignore covers .venv")
    check("requires-python" in pyproject["project"], "3",
          "requires-python is set")
    # The Windows install guide has students set git to check out CRLF, so without
    # this a Makefile and every .sh arrive with carriage returns: bash fails on the
    # shebang and make appends \r to every argument. This repo is the template those
    # repos are copied from, so losing the file here propagates the breakage.
    gitattributes = (root / ".gitattributes").read_text(encoding="utf-8")
    for pattern in ("*.sh", "Makefile"):
        check(f"{pattern} " in gitattributes and "eol=lf" in gitattributes, "3",
              f".gitattributes pins {pattern} to LF")

    # §5: the routes the guides promise. A Makefile target per route means the
    # promise is executable rather than prose.
    makefile = (root / "Makefile").read_text(encoding="utf-8")
    for target, route in [("pdf", "LaTeX PDF"), ("typst", "Typst PDF"),
                          ("html", "HTML"), ("webpdf", "WebPDF")]:
        # The target has to have prerequisites, not merely exist. `pdf:` with an empty
        # right-hand side satisfies a substring test and renders nothing.
        line = next((l for l in makefile.splitlines()
                     if l.startswith(f"{target}:")), "")
        prereqs = line.split(":", 1)[1].split("##")[0].strip() if line else ""
        check(bool(prereqs), "5", f"{route} route has a make target",
              "the target exists but has no prerequisites" if line else "no such target")

    # The script students actually run renders the fixtures too, and it is not covered by
    # any other check here. A fixture renamed in the Makefile and not in the script is
    # invisible until install week -- which is exactly what happened to check-quarto.qmd.
    script = (root / "check-setup-mds.sh").read_text(encoding="utf-8")
    # Anchored on the "$mds_project/" the script actually copies FROM, not on the bare
    # basename. A basename is also printed in the student-facing error messages, so
    # matching it would verify a message string rather than a path -- and would pass
    # happily while one of the five copy sites kept a stale directory. This resolves
    # what the script really opens, so a missing prefix at any site is a failure.
    referenced = set(re.findall(
        r"\$mds_project/(\S+?\.(?:qmd|ipynb|Rmd))", script))
    check(bool(referenced), "5", "the setup check script names some fixtures")
    for fixture in sorted(referenced):
        check((root / fixture).exists(), "5",
              f"check-setup-mds.sh renders {fixture}, and it exists")
    # Both PDF routes in that script need the logo the fixtures embed; a missing image is
    # a hard error in LaTeX and in Typst, not a warning.
    logos = set(re.findall(r"\$mds_project/(\S*mds-logo\.png)", script))
    check(bool(logos) and all((root / p).exists() for p in logos), "5",
          "check-setup-mds.sh copies mds-logo.png alongside the fixtures",
          "the fixtures embed it, and every PDF route fails without it")

    print()
    if FAIL:
        print(f"{len(FAIL)} contract check(s) failed.")
        return 1
    print("The repository still matches what assignment-workflow-uv.md describes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
