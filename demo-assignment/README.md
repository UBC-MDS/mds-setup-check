# A demo assignment repo

**Audience:** MDS instructors and TAs. This is not a course repo and no student
should be given it. It is the smallest thing that is honestly an assignment, built
to show what [`../assignment-workflow-uv.md`](../assignment-workflow-uv.md)
describes in the abstract.

It runs. Everything below has been executed on this machine, not sketched.

## What a student does

```bash
git clone <this repo>
cd demo-assignment
uv sync
make lab
```

`uv sync` creates `.venv` here and installs the locked versions. `make lab` opens
the notebook. Then, to hand in:

```bash
make all      # lint, re-run every cell, render lab1-latex.pdf
```

Run `make` on its own to list the commands.

## What is deliberate, and why

**The dependency list is shorter than `mds-setup-check`'s.** That repo declares
every package the install guides expect a student to end up with, because its job
is to check the install. An assignment declares what the assignment uses. Copying
the full list into every lab is the easy mistake, and it is why §3 of the guide is
worth reading rather than skimming.

Two entries are there for reasons that are not obvious, both from §3 and §7:
`jupyterlab` is a real dependency rather than a dev one, because Jupyter server
extensions only work in the same environment prefix as the kernel; and `ipykernel`
is named explicitly even though `jupyterlab` pulls it in, so that a grading image
built with `uv sync --no-dev` still has a Python kernel.

**`uv.lock` is committed.** Every student resolves to byte-identical versions. Run
`uv add <pkg>` mid-assignment and commit both files it changes.

**`.gitattributes` pins line endings.** The Windows install guide has students set
git to check out CRLF. Without this file, `bash` fails on a shebang with
`$'\r': command not found` and GNU make appends a carriage return to every
argument. Neither error mentions line endings, and both get reported as "the repo
is broken".

**The `Makefile` names its two PDF outputs apart.** Quarto compiles to an
intermediate named after the *input* and then moves it, and treats `--to pdf` and
`--to typst` as the same output for a given input. Two targets over one source
overwrite each other with no warning.

**`make run` re-executes the notebook.** Quarto does not run an `.ipynb` by
default, so a student who edits a cell without re-running it renders a PDF of
stale output and is told nothing. That is the failure that actually reaches a TA.

## `make lint`, which is the part worth stealing

`lint-portability.py` refuses constructs that some PDF route drops *silently*.
Every route in the MDS toolchain exits 0 while discarding what it cannot set, so
"it rendered" is not evidence it rendered correctly, and the sentence around the
missing thing is still grammatical. Nobody reports these.

It enforces the three rules from §5 of the guide:

1. Maths goes inside `$…$` or `$$…$$`. A bare `\begin{equation}` is a raw LaTeX
   environment that Typst renders nothing for. Numbering comes from Quarto's
   `$$ … $$ {#eq-label}`, which is numbered in both PDF routes.
2. Nothing outside maths starts with a backslash. `\textbf{}`, `\emph{}`,
   `\footnote{}` and `tabular` reach the LaTeX PDF and vanish from Typst and HTML.
3. Greek is `\alpha`, not a literal `α`. `$$` is not a shield: `\text{}` switches
   back to the text font, so a literal character there is dropped by LaTeX inside
   an equation that otherwise typesets perfectly.

Code spans and fenced blocks are exempt, so a notebook may still *discuss*
`\begin{align}` or name a column `alpha`.

The rules are not folklore. `mds-setup-check` measures each one on fixtures and
regenerates its table from the rendered files; `check-raw-passthrough.qmd` is the
fixture for rules 2 and 3.

## What this demo does not show

- **Autograding.** `grader.check()` gives students feedback against the public
  tests in `tests/`. Grading a submitted notebook is `otter grade` on the
  instructor side, which needs Docker and is out of scope here.
- **Hidden tests.** Every case in `tests/` is public, which no real assignment
  should do.
- **R.** uv does not manage R. See §3 of the guide for the renv option.

One honest observation while building it: `otter-grader` requires
`nbconvert[webpdf]`, `jupytext`, `ipywidgets` and `ipylab`, so playwright lands in
the environment whether or not the assignment wants it. Declaring a short
dependency list keeps the *repo* honest about what it uses; it does not keep the
install small.
