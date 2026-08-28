# The instructor side of an MDS assignment. Students never see this file; they get the
# directories `make all` builds, each with a Makefile of its own.
#
#   source/<lab>/   the assignment as you write it, solutions and tests included
#   release/<lab>/  what `otter assign` produces: a student copy and an autograder
#   DSCI_521_...    the student copy plus the project files, ready to hand out
#
# Everything goes through `uv run`, because `otter assign` executes the notebook to
# check the solutions against their own tests.

LAB   ?= lab0a
KIND  ?= py
OUT   ?= DSCI_521_LAB_ORIENTATION_PY
ASSIGN_FLAGS ?=

.PHONY: commands setup py r generate package all clean clear

commands:  ## Show this list
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*## "}; {printf "  %-9s %s\n", $$1, $$2}'

setup:  ## Create .venv and install what building an assignment needs
	uv sync

py:  ## Build the Python assignment
	@$(MAKE) LAB=lab0a KIND=py OUT=DSCI_521_LAB_ORIENTATION_PY package

# --no-run-tests is not optional today: that step grades through rpy2, which fails to
# initialise against R 4.6. So R has no safety net -- check its tests by hand, and drop
# the flag the day rpy2 catches up.
r:  ## Build the R assignment
	@$(MAKE) LAB=lab0b KIND=r OUT=DSCI_521_LAB_ORIENTATION_R \
		ASSIGN_FLAGS=--no-run-tests package

# Run FROM the source directory: otter resolves ASSIGNMENT CONFIG paths relative to the
# working directory.
generate:  ## Build release/$(LAB) with otter assign
	cd source/$(LAB) && uv run --project ../.. otter assign $(ASSIGN_FLAGS) \
		$(LAB).$(if $(filter r,$(KIND)),Rmd,ipynb) ../../release/$(LAB)

package: generate  ## Build the folder students are given
	uv run python package-assignment.py --lab $(LAB) --kind $(KIND) --into $(OUT)

all: py r  ## Build both assignments

clean:  ## Delete everything the steps above produced
	rm -rf release/lab0a release/lab0b \
		DSCI_521_LAB_ORIENTATION_PY DSCI_521_LAB_ORIENTATION_R

# Run after opening a source notebook: committing saved output makes every later diff
# unreadable. R Markdown stores no output, so it needs no equivalent.
clear:  ## Strip saved output from the source notebook
	uv run jupyter nbconvert --clear-output --inplace source/lab0a/lab0a.ipynb
