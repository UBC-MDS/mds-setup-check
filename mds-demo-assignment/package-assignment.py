#!/usr/bin/env python3
"""Turn otter's student output into the folder a student is actually handed.

`otter assign` produces the assignment and its tests and nothing else. This adds what a
student also needs: for Python a `pyproject.toml`, `uv.lock` and `.python-version`; for
both a `.gitignore` and a `Makefile`. The R one carries no lock file, because R packages
come from the library the MDS install guides set up.

Usage:  python package-assignment.py --lab lab0a --kind py --into DSCI_521_LAB_ORIENTATION_PY
        python package-assignment.py --lab lab0b --kind r  --into DSCI_521_LAB_ORIENTATION_R
"""
from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent

# Copied verbatim rather than regenerated: a fresh resolve on a student's machine could
# pick up a newer pandas the week an assignment is due.
KIND = {
    "py": {"suffix": ".ipynb",
           "workspace": ["pyproject.toml", "uv.lock", ".gitignore", ".gitattributes"]},
    "r": {"suffix": ".Rmd",
          "workspace": [".gitignore", ".gitattributes"]},
}


def clear_outputs(notebook: pathlib.Path) -> int:
    """Strip saved output and execution counts from a .ipynb, in place.

    otter already does this, but an instructor who ran the source notebook to check
    their own answers leaves it behind, and an assignment that arrives with results
    already in it is confusing at best.
    """
    nb = json.loads(notebook.read_text(encoding="utf-8"))
    dirty = sum(1 for c in nb["cells"] if c.get("cell_type") == "code"
                and (c.get("outputs") or c.get("execution_count") is not None))
    if dirty:
        for cell in nb["cells"]:
            if cell.get("cell_type") == "code":
                cell["outputs"], cell["execution_count"] = [], None
        notebook.write_text(json.dumps(nb, indent=1, ensure_ascii=False) + "\n",
                            encoding="utf-8")
    return dirty


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--lab", default="lab0a")
    ap.add_argument("--kind", choices=sorted(KIND), default="py")
    ap.add_argument("--into", default="DSCI_521_LAB_ORIENTATION_PY")
    args = ap.parse_args()
    spec = KIND[args.kind]

    student = HERE / "release" / args.lab / "student"
    if not student.is_dir():
        print(f"error: {student.relative_to(HERE)} does not exist.")
        print(f"Run `make LAB={args.lab} generate` first -- that builds it from source/.")
        return 1

    out = HERE / args.into
    # Rebuilt from scratch every time. Anything a previous run left behind is not part
    # of the assignment, and a stale file here would ship to every student in the class.
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(student, out)

    missing = []
    for name in spec["workspace"]:
        src = HERE / name
        shutil.copy2(src, out / name) if src.exists() else missing.append(name)
    template = HERE / "student-template" / args.kind
    if not template.is_dir():
        missing.append(f"student-template/{args.kind}/")
    else:
        for src in sorted(template.iterdir()):
            if src.is_file():
                shutil.copy2(src, out / src.name)

    if missing:
        print("error: these files are missing from the workspace:")
        for m in missing:
            print(f"  {m}")
        return 1

    assignment = out / f"{args.lab}{spec['suffix']}"
    if not assignment.exists():
        print(f"error: {assignment.name} is not in the student output.")
        return 1

    if spec["suffix"] == ".ipynb":
        cleared = clear_outputs(assignment)
        if cleared:
            print(f"cleared saved output from {cleared} cell(s)")

    # otter strips solutions, but this runs anyway: handing out an assignment with its
    # answers in it cannot be taken back once the folder is given away.
    body = assignment.read_text(encoding="utf-8")
    for marker in ("BEGIN SOLUTION", "END SOLUTION"):
        if marker in body:
            print(f"error: {assignment.name} still contains a {marker!r} marker.")
            print("The solutions were not stripped. Do not hand this out.")
            return 1

    print(f"Built {out.relative_to(HERE)}/ from release/{args.lab}/student/")
    for p in sorted(out.rglob("*")):
        if p.is_file():
            print(f"  {p.relative_to(out)}")
    print()
    print("Give students the whole directory. They move it somewhere outside this")
    print("repository, then run `make setup`.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
