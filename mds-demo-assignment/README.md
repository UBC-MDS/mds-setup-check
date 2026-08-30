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
the install guides set up. Both get a `.gitattributes`, and from
`student-template/<kind>/` a `.gitignore` and a `Makefile`, R additionally a `.Rproj`.
It clears saved notebook output and **refuses to write the folder if a `BEGIN SOLUTION`
marker survived**. `uv.lock` is copied, not regenerated.

**Edit `source/` and `student-template/`, never a handout directory.** `package`
deletes and rewrites the handout every run, so a change made there is reverted by the
next build without saying so.

The handout `.gitignore`s carry github/gitignore's `R.gitignore` and
`Python.gitignore`, with nothing in them that would ignore a `.pdf` or `.html`
submission. One upstream rule is worth knowing: `R.gitignore` ignores `docs/`, which is
its pkgdown rule, so an R lab cannot hand out a folder by that name.

### The R project file

Copy `student-template/r/assignment.Rproj` into every R assignment, unchanged and under
that same name. A student who clones the repository then gets an RStudio project on a
double click rather than a folder of loose files.

1. **Do not rename it, and do not generate one per student.** RStudio takes the name it
   shows in the Projects toolbar from the *folder*, so a student whose repository is
   `DSCI_521_LAB1_USERNAME` sees exactly that, whatever the file is called. Since
   RStudio 1.2 it also opens whichever `.Rproj` it finds in a directory rather than
   writing a second one when the names differ, so the mismatch is safe as well as
   invisible.
2. **Take the settings as they are.** Three of them are doing work. `LaTeX: XeLaTeX`,
   because RStudio's Knit button otherwise runs pdfLaTeX, which cannot typeset the
   accented characters that turn up in real student work and fails with an error that
   does not point at the engine. `RestoreWorkspace: No` and `SaveWorkspace: No`, so a
   saved `.RData` cannot make code that no longer runs look as though it still does.
   `BuildType: Makefile`, so the Build pane runs the assignment's own `make`.
3. **Positron costs nothing here.** It opens the folder as a workspace and never reads
   the file, so one handout serves a student using either editor.

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
