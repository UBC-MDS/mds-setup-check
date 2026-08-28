# The instructor side of an MDS assignment. Students never see this file; they get the
# directory `make package` builds, which has a Makefile of its own.
#
#   source/<lab>/   the assignment as you write it, solutions and tests included
#   release/<lab>/  what `otter assign` produces: a student copy and an autograder
#   DSCI_521_...    the student copy plus the project files, ready to hand out
#
# Every command goes through `uv run` so it uses this folder's .venv, which is pinned
# by uv.lock. `otter assign` executes the notebook to check the solutions against their
# own tests, so that environment has to contain everything the notebook imports.

LAB ?= lab0a
OUT ?= DSCI_521_LAB_ORIENTATION_PY

.PHONY: commands setup generate package all clean clear

commands:  ## Show this list
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*## "}; {printf "  %-9s %s\n", $$1, $$2}'

setup:  ## Create .venv and install what building an assignment needs
	uv sync

# otter assign is run FROM the source directory. It resolves the paths in ASSIGNMENT
# CONFIG relative to the working directory, so running it from here would look for
# requirements.txt in the wrong place.
#
# It also grades the solution notebook against its own tests and exits non-zero if any
# fail. That is the point of the step, not a side effect: it catches a test that is
# wrong, and a test that depends on a cell the student might not have run.
generate:  ## Build release/$(LAB) from source/$(LAB) with otter assign
	cd source/$(LAB) && uv run --project ../.. otter assign $(LAB).ipynb ../../release/$(LAB)

package: generate  ## Build the folder students are given
	uv run python package-assignment.py --lab $(LAB) --into $(OUT)

all: package  ## Generate and package in one step

clean:  ## Delete everything the two steps above produced
	rm -rf release/$(LAB) $(OUT)

# Run after opening the source notebook to check your own answers. Committing a
# notebook full of saved output makes every later diff unreadable.
clear:  ## Strip saved output from the source notebook
	uv run jupyter nbconvert --clear-output --inplace source/$(LAB)/$(LAB).ipynb
