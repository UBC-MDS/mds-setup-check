#!/usr/bin/env python3
"""Fail if the README's table has drifted from what the renders actually produce.

The README says the block is generated and must not be edited by hand. Nothing enforced
that, so the table could quietly stop describing the toolchain -- which is the exact
failure this repository exists to catch, one level up.

The comparison is only meaningful on the platform the committed table was generated on.
One route differs by operating system, so CI runs this on Linux alone.
"""
import io, pathlib, sys, contextlib, importlib.util

for stream in (sys.stdout, sys.stderr):
    try:
        stream.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass

HERE = pathlib.Path(__file__).resolve().parent
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
    # A path bug in the generator makes every route look unrendered, and a diff of
    # two equally-wrong tables still matches. So check the shape of the generated
    # table before comparing it to anything: more "no file" notes than there are
    # known limitations means the generator is not finding the rendered files.
    out = generated()
    warned = out.count("produces no file at all")
    allowed = sum(1 for n in _ar.KNOWN_TO_FAIL if _ar.is_known(n))
    if warned > allowed:
        print(f"The matrix reports {warned} routes with no output, but only {allowed} "
              f"are known limitations on this platform.")
        print("The generator is not finding the rendered files. Run `make all` first;")
        print("if they are there, the fixture directory join is wrong.")
        return 1

    readme = (HERE.parent / "README.md").read_text(encoding="utf-8")
    start = readme.index("\n", readme.index(BEGIN)) + 1
    committed = readme[start:readme.index(END)].strip()
    if committed == out:
        print("The README's table matches what the renders produce.")
        return 0
    print("The README's table no longer matches what the renders produce.")
    print("Run `make matrix` and paste the output between the matrix markers.")
    print()
    import difflib
    for line in difflib.unified_diff(committed.splitlines(), out.splitlines(),
                                     "README.md", "make matrix", lineterm="", n=1):
        print(line)
    return 1


if __name__ == "__main__":
    sys.exit(main())
