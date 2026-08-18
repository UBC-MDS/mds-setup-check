#!/usr/bin/env python3
"""Check that the rendered documents contain what they are supposed to contain.

Rendering is not the same as rendering correctly. Every LaTeX route in this
project exits 0 while silently replacing characters it has no glyph for, so a
check that only looks at exit codes or at whether a file exists passes on a
broken document. This asserts on the extracted text instead.

Routes do not all support the same characters. That is a measured fact about the
toolchain rather than a bug in any one document, so the expectations differ per
route and the differences are spelled out below.

Usage:  python ci/assert-renders.py
Exit:   0 if every present output holds what that route should hold, 1 otherwise.
"""
import sys

# Windows consoles default to a legacy codepage, and these scripts print the very
# characters they are checking for. Without this, a report mentioning α dies with
# UnicodeEncodeError on Windows and takes the whole check with it.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
import pathlib
import re

# Characters the fixtures contain, and which routes can reproduce them.
#   ok     - must be present, the route supports it
#   absent - the route is known not to support it; assert it is NOT there, so
#            that a future fix is noticed rather than silently absorbed
LATEX = "latex"   # accents and maths yes; Greek and emoji dropped
TYPST = "typst"   # Greek and emoji yes; raw LaTeX environments dropped
FULL = "full"     # HTML and the browser route: everything

# Routes known not to produce output at all, with the reason. A route listed here
# is reported as a known limitation rather than a failure -- but if it starts
# working, that is reported too, because the limitation is what is documented.
# Some limitations are platform specific, so an entry can name the platforms it
# applies to. A route that fails somewhere it is not expected to still fails the
# check, and a route that starts working anywhere is reported too.
KNOWN_TO_FAIL = {
    "check-notebook-nbconvert-web.pdf": (
        {"win32"},
        "nbconvert's command-line application sets WindowsSelectorEventLoopPolicy in "
        "NbConvertApp.initialize, for tornado and pyzmq. Its own WebPDF exporter then "
        "runs playwright under that policy, and a SelectorEventLoop cannot start a "
        "subprocess -- so launching Chromium raises NotImplementedError. Neither "
        "Windows nor playwright is at fault: the nbconvert API route beside this one "
        "exports the same notebook on the same machine. Students meet it anyway, "
        "because JupyterLab's export menu goes through jupyter_server, which sets the "
        "same policy. Use Typst on Windows."),
    "check-notebook-table-nbconvert-latex.pdf":
        "nbconvert's LaTeX template emits \\LTcaptype{none} for a markdown table, "
        "which this TeX Live rejects with \"No counter 'none' defined\". A notebook "
        "containing a markdown table fails JupyterLab's PDF export for this reason, "
        "and one without a table exports fine -- which is why the table lives in a "
        "fixture of its own. Rendering the same notebook through Quarto works, "
        "table and all.",
}
KNOWN_TO_FAIL = {k: (v if isinstance(v, tuple) else (None, v))
                 for k, v in KNOWN_TO_FAIL.items()}


def is_known(name: str) -> bool:
    entry = KNOWN_TO_FAIL.get(name)
    if entry is None:
        return False
    platforms, _ = entry
    return platforms is None or sys.platform in platforms

QMD_PY, QMD_R = "check-quarto-py.qmd", "check-quarto-r.qmd"
IPYNB, RMD = "check-notebook.ipynb", "check-rmarkdown.Rmd"
# The one construct JupyterLab's PDF export cannot handle, kept on its own so the
# matrix can say both things: that the notebook route works, and exactly what
# breaks it. If its LaTeX row ever turns green, nbconvert has fixed the bug.
TABLE = "check-notebook-table.ipynb"

