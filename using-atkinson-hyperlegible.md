# Using Atkinson Hyperlegible in MDS documents

[Atkinson Hyperlegible](https://www.brailleinstitute.org/freefont/) is a typeface
designed so that characters which normally look alike do not: `I l 1`, `O 0`, `rn` and
`m`. Use **Next** for prose and **Mono** for code.

This is **optional**, and needs no new installation: `atkinson` is already in the
`tlmgr` list all three install guides walk students through.

## HTML

Nothing to install; the fonts come from Google Fonts when the page opens.

```yaml
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
```

The `<style>` block does the work -- Quarto's `mainfont` and `monofont` keys are
LaTeX-only, so setting them for HTML changes nothing. Keep the fallbacks after each
font name for readers who are offline or have Google Fonts blocked.

## PDF, through LaTeX

LaTeX embeds the font rather than fetching it, so it has to be installed:

```bash
# Only if you skipped the tlmgr step in the install guide. Driven through R because
# TeX Live ships `tlmgr.bat` on Windows and `tlmgr` everywhere else.
Rscript -e 'tinytex::tlmgr_install("atkinson")'
```

```yaml
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
```

The italic is `RegularItalic`, not `Italic`. Guessing gives a `fontspec` error and no
PDF.

## What it does not change

- **Maths.** Atkinson has no mathematical glyphs, so equations stay in Latin Modern
  Math and will not match the prose. That is the trade, and why this is a choice.
- **Greek and emoji.** Atkinson has neither. Write Greek as maths (`$\alpha$`), which
  is what [the README](README.md) recommends anyway.

Both families are on [Google Fonts](https://fonts.google.com/) and can be installed
locally, after which Positron, RStudio and VS Code will offer them as an editor font.
That changes what you look at while writing, not what your documents render as.
