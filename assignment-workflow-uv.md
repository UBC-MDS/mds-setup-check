# MDS assignment repos with uv — a guide for the teaching team

**Audience:** instructors and TAs who build MDS assignment repositories.
**Status:** written for the 2026-27 cohort, alongside the move from conda to uv.

This document is self-contained. It does not assume you have read the
installation guides, though it describes the environment those guides leave
students with.

The reference implementation of everything below is **this repository**, which
students clone during installation: it measures every claim in §5 against real
fixtures, in `render-checks/`. It is not the thing to copy, though -- its `Makefile`
renders six fixtures by twenty-one routes. Start a new assignment repo from
[`mds-demo-assignment/`](mds-demo-assignment/) instead: one notebook, its own
`pyproject.toml` and `uv.lock`, a short `Makefile`, and `lint-portability.py` for the
§5 rules.

---

## 1. What changed, in one paragraph

MDS used to install Miniforge, which auto-activated a `base` conda environment
in every terminal. `python`, `jupyter`, `pandas` and everything else were
therefore always on `PATH`, and assignment repos could assume they were
present. That is gone. Students now install **uv** and no global environment at
all. Each assignment repo carries its own package list and its own `.venv`,
created by `uv sync`. Nothing is available until the student is standing in a
project folder and prefixes the command with `uv run`.

This is closer to how Python work is actually done, and it removes a setup
students would have had to unlearn. It does mean every assignment repo has to
declare what it needs, because nothing is inherited any more.

---

## 2. What a student does

Three commands, identical for every assignment:

```bash
git clone <assignment-repo-url>
cd <assignment-repo>
uv sync
```

and then either

```bash
uv run jupyter lab
```

or open the folder in Positron (`File > Open Folder...`), which picks up the
`.venv` automatically.

`uv sync` reads `pyproject.toml` and `uv.lock`, creates `.venv` inside the repo,
and installs the exact locked versions. It is idempotent and fast after the
first run, because uv hardlinks from a shared cache in the student's home
folder.

This is the same sequence they used during installation on the
`mds-setup-check` repo, so it is not new in week 1.

---

## 3. What an assignment repo must contain

### `pyproject.toml`

```toml
[project]
name = "dsci-5xx-lab1"
version = "0.1.0"
requires-python = ">=3.14"

dependencies = [
    "ipykernel>=7",
    "jupyterlab>=4.6",
    "jupyterlab-git>=0.54",
    "jupyterlab-spellchecker>=0.9",
    "jupytext>=1.19",
    "nbconvert[webpdf]>=7.17",
    "otter-grader>=7",
    "pandas>=3",
    # ...whatever else this particular assignment needs
]

[tool.uv]
package = false
```

Four things in there are deliberate:

- **`jupyterlab` is a real dependency, not a dev dependency.** It has to be in
  the same environment prefix as the kernel, because that is the only place
  Jupyter *server extensions* — `jupyterlab-git`, `jupyterlab-spellchecker`,
  `jupytext` — actually work. Running `uv run --with jupyterlab jupyter lab`
  silently drops all three.
- **`ipykernel` is listed explicitly even though `jupyterlab` pulls it in.**
  See §7; this is what stops `uv sync --no-dev` from producing a grading
  environment with no Python kernel.
- **`otter-grader` is a real dependency**, because students write
  `import otter` inside their notebooks.
- **`package = false`** tells uv this repo is a set of files to work in, not a
  library to build and install.

### `uv.lock`, committed

Run `uv lock`, commit the result, and commit it again whenever
`pyproject.toml` changes. This is the single biggest improvement over the conda
setup: every student in the cohort resolves to byte-identical versions, so
"works on my machine" stops being a per-student variable. uv's lock file is
universal — one lock covers macOS, Linux and Windows.

### `.gitignore` containing `.venv`

`uv init` writes this for you. `uv init --bare` does not, so check.

### `.gitattributes`, if the repo contains a `Makefile` or any `.sh`

```
*.sh     text eol=lf
Makefile text eol=lf
*.py     text eol=lf
```

