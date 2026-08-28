# Everything you need for this assignment. Run `make` on its own to see the list.
#
# R packages are NOT managed per project the way Python ones are. They come from the
# library the MDS install guides set up, so there is no lock file here and `make setup`
# checks rather than installs.

.PHONY: commands setup pdf html all clean

commands:  ## Show this list
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*## "}; {printf "  %-9s %s\n", $$1, $$2}'

setup:  ## Check you have the R packages this lab needs
	@Rscript -e 'miss <- Filter(function(p) !requireNamespace(p, quietly = TRUE), c("ggplot2", "ottr", "testthat")); \
	  if (length(miss)) stop("missing R packages: ", paste(miss, collapse = ", "), \
	  ". Run the MDS setup check, which installs them.") else cat("R packages OK\n")'

# Typst rather than LaTeX, deliberately. Both make a PDF; only Typst keeps emoji and
# pasted Greek letters. Section 7 has the table. RStudio's Knit button takes the LaTeX
# route, which is why it is not what this target does.
#
# knitr always executes the chunks, so unlike the Python lab there is no --execute flag
# to remember: rendering is always a clean run from the top.
pdf: lab0b.pdf  ## Render the PDF you hand in (via Typst)
lab0b.pdf: lab0b.Rmd
	quarto render lab0b.Rmd --to typst

html: lab0b.html  ## Render an HTML copy you can open in a browser
lab0b.html: lab0b.Rmd
	quarto render lab0b.Rmd --to html

all: pdf html  ## Render both, re-running every chunk from a clean start

clean:  ## Delete everything the renders produced
	rm -f lab0b.pdf lab0b.html
	rm -rf .quarto lab0b_files
