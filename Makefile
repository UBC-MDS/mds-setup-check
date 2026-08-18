# Builds and checks this project.
#
#   make install   install everything this project needs, in both languages
#   make all       render every document by every route
#   make clean     delete everything the renders produced
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

.PHONY: commands all install clean pdf typst html webpdf

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
all: pdf typst html webpdf  ## Render every document by every route

pdf: check-quarto.pdf check-notebook.pdf check-rmarkdown.pdf  ## Render to PDF through LaTeX
typst: check-quarto-typst.pdf  ## Render to PDF through Typst, which handles emoji and Greek
html: check-quarto.html check-notebook.html check-rmarkdown.html  ## Render to HTML

# Quarto is the route MDS asks you to use for anything you hand in.
# check-quarto.qmd contains a Python code chunk, so Quarto has to find this
# project's Python and start a kernel in it before it can render the document.
check-quarto.pdf: check-quarto.qmd
	uv run quarto render $< --to pdf

check-quarto.html: check-quarto.qmd
	uv run quarto render $< --to html

# Typst is Quarto's other PDF engine. It needs no LaTeX at all, and unlike the
# LaTeX route it reproduces emoji, literal Greek letters and symbols.
check-quarto-typst.pdf: check-quarto.qmd
	uv run quarto render $< --to typst --output check-quarto-typst.pdf

# The same route as JupyterLab's File -> Save and Export Notebook As... -> PDF.
# It goes through pandoc and LaTeX.
check-notebook.pdf: check-notebook.ipynb
	uv run jupyter nbconvert $< --to pdf

check-notebook.html: check-notebook.ipynb
	uv run jupyter nbconvert $< --to html

# R Markdown is rendered by R itself. The document asks for xelatex, because the
# pdflatex that R Markdown uses by default cannot typeset accented characters.
check-rmarkdown.pdf: check-rmarkdown.Rmd
	Rscript -e 'rmarkdown::render("$<", output_format = "pdf_document")'

check-rmarkdown.html: check-rmarkdown.Rmd
	Rscript -e 'rmarkdown::render("$<", output_format = "html_document")'

# The LaTeX-free route, rendered by a headless browser rather than TeX. It is the
# only PDF route that reproduces emoji, literal Greek letters and symbols such as
# the check and cross marks, so it is the one to use for a document that contains
# them. Needs the Chromium that `make install` downloads.
webpdf: check-notebook.ipynb  ## Render to PDF through a headless browser
	uv run jupyter nbconvert $< --to webpdf --output check-notebook-web

# ------------------------------------------------------------------ clean ----
clean:  ## Delete everything the renders produced
	rm -f check-quarto.pdf check-notebook.pdf check-rmarkdown.pdf
	rm -f check-quarto-typst.pdf
	rm -f check-quarto.html check-notebook.html check-rmarkdown.html
	rm -f check-notebook-web.pdf
	rm -f check-setup-mds.log *.log
	rm -f *.tex *.knit.md *.quarto_ipynb
	rm -rf .quarto check-quarto_files check-notebook_files check-rmarkdown_files
