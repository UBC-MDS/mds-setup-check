# Renders every document in this project to PDF.
#
#   make             render all three documents
#   make clean       delete the rendered files
#   make webpdf      render the notebook without LaTeX, using a headless browser
#   make r-packages  install this project's R packages without rendering anything
#
# This project carries its own packages for both languages, so it does not matter
# what else is installed on the machine:
#
#   Python  uv     installs into .venv       from pyproject.toml and uv.lock
#   R       renv   installs into renv/library from renv.lock
#
# Each Python command is therefore prefixed with `uv run`, and the R rule starts
# by asking renv to make sure the R library matches the lockfile.

.PHONY: all clean webpdf r-packages

all: check-quarto.pdf check-notebook.pdf check-rmarkdown.pdf

# Quarto is the route MDS asks you to use for anything you hand in.
# check-quarto.qmd contains a Python code chunk, so Quarto has to find this
# project's Python and start a kernel in it before it can render the document.
check-quarto.pdf: check-quarto.qmd
	uv run quarto render $< --to pdf

# The same route as JupyterLab's File -> Save and Export Notebook As... -> PDF.
# It goes through pandoc, which comes from your Quarto installation, and LaTeX.
check-notebook.pdf: check-notebook.ipynb
	uv run jupyter nbconvert $< --to pdf

# R Markdown is rendered by R itself. The document asks for xelatex, because the
# pdflatex that R Markdown uses by default cannot typeset accented characters.
# `renv::restore()` runs first so that this works on a machine where rmarkdown was
# never installed globally; when the library already matches renv.lock it is a
# no-op. `prompt = FALSE` keeps it from asking anything.
check-rmarkdown.pdf: check-rmarkdown.Rmd renv.lock
	Rscript -e 'renv::restore(prompt = FALSE); rmarkdown::render("$<", output_format = "pdf_document")'

# Install this project's R packages without rendering anything. Useful on its own
# the first time, since it is the step that can take a while.
r-packages:
	Rscript -e 'renv::restore(prompt = FALSE)'

# Not part of `make all`, because it needs a copy of Chromium that you download
# once with `uv run playwright install chromium`.
webpdf:
	uv run jupyter nbconvert check-notebook.ipynb --to webpdf --output check-notebook-web

clean:
	rm -f check-quarto.pdf check-notebook.pdf check-rmarkdown.pdf check-notebook-web.pdf
	rm -rf .quarto
