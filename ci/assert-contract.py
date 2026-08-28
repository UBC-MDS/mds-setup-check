#!/usr/bin/env python3
"""Check the claims assignment-workflow-uv.md makes about this repository.

Course repos are copied from what that document describes, so if these stop being true
every repo derived from it inherits the problem. Each check names the section it
defends, by heading rather than by number, so renumbering the guide cannot strand it.

Usage:  python ci/assert-contract.py
Exit:   0 if the contract holds, 1 otherwise.
"""
import pathlib
import re
import sys

# Windows consoles default to a legacy codepage, and this prints the very characters
# it checks for: without this a report mentioning α dies with UnicodeEncodeError.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
import tomllib

FAIL = []


# The headings in assignment-workflow-uv.md that these checks defend.
CONTRACT = "What your repo must contain"
ROUTES = "Writing a document that renders everywhere"


_shown = None


def check(ok: bool, section: str, claim: str, detail: str = "") -> None:
    global _shown
    if section != _shown:
        print(f"\n  {section}")
        _shown = section
    print(f"    {'ok  ' if ok else 'FAIL'}  {claim}"
          + (f" -- {detail}" if not ok and detail else ""))
    if not ok:
        FAIL.append(claim)


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent
    pyproject = tomllib.loads((root / "pyproject.toml").read_text(encoding="utf-8"))
    deps = pyproject["project"]["dependencies"]
    names = {d.split(">=")[0].split("[")[0].split("==")[0].strip() for d in deps}

    # Four deliberate choices, each with a stated reason
    check("jupyterlab" in names, CONTRACT,
          "jupyterlab is a real dependency, not a dev one",
          "server extensions only work in the same prefix as the kernel")
    check("ipykernel" in names, CONTRACT,
          "ipykernel is listed explicitly",
          "so `uv sync --no-dev` still leaves a Python kernel")
    check("otter-grader" in names, CONTRACT,
          "otter-grader is a real dependency",
          "students write `import otter` in their notebooks")
    check(pyproject.get("tool", {}).get("uv", {}).get("package") is False, CONTRACT,
          "package = false")

    # The rest of the repo contract
    check((root / "uv.lock").exists(), CONTRACT, "uv.lock is committed")
    gitignore = (root / ".gitignore").read_text(encoding="utf-8")
    check(".venv" in gitignore, CONTRACT, ".gitignore covers .venv")
    check("requires-python" in pyproject["project"], CONTRACT,
          "requires-python is set")
    # Without this a Makefile and every .sh arrive on Windows with carriage returns:
    # bash fails on the shebang and make appends \r to every argument.
    gitattributes = (root / ".gitattributes").read_text(encoding="utf-8")
    for pattern in ("*.sh", "Makefile"):
        check(f"{pattern} " in gitattributes and "eol=lf" in gitattributes, CONTRACT,
              f".gitattributes pins {pattern} to LF")

    # The routes the guides promise. A Makefile target per route means the promise is
    # executable rather than prose.
    makefile = (root / "Makefile").read_text(encoding="utf-8")
    for target, route in [("pdf", "LaTeX PDF"), ("typst", "Typst PDF"),
                          ("html", "HTML"), ("webpdf", "WebPDF")]:
        # Prerequisites, not merely existence: `pdf:` with an empty right-hand side
        # satisfies a substring test and renders nothing.
        line = next((l for l in makefile.splitlines()
                     if l.startswith(f"{target}:")), "")
        prereqs = line.split(":", 1)[1].split("##")[0].strip() if line else ""
        check(bool(prereqs), ROUTES, f"{route} route has a make target",
              "the target exists but has no prerequisites" if line else "no such target")

    # The script students run renders the fixtures too, and nothing else here covers it.
    # A fixture renamed in the Makefile and not in the script is invisible until install
    # week -- which is exactly what happened once.
    script = (root / "check-setup-mds.sh").read_text(encoding="utf-8")
    # Anchored on the "$mds_project/" the script copies FROM, not the bare basename:
    # basenames also appear in error messages, so matching one would verify a string
    # rather than a path and pass while a copy site kept a stale directory.
    referenced = set(re.findall(
        r"\$mds_project/(\S+?\.(?:qmd|ipynb|Rmd))", script))
    check(bool(referenced), ROUTES, "the setup check script names some fixtures")
    for fixture in sorted(referenced):
        check((root / fixture).exists(), ROUTES,
              f"check-setup-mds.sh renders {fixture}, and it exists")
    # A missing image is a hard error in LaTeX and in Typst, not a warning.
    logos = set(re.findall(r"\$mds_project/(\S*mds-logo\.png)", script))
    check(bool(logos) and all((root / p).exists() for p in logos), ROUTES,
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
