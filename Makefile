# Renders every document in this project to PDF.
#
#   make          render all three documents
#   make clean    delete the rendered files
#   make webpdf   render the notebook without LaTeX, using a headless browser
#
# Each Python command is prefixed with `uv run`, which is what gives it the
# packages belonging to this project. R is not managed by uv, so the R Markdown
# rule calls Rscript directly.

.PHONY: all clean webpdf

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
check-rmarkdown.pdf: check-rmarkdown.Rmd
	Rscript -e 'rmarkdown::render("$<", output_format = "pdf_document")'

# Not part of `make all`, because it needs a copy of Chromium that you download
# once with `uv run playwright install chromium`.
webpdf:
	uv run jupyter nbconvert check-notebook.ipynb --to webpdf --output check-notebook-web

clean:
	rm -f check-quarto.pdf check-notebook.pdf check-rmarkdown.pdf check-notebook-web.pdf
	rm -rf .quarto
