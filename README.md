# mds-setup-check

A small project used to verify a UBC Master of Data Science software stack
installation. It is referenced from the MDS installation guides:

- [macOS](https://ubc-mds.github.io/resources_pages/install_ds_stack_mac)
- [Ubuntu](https://ubc-mds.github.io/resources_pages/install_ds_stack_ubuntu)
- [Windows](https://ubc-mds.github.io/resources_pages/install_ds_stack_windows)

## For students

Clone it into your home folder, so that the setup check script can find it
later:

```bash
cd ~
git clone https://github.com/UBC-MDS/mds-setup-check.git
cd mds-setup-check
uv sync
```

`uv sync` creates a `.venv` folder inside this project and installs the exact
package versions recorded in `uv.lock`. Every student in the cohort therefore
gets an identical environment.

From then on, every Python command you run for this project starts with
`uv run`:

```bash
uv run python --version
uv run jupyter lab
```

The R packages work the same way, managed by
[renv](https://rstudio.github.io/renv/) instead of uv. One command installs
everything this project needs in both languages, plus the browser one of the PDF
routes uses:

```bash
make install
```

Then render every document by every route:

```bash
make all
```

and check that the results are actually correct:

```bash
make check
```

`make` on its own lists every target with a one-line description, so you do not
have to read this file to remember them.

### What each document proves

| document | rendered by | what it proves |
| --- | --- | --- |
| `check-quarto.qmd` | `uv run quarto render` | Quarto finds this project's Python, starts a kernel, and typesets the result |
| `check-quarto-r.qmd` | `uv run quarto render` | Quarto finds R and runs it — a different path from R Markdown |
| `check-notebook.ipynb` | `uv run jupyter nbconvert` | the same route as JupyterLab's `File -> Save and Export Notebook As... -> PDF`, which goes through pandoc |
| `check-rmarkdown.Rmd` | `Rscript -e 'rmarkdown::render(...)'` | R, knitr, pandoc and LaTeX work together |

R and Python live in separate documents on purpose. Putting both in one would
need `reticulate` to locate this project's Python from inside R, which is a thing
that goes wrong often enough not to be worth meeting in week one.

### What renders where

Each fixture contains the same set of features, so the same table applies whichever
document you look at. **This is measured, not asserted** — `make matrix` regenerates
it from the rendered files, and `make check` fails if any cell stops being true.

| feature | LaTeX PDF | Typst PDF | HTML | WebPDF |
|---|---|---|---|---|
| accented latin — `Montréal`, `naïve`, `Öl` | yes | yes | yes | yes |
| degree sign, middot, en dash | yes | yes | yes | yes |
| curly quotes | yes | yes | yes | yes |
| **literal Greek in prose — `α β γ`** | **no** | yes | yes | yes |
| **emoji — `✅ ❌ 📊 ⚠️`** | **no** | yes | yes | yes |
| inline maths — `$\alpha$` | yes | yes | yes | yes |
| display equation — `$$…$$` | yes | yes | yes | yes |
| numbered equation — `\begin{equation}` | yes | yes | yes | yes |
| **aligned equations — `\begin{align}`** | yes | **no** | yes | yes |
| embedded image | yes | yes | yes | yes |

Every route in a column behaves identically, so `Quarto -> LaTeX`, `nbconvert -> LaTeX`
and `rmarkdown -> LaTeX` are one column here.

**Use this table when something looks wrong in an assignment.** If a character is
missing from a rendered PDF and the table says **no** for that route, it is a known
limitation of the engine rather than a broken installation, and the fix is to change
route rather than to reinstall anything.

Two of these are worth knowing before writing an assignment:

- **LaTeX silently drops Greek letters and emoji.** It does not warn, and it still
  exits successfully, so the PDF simply arrives with holes in it. A data frame
  column named `α` disappears the same way. Render with Typst if the document needs
  them.
- **Typst silently drops `\begin{align}`.** It handles inline maths, `$$…$$` and
  `\begin{equation}` — only the align environment is lost, and again without a
  warning. So a document with aligned multi-line equations wants LaTeX, and a
  document with emoji wants Typst. A document with both needs HTML or WebPDF.

`make clean` deletes everything the renders produced.

**Keep this folder until you have submitted your setup check log.** The
`check-setup-mds.sh` script looks for it at `~/mds-setup-check`.

## What is in here

| file | what it is for |
| --- | --- |
| `pyproject.toml` | the Python packages the MDS stack needs |
| `uv.lock` | the exact resolved Python versions, so everybody gets the same ones |
| `.python-version` | the Python version this project runs on |
| `renv.lock` | the same idea for R packages |
| `.Rprofile`, `renv/` | how R finds this project's own package library |
| `Makefile` | installs, renders and checks; run `make` to list its targets |
| `check-quarto.qmd` | Quarto fixture, Python |
| `check-quarto-r.qmd` | Quarto fixture, R |
| `check-notebook.ipynb` | Jupyter notebook fixture, already executed |
| `check-rmarkdown.Rmd` | R Markdown fixture |
| `ci/assert-renders.py` | checks the rendered files contain what they should, per route |
| `ci/assert-contract.py` | checks this repo still matches what `assignment-workflow-uv.md` describes |
| `ci/tlmgr-packages.txt` | the LaTeX packages the install guides ask for |
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

`renv.lock` deliberately contains only what
is `rmarkdown` and its dependencies. It is not a copy of the R packages the
installation guides ask students to install globally — the setup check script
verifies those separately, against the user library. The two are different
questions: "does your machine have the MDS R stack" and "can this project
install its own R packages reproducibly".

The R version in `renv.lock` is set to the version the installation guides ask
for. renv warns, but proceeds, when the running R has a different minor version.
