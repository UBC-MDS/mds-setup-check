# mds-setup-check

A small project used to verify a UBC Master of Data Science software stack
installation. It is referenced from the MDS installation guides:

- [macOS](https://ubc-mds.github.io/resources_pages/install_ds_stack_mac)
- [Ubuntu](https://ubc-mds.github.io/resources_pages/install_ds_stack_ubuntu)
- [Windows](https://ubc-mds.github.io/resources_pages/install_ds_stack_windows)

## For students

**You do not normally clone this yourself.** Running the setup check at the end of
your install guide downloads it into `~/mds-setup-check` for you.

That script makes the folder itself and will not reuse one that is already there —
it has no way to tell a fresh clone from last year's copy or an interrupted
download, so measuring it would report on whatever happens to be in there rather
than on the version everyone else is checked against.

If `~/mds-setup-check` already exists, the script asks whether to delete it and
download a fresh copy. The answer defaults to **no**, and only `y` or `yes` counts
as agreement, because saying yes removes that folder and everything in it. Answer
no and it leaves the folder alone, skips the Python and document export checks,
and tells you how to delete it yourself once you have moved out anything you want
to keep.

### Working in the project directly

To reproduce the render matrix below yourself, clone it anywhere *other* than
`~/mds-setup-check` and run three commands:

```bash
git clone https://github.com/UBC-MDS/mds-setup-check.git
cd mds-setup-check

make install
make all
make check
```

That is the whole sequence. There is nothing to run by hand and nothing to
remember about flags:

- **`make install`** installs the Python packages, the R packages and the browser
  one of the PDF routes needs. Python is managed by uv from `uv.lock` and R by
  [renv](https://rstudio.github.io/renv/) from `renv.lock`, so every student in the
  cohort ends up with byte-identical versions.
- **`make all`** renders every document by every route. It keeps going past a
  failure rather than stopping at the first one, because one route is *known* not to
  work — `check-notebook-table.ipynb` cannot be exported to PDF by nbconvert, which
  is the whole reason that fixture exists — and stopping there would leave every
  later route unrendered and looking broken.
- **`make check`** is the verdict. Rendering without an error is not the same as
  rendering correctly: every LaTeX route here exits 0 while silently dropping
  characters it has no glyph for, so this looks inside the finished files instead
  of at exit codes. It knows which failures are known limitations of the toolchain
  and which mean something is wrong with your install, and it refuses to certify an
  output older than the document it came from — so re-running it on a machine that
  has since broken cannot pass on last month's files.

Running `make` on its own lists every target with a one-line description.

These are the same commands CI runs on macOS, Ubuntu and Windows, which is the
point of putting them in the `Makefile` rather than writing them out here: what you
run and what is tested cannot drift apart.

> Every Python command in this project goes through `uv run`, which is what puts
> the project's own `.venv` first on `PATH`. The `Makefile` already does that for
> you, so you only need it when running something yourself —
> `uv run jupyter lab`, not `jupyter lab`.

`make matrix-check` is a separate gate, and the one that keeps this file honest: it
regenerates the tables below from the rendered files and fails if the committed
block has drifted from them.

### What each document proves

| document | rendered by | what it proves |
| --- | --- | --- |
| `check-quarto-py.qmd` | `uv run quarto render` | Quarto finds this project's Python, starts a kernel, and typesets the result |
| `check-quarto-r.qmd` | `uv run quarto render` | Quarto finds R and runs it — a different path from R Markdown |
| `check-notebook.ipynb` | `uv run jupyter nbconvert` | the same route as JupyterLab's `File -> Save and Export Notebook As... -> PDF`, which goes through pandoc |
| `check-notebook.ipynb` | `uv run quarto render` | the same notebook through Quarto instead — the workaround when the export menu fails |
| `check-notebook-table.ipynb` | both of the above | isolates the one construct the export menu cannot handle, so the failure is attributable rather than just present |
| `check-rmarkdown.Rmd` | `Rscript -e 'rmarkdown::render(...)'` | R, knitr, pandoc and LaTeX work together |
| `check-rmarkdown.Rmd` | `uv run quarto render` | Quarto reads `.Rmd` as well, so the same document has two routes |

Every rendered file produced by more than one tool is named for both the document and
the tool —
`check-rmarkdown-quarto-typst.pdf`, not `check-rmarkdown.pdf`. That is partly so the
table below can be read, and partly because Quarto compiles `check-rmarkdown.Rmd`
to an intermediate file named `check-rmarkdown.pdf` before moving it to its final
name. A route named after its input alone gets silently eaten by the next route.

R and Python live in separate documents on purpose. Putting both in one would
need `reticulate` to locate this project's Python from inside R, which is a thing
that goes wrong often enough not to be worth meeting in week one.

### What renders where

The four full fixtures contain the same features, so any difference between them
below is a property of the toolchain rather than the document.
`check-notebook-table.ipynb` is the exception: it holds one construct and nothing
else, and a dash means the fixture does not contain that feature at all, which is
a different statement from a cross.

**This is measured, not asserted** — `make matrix` regenerates these tables from
the rendered files, `make matrix-check` fails if the committed block has drifted
from them, and `make check` fails if a route stops containing what that route
should contain. `make check` also fails if an output is older than the document it
came from, so a table cannot be certified by last month's renders.

**The tables show this machine.** One route differs by platform, marked below.

There is one table per input format, and the **rendered by** column is the reason:
Quarto reads all three input formats, so it appears in all three tables, while
nbconvert only reads `.ipynb` and `rmarkdown` only reads `.Rmd`.

<!-- begin matrix: generated by `make matrix`, do not edit by hand -->

**`.qmd`**

| input | rendered by | output | accented latin | degree sign | en dash | curly quotes | inline maths | display eqn | aligned eqns | literal Greek | emoji | middot | numbered eqn | markdown table | image |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `check-quarto-py.qmd` | Quarto | LaTeX PDF | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| `check-quarto-py.qmd` | Quarto | Typst PDF | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| `check-quarto-py.qmd` | Quarto | HTML | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `check-quarto-r.qmd` | Quarto | LaTeX PDF | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| `check-quarto-r.qmd` | Quarto | Typst PDF | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| `check-quarto-r.qmd` | Quarto | HTML | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

**`.ipynb`**

| input | rendered by | output | accented latin | degree sign | en dash | curly quotes | inline maths | display eqn | aligned eqns | literal Greek | emoji | middot | numbered eqn | markdown table | image |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `check-notebook.ipynb` | Quarto | LaTeX PDF | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | — | ✅ |
| `check-notebook.ipynb` | Quarto | Typst PDF | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | — | ✅ |
| `check-notebook.ipynb` | Quarto | HTML | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| `check-notebook.ipynb` | nbconvert | LaTeX PDF | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | — | ✅ |
| `check-notebook.ipynb` | nbconvert | HTML | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| `check-notebook.ipynb` | nbconvert | WebPDF | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| `check-notebook.ipynb` | nbconvert API | WebPDF | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | — | ✅ |
| `check-notebook-table.ipynb` | nbconvert ⚠️ | LaTeX PDF | — | — | — | — | — | — | — | — | — | — | — | ❌ | — |
| `check-notebook-table.ipynb` | nbconvert | HTML | — | — | — | — | — | — | — | — | — | — | — | ✅ | — |
| `check-notebook-table.ipynb` | Quarto | LaTeX PDF | — | — | — | — | — | — | — | — | — | — | — | ✅ | — |

⚠️ **nbconvert → LaTeX PDF produces no file at all.** nbconvert's LaTeX template emits \LTcaptype{none} for a markdown table, which this TeX Live rejects with "No counter 'none' defined". A notebook containing a markdown table fails JupyterLab's PDF export for this reason, and one without a table exports fine -- which is why the table lives in a fixture of its own. Rendering the same notebook through Quarto works, table and all.

**`.Rmd`** — `check-rmarkdown.Rmd`

| rendered by | output | accented latin | degree sign | en dash | curly quotes | inline maths | display eqn | aligned eqns | literal Greek | emoji | middot | numbered eqn | markdown table | image |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Quarto | LaTeX PDF | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Quarto | Typst PDF | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Quarto | HTML | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| rmarkdown | LaTeX PDF | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| rmarkdown | HTML | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

<!-- end matrix -->

**Windows: `nbconvert → WebPDF` does not work**, so that row is ✅ here and would be
❌ on a Windows machine. `make check` knows this and does not fail the Windows run
over it.

It is worth knowing *why*, because it is neither Windows nor playwright. nbconvert's
command-line application sets `WindowsSelectorEventLoopPolicy` for tornado and pyzmq,
and its own WebPDF exporter then runs playwright under that policy — and a
`SelectorEventLoop` is the one Windows event loop that cannot start a subprocess, so
launching Chromium raises `NotImplementedError`. The **`nbconvert API`** row beside it
is the same exporter called directly, bypassing that one line, and it is green on
Windows. Students still cannot use WebPDF there, because JupyterLab's export menu goes
through `jupyter_server`, which sets the same policy — but the row means the cause is
attributable, and it will turn green the day upstream fixes it.

The input format matters as much as the output one. `check-notebook-table.ipynb` to a
LaTeX PDF via nbconvert is the only route of the twenty-one that fails outright, and
the same output format from the same notebook through Quarto is fine — so that failure
is a property of nbconvert's LaTeX template, not of PDFs and not of notebooks.

**Use this table when something looks wrong in an assignment.** If a character is
missing and the table says **no** for that route, it is a known limitation of the
toolchain rather than a broken installation, and the fix is to change route.

Three things are worth knowing before writing an assignment:

- **LaTeX cannot do literal Greek or emoji.** It drops them without warning and
  still reports success, so the PDF simply arrives with holes in it. Writing Greek
  as maths — `$\alpha$` rather than `α` — works in every route, and is the right
  spelling in a statistics program anyway. Emoji have no portable form, so a
  document that needs them wants Typst or HTML — or WebPDF, on a Mac or on Linux.
- **Write equations as `$$…$$`, and multi-line ones as
  `$$\begin{aligned}…\end{aligned}$$`.** A bare `\begin{align}` or
  `\begin{equation}` is a raw LaTeX environment that pandoc passes through
  untranslated, so Typst never sees any maths and renders nothing — silently. That is
  the `numbered eqn` ❌ on every Typst row above: the fixtures write that one the
  failing way on purpose. Inside `$$` every route handles it.
- **A notebook containing a markdown table cannot be exported to PDF from
  JupyterLab.** nbconvert's template writes `\LTcaptype{none}`, which this TeX Live
  rejects. Rendering the same notebook through Quarto works, table and all, so the
  fix is to use Quarto rather than to change the notebook.

`make clean` deletes everything the renders produced.

You can delete `~/mds-setup-check` once you have submitted your log. The script
does not look for it — it creates it — so the next run makes it again.

## What is in here

| file | what it is for |
| --- | --- |
| `pyproject.toml` | the Python packages the MDS stack needs |
| `uv.lock` | the exact resolved Python versions, so everybody gets the same ones |
| `.python-version` | the Python version this project runs on |
| `renv.lock` | the same idea for R packages |
| `.Rprofile`, `renv/` | how R finds this project's own package library |
| `Makefile` | installs, renders and checks; run `make` to list its targets |
| [`CLAUDE.md`](CLAUDE.md) | context for an AI agent working here: the invariants, and what makes a check real |
| `check-quarto-py.qmd` | Quarto fixture, Python |
| `check-quarto-r.qmd` | Quarto fixture, R |
| `check-notebook.ipynb` | Jupyter notebook fixture, already executed |
| `check-notebook-table.ipynb` | one markdown table and nothing else: the single construct JupyterLab's PDF export cannot handle |
| `check-rmarkdown.Rmd` | R Markdown fixture |
| `ci/assert-renders.py` | checks the rendered files contain what they should, per route |
| `ci/assert-contract.py` | checks this repo still matches what `assignment-workflow-uv.md` describes |
| `ci/assert-docs.py` | checks every make target, fixture and script named in `README.md` and `CLAUDE.md` exists |
| `ci/feature-matrix.py` | measures which features survive which route, and prints the tables above |
| `ci/check-matrix-block.py` | fails if those tables have drifted from the rendered files |
| `ci/run-setup-check.py` | attaches a terminal to `check-setup-mds.sh` so CI can answer its prompts |
| `ci/webpdf.py` | exports a notebook through the browser without nbconvert's command line, which is what breaks that route on Windows |
| `.github/workflows/assignment-workflow.yml` | the CI described under **For instructors** below |
| `ci/tlmgr-packages.txt` | the LaTeX packages the install guides ask for |
| `mds-logo.png` | the image every fixture embeds, so that image rendering is checked too |
| [`using-atkinson-hyperlegible.md`](using-atkinson-hyperlegible.md) | optional: how to set a document in the Atkinson Hyperlegible typeface |
| `check-setup-mds.sh` | the setup check itself, the script students are told to run |
| `check-python-installs.sh` | reports every Python already on the machine; run on its own before installing uv, and again from inside the setup check |
| `mds-help.sh` | the `mds-help` reference card students install into their shell |

The three scripts above are served straight out of this repository by GitHub
Pages, so the copy students run is always the copy on `main`:

```
https://ubc-mds.github.io/mds-setup-check/check-setup-mds.sh
https://ubc-mds.github.io/mds-setup-check/check-python-installs.sh
https://ubc-mds.github.io/mds-setup-check/mds-help.sh
```

That is why `.nojekyll` and `index.html` are here. They are not part of the check.

## For instructors

This project doubles as the reference shape for an MDS assignment repo.
[assignment-workflow-uv.md](assignment-workflow-uv.md) covers what a course repo
must declare, why `uv.lock` is committed, how PDFs get produced, and the failure
modes students will report.

### How this is tested, and what a green build does not prove

[`.github/workflows/assignment-workflow.yml`](.github/workflows/assignment-workflow.yml)
runs on every push, every pull request, and every Monday — the schedule matters
because this repository can sit unchanged for months while everything that breaks
it moves upstream. It renders every route on macOS, Ubuntu and Windows, checks the
content of what came out, and runs `check-setup-mds.sh` end to end the way a
student does.

A green badge is a narrower claim than it looks. **Read this list before treating
CI as evidence that the install guides work.**

- **The student script is executed on Ubuntu only.** Its macOS branch (`mdls` for
  RStudio, the `/Library/PostgreSQL` scan, bash 3.2 patterns) and its Windows
  branch (`tlmgr.bat`, `reg query`, `$LOCALAPPDATA`) have no execution coverage at
  all. Those two branches are also where most of its platform-specific code lives.
- **Nothing asserts on a `MISSING` line.** The end-to-end step runs to completion
  regardless, and the check that follows greps for four specific strings. Every
  version pattern in the script could be wrong and CI would still be green.
- **The version patterns are substring tests, not version tests.** `R=4.*` accepts
  `R version 5.0.0 (2027-04-20)` — it matches the `04` in the date. `latex=3.*`
  cannot fail at all, because pdfTeX's version string is π. See
  [#7](https://github.com/UBC-MDS/mds-setup-check/issues/7).
- **The R packages the guides tell students to install are installed by nothing
  here.** `tidyverse`, `janitor`, `gapminder`, `readxl`, `usethis`, `devtools`,
  `languageserver`, and — most fragile — `ottr` and `canlang`, which install from
  git HEAD and can break with nobody touching anything. `renv.lock` answers a
  different question (see below) and shares three packages with that list.
- **Several programs are never installed on a runner**, so their checks are
  exercised nowhere: Positron, RStudio, PostgreSQL, Docker, XQuartz and Rtools.
- **The Python packages section of the log cannot fail for anything a student
  did.** The script clones this repository, runs `uv sync` against the committed
  `uv.lock`, and then reports the versions it just installed. What it genuinely
  proves is that `uv` works and the network was reachable.
- **TinyTeX is installed by a GitHub action, not by the route the guides give
  students.** The guides use `tinytex::install_tinytex()` followed by a logout, and
  it is precisely that PATH step they warn about — which is therefore verified on
  no platform. The 22-package `tlmgr` list *is* checked, and does match the guides.
- **`check-python-installs.sh` is fetched from the live site at run time**, so a
  pull request testing the end-to-end script is testing the *published* copy of
  that half, not the branch's.

The route-level limitations are a different matter and are kept honest
mechanically: they live in `KNOWN_TO_FAIL` in
[`ci/assert-renders.py`](ci/assert-renders.py), the footnotes under the tables above
are generated from that same list, and a route that starts working fails the build
rather than being silently absorbed.

Three things here are deliberate and should be preserved if this file is copied:

- `ipykernel` is a real dependency, not a dev dependency. `jupyterlab` would
  pull it in anyway, but an autograding image built with `uv sync --no-dev`
  would then have no Python kernel at all.
- `nbconvert[webpdf]` is named explicitly. `otter-grader` already requires it,
  but naming it records that MDS depends on WebPDF export directly.
- `check-rmarkdown.Rmd` asks for `latex_engine: xelatex`. R Markdown's default
  pdflatex cannot typeset the accented characters that turn up in real student
  work, and it fails with an error that does not obviously point at the engine.

Note that the fixtures are not empty files. An empty notebook has no markdown
cells, so rendering one never calls pandoc and passes on machines where PDF
export of a real assignment would fail.

`renv.lock` uses implicit snapshots, so it records only the packages the documents
here actually use. It previously used `snapshot.type: "all"`, which pulled in the
fifteen base and recommended packages that ship with R. Those are invisible on any
machine that already has them and a hard failure on one that does not: a fresh
macOS runner tried to compile `rpart`, `Matrix` and `nlme` from source and died on
a missing header.

The repository is Posit Package Manager rather than CRAN. CRAN publishes no Linux
binaries at all, so an Ubuntu student compiles every R package from source; P3M
serves the same packages pre-built. It matters again for Docker images later.

`renv.lock` deliberately contains only what these documents render with, which is
`rmarkdown` and its dependencies. It is not a copy of the R packages the
installation guides ask students to install globally — the setup check script
verifies those separately, against the user library. The two are different
questions: "does your machine have the MDS R stack" and "can this project
install its own R packages reproducibly".

The R version in `renv.lock` is set to the version the installation guides ask
for. renv warns, but proceeds, when the running R has a different minor version.
