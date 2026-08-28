#!/usr/bin/env python3
"""Export a notebook to PDF through a headless browser, without nbconvert's CLI.

`jupyter nbconvert --to webpdf` cannot work on Windows because of one line in
nbconvert's command-line application (NbConvertApp.initialize):

    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

The WebPDF exporter then runs playwright under that policy, and a SelectorEventLoop
cannot start a subprocess, so launching Chromium raises NotImplementedError.

This calls the exporter directly. Nothing else differs, so a PDF here and none from the
CLI attributes the failure to that line. It is NOT a workaround students can use --
JupyterLab's export menu goes through jupyter_server, which sets the same policy.

Usage:  python ci/webpdf.py <notebook.ipynb> <output.pdf>
"""
import pathlib
import sys

import nbformat
from nbconvert.exporters import WebPDFExporter

if len(sys.argv) != 3:
    sys.exit(__doc__)

source, target = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
notebook = nbformat.read(source, as_version=4)
body, _ = WebPDFExporter().from_notebook_node(notebook)
target.write_bytes(body)
print(f"wrote {target}")
