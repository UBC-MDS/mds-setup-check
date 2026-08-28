# The instructor side of an MDS assignment. Students never see this file; they get the
# directories `make all` builds, each of which has a Makefile of its own.
#
#   source/<lab>/   the assignment as you write it, solutions and tests included
#   release/<lab>/  what `otter assign` produces: a student copy and an autograder
#   DSCI_521_...    the student copy plus the project files, ready to hand out
#
# Every command goes through `uv run` so it uses this folder's .venv, which is pinned by
# uv.lock. `otter assign` executes the notebook to check the solutions against their own
# tests, so that environment has to contain everything the assignment imports.

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

# --no-run-tests, and it is not optional today. That step grades the solution through
# rpy2, which fails to initialise against R 4.6 with "Error in substring(x, m + 1L)".
# Generation itself is unaffected, but the safety net it provides for lab0a -- catching
# a test that is wrong, or that depends on a chunk the student might not have run -- is
# NOT running for R. Check the R tests by hand until rpy2 catches up, and drop this flag
# the day it does.
r:  ## Build the R assignment
	@$(MAKE) LAB=lab0b KIND=r OUT=DSCI_521_LAB_ORIENTATION_R \
		ASSIGN_FLAGS=--no-run-tests package

# otter assign is run FROM the source directory. It resolves the paths in ASSIGNMENT
# CONFIG relative to the working directory, so running it from here would look for
# requirements.txt in the wrong place.
generate:  ## Build release/$(LAB) with otter assign
	cd source/$(LAB) && uv run --project ../.. otter assign $(ASSIGN_FLAGS) \
		$(LAB).$(if $(filter r,$(KIND)),Rmd,ipynb) ../../release/$(LAB)

package: generate  ## Build the folder students are given
	uv run python package-assignment.py --lab $(LAB) --kind $(KIND) --into $(OUT)

all: py r  ## Build both assignments

clean:  ## Delete everything the steps above produced
	rm -rf release/lab0a release/lab0b \
		DSCI_521_LAB_ORIENTATION_PY DSCI_521_LAB_ORIENTATION_R

# Run after opening a source notebook to check your own answers. Committing one full of
# saved output makes every later diff unreadable. R Markdown needs no equivalent: it
# stores no output in the file.
clear:  ## Strip saved output from the source notebook
	uv run jupyter nbconvert --clear-output --inplace source/lab0a/lab0a.ipynb