The Windows install guide has students configure git with "checkout Windows-style,
commit Unix-style", so without this every shell script and `Makefile` arrives on a
Windows machine with CRLF line endings. `bash` then fails on the shebang with
`$'\r': command not found`, and GNU make appends a carriage return to every
argument in a recipe. Neither error mentions line endings, both are baffling, and
they get reported as "the repo is broken". Section 6 recommends a `Makefile` for
every assignment repo, which is exactly the file this protects.

### Python version

`requires-python` in `pyproject.toml`, and optionally a `.python-version` file,
are **per repo**. Default to `3.14` for 2026-27. A repo with a constraint of its
own — a PyTorch assignment, say — can pin whatever it needs, and uv will
download that interpreter on the student's machine without touching anything
else. This is per-project, not per-student, and needs no coordination.

### If the assignment uses R

R is *not* managed by uv. Two options:

- **Global R library** (what the installation guides set up): tidyverse,
  rmarkdown, and the rest are installed once with `install.packages()` and
  shared by everything. Simplest; fine for most assignments.
- **`renv` in the repo**, which is the R analogue of `uv sync`. Commit
  `renv.lock`, `.Rprofile` and `renv/activate.R`, and have students run
  `Rscript -e 'renv::restore(prompt = FALSE)'`. Use `prompt = FALSE` or it will
  block waiting for input. This is what `mds-setup-check` does.

Use renv when the assignment depends on a specific R package version, and the
global library otherwise.

---

## 4. The rule: every Python command starts with `uv`

`uv run` **prepends the project's `.venv` binary directory to `PATH`** and
inherits the rest of it. That is the whole mechanism, and it has two
consequences worth internalising.

The good one: a student who still has Homebrew Python, pyenv, an old Anaconda
and the Microsoft Store alias installed still gets the right interpreter. Their
leftover installs stop mattering.

The sharp edge: because the rest of `PATH` is inherited, a repo that forgets to
declare `pytest` will still find a **system** `pytest` under `uv run pytest`,
running against the wrong interpreter, and the failure will look like a code
bug rather than a packaging one. Declare everything you invoke.

| instead of | write |
| --- | --- |
| `python script.py`, `python --version` | `uv run python ...` |
| `pip install X` | `uv add X` (records it in `pyproject.toml`) |
| ad-hoc install into an env | `uv pip install X` — **wiped by the next `uv sync`** |
| `pip list`, `pip freeze` | `uv pip list`, `uv export` |
| `jupyter lab`, `jupyter nbconvert ...` | `uv run jupyter ...` |
| `quarto render` on anything with Python in it | `uv run quarto render ...` |
| `pytest`, `ruff`, `otter` | `uv run pytest`, etc. |
| `python -m venv` | `uv venv` |
| installing Python itself | `uv python install 3.14` |

Not prefixed: `git`, `make`, R and `Rscript`, plain `quarto render` on a
document with no Python chunks, and `uv` itself.

---

## 5. Producing PDFs

Five routes exist. Students have all of them set up, and Quarto reads all three input
formats — `.qmd`, `.ipynb` and `.Rmd` — so it can stand in for either of the others.

| route | engine | when |
| --- | --- | --- |
| `uv run quarto render <file> --to pdf` | lualatex | **Preferred.** Handles `.ipynb`, `.qmd` and `.Rmd` |
| `uv run quarto render <file> --to typst` | Typst | When the document contains emoji or Greek letters |
| `Rscript -e 'rmarkdown::render("f.Rmd")'` | xelatex, via knitr | An `.Rmd` rendered by R itself |
| JupyterLab `File > Save and Export Notebook As... > PDF` | xelatex, via nbconvert | Familiar in-Lab route, but see the markdown-table limitation below |
| JupyterLab `... > WebPDF` | headless Chromium | No LaTeX at all; also handles emoji. **Not available on Windows** |

**Why WebPDF is unavailable on Windows**, since it comes up every year and the error
is unreadable. It is not a Windows limitation and not a playwright bug. nbconvert's
own command-line application sets `WindowsSelectorEventLoopPolicy` on Windows (for
tornado and pyzmq), and its WebPDF exporter then runs playwright under that policy.
A `SelectorEventLoop` cannot start a subprocess, so launching Chromium raises
`NotImplementedError` from deep inside asyncio. `jupyter_server` sets the same
policy, which is why the Lab export menu fails the same way. Calling the exporter
directly does work on Windows -- `mds-setup-check` carries `ci/webpdf.py` to prove
it -- but there is no way for a student to reach that from the Lab menu, so tell
them to use Typst.

