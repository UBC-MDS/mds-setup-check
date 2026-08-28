#!/usr/bin/env python3
"""Fail if docs/render-matrix.md has drifted from what the renders actually produce.

The block says it is generated and must not be edited by hand; this enforces it. Only
meaningful on the platform the committed table was generated on -- one route differs by
operating system, so CI runs this on Linux alone.
"""
import io, pathlib, sys, contextlib, importlib.util

for stream in (sys.stdout, sys.stderr):
    try:
        stream.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass

HERE = pathlib.Path(__file__).resolve().parent
DOC = HERE.parent / "docs" / "render-matrix.md"
BEGIN, END = "<!-- begin matrix", "<!-- end matrix -->"


_arspec = importlib.util.spec_from_file_location(
    "assert_renders", HERE / "assert-renders.py")
_ar = importlib.util.module_from_spec(_arspec)
_arspec.loader.exec_module(_ar)


def generated() -> str:
    spec = importlib.util.spec_from_file_location("fm", HERE / "feature-matrix.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        mod.main()
    return buf.getvalue().strip()


def main() -> int:
    # A path bug in the generator makes every route look unrendered, and a diff of two
    # equally-wrong tables still matches. So check the shape first: more "no file"
    # notes than known limitations means the generator is not finding the files.
    out = generated()
    warned = out.count("produces no file at all")
    allowed = sum(1 for n in _ar.KNOWN_TO_FAIL if _ar.is_known(n))
    if warned > allowed:
        print(f"The matrix reports {warned} routes with no output, but only {allowed} "
              f"are known limitations on this platform.")
        print("The generator is not finding the rendered files. Run `make all` first;")
        print("if they are there, the fixture directory join is wrong.")
        return 1

    doc = DOC.read_text(encoding="utf-8")
    start = doc.index("\n", doc.index(BEGIN)) + 1
    committed = doc[start:doc.index(END)].strip()
    if committed == out:
        print(f"{DOC.name} matches what the renders produce.")
        return 0
    print(f"{DOC.name} no longer matches what the renders produce.")
    print("Run `make matrix` and paste the output between the matrix markers.")
    print()
    import difflib
    for line in difflib.unified_diff(committed.splitlines(), out.splitlines(),
                                     "docs/render-matrix.md", "make matrix",
                                     lineterm="", n=1):
        print(line)
    return 1


if __name__ == "__main__":
    sys.exit(main())
