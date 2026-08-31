# Everything you need for this assignment. Run `make` on its own to see the list.
#
# Every Python command goes through `uv run`, which puts this folder's own .venv first
# on PATH, so a leftover Homebrew or pyenv Python cannot be picked up by accident.

.PHONY: commands setup lab pdf html all clean

commands:  ## Show this list
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*## "}; {printf "  %-9s %s\n", $$1, $$2}'

setup:  ## Create .venv and install the exact package versions this lab needs
	uv sync

lab:  ## Open the assignment in JupyterLab
	uv run jupyter lab

# --execute because Quarto does NOT run a notebook by default: without it you render a
# PDF of whatever output was saved, which is how a submitted PDF stops matching the code
# beside it. Typst rather than LaTeX because only Typst keeps emoji and pasted Greek.
pdf: lab0a.pdf  ## Render the PDF you hand in (via Typst)
lab0a.pdf: lab0a.ipynb
	uv run quarto render lab0a.ipynb --to typst --execute

html: lab0a.html  ## Render an HTML copy you can open in a browser
lab0a.html: lab0a.ipynb
	uv run quarto render lab0a.ipynb --to html --execute

all: pdf html  ## Render both, re-running every cell from a clean start

clean:  ## Delete everything the renders produced
	rm -f lab0a.pdf lab0a.html
	rm -rf .quarto lab0a_files .OTTER_LOG
