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
import sys
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
    pyproject = tomllib.loads((root / "pyproject.toml").read_text())
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
    gitignore = (root / ".gitignore").read_text()
    check(".venv" in gitignore, "3", ".gitignore covers .venv")
    check("requires-python" in pyproject["project"], "3",
          "requires-python is set")

    # §5: the routes the guides promise. A Makefile target per route means the
    # promise is executable rather than prose.
    makefile = (root / "Makefile").read_text()
    for target, route in [("pdf:", "LaTeX PDF"), ("typst:", "Typst PDF"),
                          ("html:", "HTML"), ("webpdf:", "WebPDF")]:
        check(f"\n{target}" in makefile, "5", f"{route} route has a make target")

    print()
    if FAIL:
        print(f"{len(FAIL)} contract check(s) failed.")
        return 1
    print("The repository still matches what assignment-workflow-uv.md describes.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
