# Builds and checks this project.
#
#   make install   install everything this project needs, in both languages
#   make all       render every document by every route
#   make check     say whether the results are actually correct
#   make clean     delete everything the renders produced
#
# Those are the three commands, in that order. Everything a student needs to run
# lives in this file rather than in the README, so that what they run and what CI
# runs cannot drift apart.
#
# There are four output routes, and they do not all handle the same characters:
#
#   pdf     LaTeX      accents and math yes; literal Greek and emoji NO
#   typst   Typst      everything, and no LaTeX involved
#   html    pandoc     everything
#   webpdf  Chromium   everything, needs the browser `make install` downloads
#
# Use typst or webpdf for a document containing emoji or literal Greek letters.
#
# This project carries its own packages for both languages, so it does not matter
# what else is installed on the machine:
#
#   Python  uv     installs into .venv        from pyproject.toml and uv.lock
#   R       renv   installs into renv/library from renv.lock
#
# Every Python command is therefore prefixed with `uv run`.

.PHONY: commands all render install clean check check-docs check-contract matrix matrix-check pdf typst html webpdf

# `commands` is first, so a bare `make` prints this list rather than doing work.
# The list is built from the `##` comments on each target below, so it cannot go
# stale the way a hand-written help message does. grep -E, sort and awk are all
# present in Git Bash on Windows as well as on macOS and Linux.
commands:  ## Show this list of targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*## "}; {printf "  %-10s %s\n", $$1, $$2}'

# ---------------------------------------------------------------- install ----
# Chromium is included because the WebPDF route below needs it, and it is the
# only PDF route that renders emoji and other symbols. It is a one-time download.
install:  ## Install the Python and R packages, and the browser for webpdf
	uv sync
	uv run playwright install chromium
	Rscript -e 'renv::restore(prompt = FALSE)'

# -------------------------------------------------------------------- all ----
# A recipe rather than a list of prerequisites, so that the keep-going flag is part
# of the target instead of something the student has to remember. One route is known
# not to work -- check-notebook-table.ipynb cannot be exported to PDF by nbconvert --
# and a bare `make` would stop there, leaving every later route unrendered and
# looking broken. The exit code is ignored for the same reason: `make check` is the
# verdict, and it is the only thing that knows which failures are expected.
all:  ## Render every document by every route
	@$(MAKE) -k render || true
	@echo
	@echo 'Rendering finished. Now run `make check` to find out whether the results'
	@echo 'are correct -- rendering without errors is not the same as rendering right.'

render: pdf typst html webpdf  ## Render, without the keep-going wrapper (used by CI)

# Every output name carries the tool that produced it. That is not only for
# reading the table: Quarto compiles `check-rmarkdown.Rmd` to an intermediate
# named `check-rmarkdown.pdf` and *then* moves it to --output, so a route named
# after the input alone gets eaten by whichever route runs next.
LATEX_OUT = check-quarto-py-latex.pdf check-quarto-r-latex.pdf \
            check-notebook-quarto-latex.pdf check-rmarkdown-quarto-latex.pdf \
            check-notebook-nbconvert-latex.pdf check-rmarkdown-rmarkdown-latex.pdf \
            check-notebook-table-nbconvert-latex.pdf \
            check-notebook-table-quarto-latex.pdf
TYPST_OUT = check-quarto-py-typst.pdf check-quarto-r-typst.pdf \
            check-notebook-quarto-typst.pdf check-rmarkdown-quarto-typst.pdf
HTML_OUT  = check-quarto-py.html check-quarto-r.html \
            check-notebook-quarto.html check-rmarkdown-quarto.html \
            check-notebook-nbconvert.html check-rmarkdown-rmarkdown.html \
            check-notebook-table-nbconvert.html
WEBPDF_OUT = check-notebook-nbconvert-web.pdf check-notebook-nbconvert-api-web.pdf

# Four documents in three input formats, three renderers, four output formats. Quarto can render every input
# format, so those combinations are all here; nbconvert only reads .ipynb and
# rmarkdown only reads .Rmd, so those have fewer.
pdf: $(LATEX_OUT)  ## Render to PDF through LaTeX

typst: $(TYPST_OUT)  ## Render to PDF through Typst

html: $(HTML_OUT)  ## Render to HTML

# --- Quarto: the .qmd sources, whose output names are set in their own YAML ---
check-quarto-py-latex.pdf check-quarto-py-typst.pdf check-quarto-py.html: check-quarto-py.qmd
	uv run quarto render $< --to $(if $(findstring typst,$@),typst,$(if $(findstring html,$@),html,pdf))

check-quarto-r-latex.pdf check-quarto-r-typst.pdf check-quarto-r.html: check-quarto-r.qmd
	uv run quarto render $< --to $(if $(findstring typst,$@),typst,$(if $(findstring html,$@),html,pdf))

