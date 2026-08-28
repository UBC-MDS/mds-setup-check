# Building an MDS assignment repo with uv (instructors)

For instructors and TAs, written for the 2026-27 cohort alongside the move from conda
to uv.

**Start from [`mds-demo-assignment/`](mds-demo-assignment/)**, not from this
repository. It is one notebook with its own `pyproject.toml`, `uv.lock`, `Makefile` and
`lint-portability.py`, small enough to read in a sitting. This repository is the
reference implementation -- every rule in
[Writing a document that renders everywhere](#4-writing-a-document-that-renders-everywhere) is measured here against real
fixtures -- but its Makefile renders six fixtures by twenty-one routes, which is not a
starting point.

---

## 1. What changed

MDS used to install Miniforge, which auto-activated a `base` conda environment in every
terminal, so `python`, `jupyter` and `pandas` were always on `PATH`. That is gone.
Students now install **uv** and no global environment at all. Each repo carries its own
package list and its own `.venv`, created by `uv sync`, and nothing is available until
the student is standing in a project folder and prefixes the command with `uv run`.

Every assignment repo therefore has to declare what it needs. Nothing is inherited.

---

## 2. What a student does

```bash
git clone <assignment-repo-url>
cd <assignment-repo>
uv sync
uv run jupyter lab
```

Or open the folder in Positron (`File > Open Folder...`), which picks up `.venv`
automatically. This is the same sequence they used during installation, so it is not
new in week 1.

---

## 3. What your repo must contain

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
    # ...whatever else this assignment needs
]

