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

# The fixtures and everything they render live here. ROUTES and KNOWN_TO_FAIL below
# keep BARE filenames, because those are the labels the README's table and the failure
# prose read; this is the only place the directory is ever joined on. Anchored to this
# file rather than to the working directory, so the gate does not care where it is run
# from.
FIXTURE_DIR = "render-checks"
_HERE = pathlib.Path(__file__).resolve().parent.parent / FIXTURE_DIR


def fixture(name: str) -> pathlib.Path:
    """The path of a fixture, or of something rendered from one."""
    return _HERE / name


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

# Most constructs behave by output format, but some follow the TOOL instead.
# Quarto resolves a `{#eq-...}` cross-reference; nbconvert and rmarkdown print it as
# literal text -- and nbconvert's HTML and Quarto's HTML are both FULL, so the route
# class cannot tell them apart. A check may therefore name individual routes in its
# supported set as well as route classes. Derived from ROUTES rather than restated,
# so a new Quarto route joins it automatically.
QUARTO = {name for name, (label, _, _) in ROUTES.items() if "Quarto" in label}
NBCONVERT = {name for name, (label, _, _) in ROUTES.items() if "nbconvert" in label}
WEBPDF = {name for name, (label, _, _) in ROUTES.items() if "WebPDF" in label}
# An .html file is read BEFORE MathJax runs; the WebPDF is the same page after it has.
# For anything MathJax touches, those two are different measurements, and the WebPDF is
# the one that says what a reader sees.
HTML_FILE = {name for name in ROUTES if name.endswith(".html")}


def supports(supported: set, kind: str, name: str) -> bool:
    """Whether this route is expected to reproduce the construct.

    `supported` holds route classes (LATEX/TYPST/FULL) and/or specific output
    filenames. Naming routes is the escape hatch for a construct whose behaviour
    follows the tool rather than the output format.
    """
    return kind in supported or name in supported


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
    ("middot",         ["·"],               {LATEX, TYPST, FULL}, " · "),
    ("literal Greek",  ["α"],               {TYPST, FULL},        "α β γ"),
    ("emoji",          ["✅", "📊"],         {TYPST, FULL},        "📊"),
    ("markdown table", ["you want", "write this"], {LATEX, TYPST, FULL}, "| you want |"),

    # ---------------------------------------------------------- mathematics --
    # Every needle below is a real statistical name occurring exactly once per
    # fixture, inside the equation it measures. That is the rule this file exists
    # to enforce: a needle that also appears in the prose beside the construct
    # cannot fail, and that has already shipped here twice -- "unbiased" beside
    # the inline equation, and "σ" in a table two sections below the numbered one.
    ("inline maths",   ["OLS"],             {LATEX, TYPST, FULL}, r"\mathrm{OLS}"),
    ("display eqn",    ["RSS"],             {LATEX, TYPST, FULL}, r"\mathrm{RSS}"),
    ("aligned eqns",   ["Var"],             {LATEX, TYPST, FULL}, r"\mathrm{Var}"),
    ("numbered eqn",   ["MSE"],             {LATEX, TYPST, FULL}, r"\mathrm{MSE}"),
    ("eqn inside $$",  ["SSE"],             {LATEX, TYPST, FULL}, r"\mathrm{SSE}"),
    ("pmatrix",        ["COV"],             {LATEX, TYPST, FULL}, r"\mathrm{COV}"),
    ("bmatrix",        ["DES"],             {LATEX, TYPST, FULL}, r"\mathrm{DES}"),
    ("cases",          ["ReLU"],            {LATEX, TYPST, FULL}, r"\mathrm{ReLU}"),
    ("labelled eqn",   ["MAE"],             {LATEX, TYPST, FULL}, r"\mathrm{MAE}"),
    # The cross-reference, as opposed to the equation it points at. Quarto turns
    # `@eq-mse` into the words "Equation 1"; nbconvert and rmarkdown leave it as
    # written. This is the check that needs route names rather than a class: the
    # two HTML routes disagree, and both are FULL. The word "Equation" appears
    # nowhere in any fixture source, so it can only come from a resolved
    # reference -- audit_needles() below fails the build if that stops being true.
    ("Quarto xref",    ["Equation"],        QUARTO,               "@eq-mse"),
    # LaTeX's own labelling, which is the one construct that fails in BOTH
    # directions: LaTeX resolves it, Typst discards it silently, and HTML prints
    # the raw label on the page. The needle is that leak, so a tick here is bad
    # news rather than good -- it is the only column in the table read that way,
    # and the fixtures say so in prose beside the equation.
    ("literal \\eqref", ["eq:mae"],         HTML_FILE,            r"\eqref{eq:mae}"),
    # ...and what a reader actually sees where MathJax has run. The label survives in
    # the HTML file only because that file is read before any JavaScript executes; in
    # a browser, and in the WebPDF which is a browser printing the same page, MathJax
    # resolves \eqref against labels it does not have and prints "(???)". Visible,
    # and meaningless. This is the pair that shows why an HTML file and a WebPDF are
    # not interchangeable evidence.
    ("unresolved xref", ["(???)"],          WEBPDF,               r"\eqref{eq:mae}"),
    # Bare environments, not wrapped in `$$`. Pandoc never parses these as maths,
    # so nothing downstream is handed an equation. LaTeX sets them because that is
    # what they are written in; HTML sets them too -- measured, not assumed, since
    # Quarto emits them as <span class="math display">\[...\]</span> and MathJax
    # renders them in the browser. Typst has no MathJax behind it, so they vanish
    # with no error. Compare `numbered eqn` above: the same maths inside `$$`,
    # which every route sets.
    ("raw equation",   ["AIC"],             {LATEX, FULL},        r"\mathrm{AIC}"),
    ("raw align",      ["BIC"],             {LATEX, FULL},        r"\mathrm{BIC}"),

    # ------------------------------------------------- raw LaTeX in prose ----
    # `RTFN` is spelled to avoid an `AW` pair on purpose. It began as `RAWFN`,
    # which renders perfectly and extracts from the LaTeX PDF as "RA WFN" --
    # lualatex kerns the pair and pypdf reports the kern as a space. A check that
    # cannot see content demonstrably on the page is worse than no check, so a
    # needle has to survive extraction as well as be unique.
    # Pandoc drops raw LaTeX it cannot use, so Quarto's and rmarkdown's HTML lose this
    # footnote entirely. nbconvert does not go through pandoc for markdown cells, so it
    # prints the command itself onto the page -- visible LaTeX source in a student's
    # exported notebook. Another difference the route class cannot express: nbconvert's
    # HTML and Quarto's HTML are both FULL and they disagree.
    ("raw LaTeX",      ["RTFN"],            {LATEX} | NBCONVERT,  r"\footnote{RTFN"),
    ("markdown note",  ["MDFN"],            {LATEX, TYPST, FULL}, "^[MDFN"),
    # `$$` is not a shield: \text{} switches back to the text font mid-equation, so
    # a literal Greek character there is dropped by LaTeX exactly as it would be in
    # prose, inside an equation whose subscript typesets perfectly beside it. The
    # letter is ξ rather than α so the needle cannot be satisfied by the α in the
    # character line two paragraphs above; TXTGRK and CMDGRK prove both equations
    # rendered at all.
    ("Greek in text{}", ["ξ"],              {TYPST, FULL},        r"\text{ξ}"),
]