**Every route drops something, silently, and still reports success.** This is the
section to read before writing an assignment. Every cell below is measured on the
fixtures in `render-checks/` by `ci/feature-matrix.py`. A bare `\begin{equation}` and
a bare `\begin{align}` get a column each, in every fixture, because pandoc forwards
both for the same reason and it is worth showing that they fail identically.

| | accents, dashes | `$…$`, `$$…$$` | `$$\begin{aligned}$$` | raw `\begin{align}`, `\begin{equation}` | raw `\emph`, `\footnote`, `tabular` | literal Greek, emoji | images |
| --- | --- | --- | --- | --- | --- | --- | --- |
| LaTeX, via Quarto, nbconvert or rmarkdown | yes | yes | yes | yes | yes | **no** | yes |
| Typst | yes | yes | yes | **no** | **no** | yes | yes |
| HTML | yes | yes | yes | yes | **no** | yes | yes |

HTML splits the two raw columns because MathJax re-reads raw LaTeX *maths* out of the
page source, so a bare `\begin{equation}` survives there even though `\emph{}` does
not. Typst has no such second pass and loses both. **WebPDF** is not a row of its own:
it prints the HTML in a browser and matches the HTML row wherever it is available,
which the notebook fixture measures directly.

**One rule explains every cell above.** Pandoc parses markdown into a format-neutral
document and writes each output format from that. Anything it *parses* is translated
per format and survives everywhere. Anything it cannot parse is *forwarded* to the
LaTeX output verbatim and discarded by every other writer, with no error. Pandoc
parses `$…$` and `$$…$$` as maths, so those reach every route; it forwards a bare
`\begin{...}`, so that reaches the LaTeX PDF and, thanks to MathJax, the HTML -- but
not Typst.

Two things sit outside that rule and are worth holding separately. A literal Greek
letter or emoji is parsed perfectly well, and is then dropped by **LaTeX**, which has
no glyph for it. And `\text{}` inside maths is parsed as maths but *typeset as text*,
which puts a literal character inside it back under the same LaTeX limitation.

**A notebook containing a markdown table cannot be exported to PDF from
JupyterLab.** nbconvert's LaTeX template writes `\LTcaptype{none}`, which TeX Live
rejects outright, so the export fails with an error naming a counter rather than
the table. Rendering the same notebook with `uv run quarto render <file> --to pdf`
works, table and all. This is why the preferred route is Quarto and not the export
menu — Quarto reads `.ipynb` directly, so nothing has to be rewritten.

### Three rules that follow from it

**1. Every maths construct goes inside `$…$` or `$$…$$`.** Never a bare
`\begin{equation}` or `\begin{align}`; both are raw environments that Typst never
sees and renders nothing for. Write aligned equations as
`$$\begin{aligned}…\end{aligned}$$`, and get a numbered equation from Quarto's own
cross-reference syntax rather than from LaTeX:

```markdown
$$
\mathrm{MSE} = \frac{1}{n-p}\sum_{i=1}^{n} e_i^2
$$ {#eq-mse}

See @eq-mse.
```

That form is numbered `(1)` in both the LaTeX PDF and the Typst PDF, and the
cross-reference resolves in both. A bare `\begin{equation}` is numbered in LaTeX and
absent from Typst.

**2. Nothing outside maths starts with a backslash.** Bold is `**bold**`, emphasis is
`*emphasis*`, tables are markdown tables, footnotes are `^[like this]`. Written that
way they reach every route, because pandoc parses them. Written as `\textbf{}`,
`\emph{}`, `\footnote{}` or a `tabular`, they reach the LaTeX PDF and vanish from
Typst and HTML -- and they vanish *tidily*, leaving a grammatical sentence with a
word missing, which is why nobody notices. The **Footnotes** section of every full
fixture in `mds-setup-check` measures this.

**3. Inside maths, Greek is `\alpha`, never a literal `α`.** The delimiters are not a
shield. `\text{}` and `\mathrm{}` switch back to the text font mid-equation, so

