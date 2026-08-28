#!/usr/bin/env python3
"""Turn otter's student output into the folder a student is actually handed.

`otter assign` produces `release/<lab>/student/`, which holds the notebook and nothing
else. A student needs more than a notebook: the packages pinned to exact versions, a
Python version, a `.gitignore`, and one command per thing they have to do. This copies
those in and gives the result the name the course uses.

The output is deliberately a plain directory rather than a subdirectory of this
repository's project. It carries its own `pyproject.toml` and `uv.lock`, so a student
moves it out, runs `uv sync`, and has one environment rather than two nested ones.

Usage:  python package-assignment.py [--lab lab0a] [--into DSCI_521_LAB_ORIENTATION_PY]
"""
from __future__ import annotations

import argparse
import pathlib
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent

# Copied verbatim from the instructor workspace, so the student resolves to the same
# versions the assignment was written and tested against. uv.lock is the reason to copy
# rather than regenerate: a fresh resolve on a student's machine could pick up a newer
# pandas the week an assignment is due.
FROM_WORKSPACE = ["pyproject.toml", "uv.lock", ".gitignore", ".gitattributes"]
FROM_TEMPLATE = ["Makefile", ".python-version"]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--lab", default="lab0a")
    ap.add_argument("--into", default="DSCI_521_LAB_ORIENTATION_PY")
    args = ap.parse_args()

    student = HERE / "release" / args.lab / "student"
    if not student.is_dir():
        print(f"error: {student.relative_to(HERE)} does not exist.")
        print("Run `make generate` first -- that is what builds it from source/.")
        return 1

    out = HERE / args.into
    # Rebuilt from scratch every time. Anything a previous run left behind is not part
    # of the assignment, and a stale file here would ship to every student in the class.
    if out.exists():
        shutil.rmtree(out)
    shutil.copytree(student, out)

    missing = []
    for name in FROM_WORKSPACE:
        src = HERE / name
        (shutil.copy2(src, out / name) if src.exists() else missing.append(name))
    for name in FROM_TEMPLATE:
        src = HERE / "student-template" / name
        (shutil.copy2(src, out / name) if src.exists() else
         missing.append(f"student-template/{name}"))

    if missing:
        print("error: these files are missing from the workspace:")
        for m in missing:
            print(f"  {m}")
        return 1

    notebook = out / f"{args.lab}.ipynb"

    # Clear every output and execution count. otter strips them, but an instructor who
    # ran the source notebook to check their own answers can leave them behind, and a
    # student opening an assignment that already has results in it is confusing at best.
    import json
    nb = json.loads(notebook.read_text(encoding="utf-8"))
    cleared = sum(1 for c in nb["cells"] if c.get("cell_type") == "code"
                  and (c.get("outputs") or c.get("execution_count") is not None))
    for cell in nb["cells"]:
        if cell.get("cell_type") == "code":
            cell["outputs"], cell["execution_count"] = [], None
    if cleared:
        notebook.write_text(json.dumps(nb, indent=1, ensure_ascii=False) + "\n",
                            encoding="utf-8")
        print(f"cleared saved output from {cleared} cell(s)")

    # The student notebook must not carry the solutions. otter strips them, but this
    # runs anyway: shipping an assignment with its answers in it is the one mistake
    # here that cannot be taken back once the folder is handed out.
    body = notebook.read_text(encoding="utf-8")
    for marker in ("BEGIN SOLUTION", "END SOLUTION"):
        if marker in body:
            print(f"error: {notebook.name} still contains a {marker!r} marker.")
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
