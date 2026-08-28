# Builds and checks this project. `make install`, then `make all`, then `make check`.
#
# Four output routes, which do not handle the same characters:
#
#   pdf     LaTeX      accents and maths yes; literal Greek and emoji NO
#   typst   Typst      everything, and no LaTeX involved
#   html    pandoc     everything
#   webpdf  Chromium   everything, needs the browser `make install` downloads
#
# Packages are carried per language -- uv into .venv, renv into renv/library -- so
# every Python command is prefixed with `uv run`.

.PHONY: commands all render install clean check check-docs check-contract matrix matrix-check pdf typst html webpdf

# First, so a bare `make` prints this list rather than doing work. Built from the `##`
# comments below, so it cannot go stale. grep -E, sort and awk are in Git Bash too.
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
# Chromium is a one-time download for the WebPDF route.
install:  ## Install the Python and R packages, and the browser for webpdf
	uv sync
	uv run playwright install chromium
	Rscript -e 'renv::restore(prompt = FALSE)'

# -------------------------------------------------------------------- all ----
# A recipe rather than prerequisites, so -k is part of the target rather than
# something to remember. One route is known not to work, and a bare `make` would stop
# there leaving every later route unrendered. The exit code is ignored for the same
# reason: `make check` is the only thing that knows which failures are expected.
all:  ## Render every document by every route
	@$(MAKE) -k render || true
	@echo
	@echo 'Rendering finished. Now run `make check` to find out whether the results'
	@echo 'are correct -- rendering without errors is not the same as rendering right.'

render: pdf typst html webpdf  ### Render, without the keep-going wrapper (used by CI)

# Each tool is told an output name WITHOUT a directory, because each resolves it
# relative to its INPUT. Measured, not assumed: `--output NAME` writes to the current
# directory, and `--output-dir` splits a document from its `_files/` sidecar and yields
# a stylesheet-less HTML that every content check still passes. `-M output-file:` works.
RC = render-checks

# Every output name carries the tool that produced it: Quarto compiles to an
# intermediate named after the INPUT and then moves it, so a route named after its
# input alone gets eaten by whichever route runs next.
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

# Quarto reads every input format, so it has the most combinations; nbconvert reads
# only .ipynb and rmarkdown only .Rmd.
pdf: $(LATEX_OUT)  ### Render to PDF through LaTeX

typst: $(TYPST_OUT)  ### Render to PDF through Typst

html: $(HTML_OUT)  ### Render to HTML

# --- Quarto: the .qmd sources, whose output names are set in their own YAML ---
$(RC)/check-quarto-py-latex.pdf $(RC)/check-quarto-py-typst.pdf $(RC)/check-quarto-py.html: $(RC)/check-quarto-py.qmd
	uv run quarto render $< --to $(if $(findstring typst,$@),typst,$(if $(findstring html,$@),html,pdf))

$(RC)/check-quarto-r-latex.pdf $(RC)/check-quarto-r-typst.pdf $(RC)/check-quarto-r.html: $(RC)/check-quarto-r.qmd
	uv run quarto render $< --to $(if $(findstring typst,$@),typst,$(if $(findstring html,$@),html,pdf))

# --- Quarto: the same notebook and R Markdown the other tools render ---------
# Quarto is the workaround when another tool cannot handle an input format.
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
# One construct, three routes: nbconvert's HTML is fine and Quarto's LaTeX is fine, so
# a failure of the first is nbconvert's LaTeX template. Keeping the table out of
# check-notebook.ipynb is what lets that notebook export from JupyterLab.
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

# Tried twice: nbconvert waits for "networkidle" on a fixed 30-second budget and the
# notebook pulls MathJax from a CDN, so a slow network fails a healthy machine. A route
# that is actually broken still fails, twice.
$(RC)/check-notebook-nbconvert-web.pdf: $(RC)/check-notebook.ipynb
	uv run jupyter nbconvert $< --to webpdf --output $(basename $(notdir $@)) \
	|| uv run jupyter nbconvert $< --to webpdf --output $(basename $(notdir $@))

# The same export through nbconvert's exporter API rather than its command line, which
# shows the Windows failure is one line in the CLI rather than the platform. The one
# recipe given a full path: ci/webpdf.py writes where it is told, not relative to input.
$(RC)/check-notebook-nbconvert-api-web.pdf: $(RC)/check-notebook.ipynb ci/webpdf.py
	uv run python ci/webpdf.py $< $@ || uv run python ci/webpdf.py $< $@

# ------------------------------------------------------------------ check ----
# Every LaTeX route exits 0 while silently dropping characters it has no glyph for, so
# this looks inside the rendered files rather than at exit codes.
check:  ## Check the rendered documents actually contain what they should
	uv run python ci/assert-renders.py

matrix:  ### Print the feature-by-route table for docs/render-matrix.md
	uv run python ci/feature-matrix.py

matrix-check:  ### Check docs/render-matrix.md still matches the rendered files
	uv run python ci/check-matrix-block.py

check-docs:  ### Check the documentation still describes this repository
	uv run python ci/assert-docs.py

# The claims docs/assignment-workflow-uv.md makes about this repo, which course repos are
# copied from.
check-contract:  ### Check this repo still matches what the assignment guide describes
	uv run python ci/assert-contract.py

# ------------------------------------------------------------------ clean ----
clean:  ## Delete everything the renders produced
	rm -f $(RC)/check-*.pdf $(RC)/check-*.html
	rm -f $(RC)/*.tex $(RC)/*.knit.md $(RC)/*.quarto_ipynb
	rm -rf $(RC)/.quarto $(RC)/*_files
# The logs are written beside the Makefile, not the fixtures, so these two lines must
# NOT gain the $(RC) prefix.
	rm -f check-setup-mds.log *.log
# Left by a working copy that predates the move to render-checks/. Gitignored, so
# nothing else would ever remove them.
	rm -f check-*.pdf check-*.html *.tex *.knit.md *.quarto_ipynb
	rm -rf .quarto *_files