# produced file -> (label, route class, the document it was rendered from)
ROUTES = {
    "check-quarto-py-latex.pdf":          ("qmd/py  -> Quarto -> LaTeX",     LATEX, QMD_PY),
    "check-quarto-py-typst.pdf":          ("qmd/py  -> Quarto -> Typst",     TYPST, QMD_PY),
    "check-quarto-py.html":               ("qmd/py  -> Quarto -> HTML",      FULL,  QMD_PY),
    "check-quarto-r-latex.pdf":           ("qmd/R   -> Quarto -> LaTeX",     LATEX, QMD_R),
    "check-quarto-r-typst.pdf":           ("qmd/R   -> Quarto -> Typst",     TYPST, QMD_R),
    "check-quarto-r.html":                ("qmd/R   -> Quarto -> HTML",      FULL,  QMD_R),
    "check-notebook-quarto-latex.pdf":    ("ipynb   -> Quarto -> LaTeX",     LATEX, IPYNB),
    "check-notebook-quarto-typst.pdf":    ("ipynb   -> Quarto -> Typst",     TYPST, IPYNB),
    "check-notebook-quarto.html":         ("ipynb   -> Quarto -> HTML",      FULL,  IPYNB),
    "check-notebook-nbconvert-latex.pdf": ("ipynb   -> nbconvert -> LaTeX",  LATEX, IPYNB),
    "check-notebook-nbconvert.html":      ("ipynb   -> nbconvert -> HTML",   FULL,  IPYNB),
    "check-notebook-nbconvert-web.pdf":   ("ipynb   -> nbconvert -> WebPDF", FULL,  IPYNB),
    # Same exporter, called directly instead of through nbconvert's command line.
    # Expected to work everywhere, including where the command line cannot.
    "check-notebook-nbconvert-api-web.pdf":
                                          ("ipynb   -> nbconvert API -> WebPDF", FULL, IPYNB),
    "check-rmarkdown-quarto-latex.pdf":   ("Rmd     -> Quarto -> LaTeX",     LATEX, RMD),
    "check-rmarkdown-quarto-typst.pdf":   ("Rmd     -> Quarto -> Typst",     TYPST, RMD),
    "check-rmarkdown-quarto.html":        ("Rmd     -> Quarto -> HTML",      FULL,  RMD),
    "check-rmarkdown-rmarkdown-latex.pdf":("Rmd     -> rmarkdown -> LaTeX",  LATEX, RMD),
    "check-rmarkdown-rmarkdown.html":     ("Rmd     -> rmarkdown -> HTML",   FULL,  RMD),
    # Three routes over one table, which is the smallest set that locates the fault:
    # nbconvert's HTML is fine and Quarto's LaTeX is fine, so it is neither nbconvert
    # nor LaTeX. It is nbconvert's LaTeX template.
    "check-notebook-table-nbconvert-latex.pdf":
                                          ("table   -> nbconvert -> LaTeX",  LATEX, TABLE),
    "check-notebook-table-nbconvert.html": ("table   -> nbconvert -> HTML",   FULL,  TABLE),
    "check-notebook-table-quarto-latex.pdf":
                                          ("table   -> Quarto -> LaTeX",     LATEX, TABLE),
}

# (label, needles, supported-by, source marker). A check passes if ANY needle is
# present, which matters because the same character can extract differently per
# engine: LaTeX sets maths in U+1D6FD MATHEMATICAL ITALIC SMALL BETA, not U+03B2.
#
# The source marker is what makes a check apply. A fixture that does not contain the
# construct is not asked about it, so a new fixture needs no special case here: it is
# measured for what it holds. Without this, splitting the markdown table into its own
# file would have reported every other notebook route as having lost a table it was
# never supposed to have.
CHECKS = [
    ("accented latin", ["Montréal"],        {LATEX, TYPST, FULL}, "Montréal"),
    ("degree sign",    ["°"],               {LATEX, TYPST, FULL}, "°C"),
    ("en dash",        ["–"],               {LATEX, TYPST, FULL}, "10 – 20"),
    ("curly quotes",   ["“", "”"],          {LATEX, TYPST, FULL}, "“curly quotes”"),
    # OLS appears in the fixtures only inside the inline equation, so this check fails
    # if the maths stops being typeset. It used to accept "unbiased", which is the prose
    # next to the equation, and so passed whatever happened to the maths.
    ("inline maths",   ["OLS"],             {LATEX, TYPST, FULL}, r"\mathrm{OLS}"),
    ("display eqn",    ["RSS"],             {LATEX, TYPST, FULL}, r"\mathrm{RSS}"),
    ("aligned eqns",   ["Var"],             {LATEX, TYPST, FULL}, r"\mathrm{Var}"),
    ("literal Greek",  ["α"],               {TYPST, FULL},        "α β γ"),
    ("emoji",          ["✅", "📊"],         {TYPST, FULL},        "📊"),
    # The four the README's table publishes and the gate used to leave ungated. An
    # unchecked column is a column that can quietly stop being true.
    ("middot",         ["·"],               {LATEX, TYPST, FULL}, " · "),
    # MSE for the same reason as OLS above: the numbered equation used to be checked
    # with "σ", which every fixture also prints as prose two sections further down, so
    # on the routes that keep literal Greek the check passed whether or not the
    # equation was typeset at all. Keying on a token that exists only inside the
    # equation immediately turned up what that was hiding -- Typst is NOT in the
    # supported set below, because a bare \begin{equation} is a raw LaTeX environment
    # that pandoc passes through untranslated, exactly like the \begin{align} the
    # fixtures already warn about. Typst receives no maths and renders nothing, with
    # no error. LaTeX and HTML both set it correctly.
    ("numbered eqn",   ["MSE"],             {LATEX, FULL},        r"\mathrm{MSE}"),
    ("markdown table", ["you want", "write this"], {LATEX, TYPST, FULL}, "| you want |"),
]

# The image is not text, so it needs a probe of its own rather than a needle.
IMAGE_ROUTES = {LATEX, TYPST, FULL}


def has_image(path: pathlib.Path) -> bool:
    if path.suffix == ".html":
        raw = path.read_text(encoding="utf-8", errors="replace")
        return "mds-logo.png" in raw or "data:image" in raw
    from pypdf import PdfReader
    for page in PdfReader(str(path)).pages:
        resources = page.get("/Resources") or {}
        if "/XObject" in resources:
            return True
    return False


