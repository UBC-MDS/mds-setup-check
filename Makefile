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
commands:  ### Show this list of targets
	@echo 'What you run, in this order:'
	@grep -E '^[a-zA-Z_-]+:.*[^#]## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*## "}; {printf "  %-10s %s\n", $$1, $$2}'
	@echo
	@echo 'Maintaining this repository. CI runs these; a student never needs them:'
	@grep -E '^[a-zA-Z_-]+:.*### ' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*### "}; {printf "  %-14s %s\n", $$1, $$2}'

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

render: pdf typst html webpdf  ### Render, without the keep-going wrapper (used by CI)

# The fixtures, and everything they render, live in one directory. The three .sh
# scripts stay at the repository root because GitHub Pages serves them from there and
# their download URLs are printed in the install guides.
#
# Each tool is told the output name WITHOUT a directory, because each one resolves it
# relative to its input rather than to the working directory. Measured, not assumed:
# `quarto render render-checks/x.ipynb --output NAME` writes NAME to the CURRENT
# directory, which silently scatters half the routes into the repo root, and
# `--output-dir` splits the document from its `_files/` sidecar and produces an HTML
# with no stylesheet that every content check still passes. `-M output-file:` is the
# form that keeps a document and its sidecar together.
RC = render-checks

# Every output name carries the tool that produced it. That is not only for
# reading the table: Quarto compiles `check-rmarkdown.Rmd` to an intermediate
# named `check-rmarkdown.pdf` and *then* moves it to --output, so a route named
# after the input alone gets eaten by whichever route runs next.
LATEX_OUT = $(RC)/check-quarto-py-latex.pdf $(RC)/check-quarto-r-latex.pdf \
            $(RC)/check-notebook-quarto-latex.pdf $(RC)/check-rmarkdown-quarto-latex.pdf \
            $(RC)/check-notebook-nbconvert-latex.pdf $(RC)/check-rmarkdown-rmarkdown-latex.pdf \
            $(RC)/check-notebook-table-nbconvert-latex.pdf \
            $(RC)/check-notebook-table-quarto-latex.pdf
TYPST_OUT = $(RC)/check-quarto-py-typst.pdf $(RC)/check-quarto-r-typst.pdf \
            $(RC)/check-notebook-quarto-typst.pdf $(RC)/check-rmarkdown-quarto-typst.pdf
HTML_OUT  = $(RC)/check-quarto-py.html $(RC)/check-quarto-r.html \
            $(RC)/check-notebook-quarto.html $(RC)/check-rmarkdown-quarto.html \
            $(RC)/check-notebook-nbconvert.html $(RC)/check-rmarkdown-rmarkdown.html \
            $(RC)/check-notebook-table-nbconvert.html
WEBPDF_OUT = $(RC)/check-notebook-nbconvert-web.pdf $(RC)/check-notebook-nbconvert-api-web.pdf

# Four documents in three input formats, three renderers, four output formats. Quarto can render every input
# format, so those combinations are all here; nbconvert only reads .ipynb and
# rmarkdown only reads .Rmd, so those have fewer.
pdf: $(LATEX_OUT)  ### Render to PDF through LaTeX

typst: $(TYPST_OUT)  ### Render to PDF through Typst

html: $(HTML_OUT)  ### Render to HTML

# --- Quarto: the .qmd sources, whose output names are set in their own YAML ---
$(RC)/check-quarto-py-latex.pdf $(RC)/check-quarto-py-typst.pdf $(RC)/check-quarto-py.html: $(RC)/check-quarto-py.qmd
	uv run quarto render $< --to $(if $(findstring typst,$@),typst,$(if $(findstring html,$@),html,pdf))

$(RC)/check-quarto-r-latex.pdf $(RC)/check-quarto-r-typst.pdf $(RC)/check-quarto-r.html: $(RC)/check-quarto-r.qmd
	uv run quarto render $< --to $(if $(findstring typst,$@),typst,$(if $(findstring html,$@),html,pdf))

# --- Quarto: the same notebook and R Markdown the other tools render ---------
# Rendering these through Quarto as well is the point: it shows whether Quarto
# handles every input format, and it is the workaround when another tool cannot.
$(RC)/check-notebook-quarto-latex.pdf: $(RC)/check-notebook.ipynb
	uv run quarto render $< --to pdf -M output-file:$(notdir $@)

$(RC)/check-notebook-quarto-typst.pdf: $(RC)/check-notebook.ipynb
	uv run quarto render $< --to typst -M output-file:$(notdir $@)

$(RC)/check-notebook-quarto.html: $(RC)/check-notebook.ipynb
	uv run quarto render $< --to html -M output-file:$(notdir $@)

$(RC)/check-rmarkdown-quarto-latex.pdf: $(RC)/check-rmarkdown.Rmd
	uv run quarto render $< --to pdf -M output-file:$(notdir $@)

$(RC)/check-rmarkdown-quarto-typst.pdf: $(RC)/check-rmarkdown.Rmd
	uv run quarto render $< --to typst -M output-file:$(notdir $@)

$(RC)/check-rmarkdown-quarto.html: $(RC)/check-rmarkdown.Rmd
	uv run quarto render $< --to html -M output-file:$(notdir $@)

