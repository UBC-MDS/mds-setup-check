#!/usr/bin/env python3
"""Export a notebook to PDF through a headless browser, without nbconvert's CLI.

`jupyter nbconvert --to webpdf` cannot work on Windows, and the reason is not the
platform, playwright, or the browser. It is one line in nbconvert's own
command-line application (`nbconvertapp.py`, NbConvertApp.initialize):

    if sys.platform.startswith("win"):
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

That is there for tornado and pyzmq. But the WebPDF exporter runs its playwright
session with `pool.submit(asyncio.run, ...)`, which picks up that global policy and
so gets a SelectorEventLoop -- the one Windows event loop that cannot start a
subprocess. Playwright needs a subprocess to launch Chromium, so it reaches
BaseEventLoop._make_subprocess_transport and raises NotImplementedError.

This script calls the exporter directly. Nothing else differs, so if it produces a
PDF on Windows while the CLI does not, the line above is the whole difference.

It is NOT a workaround students can use: JupyterLab's own export menu goes through
jupyter_server, which sets the same policy (serverapp.py, init_event_loop). So the
route students actually reach stays broken on Windows either way, and the guides
still tell them to use Typst there. This exists to keep the cause attributable, and
to notice the day an upstream fix lands.

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
