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
[renv](https://rstudio.github.io/renv/) instead of uv:

```bash
make r-packages
```

which is shorthand for `Rscript -e 'renv::restore(prompt = FALSE)'`. It installs
the versions recorded in `renv.lock` into `renv/library`, so the R side of this
project runs the same way for everybody and does not depend on what you happen
to have installed globally. On Ubuntu this is the slowest step in the project;
give it a few minutes the first time.

To check that you can produce PDFs, render every document in the project:

```bash
make
```

That runs the three routes MDS uses, in order, and stops at the first one that
fails so you can see the error:

| document | rendered by | what it proves |
| --- | --- | --- |
| `check-quarto.qmd` | `uv run quarto render` | Quarto can find this project's Python, start a kernel, and typeset the result with LaTeX |
| `check-notebook.ipynb` | `uv run jupyter nbconvert` | the same route as JupyterLab's `File -> Save and Export Notebook As... -> PDF`, which goes through pandoc |
| `check-rmarkdown.Rmd` | `Rscript -e 'rmarkdown::render(...)'` | R, knitr, pandoc and LaTeX work together |

Each document prints its versions and ends with a line of accented and Greek
characters, so opening the PDFs also tells you whether LaTeX has the fonts it
needs.

There is one more route that does not use LaTeX at all:

```bash
uv run playwright install chromium   # once, downloads a browser
make webpdf
```

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
| `Makefile` | renders every document to PDF |
| `check-quarto.qmd` | Quarto fixture, with a Python code chunk |
| `check-notebook.ipynb` | Jupyter notebook fixture, already executed |
| `check-rmarkdown.Rmd` | R Markdown fixture |

## For instructors

This project doubles as the reference shape for an MDS assignment repo. See the
assignment workflow document for what a course repo should declare and why
`uv.lock` is committed.

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

`renv.lock` deliberately contains only what `check-rmarkdown.Rmd` needs, which
is `rmarkdown` and its dependencies. It is not a copy of the R packages the
installation guides ask students to install globally — the setup check script
verifies those separately, against the user library. The two are different
questions: "does your machine have the MDS R stack" and "can this project
install its own R packages reproducibly".

The R version in `renv.lock` is set to the version the installation guides ask
for. renv warns, but proceeds, when the running R has a different minor version.