_source_cache: dict[str, str] = {}


def source_text(name: str) -> str:
    """The prose and code of a fixture, as written rather than as rendered.

    A notebook keeps its text in JSON, so reading the file raw would match markers
    against escaped source lines and metadata. Cached because every route asks the
    same handful of files the same questions.
    """
    if name not in _source_cache:
        raw = pathlib.Path(name).read_text(encoding="utf-8")
        if name.endswith(".ipynb"):
            import json
            raw = "\n".join("".join(cell["source"])
                            for cell in json.loads(raw)["cells"])
        _source_cache[name] = raw
    return _source_cache[name]


def text_of(path: pathlib.Path) -> str:
    if path.suffix == ".html":
        raw = path.read_text(encoding="utf-8", errors="replace")
        raw = re.sub(r"<(script|style).*?</\1>", " ", raw, flags=re.S)
        import html as _html
        return _html.unescape(re.sub(r"<[^>]+>", " ", raw))
    from pypdf import PdfReader
    return "\n".join(page.extract_text() or "" for page in PdfReader(str(path)).pages)


def main() -> int:
    missing, broken, ok, stale = [], [], [], []

    for name, (label, kind, source) in ROUTES.items():
        path = pathlib.Path(name)
        # An output older than the document it came from is last month's answer. make
        # rebuilds nothing when the outputs are newer than their sources, so without this
        # a re-run on a since-broken machine re-reads the old files and reports success.
        if path.exists() and path.stat().st_mtime < pathlib.Path(source).stat().st_mtime:
            stale.append((label, name, source))
            print(f"  STALE    {label:<24} {name} is older than {source}")
            continue
        if not path.exists():
            if is_known(name):
                print(f"  known    {label:<24} does not render -- see KNOWN_TO_FAIL")
                continue
            missing.append((label, name))
            print(f"  MISSING  {label:<24} {name} was not produced")
            continue
        if is_known(name):
            broken.append(f"{name}: rendered, but is listed in KNOWN_TO_FAIL -- "
                          f"the limitation may be fixed; remove it from that list")
            print(f"  FAIL     {label:<24} now renders; update KNOWN_TO_FAIL")
            continue
        try:
            body = text_of(path)
        except Exception as exc:                      # noqa: BLE001
            broken.append(f"{name}: could not be read ({exc})")
            print(f"  FAIL     {label:<24} unreadable: {exc}")
            continue

        problems = []
        written = source_text(source)
        for desc, needles, supported, marker in CHECKS:
            if marker not in written:
                continue          # this fixture does not contain the construct
            present = any(n in body for n in needles)
            if kind in supported and not present:
                problems.append(f"missing {desc} ({needles[0]!r})")
            elif kind not in supported and present:
                problems.append(
                    f"{desc} ({needles[0]!r}) now renders -- this route was not "
                    f"expected to support it; update ci/assert-renders.py")
        # Engines differ in what they leave behind for a glyph they cannot set:
        # lualatex extracts as U+FFFD, xelatex as U+FFFF.
        if kind in IMAGE_ROUTES and "mds-logo.png" in written and not has_image(path):
            problems.append("the embedded image is missing")

        if kind in (TYPST, FULL) and any(c in body for c in ("\ufffd", "\ufffe", "\uffff")):
            problems.append("contains a replacement character, so something was dropped")

        if problems:
            broken.append(f"{name}: " + "; ".join(problems))
            print(f"  FAIL     {label:<24} " + "; ".join(problems))
        else:
            ok.append(name)
            print(f"  ok       {label:<24} {name}")

    print()
    total = len(ROUTES)

    if len(missing) == total:
        print("Nothing has been rendered yet. Run `make all` first.")
        return 1

    if stale:
        print(f"{len(stale)} of {total} outputs are older than the document they came from:")
        for label, name, source in stale:
            print(f"  - {label}  ({name} predates {source})")
        print("  These were rendered by an earlier run and prove nothing about this one.")
        print("  Run `make clean` and then `make -k all` to rebuild them.")
        print()

    if missing:
        print(f"{len(missing)} of {total} routes produced no output at all:")
        for label, name in missing:
            print(f"  - {label}  (expected {name})")
        print("  These routes failed to render. Re-run `make -k all` and read the")
        print("  error for each one; `-k` keeps going so one failure does not hide")
        print("  the rest.")
        print()

    if broken:
        print(f"{len(broken)} of {total} routes rendered but the content is wrong:")
        for b in broken:
            print(f"  - {b}")
        print()

    if missing or broken or stale:
        print(f"{len(ok)} of {total} routes are fully correct.")
        return 1

    applicable = {n: w for n, (p, w) in KNOWN_TO_FAIL.items()
                  if p is None or sys.platform in p}
    if applicable:
        print(f"{total - len(applicable)} of {total} routes rendered correctly; "
              f"{len(applicable)} known limitation(s) on this platform:")
        for name, why in applicable.items():
            print(f"  - {name}: {why}")
        return 0
    print(f"All {total} routes rendered, and each contains what it should.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