# A needle that also appears in the prose beside its construct CANNOT FAIL: the check
# passes on the prose whatever happened to the thing under test. That has shipped here
# three times now -- "unbiased" beside the inline equation, "σ" in a table two sections
# below the numbered one, and "MDEQ" quoted in a "what you should see" paragraph. The
# rule was written down each time and broken again the next time, so it is enforced
# here instead of remembered.
#
# A needle may legitimately repeat when every occurrence IS the construct under test.
# Those are listed, with the reason, so that adding one is a deliberate act.
NEEDLE_MAY_REPEAT = {
    "α": "the character line and the 'as literal text' bullet are both literal Greek "
         "in prose, which is exactly what this needle measures",
    "·": "the character line separates its items with middots, so all seven occurrences "
         "ARE the construct -- if middots stopped rendering they would all go together",
    "eq:mae": "\\label{eq:mae} and \\eqref{eq:mae} are the two halves of one "
              "construct: LaTeX's own cross-referencing, which the check measures by "
              "whether the label leaks into the output as text",
}

# Strings that must not appear in any fixture SOURCE, because a check reads them as
# evidence that a renderer produced something.
# Needles for things a RENDERER generates, never something an author writes. The
# uniqueness rule above cannot catch these: they occur once in the source, and that
# one occurrence is the prose, so every route reports success. Both entries below
# were added after exactly that happened.
FORBIDDEN_IN_SOURCE = {
    "Equation": "Quarto writes this word when it resolves an @eq- cross-reference. In "
                "a fixture source it would satisfy the `Quarto xref` needle without "
                "any reference having been resolved.",
    "(???)": "MathJax writes this when it cannot resolve an \\eqref. Describing it in "
             "prose -- rather than letting a renderer produce it -- made all 21 routes "
             "report the marker and the `unresolved xref` check pass everywhere.",
}


def audit_needles() -> list[str]:
    """Check the checks: every needle must be able to fail on every fixture."""
    problems = []
    for src in sorted({s for _, _, s in ROUTES.values()}):
        written = source_text(src)
        for bad, why in FORBIDDEN_IN_SOURCE.items():
            if bad in written:
                problems.append(f"{src} contains {bad!r} in its source. {why}")
        for desc, needles, _, marker in CHECKS:
            if marker not in written:
                continue
            for n in needles:
                if written.count(n) > 1 and n not in NEEDLE_MAY_REPEAT:
                    problems.append(
                        f"{src}: the {desc!r} needle {n!r} appears "
                        f"{written.count(n)} times in the source, so the check cannot "
                        f"fail -- it would pass on the prose. Rename it, or add it to "
                        f"NEEDLE_MAY_REPEAT with a reason.")
    return problems


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
        raw = fixture(name).read_text(encoding="utf-8")
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
    # Before asking whether the outputs are right, ask whether the questions are
    # answerable. A contaminated needle makes every route below report success.
    if flaws := audit_needles():
        print("The checks themselves are broken:")
        for flaw in flaws:
            print(f"  - {flaw}")
        print("\nNo route was checked, because the result would not mean anything.")
        return 1

    missing, broken, ok, stale = [], [], [], []

    for name, (label, kind, source) in ROUTES.items():
        path = fixture(name)
        # An output older than the document it came from is last month's answer. make
        # rebuilds nothing when the outputs are newer than their sources, so without this
        # a re-run on a since-broken machine re-reads the old files and reports success.
        if path.exists() and path.stat().st_mtime < fixture(source).stat().st_mtime:
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
            expected = supports(supported, kind, name)
            if expected and not present:
                problems.append(f"missing {desc} ({needles[0]!r})")
            elif not expected and present:
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
