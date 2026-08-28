# The MDS demo assignment

Two labs, the same lesson in two languages.

| lab | language | source | students get |
| --- | --- | --- | --- |
| `lab0a` | Python, Jupyter | `source/lab0a/lab0a.ipynb` | `DSCI_521_LAB_ORIENTATION_PY/` |
| `lab0b` | R, R Markdown | `source/lab0b/lab0b.Rmd` | `DSCI_521_LAB_ORIENTATION_R/` |

---

## For students

1. **Move your lab out of this repository first.**

   ```bash
   mv DSCI_521_LAB_ORIENTATION_PY ~/Desktop/     # or ..._R
   cd ~/Desktop/DSCI_521_LAB_ORIENTATION_PY
   ```

   That folder is a complete assignment on its own. Left where it is, `uv sync` builds
   a second environment inside a repository that already has one, and warns about it in
   a way that reads like an error. `git status` here will then report a deleted
   directory -- expected, nothing to fix.

2. **Set up.** `make setup` - Python installs the exact versions; R just checks you
   have the packages.

3. **Do the lab.**

4. **Render what you hand in.** `make all` builds the PDF and HTML, re-running
   everything from a clean start. Run it before you finish: if it fails, your work only
   ran because of something you did earlier and then changed.

`make` on its own lists every target.

---

## For instructors

```bash
make setup    # once: create .venv from uv.lock
make all      # build both assignments; or `make py` / `make r` for one
```

### The three directories

| directory | what it is | who sees it |
| --- | --- | --- |
| `source/<lab>/` | the assignment as you write it: solutions, tests, otter config | you |
| `release/<lab>/` | what `otter assign` produces: `student/` and `autograder/` | you |
| `DSCI_521_LAB_ORIENTATION_*/` | the student copy plus the project files | students |

You edit `source/`. The other two are built, and `make clean` deletes them.

`generate` runs `otter assign` from inside `source/<lab>/`. For Python it also executes
the solution and grades it against its own tests, which catches a test that is wrong or
that depends on a variable defined in another cell.

`package` copies `release/<lab>/student/` into the handout directory and adds what the
assignment alone does not have: for Python `pyproject.toml`, `uv.lock` and
`.python-version`; for R nothing of the sort, because R packages come from the library
the install guides set up. Both get a `.gitignore`, `.gitattributes` and a `Makefile`.
It clears saved notebook output and **refuses to write the folder if a `BEGIN SOLUTION`
marker survived**. `uv.lock` is copied, not regenerated.

### Writing questions

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

Three rules, each of which cost a morning to find:

1. **Without the raw `# BEGIN SOLUTION` boundary cells the solution is not stripped**,
   silently. Inline comments only control what the student sees *within* a cell otter
   has already tagged.
2. **A test may use only builtins and the student's own answer.** Not `pd`, not a
   DataFrame from an earlier cell -- the environment otter grades in is not the one you
   have open.
3. **A tests cell whose first line contains `hidden` is hidden**: stripped from the
   student copy, kept in the autograder. Say so in the prompt.

### The R caveat

`make r` passes `--no-run-tests`, and today that is not optional: the validation step
grades through `rpy2`, which fails to initialise against R 4.6 with
`Error in substring(x, m + 1L) : invalid substring arguments`. Generation itself is
fine, but **R has no safety net**. Check the R tests by hand, and drop the flag the day
rpy2 catches up.