# --- nbconvert: the route JupyterLab's export menu uses ----------------------
$(RC)/check-notebook-nbconvert-latex.pdf: $(RC)/check-notebook.ipynb
	uv run jupyter nbconvert $< --to pdf --output $(basename $(notdir $@))

$(RC)/check-notebook-nbconvert.html: $(RC)/check-notebook.ipynb
	uv run jupyter nbconvert $< --to html --output $(basename $(notdir $@))

# --- the markdown table, alone -----------------------------------------------
# One construct, three routes. nbconvert's HTML is fine and Quarto's LaTeX is fine,
# so when the first of these fails it is neither nbconvert nor LaTeX at fault: it is
# nbconvert's LaTeX template. Keeping the table out of check-notebook.ipynb is what
# lets that notebook export from JupyterLab, which is what students are told to do.
$(RC)/check-notebook-table-nbconvert-latex.pdf: $(RC)/check-notebook-table.ipynb
	uv run jupyter nbconvert $< --to pdf --output $(basename $(notdir $@))

$(RC)/check-notebook-table-nbconvert.html: $(RC)/check-notebook-table.ipynb
	uv run jupyter nbconvert $< --to html --output $(basename $(notdir $@))

$(RC)/check-notebook-table-quarto-latex.pdf: $(RC)/check-notebook-table.ipynb
	uv run quarto render $< --to pdf -M output-file:$(notdir $@)

# --- rmarkdown: rendered by R itself -----------------------------------------
$(RC)/check-rmarkdown-rmarkdown-latex.pdf: $(RC)/check-rmarkdown.Rmd
	Rscript -e 'rmarkdown::render("$<", output_format = "pdf_document", output_file = "$(notdir $@)")'

$(RC)/check-rmarkdown-rmarkdown.html: $(RC)/check-rmarkdown.Rmd
	Rscript -e 'rmarkdown::render("$<", output_format = "html_document", output_file = "$(notdir $@)")'

# The LaTeX-free route, rendered by a headless browser rather than TeX.
webpdf: $(WEBPDF_OUT)  ### Render to PDF through a headless browser

# Tried twice. nbconvert loads the page with playwright and waits for "networkidle" with
# a fixed 30-second budget; the notebook pulls MathJax from a CDN, so a slow network makes
# this fail on a machine where nothing is wrong. Seen once on a macOS runner, passing on
# the next run with no change. A route that is actually broken still fails, twice.
$(RC)/check-notebook-nbconvert-web.pdf: $(RC)/check-notebook.ipynb
	uv run jupyter nbconvert $< --to webpdf --output $(basename $(notdir $@)) \
	|| uv run jupyter nbconvert $< --to webpdf --output $(basename $(notdir $@))

# The same export, driven through nbconvert's exporter API rather than its command
# line. The CLI cannot do this on Windows, and this route is here to show that the
# reason is one line in the CLI rather than anything about the platform. Read
# ci/webpdf.py for the mechanism. Retried once for the same network reason.
#
# This is the one recipe that is given a full path rather than $(notdir $@). Unlike
# quarto and nbconvert, which resolve an output name relative to their input, this
# script writes exactly where it is told relative to the working directory -- so it
# takes $@ unchanged.
$(RC)/check-notebook-nbconvert-api-web.pdf: $(RC)/check-notebook.ipynb ci/webpdf.py
	uv run python ci/webpdf.py $< $@ || uv run python ci/webpdf.py $< $@

# ------------------------------------------------------------------ check ----
# Rendering is not the same as rendering correctly: every LaTeX route exits 0
# while silently dropping characters it has no glyph for. This looks inside the
# rendered files instead of at the exit codes.
check:  ## Check the rendered documents actually contain what they should
	uv run python ci/assert-renders.py

matrix:  ### Print the feature-by-route table that is in the README
	uv run python ci/feature-matrix.py

matrix-check:  ### Check the README's table still matches the rendered files
	uv run python ci/check-matrix-block.py

# Documentation drifts silently, which is the failure this project exists to catch, so
# the mechanical half of "keep the docs in sync" is a target rather than a promise.
check-docs:  ### Check the documentation still describes this repository
	uv run python ci/assert-docs.py

# The claims assignment-workflow-uv.md makes about this repo, which course repos are
# copied from. It ran only in CI, so an instructor copying this repository could not
# check the contract they were inheriting without knowing the script by name.
check-contract:  ### Check this repo still matches what the assignment guide describes
	uv run python ci/assert-contract.py

# ------------------------------------------------------------------ clean ----
clean:  ## Delete everything the renders produced
	rm -f $(RC)/check-*.pdf $(RC)/check-*.html
	rm -f $(RC)/*.tex $(RC)/*.knit.md $(RC)/*.quarto_ipynb
	rm -rf $(RC)/.quarto $(RC)/*_files
# The logs are written beside the Makefile, not beside the fixtures, so these two
# lines must NOT gain the prefix: check-setup-mds.sh opens its log in the working
# directory and every per-route error log lands there too.
	rm -f check-setup-mds.log *.log
# Left by a working copy that predates the move. They are gitignored, so nothing else
# would ever remove them, and an `ls` at the root would go on showing render output
# that no longer has anything to do with this build.
	rm -f check-*.pdf check-*.html *.tex *.knit.md *.quarto_ipynb
	rm -rf .quarto *_files
