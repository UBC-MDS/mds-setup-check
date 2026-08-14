# mds-setup-check

A small Python project used to verify a UBC Master of Data Science software
stack installation. It is referenced from the MDS installation guides:

- [macOS](https://ubc-mds.github.io/resources_pages/install_ds_stack_mac)
- [Ubuntu](https://ubc-mds.github.io/resources_pages/install_ds_stack_ubuntu)
- [Windows](https://ubc-mds.github.io/resources_pages/install_ds_stack_windows)

## For students

Clone it into your home folder, so that the setup check script can find it
later:

```bash
cd ~
git clone https://github.com/UBC-MDS/mds-setup-check.git
cd mds-setup-check
uv sync
```

`uv sync` creates a `.venv` folder inside this project and installs the exact
package versions recorded in `uv.lock`. Every student in the cohort therefore
gets an identical environment.

From then on, every Python command you run for this project starts with
`uv run`:

```bash
uv run python --version
uv run jupyter lab
```

**Keep this folder until you have submitted your setup check log.** The
`check-setup-mds.sh` script looks for it at `~/mds-setup-check`.

## What is in here

| file | what it is for |
| --- | --- |
| `pyproject.toml` | the list of packages the MDS stack needs |
| `uv.lock` | the exact resolved versions, so everybody gets the same ones |
| `.python-version` | the Python version this project runs on |
| `setup-check.qmd` | Quarto fixture — has a Python code chunk, so rendering it to PDF proves Quarto can find and run this project's Python |
| `setup-check.ipynb` | Jupyter notebook fixture — used for the JupyterLab PDF and WebPDF export checks |

## For instructors

This project doubles as the reference shape for an MDS assignment repo. See
the assignment workflow document for what a course repo should declare and
why `uv.lock` is committed.

Two things are deliberate and should be preserved if this file is copied:

- `ipykernel` is a real dependency, not a dev dependency. `jupyterlab` would
  pull it in anyway, but an autograding image built with `uv sync --no-dev`
  would then have no Python kernel at all.
- `nbconvert[webpdf]` is named explicitly. `otter-grader` already requires it,
  but naming it records that MDS depends on WebPDF export directly.
