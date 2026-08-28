# The MDS demo assignment

Two audiences, so two halves. **Students** want the section at the bottom. **Instructors
and TAs** want everything above it.

---

# For instructors

This is the assignment pipeline in miniature, with one real lab in it. Three commands:

```bash
make setup      # once: create .venv from uv.lock
make package    # generate the student copy, then build the folder you hand out
```

`make package` runs `make generate` first, so that is the whole thing.

## The three directories

| directory | what it is | who sees it |
| --- | --- | --- |
| `source/lab0a/` | the assignment as you write it: solutions, tests, otter config | you |
| `release/lab0a/` | what `otter assign` produces: `student/` and `autograder/` | you |
| `DSCI_521_LAB_ORIENTATION_PY/` | the student copy plus the project files | students |

You edit `source/`. The other two are built, and `make clean` deletes them.

## What each step does

**`make generate`** runs `otter assign` from inside `source/lab0a/`, which matters:
otter resolves the paths in `ASSIGNMENT CONFIG` relative to the working directory, so
running it from here looks for `requirements.txt` in the wrong place.

It also **executes your solution notebook and grades it against its own tests**, and
exits non-zero if anything fails. That is the point of the step. It catches a test that
is wrong, and — more often — a test that depends on a variable defined in some other
cell.

**`make package`** runs `package-assignment.py`, which copies `release/lab0a/student/`
into `DSCI_521_LAB_ORIENTATION_PY/` and adds what a notebook alone does not have:
`pyproject.toml`, `uv.lock`, `.python-version`, `.gitignore`, `.gitattributes`, and a
`Makefile` with one target per thing a student does. It refuses to write the folder if
a `BEGIN SOLUTION` marker survived into the student notebook.

`uv.lock` is **copied, not regenerated**, so every student resolves to the versions the
assignment was written against rather than to whatever pandas shipped that week.

## Writing questions

Otter's format, and the two rules worth knowing:

```
raw   # BEGIN QUESTION            <- boundary cells must be RAW, not markdown
      name: q1
md    the prompt
raw   # BEGIN SOLUTION            <- without these, the solution is NOT stripped
code  answer, with inline # BEGIN SOLUTION / # END SOLUTION for scaffolding
raw   # END SOLUTION
raw   # BEGIN TESTS
code  visible test cases
code  # HIDDEN                    <- a tests cell whose FIRST LINE says "hidden"
raw   # END TESTS
raw   # END QUESTION
```

**A test may use only builtins and the student's own answer.** Not `pd`, not a
DataFrame from an earlier cell. A test that reaches for something defined elsewhere
fails for anyone who did not run that cell, and blames their answer for it. `make
generate` catches this, because the environment it grades in is not the one you have
open.

**Hidden tests are stripped from the student notebook and kept in the autograder.**
Say so in the prompt when you use them — `lab0a` does.

## Adding another lab

`make LAB=lab0b package`. `lab0b` is the R counterpart and still uses the old
conda-based otter path; it has not been through this pipeline yet.

---

# For students

**Move `DSCI_521_LAB_ORIENTATION_PY` out of this repository before you start.**

```bash
mv DSCI_521_LAB_ORIENTATION_PY ~/Desktop/
cd ~/Desktop/DSCI_521_LAB_ORIENTATION_PY
```

That folder is a complete assignment on its own — it has its own packages and its own
`Makefile`. Left where it is, `uv sync` would build a second environment inside a
repository that already has one, and uv warns about it in a way that reads like an
error. Moving it also leaves `git status` here reporting a deleted directory, which is
expected and nothing to fix.

Then:

```bash
make setup    # install the exact package versions this lab needs
make lab      # open it in JupyterLab
make all      # render the PDF and HTML you hand in
```

`make all` re-runs every cell from a clean start. Run it before you finish: if it
fails, your notebook only worked because of something you ran earlier and then changed.

Run `make` on its own for the full list.