[tool.uv]
package = false
```

Four of those are deliberate:

1. **`jupyterlab` is a real dependency, not a dev one.** Jupyter *server extensions*
   only work in the same environment prefix as the kernel, so
   `uv run --with jupyterlab jupyter lab` silently drops all three of them.
2. **`ipykernel` is listed explicitly** even though `jupyterlab` pulls it in. See
   [Autograding and Docker](#6-autograding-and-docker).
3. **`otter-grader` is a real dependency**, because students write `import otter` in
   their notebooks to run the self-checks.
4. **`package = false`** tells uv this is a set of files to work in, not a library.

### `uv.lock`, committed

Run `uv lock`, commit the result, and commit it again whenever `pyproject.toml`
changes. Every student then resolves to byte-identical versions. One lock file covers
macOS, Linux and Windows.

### `.gitignore` containing `.venv`

`uv init` writes this for you; `uv init --bare` does not.

Copy paste the default Python gitignore file from github: <https://github.com/github/gitignore/blob/main/Python.gitignore>

### `.gitattributes`, if the repo has a `Makefile` or any `.sh`

```
*.sh     text eol=lf
Makefile text eol=lf
*.py     text eol=lf
```

The Windows install guide has students commit Unix-style and check out Windows-style,
so without this every script arrives with CRLF. `bash` then fails on the shebang with
`$'\r': command not found`, and make appends a carriage return to every argument.
Neither error mentions line endings and both get reported as "the repo is broken".

### A Python version

`requires-python`, and optionally `.python-version`. Default to `3.14` for 2026-27. A
repo needing something else can pin it, and uv downloads that interpreter without
touching anything else. Per project, not per student.

### If the assignment uses R

R is not managed by uv. Use the global library the install guides set up unless the
assignment needs a specific package version, in which case commit `renv.lock`,
`.Rprofile` and `renv/activate.R` and have students run
`Rscript -e 'renv::restore(prompt = FALSE)'`. Use `prompt = FALSE` or it blocks waiting
for input.

---

## 4. Writing a document that renders everywhere

### The routes

| route | engine | when |
| --- | --- | --- |
| `uv run quarto render <file> --to pdf` | lualatex | **Preferred.** Reads `.ipynb`, `.qmd` and `.Rmd` |
| `uv run quarto render <file> --to typst` | Typst | When the document has emoji or literal Greek |
| `Rscript -e 'rmarkdown::render("f.Rmd")'` | xelatex, via knitr | An `.Rmd` rendered by R itself |
| JupyterLab `File > Save and Export Notebook As... > PDF` | xelatex, via nbconvert | Familiar, but breaks on markdown tables |
| JupyterLab `... > WebPDF` | headless Chromium | No LaTeX; handles emoji. **Not on Windows** |

### The four rules

Every route drops something silently and still reports success. These rules avoid all
of it, and `lint-portability.py` in `mds-demo-assignment/` enforces them on the source.

1. **Every maths construct goes inside `$…$` or `$$…$$`.** A bare `\begin{equation}` or
   `\begin{align}` is a raw LaTeX environment that Typst never sees. Write aligned
   equations as `$$\begin{aligned}…\end{aligned}$$`, and get numbering from Quarto's own
   cross-references rather than from LaTeX:

   ```markdown
   $$
   \mathrm{MSE} = \frac{1}{n-p}\sum_{i=1}^{n} e_i^2
   $$ {#eq-mse}

   See @eq-mse.
   ```

   That is numbered `(1)` in both the LaTeX and the Typst PDF, and the reference
   resolves in both.

2. **Nothing outside maths starts with a backslash.** `**bold**`, `*emphasis*`,
   markdown tables, `^[footnotes]`. Written as `\textbf{}`, `\emph{}`, `\footnote{}` or
   `tabular` they reach the LaTeX PDF but vanish in Typst and HTML, leaving
   a grammatical sentence with a word or symbol missing.

3. **Inside maths, Greek is `\alpha`, never a literal `α`.** The delimiters are not a
   shield: `\text{}` and `\mathrm{}` switch back to the text font, so `$$\theta =
   \text{α}$$` loses its α in every LaTeX route while the symbols beside it typeset correctly.

4. **Emoji need Typst, HTML or WebPDF.** There is no maths form for one, so rules 1--3
   cannot rescue it. Typst is the usual answer: it ships with Quarto and needs no LaTeX.

**One rule explains all four.** Pandoc parses markdown into a format-neutral document
and writes each output format from that.

- Anything it *parses* survives everywhere.
- Anything it cannot parse is *forwarded* to LaTeX verbatim and discarded by every other
writer, with no error

Two things sit outside it

- a literal Greek letter
- an emoji

these are parsed fine and then dropped by **LaTeX**, which has no glyph for it.

Measured results per route, and the three known toolchain limitations, are in
[`docs/render-matrix.md`](docs/render-matrix.md).

### Five more things worth knowing

- **A notebook containing a markdown table cannot be exported to PDF from JupyterLab.**
  Quarto renders the same notebook fine.
- **Quarto does not execute `.ipynb` files by default.** A student who edits a notebook
  without re-running it gets a PDF with stale outputs and no warning. Pass `--execute`.
- **`quarto render` needs `uv run` whenever the document contains Python.** On Windows
  this is worse than a plain failure: Quarto's discovery order can find a *different*
  Python with no jupyter in it. Check for a missing `uv run` first.
- **pandoc comes from Quarto, not from pip.** `PandocMissing` means that `PATH` entry is
  wrong. It only bites on documents with markdown cells, so a minimal test notebook will
  not reproduce it.
- **WebPDF needs Chromium downloaded once.** Run `uv run playwright install chromium`
  from inside the repo. Each playwright version expects one specific Chromium build, so
  `uvx playwright install chromium` resolves its own playwright and downloads a
  different build. The download succeeds and the export still fails, saying the
  executable does not exist.

**Keep R and Python in separate documents.** Quarto's knitr engine can run both, but
the Python chunks go through `reticulate`, which has to find the project's `.venv` from
inside R. It's doable, just adds complexity.

---

## 5. Ship a `Makefile`

`make` is on all three platforms, and it gives students one command that is the same in
every repo. Render through Typst by default: it needs no LaTeX, and it keeps the emoji
and pasted Greek letters that LaTeX drops silently.

```makefile
.PHONY: all clean

all: report.pdf

report.pdf: report.qmd
	uv run quarto render $< --to typst

clean:
	rm -f report.pdf
	rm -rf .quarto
```

**If a repo renders one source by more than one route, name the outputs apart.** Quarto
compiles to an intermediate named after the *input*, and treats `--to pdf` and
`--to typst` as the same output for a given input, so two targets over one source
overwrite each other with no warning:

```yaml
format:
  pdf:   { output-file: report-latex.pdf }
  typst: { output-file: report-typst.pdf }
```

---

## 6. Autograding and Docker

`uv sync --no-dev` builds a slimmer grading image and has one trap. `jupyterlab` is
what drags `ipykernel` in; if JupyterLab is a dev dependency, `--no-dev` removes both
and leaves an image with **no Python kernel at all**. Autograding, `nbconvert --execute`
and Quarto's jupyter engine then fail with errors pointing at kernels rather than at
the dependency you changed. Declaring it explicitly, as in
[What your repo must contain](#3-what-your-repo-must-contain), prevents this.

In a Dockerfile prefer `uv sync --locked --no-dev`, so the build fails loudly if the
lock file is out of date.

Or don't use optional groups in your `pyproject.toml` file and list everything as a dependency.

---

## 7. Adding a package mid-assignment

```bash
uv add scikit-learn
```

Commit **both** the changed `pyproject.toml` and the changed `uv.lock`. Students pick it
up with `uv sync`.

Never tell students to run `uv pip install`. It works, and then the next `uv sync`
silently removes it again.

---

## 8. Keep these out of assignment instructions

- `conda install` / `conda activate` -- nothing has conda any more.
- Bare `pip install`.
- Bare `python`, which does not exist. `python3` does, and has no pandas. A student
  who runs `python3 --version`, sees a version and concludes they are fine will hit
  `ModuleNotFoundError` at the worst moment.
- Any assumption that a package is "already installed".
- Instructions that do not begin by `cd`-ing into the repo. Under conda the working
  directory was irrelevant; now the current working directory decides everything.

Running `uv run` *outside* a project does not reliably fail -- `uv run jupyter lab` will
start whatever `jupyter` is on `PATH`. The reliable tell that a student is in the wrong
folder is `ModuleNotFoundError` for a package the repo declares, not an error from uv.

---

## 9. Failure modes, with the text students will see

| what they see | what it means |
| --- | --- |
| ``error: No `pyproject.toml` found in current directory or any parent directory`` | run outside a project folder -- `cd` into the repo |
| ``error: Failed to spawn: `jupyter` `` | `uv run` outside a project, or `jupyterlab` is not declared |
| `ModuleNotFoundError: No module named 'pandas'` | no `uv run`, wrong folder, or the package is not declared |
| `nbconvert.utils.pandoc.PandocMissing` | Quarto's pandoc is not on `PATH`; see [Writing a document that renders everywhere](#4-writing-a-document-that-renders-everywhere) |
| `Failed to spawn: 'quarto'` / Quarto cannot find a kernel | missing `uv run`, especially on Windows |
| `The lockfile at 'uv.lock' needs to be updated, but '--locked' was provided` | `pyproject.toml` changed without `uv lock`; commit the new lock |
| a package installed with `uv pip install` disappears | expected. Use `uv add` |
| Chromium not found during WebPDF export | `uv run playwright install chromium`, from inside the repo |

---

## 10. Open items for the teaching team

- **A shared repo template.** `mds-demo-assignment/` is a working example, not yet a
  GitHub template repo.
- **DSCI 521.** The environments content was written around uv. `.venv` is no longer
  something students meet for the first time in block 2, so the material can start from
  "you have been using one, here is what it is".
- **R kernels in Jupyter.** IRkernel is installed nowhere by the MDS setup. A course
  that wants R notebooks registers it from inside its own repo:

  ```bash
  R -e 'install.packages("IRkernel", repos = "https://packagemanager.posit.co/cran/latest")'
  R -e "IRkernel::installspec()"
  ```

  `installspec()` writes a **user-level** kernelspec, so it is a one-time machine-wide
  action. Positron does not need it; it uses its own ARK kernel.