```markdown
$$ \theta = \text{α} $$
```

loses its α in every LaTeX route -- inside an equation whose other symbols typeset
perfectly beside it. Write `$\theta = \alpha$` and it renders everywhere.

### What is left over

**Emoji.** There is no maths form for an emoji, so the rules above cannot rescue one.
An assignment that needs emoji in a PDF has to be rendered with Typst, HTML or
WebPDF. Typst is the usual answer: it ships with Quarto, needs no LaTeX, and requires
no extra installation.

Note that this is a property of the *characters*, not of the assignment's difficulty.
An assignment full of hard mathematics is safe on every route as long as the maths is
written as maths. One with an emoji in a heading, or a data frame column literally
named `α`, is not.

**Keep R and Python in separate documents.** Quarto's `knitr` engine can run both
in one file, but the Python chunks go through `reticulate`, which has to locate
the project's `.venv` from inside R. That is an extra failure mode with its own
diagnostics, and it is not worth introducing in an early assignment. One language
per document needs no `reticulate` at all.

Four more things to know before you write PDF instructions into an assignment.

**Quarto does not execute `.ipynb` files by default.** A student who edits a
notebook without re-running the cells gets a PDF with stale outputs and no
warning. Either have them run the notebook first, or pass `--execute`.

**`quarto render` needs the `uv run` prefix whenever the document contains
Python.** Quarto looks for Python on `PATH`, and outside `uv run` there isn't
one. On Windows this is worse than a plain failure: Quarto's discovery order
accepts a `PATH` Python only if it looks conda-like, and otherwise falls back to
the `py.exe` launcher, so it can find a *different* Python that has no jupyter
in it. If a Windows student reports a confusing Quarto error, check for a
missing `uv run` first.

**pandoc comes from Quarto, not from pip.** nbconvert's LaTeX PDF exporter
shells out to `pandoc`, which is not a Python package and is not installed by
`uv sync`. The installation guides put Quarto's bundled copy on `PATH`. If a
student reports `PandocMissing`, that `PATH` entry is what is wrong. Note that
this only bites on documents with markdown cells, so a minimal test notebook
will not reproduce it.

**WebPDF needs a browser downloaded once.** `nbconvert[webpdf]` brings the
`playwright` Python package, but not the browser binary. Students run
`uv run playwright install chromium` **from inside the repo** — not `uvx`,
because browser revisions are pinned per playwright version and a
`uvx`-resolved playwright can fetch a revision the project's copy will not
accept.

---

## 6. A `Makefile` is a good default

`make` is installed on all three platforms, and a Makefile gives students one
command that is the same in every repo:

```makefile
.PHONY: all clean

all: report.pdf

report.pdf: report.qmd
	uv run quarto render $< --to pdf

clean:
	rm -f report.pdf
	rm -rf .quarto
```

It also documents the exact commands, which is more useful than prose when a
student is stuck.

**If a repo renders one source by more than one route, name the outputs apart.**
Quarto compiles to an intermediate named after the *input* and then moves it to
`--output`, and it treats `--to pdf` and `--to typst` as the same output for a
given input. Two targets over one source therefore overwrite each other, with no
error and no warning — the second render simply deletes the first file. Either set
`output-file:` per format in the document's YAML:

```yaml
format:
  pdf:   { output-file: report-latex.pdf }
  typst: { output-file: report-typst.pdf }
```

or pass `--output report-typst.pdf`. `mds-setup-check` names every output
`<document>-<tool>-<format>` for this reason, and found the problem the hard way:
a route reported as missing had in fact rendered fine and been eaten by the next
one.

---

## 7. Autograding and Docker

`uv sync --no-dev` is the obvious way to build a slimmer grading image, and it
has one trap that is easy to ship by accident.

`jupyterlab` is what drags `ipykernel` into the environment. If JupyterLab is
a dev dependency, `--no-dev` removes it, and `ipykernel` goes with it — leaving
an image with **no Python kernel at all**. Autograding, `nbconvert --execute`
and Quarto's jupyter engine all then fail, and the error message points at
kernels rather than at the dependency you actually changed.

