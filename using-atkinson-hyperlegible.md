# Using Atkinson Hyperlegible in MDS documents

[Atkinson Hyperlegible](https://www.brailleinstitute.org/freefont/) is a typeface
from the Braille Institute, designed so that characters which normally look alike
do not: `I l 1`, `O 0`, `rn` and `m`. That matters more than usual in a program
where you read other people's code and your own output all day.

Using it is **optional**: a document that does not ask for it renders exactly as
before. The font itself is already there, though — `atkinson` is in
`ci/tlmgr-packages.txt` and in the `tlmgr` list all three install guides walk students
through, so nothing below needs a new installation on the LaTeX side. Everything
below is a recipe you can copy into an assignment, a course template, or your own
notes.

There are two families, and they do different jobs:

| family | use for |
| --- | --- |
| Atkinson Hyperlegible **Next** | prose |
| Atkinson Hyperlegible **Mono** | code |

---

## HTML

Nothing to install: the fonts come from Google Fonts when the page is opened.

```yaml
---
format:
  html:
    include-in-header:
      text: |
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Next:ital,wght@0,200..800;1,200..800&family=Atkinson+Hyperlegible+Mono:ital,wght@0,200..800;1,200..800&display=swap">
        <style>
          body { font-family: "Atkinson Hyperlegible Next", system-ui, sans-serif; }
          code, pre, kbd, samp { font-family: "Atkinson Hyperlegible Mono", ui-monospace, monospace; }
        </style>
---
```

The `<style>` block is doing the work. Quarto's `mainfont` and `monofont` keys are
LaTeX-only — setting them for an HTML format links nothing and changes nothing,
which is easy to miss because the document still renders.

The fallbacks after each font name matter: `system-ui` and `ui-monospace` are what
a reader gets if they are offline or Google Fonts is blocked.

## PDF, through LaTeX

This one needs the font installed, because LaTeX embeds it rather than fetching it:

```bash
# Only needed if you skipped the tlmgr step in the install guide. Driven through R
# because TeX Live ships `tlmgr.bat` on Windows and `tlmgr` everywhere else, so the
# bare command is not found there.
Rscript -e 'tinytex::tlmgr_install("atkinson")'
```

```yaml
---
format:
  pdf:
    mainfont: "AtkinsonHyperlegibleNext-Regular.otf"
    mainfontoptions:
      - BoldFont=AtkinsonHyperlegibleNext-Bold.otf
      - ItalicFont=AtkinsonHyperlegibleNext-RegularItalic.otf
      - BoldItalicFont=AtkinsonHyperlegibleNext-BoldItalic.otf
    monofont: "AtkinsonHyperlegibleMono-Regular.otf"
    monofontoptions:
      - BoldFont=AtkinsonHyperlegibleMono-Bold.otf
      - ItalicFont=AtkinsonHyperlegibleMono-RegularItalic.otf
---
```

The italic is `RegularItalic`, not `Italic`. Guessing the obvious name gives a
`fontspec` error and no PDF.

## What it does not change

**Mathematics.** Atkinson has no mathematical glyphs, so equations continue to be
set in Latin Modern Math. Prose and equations therefore do not match visually,
which is more noticeable with a sans-serif body font than with the default serif.
That is the trade, and it is why this is a choice rather than a default.

**Greek letters.** Atkinson has no Greek either — 347 glyphs, no `α β γ`. This
does not matter as long as Greek is written as maths (`$\alpha$`), which is what
[the README](README.md) recommends anyway and what works in every route. It does
mean Atkinson cannot rescue literal Greek in a LaTeX PDF.

**Emoji.** Unchanged, and still absent from LaTeX PDFs. No text font supplies them.

## Using it in an editor

Both families are on [Google Fonts](https://fonts.google.com/) and can be
downloaded and installed like any other font, after which Positron, RStudio and
VS Code will offer them in the editor font setting. That is independent of
anything above — it changes what you look at while writing, not what your
documents render as.
