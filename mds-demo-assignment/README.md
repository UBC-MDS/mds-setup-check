# The MDS demo assignment

Two labs, the same lesson in two languages:

| lab | language | source | students get |
| --- | --- | --- | --- |
| `lab0a` | Python, Jupyter | `source/lab0a/lab0a.ipynb` | `DSCI_521_LAB_ORIENTATION_PY/` |
| `lab0b` | R, R Markdown | `source/lab0b/lab0b.Rmd` | `DSCI_521_LAB_ORIENTATION_R/` |

Two audiences, so two halves below. **Students** want the section at the bottom.
**Instructors and TAs** want everything above it.

---

# For instructors

```bash
make setup    # once: create .venv from uv.lock
make all      # build both assignments; or `make py` / `make r` for one
```

## The three directories

| directory | what it is | who sees it |
| --- | --- | --- |
| `source/<lab>/` | the assignment as you write it: solutions, tests, otter config | you |
| `release/<lab>/` | what `otter assign` produces: `student/` and `autograder/` | you |
| `DSCI_521_LAB_ORIENTATION_*/` | the student copy plus the project files | students |

You edit `source/`. The other two are built, and `make clean` deletes them.

## What each step does

**`generate`** runs `otter assign` from inside `source/<lab>/`, which matters: otter
resolves the paths in `ASSIGNMENT CONFIG` relative to the working directory.

For Python it also **executes the solution and grades it against its own tests**,
exiting non-zero if anything fails. That is the point of the step — it catches a test
that is wrong, and, more often, a test that depends on a variable defined in some other
cell.

**`package`** runs `package-assignment.py`, which copies `release/<lab>/student/` into
the handout directory and adds what the assignment alone does not have. For Python that
is `pyproject.toml`, `uv.lock` and `.python-version`; for R, nothing of the sort,
because R packages come from the library the MDS install guides set up. Both get a
`.gitignore`, a `.gitattributes` and a `Makefile` with one target per thing a student
does. It clears saved notebook output, and it **refuses to write the folder if a
`BEGIN SOLUTION` marker survived**.

`uv.lock` is **copied, not regenerated**, so every student resolves to the versions the
assignment was written against rather than to whatever pandas shipped that week.

## Writing questions

Otter's format. In a notebook the boundary cells are **raw**; in R Markdown they are
**HTML comments**:

```
notebook (.ipynb)                 R Markdown (.Rmd)
raw   # BEGIN QUESTION            <!--
      name: q1                    # BEGIN QUESTION
                                  name: q1
                                  -->
md    the prompt                  the prompt
raw   # BEGIN SOLUTION            <!-- # BEGIN SOLUTION -->
code  the answer                  ```{r} the answer ```
raw   # END SOLUTION              <!-- # END SOLUTION -->
raw   # BEGIN TESTS               <!-- # BEGIN TESTS -->
code  visible cases               ```{r} visible cases ```
code  # HIDDEN                    ```{r} # HIDDEN ... ```
raw   # END TESTS                 <!-- # END TESTS -->
raw   # END QUESTION              <!-- # END QUESTION -->
```

Three rules worth knowing, each of which cost a morning to find:

1. **Without the raw `# BEGIN SOLUTION` boundary cells the solution is not stripped**,
   silently. Inline `# BEGIN SOLUTION` comments inside the cell only control what the
   student sees *within* a cell that otter has already tagged. `package-assignment.py`
   checks for surviving markers because of this.
2. **A test may use only builtins and the student's own answer.** Not `pd`, not a
   DataFrame from an earlier cell. The environment otter grades in is not the one you
   have open — `import matplotlib` fails there — so a test that reaches for something
   defined elsewhere fails for reasons that have nothing to do with the answer.
3. **A tests cell whose first line contains `hidden` is hidden**: stripped from the
   student copy, kept in the autograder. Say so in the prompt. Both labs do.

## The R caveat

`make r` passes `--no-run-tests`, and today that is not optional. The validation step
grades the solution through `rpy2`, which fails to initialise against R 4.6:

```
Error in substring(x, m + 1L) : invalid substring arguments
```

Generation itself is unaffected — the student copy and the autograder are correct — but
the safety net that Python gets is **not running for R**. Check the R tests by hand, and
drop the flag the day rpy2 catches up.

---

# For students

**Move your lab out of this repository before you start.**

```bash
mv DSCI_521_LAB_ORIENTATION_PY ~/Desktop/     # or ..._R
cd ~/Desktop/DSCI_521_LAB_ORIENTATION_PY
```

That folder is a complete assignment on its own. The Python one has its own packages;
left where it is, `uv sync` would build a second environment inside a repository that
already has one, and uv warns about it in a way that reads like an error. Moving it also
leaves `git status` here reporting a deleted directory, which is expected and nothing to
fix.

Then, in either folder:

```bash
make setup    # Python: install the exact versions. R: check you have the packages.
make all      # render the PDF and HTML you hand in
```

`make all` re-runs everything from a clean start. Run it before you finish: if it fails,
your work only ran because of something you did earlier and then changed.

Run `make` on its own for the full list.