Declaring `ipykernel` as a real dependency, as in §3, prevents this. Note also
that `otter-grader` already requires `nbconvert[webpdf]`, `jupytext`,
`ipywidgets` and `ipylab`, so playwright arrives in the image whether or not
you asked for it.

In a Dockerfile, prefer `uv sync --locked --no-dev` so the build fails loudly if
the lock file is out of date rather than silently resolving something new.

---

## 8. Adding a package mid-assignment

```bash
uv add scikit-learn
```

then commit **both** the changed `pyproject.toml` and the changed `uv.lock`.
Students pick it up with `uv sync`.

Do not tell students to run `uv pip install`. It works, and then the next
`uv sync` silently removes it again, which is a genuinely confusing failure.

---

## 9. Keep these out of assignment instructions

- `conda install` / `conda activate` — nothing has conda any more.
- Bare `pip install`.
- Bare `python`, which does not exist. `python3` does exist on macOS and Ubuntu,
  and `python3.14` exists wherever uv installed it, but none of them have
  pandas. A student who tests with `python3 --version`, sees a version, and
  concludes they are fine will hit `ModuleNotFoundError` at the worst moment.
- Any assumption that a package is "already installed". If the repo does not
  declare it, it is not there.
- Instructions that do not begin by `cd`-ing into the repo. Under conda the
  working directory was irrelevant to whether `python` worked; now it decides
  everything, and terminal navigation is not taught until DSCI 511 week 1.

Worth knowing when you write troubleshooting advice: running `uv run` *outside*
a project does not reliably fail. `uv run python --version` prints a version
quite happily, and `uv run jupyter lab` will start whatever `jupyter` happens to
be on `PATH` — on a machine with a leftover Homebrew or pyenv install, that is a
real and entirely wrong JupyterLab. The reliable tell that a student is in the
wrong folder is `ModuleNotFoundError` for a package the repo declares, not an
error from uv itself.

---

## 10. Failure modes, with the text students will actually see

| what they see | what it means |
| --- | --- |
| ``error: No `pyproject.toml` found in current directory or any parent directory`` | `uv sync` was run outside a project folder — `cd` into the repo |
| ``error: Failed to spawn: `jupyter` `` | `uv run` outside a project folder, or the repo does not declare `jupyterlab` |
| `ModuleNotFoundError: No module named 'pandas'` | run without `uv run`, or run in the wrong folder, or the package is not declared |
| `nbconvert.utils.pandoc.PandocMissing` | Quarto's pandoc is not on `PATH`; see §5 |
| `Failed to spawn: 'quarto'` / Quarto cannot find a kernel | missing `uv run`, especially on Windows |
| `The lockfile at 'uv.lock' needs to be updated, but '--locked' was provided` | `pyproject.toml` changed without re-running `uv lock`; commit the new lock |
| a package installed with `uv pip install` disappears | expected — `uv sync` restores the environment to the lock file. Use `uv add` |
| Chromium not found during WebPDF export | `uv run playwright install chromium`, from inside the repo |

---

## 11. Open items for the teaching team

- **A shared repo template.** `mds-demo-assignment/` in this repository is a working
  example of everything above -- one notebook, its own lock file, a `Makefile`, and
  a linter for the §5 rules. It is a demo rather than a template: turning it into a
  real template repo, so that JupyterLab and `ipykernel` are declared consistently
  and nobody has to remember §7, is still to do.
- **DSCI 521.** The environments content was written around conda and needs to
  move to uv. `.venv` is no longer a thing students meet for the first time in
  block 2 — they will have been inside one since installation week — so the
  material can start from "you have been using one, here is what it is".
- **R kernels in Jupyter.** IRkernel is no longer installed during setup. A
  course that wants R notebooks registers it from inside its own repo:

  ```bash
  cd <hw-repo>
  uv sync
  # IRkernel itself is installed nowhere by the MDS setup, so it comes first
  R -e 'install.packages("IRkernel", repos = "https://packagemanager.posit.co/cran/latest")'
  R -e "IRkernel::installspec()"
  ```

  Note that `installspec()` writes a **user-level** kernelspec, so although it is
  run from one repo it is a one-time, machine-wide action. Positron does not
  need it at all; it uses its own ARK kernel.
