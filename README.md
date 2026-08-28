# mds-setup-check

Provides an example workflow for instructors and students.

Also provides CI that tests whether the UBC MDS install instructions still work. It renders the same
documents by every route students have and checks what actually came out.

Install guides: [macOS](https://ubc-mds.github.io/resources_pages/install_ds_stack_mac)
· [Ubuntu](https://ubc-mds.github.io/resources_pages/install_ds_stack_ubuntu)
· [Windows](https://ubc-mds.github.io/resources_pages/install_ds_stack_windows)

---

## For students

### 1. Check your install

The install guide gave you a command that
downloads it into `~/mds-setup-check` for you.
You may re-run that command,
or manually download/clone this repository
to your computer

1. Follow your install guide to the end.
2. Run the setup check command it gives you.
3. Answer the two prompts. Both default to **no**, so pressing Enter is always safe.
4. Submit the `check-setup-mds.log` file it leaves behind.
5. Delete `~/mds-setup-check` whenever you like. The next run makes it again.

If `~/mds-setup-check` already exists, the script offers to delete it and download a
fresh copy. Say no and it leaves your folder alone, skipping the Python and PDF checks.

**RStudio** and **Positron** may be safely ignored when marked `MISSING`.
They are the only programs checked that you never launch from a terminal, so if the application
opens, the lookup was wrong and nothing is broken. Everything else on that list is a
command you will type.

### 2. Every Python command starts with `uv run`

```bash
uv run jupyter lab      # not: jupyter lab
uv run python script.py # not: python script.py
```

There is no global Python any more. `uv run` puts your project's own `.venv` first on
`PATH`, and it only works from inside a project folder -- so `cd` into the repo first.

### 3. Make a PDF of your assignment

Use Quarto. It reads notebooks (`.ipynb`), `.qmd` and `.Rmd` alike:

```bash
uv run quarto render your-file.ipynb --to typst
```

`--to typst` supports emoji and literal Greek letters. Use `--to pdf` instead if you
want the LaTeX engine.
Quarto does not re-run a notebook by default; add `--execute` if you want it to.
Otherwise, make sure you run all your code before
exporting.

### 4. Four rules for a document that renders everywhere

Every PDF route drops something without telling you. These four rules avoid all of it.

1. **Put every maths construct inside `$…$` or `$$…$$`.** A bare `\begin{equation}` or
   `\begin{align}` renders as nothing at all in Typst, silently. Write aligned
   equations as `$$\begin{aligned}…\end{aligned}$$`.
2. **Inside maths, Greek is `\alpha`, never a literal `α`.** LaTeX has no glyph for `α`
   and drops it without an error. This includes Greek inside `\text{}`.
3. **Nothing outside maths starts with a backslash.** `**bold**` not `\textbf{}`,
   markdown tables not `tabular`, footnotes as `^[like this]`. Written the LaTeX way
   they vanish from Typst and HTML, leaving a grammatical sentence with a word missing.
4. **Emoji only survive Typst, HTML and WebPDF.** There is no maths form for one.

If something is already missing from a PDF, check
[docs/render-matrix.md](docs/render-matrix.md). If that route is marked as not
supporting the thing you lost, your install is fine and you need a different route.

---

## For instructors

Building an assignment repo: **[assignment-workflow-uv.md](assignment-workflow-uv.md)**.
A working example of it: **[`mds-demo-assignment/`](mds-demo-assignment/)**.

### Running the checks yourself

Clone anywhere *except* `~/mds-setup-check`, then:

```bash
make install   # Python via uv, R via renv, and the browser WebPDF needs
make all       # render every document by every route
make check     # the verdict
```

- `make` on its own lists every target.

- `make all` deliberately keeps going past a failure and ignores make's exit code: one
route is known not to work, and stopping there would leave every later route unrendered
and looking broken.

- `make check` looks
inside the finished files, because every LaTeX route exits 0 while silently dropping
characters it has no glyph for.
This runs a vibe-coded linter script.

### Results

- [docs/render-matrix.md](docs/render-matrix.md) -- which features survive which route.
- [Latest CI runs](https://github.com/UBC-MDS/mds-setup-check/actions/workflows/assignment-workflow.yml)
  -- every route on macOS, Ubuntu and Windows, on every push and every Monday.

### What a green build does not prove

- **The student script runs end to end on all three platforms**, but nothing asserts
  that a `MISSING` line is *right*. Every version pattern could be wrong and CI would
  still be green.
- **The version patterns are substring tests.** `R=4.*` accepts `R version 5.0.0
  (2027-04-20)` by matching the `04` in the date. See
  [#7](https://github.com/UBC-MDS/mds-setup-check/issues/7).
- **The R packages the guides tell students to install are installed by nothing here** --
  `tidyverse`, `ottr`, `canlang` and the rest. `renv.lock` answers a different question.
- **Several programs are never installed on a runner:** Positron, RStudio, PostgreSQL,
  Docker, XQuartz, Rtools.
- **The Python packages section cannot fail for anything a student did.** It reports the
  versions `uv sync` just installed from this repo's own `uv.lock`.
- **TinyTeX is installed by a GitHub action**, not by the `tinytex::install_tinytex()`
  route the guides give students -- so the PATH step they warn about is verified
  nowhere. The 22-package `tlmgr` list *is* checked.

### What is in here

| path | what it is |
| --- | --- |
| `check-setup-mds.sh` | the setup check students run |
| `check-python-installs.sh` | reports every Python on the machine; run before installing uv, and again from inside the check |
| `mds-help.sh` | the `mds-help` reference card |
| `Makefile` | installs, renders and checks; run `make` for the list |
| `render-checks/` | the fixtures, and everything they render |
| `docs/` | [`render-matrix.md`](docs/render-matrix.md): which features survive which route, generated by `make matrix` |
| `ci/` | the gates: content assertions, the feature matrix, doc and contract checks |
| `pyproject.toml`, `uv.lock`, `.python-version` | the Python stack, pinned |
| `renv.lock`, `.Rprofile`, `renv/`, `DESCRIPTION` | the R stack, pinned. Students never use these -- theirs come from the MDS install |
| [`mds-demo-assignment/`](mds-demo-assignment/) | the assignment pipeline, end to end |
| [`assignment-workflow-uv.md`](assignment-workflow-uv.md) | how to build an MDS assignment repo |
| [`using-atkinson-hyperlegible.md`](using-atkinson-hyperlegible.md) | optional: a more legible typeface |
| [`CLAUDE.md`](CLAUDE.md) | context for an AI agent working here |

The first three files are served straight out of `main` by GitHub Pages, so the copy
students run is always the copy on `main`. That is what `.nojekyll` and `index.html`
are for.

```
https://ubc-mds.github.io/mds-setup-check/check-setup-mds.sh
https://ubc-mds.github.io/mds-setup-check/check-python-installs.sh
https://ubc-mds.github.io/mds-setup-check/mds-help.sh
```

Open work lives in this repository's GitHub issues.