# --- Quarto: the same notebook and R Markdown the other tools render ---------
# Rendering these through Quarto as well is the point: it shows whether Quarto
# handles every input format, and it is the workaround when another tool cannot.
check-notebook-quarto-latex.pdf: check-notebook.ipynb
	uv run quarto render $< --to pdf --output $@

check-notebook-quarto-typst.pdf: check-notebook.ipynb
	uv run quarto render $< --to typst --output $@

check-notebook-quarto.html: check-notebook.ipynb
	uv run quarto render $< --to html --output $@

check-rmarkdown-quarto-latex.pdf: check-rmarkdown.Rmd
	uv run quarto render $< --to pdf --output $@

check-rmarkdown-quarto-typst.pdf: check-rmarkdown.Rmd
	uv run quarto render $< --to typst --output $@

check-rmarkdown-quarto.html: check-rmarkdown.Rmd
	uv run quarto render $< --to html --output $@

# --- nbconvert: the route JupyterLab's export menu uses ----------------------
check-notebook-nbconvert-latex.pdf: check-notebook.ipynb
	uv run jupyter nbconvert $< --to pdf --output $(basename $@)

check-notebook-nbconvert.html: check-notebook.ipynb
	uv run jupyter nbconvert $< --to html --output $(basename $@)

# --- the markdown table, alone -----------------------------------------------
# One construct, three routes. nbconvert's HTML is fine and Quarto's LaTeX is fine,
# so when the first of these fails it is neither nbconvert nor LaTeX at fault: it is
# nbconvert's LaTeX template. Keeping the table out of check-notebook.ipynb is what
# lets that notebook export from JupyterLab, which is what students are told to do.
check-notebook-table-nbconvert-latex.pdf: check-notebook-table.ipynb
	uv run jupyter nbconvert $< --to pdf --output $(basename $@)

check-notebook-table-nbconvert.html: check-notebook-table.ipynb
	uv run jupyter nbconvert $< --to html --output $(basename $@)

check-notebook-table-quarto-latex.pdf: check-notebook-table.ipynb
	uv run quarto render $< --to pdf --output $@

# --- rmarkdown: rendered by R itself -----------------------------------------
check-rmarkdown-rmarkdown-latex.pdf: check-rmarkdown.Rmd
	Rscript -e 'rmarkdown::render("$<", output_format = "pdf_document", output_file = "$@")'

check-rmarkdown-rmarkdown.html: check-rmarkdown.Rmd
	Rscript -e 'rmarkdown::render("$<", output_format = "html_document", output_file = "$@")'

# The LaTeX-free route, rendered by a headless browser rather than TeX.
webpdf: $(WEBPDF_OUT)  ## Render to PDF through a headless browser

# Tried twice. nbconvert loads the page with playwright and waits for "networkidle" with
# a fixed 30-second budget; the notebook pulls MathJax from a CDN, so a slow network makes
# this fail on a machine where nothing is wrong. Seen once on a macOS runner, passing on
# the next run with no change. A route that is actually broken still fails, twice.
check-notebook-nbconvert-web.pdf: check-notebook.ipynb
	uv run jupyter nbconvert $< --to webpdf --output $(basename $@) \
	|| uv run jupyter nbconvert $< --to webpdf --output $(basename $@)

# The same export, driven through nbconvert's exporter API rather than its command
# line. The CLI cannot do this on Windows, and this route is here to show that the
# reason is one line in the CLI rather than anything about the platform. Read
# ci/webpdf.py for the mechanism. Retried once for the same network reason.
check-notebook-nbconvert-api-web.pdf: check-notebook.ipynb ci/webpdf.py
	uv run python ci/webpdf.py $< $@ || uv run python ci/webpdf.py $< $@

# ------------------------------------------------------------------ check ----
# Rendering is not the same as rendering correctly: every LaTeX route exits 0
# while silently dropping characters it has no glyph for. This looks inside the
# rendered files instead of at the exit codes.
check:  ## Check the rendered documents actually contain what they should
	uv run python ci/assert-renders.py

matrix:  ## Print the feature-by-route table that is in the README
	uv run python ci/feature-matrix.py

matrix-check:  ## Check the README's table still matches the rendered files
	uv run python ci/check-matrix-block.py

# Documentation drifts silently, which is the failure this project exists to catch, so
# the mechanical half of "keep the docs in sync" is a target rather than a promise.
check-docs:  ## Check the documentation still describes this repository
	uv run python ci/assert-docs.py

# The claims assignment-workflow-uv.md makes about this repo, which course repos are
# copied from. It ran only in CI, so an instructor copying this repository could not
# check the contract they were inheriting without knowing the script by name.
check-contract:  ## Check this repo still matches what the assignment guide describes
	uv run python ci/assert-contract.py

# ------------------------------------------------------------------ clean ----
clean:  ## Delete everything the renders produced
	rm -f check-*.pdf check-*.html
	rm -f check-setup-mds.log *.log
	rm -f *.tex *.knit.md *.quarto_ipynb
	rm -rf .quarto *_files
