# One command per thing a student does. `make` alone lists them.
#
# Every Python command goes through `uv run`, which puts this project's .venv first
# on PATH. That is what makes the repo self-contained: nothing is inherited from the
# machine, so a leftover Homebrew or pyenv Python cannot be picked up by accident.

.PHONY: commands install lab lint run pdf typst all clean

commands:  ## List these commands
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

install:  ## Create .venv and install the locked packages
	uv sync

lab:  ## Open the assignment in JupyterLab
	uv run jupyter lab lab1.ipynb

lint:  ## Check the notebook for constructs that do not survive every PDF route
	uv run python lint-portability.py lab1.ipynb

# Not "did you get the right answer" -- grader.check() in the notebook tells you that.
# This is "does the notebook still run top to bottom", which is the failure that
# actually reaches a TA: a cell is edited, not re-run, and the submitted PDF shows
# output that no longer matches the code. Quarto does not execute an .ipynb by
# default, so nothing else here would catch it.
#
# Note there is no `uv run pytest` target. pytest is not declared in pyproject.toml,
# and under `uv run` an undeclared command is looked up on the inherited PATH -- so on
# a machine that happens to have one, it would run against the wrong interpreter and
# fail in a way that looks like a bug in the assignment. See §4 of the guide.
run:  ## Re-run the whole notebook and fail if any cell errors
	uv run jupyter nbconvert --to notebook --execute --inplace lab1.ipynb

# Quarto reads .ipynb directly, so nothing has to be converted first. --execute
# because Quarto does NOT run a notebook by default: without it a student who edited
# a cell without re-running it submits a PDF of stale output, with no warning.
pdf: lab1-latex.pdf  ## Render the submission PDF (LaTeX)
typst: lab1-typst.pdf  ## Render the submission PDF (Typst; use if you need emoji)

# Named apart on purpose. Quarto compiles to an intermediate named after the INPUT
# and then moves it, and treats --to pdf and --to typst as the same output for a
# given input, so two targets over one source overwrite each other with no warning.
lab1-latex.pdf: lab1.ipynb
	uv run quarto render $< --to pdf --execute --output $@

lab1-typst.pdf: lab1.ipynb
	uv run quarto render $< --to typst --execute --output $@

all: lint run pdf  ## Lint, re-run every cell, and render what you submit

clean:  ## Delete everything the renders produced
	rm -f lab1-latex.pdf lab1-typst.pdf
	rm -rf .quarto lab1_files
