# Testing the MDS install instructions

**Status:** revised after council round 6 · **Written:** 2026-08-15 · **Merge target:** 2026-08-27
**Students install before:** ~2026-09-05

> **Why the review stopped at six rounds, and it wasn't because findings ran out.** Every
> round produced material findings, and round 6 produced the most severe one in the whole
> review (`curl` absent from Ubuntu Desktop). But the triage seat identified the top risk to
> this effort as *"the branch does not merge in time, because the finding list keeps growing
> against it"* — and at that point further review has **negative** expected value, because
> every new finding is an edit to the branch that has to ship. The remaining unexplored
> surface also needs hardware this review did not have: a Windows box, an Ubuntu desktop, and
> a clean Mac. **Two colleagues doing a cold install from the merged docs is worth more than
> a seventh round**, and it is the only thing that would exercise the Windows `msys` branch,
> which still has zero execution coverage.

## What was asked, and what we found

The ask was GitHub Actions that script and test the UBC MDS install instructions. That
design is in [The CI design](#the-ci-design) and it stands.

But four rounds of review — the last two of which *ran* things rather than reading them —
turned up defects in the live student-facing material that no CI would have fixed, and that
outrank building the CI. Every one of them produces a **green result while being broken**,
which is the same failure mode the CI exists to catch. That is the argument for building it,
and a stronger argument that it must assert on **content**, not exit codes.

Terminology used throughout, because the subject is a checker's verdicts:
**false OK** = wrongly accepts. **false MISSING** = wrongly alarms.

## The governing constraint: the merge date

**The single largest risk in this plan is that the branch does not merge in time, because
the finding list keeps growing against it.** Every doc finding here is an edit to the one
branch that has to merge; each "we should fix this first" pushes it later. If it merges
Sept 3 instead of Aug 27 there is no slack to discover the merge itself broke something —
and the fallback is 100 arriving students reading 2025 conda-era instructions. **That
outcome is worse than every defect in this document combined**, and unrelated to any of them.

Cheapest mitigation, and it costs one sentence in the PR description:

> After Aug 22, the only changes that go on this branch are ones that break a student's
> install. Everything else lands on `main` after the merge.

**Pick Aug 27, merge on the 27th even if items are unfinished** — every item below except
the two in this repo is a doc edit that can equally well be made on `main` afterwards.

## Do this today

Ordered by dependency. Items 1-4 are edits to the website repo on `2026-27/install_update`;
item 6 is in this repo.

| # | Do | Why | Done when |
|---|---|---|---|
| 1 | **Rotate `GITHUB_PAT`, `GITHUB_TOKEN`, `YOUTRACK_TOKEN`** | They are in plaintext in `~/mds-setup-check/check-setup-mds.log` | New tokens issued; old ones revoked |
| 2 | **Commit the 19 fence retags** (already applied, uncommitted) + add `# CI-SKIP:` for `ubuntu:1000` | Uncommitted work does not merge in item 5 | `git status` clean on those two files |
| 3 | **Drop or allowlist the `env` dump** (`check-setup-mds.sh:467`); read `~/.zshrc`/`~/.zprofile`/`~/.zshenv` too. **Keep an explicit `$SHELL` line** — see below | Students are told to *send* this log; the bash pair is dead on macOS | A fresh log contains no `ghp_`/`perm-`; contains zsh config **and `$SHELL`** |
| 4 | **Quote `"${sys_progs[@]}"`** (`:197`) — the glob bug only. **Do NOT anchor the regexes yet** — see below | One character; removes the pathname-expansion defect | `R=4.txt` in cwd no longer rewrites the check |
| 4a | **`sudo apt install git curl`** at `ubu:198`, and add `libgit2-dev libuv1-dev` to `ubu:758` | **`curl` is absent from Ubuntu Desktop** (verified: 1,819/1,828 packages, curl in neither), so uv never installs and the doc misdiagnoses it; `fs`'s configure hard-fails without libuv | A stock-desktop Ubuntu install reaches `uv --version` successfully |
| 5 | **Add `--include-verbatim` to `link-check.yml`** | Covers all 13 in-fence URLs | Next run reports the `check-python-installs.sh` 404 |
| 6 | **Merge `2026-27/install_update`** | Nothing else is testable until the live scripts stop being the 2025 conda-era ones | `check-python-installs.sh` returns 200 |

Item 5 goes **before** item 6 deliberately: run against the live 404 and it proves the
mechanism; run after the merge and it proves nothing until the next regression.

> **The regex anchoring is deferred to October. It is not a 30-minute job.**
>
> The script uses **one regex for both the match and the display**. Verified:
>
> ```
> "R version 4.6.1 (2026-06-24) …"   grep -Eio '4.*'          → OK  R 4.6.1 (2026-06-24) …
> "R version 4.6.1 (2026-06-24) …"   grep -Eio '^R version 4\.' → OK  R R version 4.
> "GNU Make 4.4.1"                   grep -Eio '^GNU Make 4\.'  → OK  make GNU Make 4.
> ```
>
> **Anchoring deletes the version number from the log instructors read to diagnose
> students.** So the real change set is: ten regexes, *plus* decoupling match-regex from
> display-regex, *plus* `tr -d '\r'`, *plus* a no-`$`-anchor rule, *plus* replacing the macOS
> `bash` entry with a login-shell check, *plus* the R architecture check — *plus* ~13 lines
> regenerated in **each of three sample-output blocks** (`mac:1192`, `ubu:1167`, `win:1376`),
> which are transcripts of a program's output on three operating systems. Hand-writing those
> is the exact defect class this project exists to remove. **Correctly sized only after a
> Windows CI job can generate the transcript.** 6-10 hours, not 30 minutes.
>
> Every false OK in that table is also caught louder and sooner by a behavioural check in the
> same log: R 3.4.4 passes `R=4.*` and then fails renv and pak visibly; pandoc 2.3 passes and
> then fails all four PDF checks; quarto 2.0.1 does not exist. The two that aren't —
> docker and psql — gate courses starting in November.
>
> **When you do it, these two traps apply:**
>
> **Windows.** Every native Windows program emits CRLF and nothing strips it:
> `"GNU Make 4.4.1\r"` matches `^GNU Make 4\.` but **not** `^GNU Make [0-9.]+$`.
> Start-anchored patterns survive; **any `$` anchor becomes a Windows-only false MISSING the
> day the fix ships.** Add `tr -d '\r'` inside `:213`/`:219`, and adopt the rule that no
> `sys_progs` regex may anchor at `$`. The same stray CR currently lands in ~13 `OK` lines
> of the log students submit.
>
> **macOS.** Anchoring `bash=3.*` to `^GNU bash, version 3\.` **rejects a Homebrew bash 5** —
> a student with a *better* bash than macOS ships would be told they are misconfigured. The
> entry is measuring the wrong thing anyway: it runs `bash --version` through `PATH`, not the
> login shell. **Replace the `bash` entry with a login-shell check** (`$SHELL` / `ps -p $$`)
> rather than anchoring it. That also gives item 3 the `$SHELL` line it needs.
>
> **Also add an architecture check while you are in here** (see the macOS section): `:213`
> reads only `head -1` of `R --version`, and `Platform: aarch64-apple-darwin20` is line 3.

Cheap wins in the same editing pass as items 3-4, all in `check-setup-mds.sh`:
**preserve the render error logs on success** (see [the diagnostics defect](#the-diagnostics-point-the-wrong-way)),
give the rmarkdown branches a dump section instead of `/dev/null`, strip ANSI escapes from
the log, and stop blaming the student's network for a server-side 404.

**Blocked on a decision from Dan** (see [Open decisions](#open-decisions-and-owners)): the
fixture font fix. It is not in the list above because it needs an answer first.

## What execution found

### The check log harvests every secret in the student's environment

`check-setup-mds.sh:467-468` appends `env` verbatim to `check-setup-mds.log`, **and the
workflow is built around students sending that file to instructors.**

Verified by running it. A canary landed as expected — and so did four live credentials
already in the environment. A log written 2026-08-14 sits at
`~/mds-setup-check/check-setup-mds.log` with `GITHUB_PAT`/`GITHUB_TOKEN` (2 lines, `ghp_`)
and `YOUTRACK_TOKEN` (1 line, `perm-`).

Three aggravating factors visible only by running it:

1. **Students never see the section.** stdout ends at `:432`; the env block is appended at
   `:467` and never `tee`d. The warning at `:518` asks students to audit for "passwords or
   access tokens" in a section they were never shown.
2. **The shell config it exists to capture is dead on macOS.** Both `~/.bash_profile` and
   `~/.bashrc` reported "not found" — macOS has defaulted to zsh since 2019. So on
   essentially every Mac student it captures **every secret and none of the config it
   wanted.** The trade is exactly backwards.
3. It is the one finding here that is urgent independent of the September deadline.

### The checker can't fail, and its version checks don't check versions

**Exit code 0 with 8 MISSING, and exit code 0 with 13 MISSING.** No `exit` anywhere, no
`set -e`. CI must grep `^MISSING`.

Nine of thirteen `sys_progs` entries are unanchored substring tests. Verified by executing
`grep -Ei` against real version strings:

```
R version 2.14.0 (2011-10-31)           vs R=4.*          → false OK  (the "4." in 14.0)
R version 3.4.4 (2018-03-15)            vs R=4.*          → false OK
Docker version 24.0.9, build 2936816    vs docker=2[89].* → false OK  (the "29" in the hash)
git version 1.9.2                       vs git=2.*        → false OK
quarto 2.0.1                            vs quarto=1.*     → false OK
GNU Make 3.82.94                        vs make=4.*       → false OK
pandoc 2.3                              vs pandoc=3.*     → false OK
pdfTeX 3.1415926-1.40.9 (Web2C 7.5.7)   vs latex=3.*      → false OK  (π, not a version)
```

**The ten to fix, by name:** `latex`, `tlmgr`, `R`, `git`, `make`, `pandoc`, `quarto`,
macOS-only `bash=3.*`, and `docker` (broken differently — it matches build hashes); plus
`psql`, which is weak rather than tautological (accepts 13.16). Sound and to be left alone:
`uv`, `positron`, `rstudio`.

**Correction:** Linux/Windows `bash=5.*` is **not** sound — `GNU bash, version 4.2.25(1)`
false-OKs, capturing `5(1)-release` from the suffix. Verified. No supported Ubuntu is
affected, so severity is nil, but it matters because the audit's `must_reject` design would
otherwise bless it permanently. Eleven unanchored regexes, not nine — and three sound ones,
not four.

The fix is anchoring and escaping — `^R version 4\.`, `^GNU Make 4\.`,
`^Docker version (28|29)\.` — verified per program against its real first line, since the
formats differ.

Same line, separate one-character defect: **`${sys_progs[@]}` at `:197` is unquoted**, so
the regexes glob-expand against the student's working directory. It is latent — it fires
only when matching files exist — but demonstrated: with `R=4.txt`, `latex=3.pdf` and
`docker=28.log` present, the checks silently *become those filenames*.

The greediness also corrupts what students read — `OK  R 4.5.3 (2026-03-11) -- "Reassured
Reassurer"` — and `MISSING` lines leak raw regex: `MISSING latex=3.*`.

**Consequence for the audit:** fixing these today means the audit ships in Week 3 already
green on all ten. Its value is then purely *regression* protection, which is what the
negative controls provide.

### The diagnostics point the wrong way

On a machine with TinyTeX installed but not on `PATH`, the log says `MISSING latex=3.*` and
`OK  quarto PDF-generation was successful.` **twelve lines apart** — because knitr/tinytex
and Quarto resolve the engine through `tinytex_root()`, never `PATH`. A student cannot
reconcile those two lines, and `:310` deletes the only file that could: 45 lines naming
`LuaHBTeX, Version 1.24.0 (TeX Live 2026)` and `Output created: check-quarto.pdf`.

**The rule: preserve the render logs on success. Do not gate deletion on a zero-MISSING
run** — the Greek-character bug below produces a clean, zero-MISSING run *and* a warning
worth keeping, so a zero-MISSING gate destroys exactly the evidence that matters. Delete
never, or only under an explicit `MDS_CI=1`.

The rmarkdown branches (`:409`, `:417`) send both streams to `/dev/null`, so they have no
dump section at all, and their advice ("check that latex is marked OK above") actively
misleads on the machine just described.

macOS-specific: `find_pandoc` selects by **highest version, not list order**, and probes an
**x86_64 pandoc under Rosetta** on Apple Silicon. The log is written with raw ANSI escapes,
which render as garbage in the editor students are told to open it in.

Reads right *and* measures right: the neutral-directory defence at `:370` is load-bearing —
inside the project renv narrows R to 55 packages; from the neutral dir there are 357.

### The fixtures pass while broken

Found by executing the fixtures, then verified independently at byte level:

```
source:    Montréal · naïve · Öl · 5 °C · α β γ · 10 – 20 · "curly quotes"
rendered:  ef bf bd ×3  where α β γ should be   →  U+FFFD REPLACEMENT CHARACTER
```

`é Ö ° – " "` survive. **Only the Greek is destroyed, and every engine exits 0.** True of
all three LaTeX routes. The only route that renders Greek is `make webpdf`, which uses
Chromium and no LaTeX — while the fixture text claims "your LaTeX installation can typeset
them".

`README.md:62-64` — "opening the PDFs also tells you whether LaTeX has the fonts it needs" —
is therefore **false**. And the originally-specced Week-1 check ("three PDFs as artifacts")
is **green today with the bug present**. A PDF artifact nobody opens is not a check.

**Root cause: the font, not the engine or template.** Latin Modern Roman, the `fontspec`
default under both engines, has no Greek in text mode. The warning names it on all three
routes: `Missing character: There is no α (U+03B1) in font [lmroman10-regular]`.

**Fix: `newcomputermodern` via `mainfont`/`monofont`.** NewCM is the Computer Modern
successor, so it is visually indistinguishable from Latin Modern — zero visual change, no
`\catcode` hackery, supported YAML only. Verified byte-level on all three routes:
`pdftotext … | grep -o 'α β γ' | xxd -p` → `ceb120ceb220ceb30a`.

Two traps found by experiment. **`\setmainfont{TeX Gyre Termes}` by family name works under
lualatex and hard-fails under xelatex** (luaotfload indexes the TEXMF tree; XeTeX uses the OS
font DB) — so font specs must be **filename-based**. And a math-mode fallback silently
substitutes a *different character*: `\ensuremath{\alpha}` extracts as U+1D6FC MATHEMATICAL
ITALIC SMALL ALPHA, which looks Greek and isn't.

**nbconvert needs a raw cell, and the tag matters.** Measured: `text/latex` is emitted by
`--to latex` and **silently dropped by `--to pdf`** (plausibly an upstream bug worth
filing); untagged works for PDF but **leaks visible LaTeX source into `make webpdf``;
`application/pdf` is included by `--to pdf`, excluded from webpdf, zero leakage. Use
`application/pdf`.

**Fix the fonts — do not change the fixture text.** The decisive evidence is not the fixture
line:

```
math mode $\alpha$:              𝛼 = 0.05     ← works today
literal Greek in prose:          � = 0.05     ← broken
DataFrame column named "α":      �   0.05     ← broken, in source AND output
verbatim block:                  alpha=�      ← broken
```

**A student who names a column `α` gets silent corruption in submitted work.** Changing the
fixture text would delete the evidence of a live defect. The honest nuance: statistics is
normally written in math mode, and math mode already works — so the fixtures should keep
literal Greek *and* gain a math-mode line, which is free and passes today.

> **Load-bearing and NOT verified here.** The claim that `tinytex::install_tinytex()`
> installs the 95-package `TinyTeX-1` bundle whose only text font is `lm` — i.e. that a
> stock student machine has **no** Greek-capable text font — was reported from upstream by
> one reviewer and could not be re-fetched in a later session. This machine has the larger
> `pkgs-yihui` set, so it cannot settle it. **Everything downstream depends on it**: the
> 22nd `tlmgr` package, the 22 MB, and the product decision below. Settle it first
> (Week 1, below) — install TinyTeX-1 in a clean container and render one fixture.

### Windows: the worst defects are six lines of PATH manipulation

The `msys` branch is ~60 lines of Windows-only code with **zero execution coverage**, and it
decides what a third of the cohort is told about their machine. *(Everything here is read or
verified against upstream/local shell tests — no Windows machine was available.)*

Four things expected to be wrong are **right**, and are settled: **Rtools 4.5 is correct**
(CRAN: "for R versions from 4.5.0", "to become R 4.7.0" — so it holds past this program
year); the RStudio probe path `/c/Program Files/RStudio/rstudio` is correct (the installer
registers the exe at the install *root*, not `bin\`); the Docker build gates are exactly
Docker's stated minimums; and uv's shell installer genuinely supports Git Bash.

The real damage is concentrated in `windows:830` and `windows:1017`:

1. **`R_DIR=(…)` is an array, so `"$R_DIR"` is `${R_DIR[0]}` — the *oldest* R.** Verified
   locally: with 4.5.3 and 4.6.1 present, `$R_DIR` resolves to **4.5.3**. R's installer
   defaults to a new versioned directory on every upgrade, so having two versions is the
   **default outcome, not an edge case** — and it gets more likely as the year progresses.
   Silent; `R=4.*` cannot catch it.
2. **The glob has no failure path.** Non-admin installs go to `%LOCALAPPDATA%\Programs`
   (CRAN, since R 4.2.0). No match → bash leaves the literal pattern on `PATH` →
   `R: command not found`, with no diagnostic anywhere in the doc.
3. **The `make` PATH edit can delete the `R_DIR` assignment.** `windows:1004` says "replace
   the section that reads:" and shows only the two `# Add R…` lines. A student who reads
   "the section" as the whole block produces an **empty PATH element, which POSIX treats as
   the current directory** — `make` works, R breaks, `.` is silently on PATH. `make` then
   fails at its *third* target with `Rscript: command not found`, **inside the LaTeX
   section**, which the doc tells them to read as a render failure.

All three are silent, all three surface somewhere else entirely, and all three get more
likely over the year. The reputation that "students get this step wrong" is misplaced: **the
step is wrong and the students are following it correctly.**

**The `.libPaths()` parity gate is vacuous where it stands.** It carries the doc's strongest
language — "Do not continue unless…" — but sits at `:882`, *before* `install.packages` at
`:922`. At that point `%LOCALAPPDATA%\R\win-library\4.6` does not exist, so R drops it and
both sides return a single element: the gate passes for everyone, and **the two-element
sample output the doc prints at `:889-890` cannot occur at that point in the instructions.**
It is also aimed at the wrong quantity: since R 4.2.0 the personal library derives from
`LOCALAPPDATA`, which is identical in both processes by construction. The divergence it was
written for is real and CRAN documents it — MSYS2 sets `HOME`, so `~` differs by exactly
`\Documents` — but that shows up in `~`, `.Renviron` and `.Rprofile`, not `.libPaths()`.
Fix it, don't delete it: move it after `install.packages`, or rewrite it to compare
`Sys.getenv("R_USER")` and `normalizePath("~")`. Also missing: no instruction to **restart
RStudio** after setting the env var, though RStudio was opened 16 lines earlier.

Open question only a Windows run can settle: **what does `mktemp -d` become when handed to a
native `.exe`?** `:293`, `:370`, `:399` do exactly that, and the answer is either a path
under `Program Files` (a space for everyone) or under `AppData\Local\Temp` (a space only for
spaced usernames). TeX with spaces in paths is a classic failure, and this gates all four
PDF checks. One line settles it: `cygpath -w "$(mktemp -d)"`.

One encouraging signal: the sample check output at `windows:1371-1389` is internally
consistent with the script's real behaviour **including its bugs** — `OK R 4.6.1 (2026-06-24)
-- "Happy Hop"` is exactly what the greedy `grep -Eio "4.*"` produces. Nobody invents that.
Someone did run this on Windows.

### Ubuntu: right code, on a machine the docs assume and Ubuntu doesn't ship

Ubuntu is the doc in the best shape — **every claim it makes about its own platform verified
correct**: the 26.04 codename and its live `resolute-cran40` suite, the Software & Updates
removal, PostgreSQL 16-vs-18 by release, the RStudio deb reuse, the CRAN lines being
byte-identical to what CRAN publishes, and the log-out-before-`latex` step (right, and for
the right reason). Someone checked these. No pinning is needed after adding CRAN on either
release — that hypothesis is dead, recorded so nobody re-runs it.

The defects are all one shape, and it is a different shape from the other two platforms:
**Windows had wrong code; macOS had verifications that verify nothing; Ubuntu has right code
executed on a machine that lacks a silent prerequisite.**

**`curl` is not installed on Ubuntu Desktop.** Verified against Canonical's own ISO
manifests: 24.04.3 has 1,819 packages and 26.04 has 1,828, and **`curl` is in neither**.
`wget` is in both; only `libcurl4t64` (the library) is present. Ubuntu *Server* does ship
curl — so this is precisely the configuration MDS students install. The doc's only
apt-installed program is `git` (`ubu:197-198`). Then five commands quietly do nothing:

| Line | What a student gets |
|---|---|
| `ubu:384` `curl -LsSf …astral.sh/uv/install.sh \| sh` | **uv never installs.** `sh` reads empty stdin and exits 0 |
| `ubu:362`, `ubu:1138` `bash <(curl …)` | silent no-op, exit 0 |
| `ubu:1043`, `ubu:1118` | git-prompt and `mds-help` never arrive |

Both mechanisms verified: with `curl` absent, `curl … | sh` and `bash <(curl …)` each exit
**0**. And the doc then **misdiagnoses it** — `ubu:401-407` says *"If you get `bash: uv:
command not found`… your bash configuration file is not being read… revisit the Setting
Positron as the default editor section"*, sending the student to audit a healthy `.bashrc`
for a missing binary. Structurally the same trap as the macOS `chsh` chain, but it fires for
**every student who did a stock desktop install**. Fix: `sudo apt install git curl` at
`ubu:198`.

**`libuv1-dev` is missing from `ubu:758`, and it is a hard build failure.** CRAN `fs` 2.1.0
(2026-04-18) declares it, and its `configure` **exits 1** on Linux when `pkg-config libuv`
fails — the bundled-libuv fallback is auto-enabled only on RHEL, and macOS autobrews it.
`fs` is a dependency of `usethis`, `devtools`, `roxygen2` and `pkgdown`. New drift: older
`fs` vendored libuv and declared nothing.

**And this reframes the `pak` sysreqs finding — I had it backwards.** pak auto-installs
system requirements only "*if the platform is supported and the user can install system
packages, either because it is the superuser, or via password-less sudo*". **No student has
password-less sudo.** So on a student machine pak prints the missing packages and stops.
`options(pkg.sysreqs = FALSE)` is still right for CI fidelity, but the incomplete `ubu:758`
list is **a live install-week failure first and a CI artifact second**. Compounding it: pak
honours `getOption("repos")`, `ubu:769` sends students to the `0-Cloud` CRAN mirror, and CRAN
ships **no Linux binaries** — so Ubuntu students compile ~120 packages from source where mac
and Windows students download. That is why every sysreqs gap surfaces here as a wall of
`configure: error` and nowhere else.

**A third "green while lying" case, and it is in my container design.** The spec resolves the
non-interactive-`~/.bashrc` problem by writing `/etc/profile.d/mds-ci.sh`. That works — and
it means **the container never executes the PATH mechanism the doc actually prescribes.** The
job goes green on a PATH the doc did not set. Either run the doc's append through
`bash -i -c`, or mark it `# CI-SKIP:` with a stated reason, alongside the Chromium and
pak-sysreqs markers.

**Worse: the container installs `curl` in step one**, which makes the highest-severity Ubuntu
defect above **structurally undetectable**. One line fixes it — assert `! command -v curl`
before the doc's first curl, or derive the base package set from the desktop manifest. It is
the cheapest high-value assertion in the whole design.

Two more: `ubu:1043` is **missing `-f`** like `mac:1061`, and it is worse here because
`ubu:1058` sources the result from *every interactive shell* — UBC wifi is the canonical
captive-portal environment. And `check-setup-mds.sh:481-486` `cat`s `~/.bashrc` into the
submitted log; on Ubuntu that file is the **primary, live** config, so it is a second
secret-leak channel that **survives removing the `env` dump**.

### macOS: the instructions are sound and the feedback loop is broken

The opposite shape to Windows. macOS's commands mostly work — the `sed` in the pandoc PATH
line everyone suspects is **correct on both architectures**, the `quarto --paths` recovery
note is right, and the uv section is genuinely good pedagogy. What's broken is that **three
of the document's own verification steps verify nothing**, and two load-bearing steps have
no verification at all.

1. **`xcode-select -v` (`mac:111`) does not check that the Command Line Tools are
   installed.** Proven: `/usr/bin/xcode-select` is a base-OS binary, **absent from the CLT
   package manifest** (`pkgutil --files com.apple.pkg.CLTools_Executables` → 5363 files, no
   `xcode-select`). It succeeds on a machine with no CLT. Use `xcode-select -p`. Ironically
   `git --version` at `mac:219` *is* a real CLT check, because `/usr/bin/git` is the shim
   that triggers the installer — the Git section accidentally does the verification the
   Xcode section fails to do.
2. **`R --version` is architecture-blind, and macOS is the only platform where that
   matters.** `check-setup-mds.sh:213` reads `head -1`; `Platform: aarch64-apple-darwin20`
   is line 3 and is never read. A student who downloads `R-4.6.1-x86_64.pkg` on an M-series
   Mac gets `OK R 4.6.1`, a Rosetta R, a package library the arm64 R will never see, and
   every source build compiled for the wrong architecture. **A false OK the checker
   structurally cannot catch — and neither can the macOS CI job, since runners are arm64.**
3. **`chsh` (`mac:92`) has no verification anywhere**, and three later sections depend on it.
   It prompts for a password (the doc doesn't say so), and it is a silent no-op if the
   student ever set Terminal's "Shells open with: Command". The failure signature is exactly
   `MISSING pandoc=3.*` + `MISSING jupyterlab PDF-generation` with everything else green —
   because pandoc's PATH line, `EDITOR`, all 12 aliases and `mds-help` live *only* in
   `~/.bash_profile`, while R, Positron, Docker, quarto and uv all survive via
   `/usr/local/bin` or uv's zsh rcfiles. And `mac:361-364` then tells that student *"Quarto
   was installed somewhere other than `/Applications/quarto`"* — **the wrong diagnosis.**
   This is the most likely macOS misdiagnosis chain in the document.

Two consequences of `chsh` the doc never names: it makes `~/.zprofile` dead, and **Homebrew's
bootstrap lives there** — `/opt/homebrew/bin` is not in `/etc/paths`, so `chsh -s /bin/bash`
silently removes `brew` and everything installed with it from `PATH`. And because
`BASH_SILENCE_DEPRECATION_WARNING` isn't set until `mac:1076`, **every new terminal for ~980
lines of instructions prints Apple's message telling the student to run `chsh -s /bin/zsh`** —
the exact opposite of step one. Some will comply.

**PostgreSQL: the doc and the checker test disjoint things.** `check-setup-mds.sh:119-125`
probes **only** `/Library/PostgreSQL/{18,17,16}/bin/psql` — the EnterpriseDB layout. A
Postgres.app or Homebrew install yields `MISSING postgreSQL` **even with a working server and
`psql` on `PATH`**, because the Darwin branch never falls back to `command -v psql` the way
the Linux branch does. Meanwhile the doc's own verification ("open the SQL Shell app") tests
the wrapper app, not the binary the checker probes, so the two can disagree in both
directions. One-line fix: fall back to `command -v psql` after the loop.

**`xattr -c` (`mac:130-136`) is the wrong fix and the wrong reflex to teach.** Positron is
properly signed and notarized (verified: `Developer ID Application: RStudio Inc.`, hardened
runtime, timestamped) and Gatekeeper assessment is on. "Damaged and can't be opened" for a
correctly-downloaded notarized app is overwhelmingly a **truncated download**. `xattr -c`
strips *all* extended attributes including `com.apple.provenance`; `xattr -d
com.apple.quarantine` is the targeted operation, and Apple's supported path since macOS 15 is
Settings → Privacy & Security → "Open Anyway" (the Control-click bypass was removed in
Sequoia). Teaching ~100 students that the response to a Gatekeeper refusal is to strip
attributes off an app is precisely what malware distribution pages instruct.

Two silent-failure mechanics worth fixing in the same pass: **`mac:1061` is the only curl in
the file without `-f`** (the other four have it), so a 404 or captive portal writes an HTML
body to `~/.git-prompt.sh`, which `mac:1079` sources from **every shell**, leaving `__git_ps1`
undefined at every prompt. And **`bash <(curl …)` is a silent no-op on failure** — verified,
`bash <(false)` exits 0 with no output — so with `check-python-installs.sh` 404ing *today*,
`mac:401` instructs students to run a command that prints nothing while the prose promises
"It prints what it finds in three groups."

Also verified here: **TinyTeX's symlinks are not on `PATH` on this machine**, so `latex` and
`tlmgr` are `command not found` — which means the 20-line backslash-continued `tlmgr install`
block at `mac:877-898` fails as **one error message**, silently, surfacing much later as a
Jupyter PDF failure. `tinytex::tlmgr_install(...)` from R needs no PATH and is never
mentioned. And **XQuartz is the only step in the document with no verification anywhere** —
probably vestigial for the documented package set, but as written it is unfalsifiable, and it
costs a logout and an admin password.

One reassurance: `mktemp -d` on macOS returns `/var/folders/…/T/tmp.XXXXXXXX` — **no spaces**,
so the Windows seat's `mktemp` concern does not apply here and the four PDF checks are safe.

### Cross-document drift: 95% synchronised, and the 5% is diagnostic

Verified mechanically, not impressionistically. The three lists most likely to generate
false MISSINGs are **clean**: the `pak::pkg_install(...)` line is byte-identical across all
three docs (same md5), the 21-package `tlmgr` list is identical modulo `tlmgr`→`tlmgr.bat`,
and the 47-line Stan block, the 34-line GitHub section and the ~85-line PDF section are all
byte-identical. The ~350-line Python/uv narrative — the largest and newest shared surface —
diffs cleanly: every difference is a path, a modifier key, or a deliberate platform Note.
**No non-OS-required ordering differences exist at all.** Somebody has been propagating
edits deliberately.

The drift clusters in three places, and where it clusters tells you what kind of bug it is:

1. **PostgreSQL — a policy contradiction, not copy-paste rot.** `mac:989` and `win:1189` say
   install 17 and avoid 18 "**so that everyone in the program is working with the same
   version**". `ubu:1005-1007` says Ubuntu students get 16 or 18 depending on release "and
   the exact minor version does not matter", and the checker accepts 16|17|18 everywhere.
   **The stated rationale is false** — the cohort has never been on one version — and it
   costs mac/Windows students a deliberate downgrade for a benefit that does not exist.
   Needs a policy call, not a sync pass.
2. **The bash-config/alias block — the three-way hand-edit signature.** `mac:1131` has
   `alias rm="rm -vi"` where the others have `rm -vI`; BSD `rm` supports `-I`, so this is
   drift, not an OS constraint, and it is behaviourally significant (`-i` prompts **per
   file**, `-I` prompts once). Windows' prose promises colours the block never configures.
   The `PS1` colour codes diverged between mac and Ubuntu for no reason, so lecture
   screenshots won't match a third of the room.
3. **The sample-output blocks — hand-maintained transcripts of a program's output**, the
   most drift-prone artifact possible. Each of the three is the correct one on a different
   axis. `ubu:1168` shows `OK psql (PostgreSQL) 16.9…` but the Linux code path strips the
   prefix and prints `OK psql 16.9…`. **These should be generated from a real run per OS,
   not hand-edited** — a natural output of the CI work.

**The most consequential single instance:** `check-setup-mds.sh:518` prints
*"Before sharing the log file, review that there is no SENSITIVE INFORMATION such as
passwords or access tokens in it."* `ubu:1229` reproduces it; `mac:1251-1253` and
`win:1435-1437` **truncate one line early and drop it**. So two-thirds of the cohort reads a
sample in which that warning does not appear, immediately before being told to upload the
log — which, per the first finding in this document, contains their entire environment.

**And a bug class per-document review cannot see by construction:** hard-won Notes that
landed in one doc and were never propagated. The OneDrive folder-sync warning exists only on
Windows, though all three docs steer students to OneDrive and macOS has the identical hazard
in iCloud's "Desktop & Documents" opt-in. The Git ≥ 2.23 floor is stated only on Ubuntu —
the platform where it matters *least* (24.04 ships 2.43) and absent from macOS, where a
stale Xcode CLT makes it most likely. Ubuntu has no `docker run hello-world` verification at
all. "How to exit psql" is Ubuntu-only. Each was almost certainly written after a real
student got stuck, and each is now missing exactly where the *next* student will get stuck.

This argues for a fourth, cheap linter that nothing else in this design provides: **a
cross-doc consistency check** that diffs the shared blocks and fails when they drift. It
would have caught all three clusters above, needs no doc edits, and its habit-level payoff
is the rule that when a Note is added to one install doc, the default is to ask whether it
belongs in the other two — and to record the answer when it does not.

### The doc-extraction reversal

The original design extracted commands from the install docs. Its premise — ` ```bash ` =
command, bare ` ``` ` = output — is **false**, verified independently four ways:

- `install_ds_stack_ubuntu.md` had **13 bare fences containing commands** — the entire R,
  LaTeX and PostgreSQL install.
- `install_ds_stack_windows.md` had **6 tagged fences containing output**; under a
  run-by-default extractor these execute `GNU Make 4.4.1` and
  `License GPLv3+: … <http://gnu.org/licenses/gpl.html>` as shell.
- `install_ds_stack_mac.md` was clean in both directions.

**All 19 are now retagged** (applied, uncommitted — see today's item 2). Fence parity
preserved; the 4-backtick block at `ubuntu:1143-1230` and its nested fence at 1154/1158
untouched. Three of the six Windows retags fix rendering that is **visibly wrong on the live
site**, where `R version 4.6.1` is tokenised as R source with the version as a numeric literal.

**The retags do not make the premise true**, and the linter must not assume they do: **14
` ```bash ` blocks remain non-commands** — 13 shell-config file contents (`ubuntu:303,1056` ·
`mac:255,287,342,1074` · `windows:314,344,423,828,1006,1015,1265`) and one
`<name-of-the-file>.deb` placeholder (`ubuntu:116`). The real taxonomy is
**command / output / file-content**, and expressing the third needs a convention
(` ```bash title="~/.bashrc" `, or a shortcode) — a design decision, deferred.

Three further facts make extraction structurally insufficient regardless:

1. **GUI apps have no install commands at all.** The Docker and RStudio sections of the
   Ubuntu doc contain *zero* code fences. Four of the thirteen Linux `sys_progs` can only
   come from a hand-written, manifest-sourced step — a shim was always mandatory, so the
   original design already contained the hand-written approach without admitting it.
2. **Session boundaries.** Of the Ubuntu doc's eight "open a new terminal" steps, only three
   are real — `:308` (Quarto tools dir), `:388` (uv), `:838` (TinyTeX); the rest are cargo
   cult because the `.deb` already put the binary on PATH.
3. **~49% of tagged blocks misbehave** under run-by-default — file contents, GUI-editor
   launches, six blocking `jupyter lab` calls, and blocks whose expected failure depends on
   a working directory carried only in prose.

**Decision: hand-write the installer; make the extractor a *linter*, deferred past
September.** The linter is **content-based** — grep raw text for `apt install`,
`curl … | sh`, `install.packages` — and asserts each has a counterpart in
`ci/install-<os>.sh` or in `ci/known-untestable.txt`. Content-based means **zero doc edits**
and no dependency on the unresolved third fence category; the cost is an exclusion list for
the 13 shell-config blocks above.

## The CI design

### Runner fidelity — negative controls are mandatory

*(Runner-image contents below are read from image manifests, not executed — no Windows or
macOS runner has been run in this review.)*

`windows-2025` preinstalls **R 4.6.1**, **PostgreSQL 17 at exactly the path
`check-setup-mds.sh:155-161` probes**, **Docker**, and **git**. So CI would report `OK` on
the `.libPaths()` parity gate and the whole PostgreSQL section without executing a line of
either. Docker is preinstalled on every runner.

macOS 15 ships gfortran, which a student Mac does not — so `pak` source builds succeed in CI
and fail for students. *(Hypothesis, not established: that this is the mechanism behind the
macOS "R package won't install" tickets.)*

**Every non-container job therefore runs a baseline preflight**: run the check script before
installing anything, record the pre-satisfied set, exclude those from counting as a pass,
and print them in the job summary.

### Container job

Run as root; `apt-get install -y git ca-certificates curl wget sudo gnupg lsb-release
software-properties-common locales tzdata` **before** the first `uses:` step, or
`actions/checkout@v6` falls back to the tarball path and leaves no `.git`. Actions cannot run
per-step as a non-root user, so create `student` (uid ≠ 1000 — the image already has a
`ubuntu` user there), `chown` a real `/home/student`, and run every doc-derived command *and*
the final check through one `su - student -c` wrapper with `HOME` fixed.
`check-setup-mds.sh:235` hardcodes `$HOME/mds-setup-check` **with no env override** — only
`MDS_BASE_URL` is overridable — and a fake `HOME` also breaks the playwright cache probe,
the shell-config capture, and R's user library.

**PATH persistence: the mechanism is `~/.profile`, not `~/.bashrc`, and not `$GITHUB_PATH`.**
`su - student -c` starts a *login* shell, so `~/.profile` is read even though it is
non-interactive — and Ubuntu's stock `~/.profile` already prepends `$HOME/.local/bin` and
`$HOME/bin`. `$GITHUB_PATH` is **inert**: `su -` resets `PATH` and re-runs
`/etc/profile` + `~/.profile`, discarding it. Write `/etc/profile.d/mds-ci.sh` instead.

*Not yet executed:* the claim that **only** the Quarto tools dir lacks a `~/.profile`
counterpart. Have the job assert this at runtime rather than trusting it.

**Locale.** The fixtures contain `Montréal · naïve · Öl · α β γ` and the container's `LANG`
is `C`. `locales` + `locale-gen en_US.UTF-8` + exporting `LANG` are required and appear
nowhere in the docs.

### A second job in `install-check.yml` — assertions, not disclaimers

A 5-minute `runs-on: ubuntu-24.04` job (no container) doing *only* the three
systemd-dependent checks the container structurally cannot make: `hostnamectl` succeeds,
`apt install postgresql` yields a running cluster reachable by `sudo su -c psql postgres`,
and `docker run hello-world` works. Do **not** fake these inside the container by shimming
`hostnamectl` — that makes the log lie about what was verified.

### Two places CI goes green while lying

Both found by drafting the installer. Both need a marker in the script *and* a line in the
job summary.

1. **Headless-Chromium dependencies.** `ubuntu:971-974` documents only `playwright install
   chromium`; `check-setup-mds.sh:334-340` then tests WebPDF. On a desktop the ~15 GTK/NSS
   libraries arrive with GNOME; in `ubuntu:24.04` they arrive only via the Positron/RStudio
   `.deb` closures — so skipping the GUI apps breaks WebPDF for reasons unrelated to the
   docs. Do not let this get fixed by accident.
2. **`pak`'s system-requirements auto-install.** With passwordless sudo, `pak` silently
   installs whatever `ubuntu:758`'s seven-package list forgot — and that list *is* incomplete
   (no `libgit2-dev`, needed by `gert` → `usethis`/`devtools`). Set
   `options(pkg.sysreqs = FALSE)` so the documented list is what is under test.

### Installer conventions

`ci/install-ubuntu.sh` **does not exist yet.** A ~330-line draft was produced during review
and its census is the useful part: **101 lines carry a `[ubuntu:NNN]` citation, but 43 lines
have no counterpart anywhere in the doc.** For every line lifted from the doc there is more
than one that is not in it — "hand-transcribed" undersells it ~2×. Week 2 writes the real
thing; the draft's marker census is the estimate to plan against, not committed code.

| Marker | Meaning | Draft count |
|---|---|---|
| `# CI-SKIP:` | documented step deliberately not run | 14 |
| `# CI-EXTRA:` | no counterpart in the doc — **each is an untested doc gap** | 43 |
| `# CI-TRANSLATED:` | documented step, meaning kept, form changed | 11 |
| `# CI-BOUNDARY:` | stands in for an "open a new terminal" step | 6 |

Two details easy to get wrong first try:

- **`R_LIBS_USER` must be created, and `path.expand()` is load-bearing.** R silently drops
  `R_LIBS_USER` from `.libPaths()` when the directory does not exist — *that*, not a flag, is
  what answers `ubuntu:767`'s "if asked about a personal library, select Yes". Without
  `path.expand()` you create a directory literally named `~`.
- **`ubuntu:446` clones upstream `main`.** Transcribed literally, the job tests nothing about
  the PR. `MDS_REPO`/`MDS_REF` overrides are load-bearing.

Skip the **whole** Stan section (`ubuntu:778-794`): `check-setup-mds.sh:363` checks neither
`rstan` nor `StanHeaders`, and building them from source dominates wall-clock. `r-stack.yml`
covers them.

Also: `ubuntu:776` documents a prompt `pak` does not emit (a `remotes`/`devtools` leftover),
and `ubuntu:905-907` is a prose-only conditional a script must resolve one way or the other.

### The audit

Comparing **prose samples** to upstream produces five findings today — uv 0.12.3→0.12.5,
Positron 2026.08.0→2026.08.1-2, Quarto 1.10.3→1.10.18, renv 1.2.3→1.2.4, ottr 1.5.2→1.6.0 —
all of which still pass their regex, i.e. all no-ops. A weekly issue opening with five
non-actionable items gets muted by week two. So the primary assertion is
**`check_regex` vs current upstream release**, not prose samples.

**But that assertion is positive-only, and a tautology satisfies it forever.** Two manifest
fields are mandatory, not niceties:

- **`must_reject`** — negative controls per component (`one major below`, `one major above`).
  Without them the audit would have validated all ten broken regexes weekly, indefinitely.
- **`pin_policy`** — PostgreSQL (docs pin 17; upstream 18.6) and Quarto (stable 1.10.18 vs
  prerelease 1.11.1) are deliberately below latest and would otherwise cry wolf every
  September, muting the channel for the exact reason we killed the prose-sample audit.

Comparison is three-way: doc prose ↔ `check_regex` ↔ upstream, filtered by `pin_policy`.

**Scope.** `link-check.yml` passes no `--include-verbatim`, so lychee keeps only links from
HTML attributes and drops every plaintext URL (confirmed in `html5gum.rs:371` and in this
site's build output). But the fix is today's item 5 — one flag covers all 13 in-fence URLs —
so the audit is scoped to two things only:

1. `check_regex` vs upstream, with negative controls and `pin_policy`.
2. Download-asset liveness for what CI never installs: **Positron, Quarto, RStudio, Docker
   Desktop, the EnterpriseDB PostgreSQL 17 installer, and the ezwinports `make` zip**
   (`windows:990`) — the last is non-GUI but every `make` instruction depends on it for a
   third of the cohort.

**Python packages audit against `uv.lock`, not PyPI.** All nine are lock-satisfied; the real
exposure is internal — `pyproject.toml` carries lower bounds only (`pandas>=3`,
`requires-python=">=3.14"`) while the checker demands exact majors, so one `uv lock --upgrade`
breaks it with no upstream event. R packages *are* upstream-driven: `renv.lock` carries only
rmarkdown/renv/tinytex; the other seven come from unpinned `pak::pkg_install`. `ottr` and
`canlang` install from **git HEAD**, so a "latest *release*" question is structurally blind to
them — `r-stack.yml` is their only guard.

**Size:** four adapters (GitHub with three sub-modes, CRAN/r-universe, PyPI,
postgresql.org) cover most gated components — **~300 lines plus a ~120-line manifest.**

### What this CI does not tell you

Printed in every job summary, because a green badge read as "the docs work" is worse than no
badge:

- Windows/macOS runners pre-satisfy R, PostgreSQL, Docker and git (mitigated by the
  preflight, not eliminated).
- macOS runners have gfortran; student Macs do not.
- Intel macOS is never exercised — free public-repo macOS runners are arm64.
- Every R command is documented as "type this into the RStudio console"; CI runs `Rscript`,
  with different `.libPaths()` and no equivalent of "if asked about a personal library,
  select Yes".
- Miniconda is preinstalled on the Ubuntu and Windows runners, so `check-python-installs.sh`
  always emits "Recommended to remove"; the clean run the docs promise is unreproducible.
- **`docker --version` and `psql --version` have never verified a daemon or a cluster on any
  platform** — that is not a container limitation but a permanent blind spot for the November
  SQL and Docker courses.
- `options(pkg.sysreqs = FALSE)` means CI tests the documented dependency list, not what a
  student's `pak` would silently repair.
- Network conditions differ from a student installing from outside Canada or on UBC wifi.

## Triage: what actually fits in three weeks

Assume ~30% of one person's time — roughly 36 hours, of which the list below is ~19 and the
rest is buffer, because the merge will overrun.

### The runners are also the test hardware

Worth stating plainly, because it changes the CI's value proposition and this review
under-weighted it: **GitHub Actions provides Linux, macOS and Windows runners, so the CI is
the only accessible way to execute the paths this review could only read.** The Windows
`msys` branch of `check-setup-mds.sh` has zero execution coverage anywhere, and it decides
what a third of the cohort is told about their machine; the Ubuntu desktop paths were
verified only against package manifests. Every finding that came from *running* something
was worth more than the ones that came from reading, and the runners are how the remaining
two platforms get run at all.

That is an argument for pulling the Windows verification job earlier than pure
regression-protection logic would suggest — not to certify `C:\Users\runneradmin`, but to
execute 60 lines of Windows-only shell that nothing has ever executed. It does not change
the September ordering below (the doc defects still outrank it), but it does mean the
Windows job earns its place on discovery value, not just regression value.

**And the mechanism is already there.** On GitHub-hosted Windows runners, `shell: bash`
resolves to **Git for Windows bash** (`C:\Program Files\Git\bin\bash.EXE`), pre-installed on
every Windows image. So the `msys` branch of `check-setup-mds.sh` runs on a hosted runner
with no setup at all:

```yaml
jobs:
  windows-job:
    runs-on: windows-latest
    steps:
      - run: bash <(curl -Ssf "$MDS_BASE_URL/check-setup-mds.sh")
        shell: bash
```

Two caveats to record. On **self-hosted** runners Git Bash is not guaranteed to be present or
on `PATH` — it must be installed and its `bin` directory added to the PATH of the account
running the runner service. And `shell:` does not accept a custom bash path, so a different
environment (MSYS2, Cygwin) needs a `PATH` adjustment or a wrapper script, because the runner
invokes whichever `bash` it finds. Neither affects the hosted-runner plan here.

### Build exactly one workflow before September: `r-stack.yml`

The review changed what the CI is *for*. The original premise was that the instructions
might drift out of true. They aren't drifting — the shared blocks are byte-identical and
someone has been propagating edits deliberately. What the review found instead is that the
instructions are **wrong now**, in ways CI cannot fix, on a branch that hasn't merged.
**CI protects against a future regression; it does nothing about a present defect.** Spending
August on CI spends the scarce resource (three weeks) on the abundant one (nine months
afterwards). The CI's real customer is the 2027-28 install update.

The strongest argument against rushing it comes from this review: the originally-specced
acceptance criterion — "three PDFs as artifacts" — **was green while the fixtures silently
corrupted Greek characters.** A workflow that checks exit codes and artifact existence is
worse than nothing, because it converts "we don't know" into "we checked."

**`r-stack.yml` first, not `fixtures.yml`.** `fixtures.yml` guards files you control, in one
repo, that this review just executed and found working, and that won't change unless you
change them. `r-stack.yml` guards `ucbds-infra/ottr` and `ttimbers/canlang` installed **from
git HEAD**, plus a 12-package `pak` resolution against live CRAN — things that can break
between now and Sept 5 without anyone touching anything, and that break identically for all
100 students on the same morning. It's also the cheapest item: ~60 lines, no LaTeX, no
container, no matrix, no `su -` archaeology.

### Six editing sessions — do not interleave them

| Session | File | Contents |
|---|---|---|
| **A** | `check-setup-mds.sh` only | delete the `env` dump; macOS `command -v psql` fallback; preserve render logs on success; rmarkdown dump section; strip ANSI; fix the 404 message; quote `"${sys_progs[@]}"`; widen `positron`/`rstudio` to `20(26\|27)\.` and `docker` to `[23][0-9]\.` **Hard rule: do not touch the ten regexes here** — the moment you do, this session acquires three sample-output blocks and two machines you don't have |
| **B** | `install_ds_stack_mac.md` | `chsh` verification + password warning + Homebrew caveat; `xcode-select -p`; `xattr` replacement; restore the sensitive-info line; add `newcomputermodern`; iCloud sync warning; `curl -f` at `:1061`; absolute path at `:769` |
| **C** | `install_ds_stack_windows.md` | the `R_DIR` block and the "replace the section that reads" step (one contiguous edit closes three findings); the `.libPaths()` one-sentence fix; restore the sensitive-info line; add `newcomputermodern` |
| **D** | `install_ds_stack_ubuntu.md` | add `newcomputermodern` only — it's the doc in the best shape |
| **E** | this repo | renv `snapshot.type: implicit` + regenerate; delete the false README/qmd claims |
| **F** | CI | `r-stack.yml` |

**Ordering dependencies, worst first:**

1. **B, C, D must land before the merge.** The merge date owns them.
2. **`--include-verbatim` must come *after* the merge, not before.** I had this backwards:
   `git grep check-python-installs main -- content` returns nothing, so no live page links
   that URL and lychee cannot find it regardless of flags. Running it early proves nothing.
3. **The 22nd `tlmgr` package must merge before any fixture asserts on the font — never the
   reverse.** A fixture declaring `mainfont: NewCM10-Regular.otf` **hard-fails** under
   fontspec on any machine whose TinyTeX lacks it. Ship the fixture change first and you
   convert a silent Greek corruption that harms nobody in install week into a hard `make`
   failure for 100 students in install week. **This is the most dangerous ordering
   dependency in the plan.** Adding the package is safe and unilateral; do it now, change
   the fixtures in October.
4. **`fixtures.yml`, whenever built, must assert against *today's* behaviour** — `Montréal`,
   `naïve`, `°C`, the en-dash, and the math-mode alpha — and **not** literal Greek, which is
   still broken. Otherwise CI is red on day one and you'll train yourself to ignore it.

### Realistic allocation

- **Week 1 (Aug 17-21):** rotate tokens (0.5h) · Session E (2.5h) · Session A (1h) ·
  Sessions B/C/D (5h) · buffer + read the branch's 34 commits (3h)
- **Week 2 (Aug 24-28) — merge week, protect it:** merge and deploy (4h) · post-merge smoke
  test from a clean `~` (1h) · `--include-verbatim` + reassign the link-rot issue off
  `ZacWarham`/`zmx721` (0.5h) · `r-stack.yml` (4h) · buffer (2.5h)
- **Week 3 (Aug 31-Sep 4):** **two colleagues do a cold install from the merged docs, one
  Windows one Mac (2h)** — worth more than any workflow you can build this month, and the
  only thing that exercises the Windows `msys` branch, which has zero execution coverage ·
  fix what they find (2h) · `fixtures.yml` ubuntu-only with content assertions (4h) · file
  the October list in YouTrack `UBC` (2h)

### Drop entirely — real findings not worth fixing

`rm -vi` vs `rm -vI` (the macOS variant is the *more* protective one; "fixing" it makes
students' `rm` less safe) · the `PS1` colour divergence · `ubu:1168`'s psql sample
parenthetical · `windows:910`'s wrong Rtools rationale (wrong prose, no failure mode) ·
"how to exit psql" being Ubuntu-only (that's a Slack answer) · removing the five cargo-cult
"open a new terminal" steps (saves 30 seconds, risks breaking a prose-carried session
assumption — negative expected value) · the prose-sample version audit · `audit.py`'s
download-liveness scope item (subsumed by `--include-verbatim` on a workflow that already
exists) · **the "settle the TinyTeX-1 bundle contents" investigation** — adding the package
unilaterally makes the answer irrelevant · triaging the 43 `# CI-EXTRA` lines, which don't
exist yet.

Also drop from active attention: `mds-help.sh` staleness (the branch copy is already
updated — conda survives only as a documented one-year transition alias) and the IRkernel
recipe (hand it to the teaching team, don't fix it here).

### Corrections to earlier rounds, verified

- **The renv finding is real but not a hard failure.** All 15 recommended packages ship with
  R and are present in the system library, so `renv::restore()` finds them satisfied and
  skips them — no source builds, no gfortran problem. What's real is the scary
  `The project is out-of-sync` warning on every student machine, and `README.md:114-116`
  being false. Fix it, but it isn't top-three.
- **`README.md:121-122` is CORRECT, not "disproven".** `renv::status()` prints *"The lockfile
  was generated with R 4.6.1, but you're using R 4.5.3."* An earlier round recorded the
  opposite and this document repeated it.

## Phases, with acceptance criteria inline

*(Superseded for the September window by the triage above; retained as the shape of the work
once the merge has landed and there is time to build properly.)*

### Week 1 (Aug 17-21) — protect what students actually run

| Deliverable | Done when |
|---|---|
| **Settle the TinyTeX-1 font question** — install the default bundle in a clean container, render one fixture | Either the Greek renders (font fix unnecessary for students; CI assertion still ships) or it does not (22nd `tlmgr` package confirmed necessary) |
| **`fixtures.yml`** — `setup-r` pinned 4.6.x, Quarto at the documented version, **LaTeX the doc's way** (`tinytex::install_tinytex()` + the `tlmgr` list lifted to `ci/tlmgr-packages.txt`), then `uv sync --locked` → `make r-packages` → `make` → `playwright install chromium` → `make webpdf`. Matrix ubuntu/macos/windows, **plus baseline preflight** on all three. `on: [push, pull_request, schedule]`; `concurrency` with `cancel-in-progress: true` | Green on all three OSes, where green means **`ci/assert-pdf-text.py` passes**, not that PDFs exist. Two negative controls: break a `tlmgr` package name → red; revert the font fix → red. `check-notebook-web.pdf` is a free positive control and must stay green throughout |
| **`r-stack.yml`** — nightly, ubuntu + macos; runs the documented R blocks verbatim: `install.packages('pak')`, the 12-entry `pak::pkg_install(...)` incl. `ucbds-infra/ottr` and `ttimbers/canlang`, then `StanHeaders`/`rstan` from r-universe. **Skip `example(stan_model)`** (20-40 min, checked by nothing). `${{ github.token }}` for GitHub rate limits | All 12 install without error; `installed.packages()` contains all ten of `check-setup-mds.sh:363`'s `r_pkgs`. Negative control: add a nonexistent package → red |

The `ci/tlmgr-packages.txt` count is **21 today, 22 if the font fix proves necessary** — do
not hard-code 21 before the first row of this table is answered.

Note the push trigger is kept because this repo *will* change through August (fixtures,
`ci/`), not because it won't — an earlier draft had that backwards.

### Week 2 (Aug 24-28) — Ubuntu, by hand

| Deliverable | Done when |
|---|---|
| **`ci/install-ubuntu.sh`** written fresh (draft census above as the estimate), with a header naming the doc sections it mirrors and the four markers | Reads top-to-bottom as something you would hand a student; every `# CI-EXTRA` line has a one-line justification |
| **`install-check.yml`** — container job + the 5-minute non-container job; `timeout-minutes: 300` on the container job only; `concurrency` with **`cancel-in-progress: false`** (Aug 17-28 is when pushes are most frequent, and a 2.5-4h run must be allowed to finish); `if: always()` on uploads; every emitted command wrapped in `timeout 900`; **log stripped of the `## Environmental variables` section before upload** | `check-setup-mds.sh` produces an accepted-exception list short enough to read in full, starting with the `hostnamectl` case. Negative control: break a documented command → red |
| **Settle: does `rstudio --version` work headless?** | Answered. If no, RStudio is a permanent accepted exception and `rstudio="2026\..*"` is exercised by nothing on Linux |

### Week 3 (Aug 31-Sep 4) — breadth and the audit

| Deliverable | Done when |
|---|---|
| **macOS verification-only job** — install via setup-actions (low fidelity, acknowledged), **baseline preflight first**, then run every `--version` and diff | Preflight output appears in the job summary and pre-satisfied components are excluded from passes |
| **Windows job (~15 min) — only worth building WITH manufactured negative controls.** A stock runner is `C:\Users\runneradmin`: ASCII, no spaces, admin, local account, one R version — i.e. none of the conditions that actually break Windows students. Without the controls it is a badge certifying the easiest configuration in existence | (1) **No `\r` anywhere in `check-setup-mds.log`** — the regression guard for item 4. (2) The four hardcoded probe paths still exist. (3) `cygpath -w "$(mktemp -d)"` recorded, and one fixture rendered from a directory containing a space. (4) `.libPaths()` diffed between `pwsh` and Git Bash, with `R_USER` unset as the negative control. (5) **`R_DIR` control: create an empty `C:\Program Files\R\R-4.5.3\bin\x64\`, source the doc's two lines, assert `R --version` still reports 4.6.1 — this fails today.** (6) Hostile-path control: run once with `HOME` under a non-ASCII directory; expect failure, that failure is the finding |
| **`ci/audit.py`** (~300 lines + ~120-line manifest) | Point a `check_regex` past upstream → issue opens; revert → closes. **Plus:** a `must_reject` entry fires; and PostgreSQL 17-vs-18.6 raises **nothing** (the `pin_policy` test — the audit's highest-risk component) |
| **Job-summary disclaimer block** wired into all workflows | "What this CI does not tell you" appears in every run summary |
| **Ownership shape applied to all four workflows** (`fixtures.yml`, `r-stack.yml`, `install-check.yml`, `version-audit.yml`) | Each has a label, an in-place issue, named assignees, and a final `exit 1` |

### Post-September

The content-based linter and the third fence-category convention. Promoting
`ci/install-ubuntu.sh` toward a student installer — **"seed for", not "promote to"**: 14
`# CI-SKIP` items are *mandatory* student steps, and four requirements point opposite ways
(pinned vs current URLs; fail-fast vs resumable; NOPASSWD vs a 15-minute sudo timestamp
across a 2-4h run; and idempotency, which matters only for students and on which CI exerts
zero pressure). The realistic end state is one shared `ci/lib-mds-install.sh` with two thin
drivers.

Known idempotency hazards for that work, in severity order: bare `git clone` (`:446`, hard
failure on re-run), three `~/.bashrc` appends totalling ~62 duplicated lines (`:238`, `:303`,
`:1056`), and `tinytex::install_tinytex()` without an `is_tinytex()` guard (`:834`). The
`tee -a` CRAN key (`:700`) is real but the least of these.

## Open decisions and owners

| Decision | Owner | Needed by | Notes |
|---|---|---|---|
| **Is literal (non-math) Greek in scope for MDS assignments?** | Dan | before Week 1 fixture work | Justifies 22 MB + a 22nd `tlmgr` package. Math mode already works; a column named `α` is silently corrupted today |
| Does `rstudio --version` work headless? | — | Week 2 | Changes the shape of the container job |
| Schedule location: cross-repo cron vs keepalive | — | Week 1 | **Recommend keepalive in this repo.** Driving the cron from the website repo dodges the 60-day auto-disable but puts failures for Dan's repo onto a file others maintain |
| Third fence-category convention | — | post-Sept | Blocks a fence-aware linter; the content-based linter does not need it |
| Docker 30: accept the clean break, or pre-empt it? | — | Week 1 | Anchoring `^Docker version (28\|29)\.` converts today's silent false-OK into a guaranteed mass false-MISSING the day 30 ships. Deliberate, but say so |
| **`positron`/`rstudio` `2026\..*` expire January 2027** — mid-program, mass false-MISSING | — | before January | Diagnosed twice, assigned to nothing. Not among the ten fixed today (they are correctly anchored — they just expire) |

**Named humans:** none of the four proposed workflows has an assignee. `link-check.yml:81`
assigns to `ZacWarham` and `zmx721` — that is the *precedent's* assignees, not this project's.
On `schedule` events GitHub emails **only the user who last committed the cron file**, so
today the answer to "CI fails at 3am in November" is one email to Dan. The risk is not alert
fatigue, it is an **unread channel** — which is worse, because a green dashboard nobody owns
is exactly what the fixture bug demonstrates.

## Defects found in passing — need tickets, not spec paragraphs

None of these are CI work and none currently has an owner. Recommend filing in YouTrack
(`UBC` project) rather than leaving here.

| Defect | Evidence | Impact |
|---|---|---|
| **`windows:830` `R_DIR` selects the oldest R** | array subscript; verified locally with 4.5.3 + 4.6.1 present | Silent, affects a third of the cohort, more likely as the year progresses. **Fix before September** |
| **`windows:830` glob has no failure path** | non-admin installs → `%LOCALAPPDATA%\Programs` (CRAN, R ≥ 4.2.0) | `R: command not found` with no diagnostic in the doc |
| **`windows:1004-1018` make edit can delete `R_DIR`** | produces an empty PATH element = current directory | R breaks; symptom surfaces in the LaTeX section |
| **`windows:882-896` `.libPaths()` gate is vacuous where placed** | personal library doesn't exist until `:922`; sample output at `:889-890` impossible at that point | The doc's most emphatic instruction currently protects nobody |
| **`windows:93` sends ARM64 students to the x64 build** | an ARM64 User install exists; CRAN ships a different R installer for WoA, whose library is `aarch64-library` | Growing share of 2026 laptops |
| **`windows:910` attributes Rtools PATH handling to RStudio** | it is R itself; CRAN says install order doesn't matter | Wrong reason implies terminal R can't compile |
| **`windows:1189` mandates PostgreSQL 17; checker probes 18 first** | accepts 16\|17\|18 | Silently blesses a version the doc didn't ask for |
| **No guidance on spaces or non-ASCII in the Windows profile path** | ezwinports `make` is a **32-bit ANSI** build (PE32/i386, verified); TeX Live is fragile there | International cohort; very hard to diagnose |
| **`check-setup-mds_kcds-toolbox.sh` executes a 404 body** | fetches from a `master` branch **that does not exist** — 200s only via GitHub's rename redirect — with `curl -Ss`, no `-f`, piped to `bash <(…)` | Arbitrary-content execution for a *different UBC program*. No owner |
| **`mds-help.sh` is stale and self-installing** | curled from `ubuntu:1118` into every student's shell; live copy is still the conda version | Student-facing |
| **`mds-help.sh` documents 7 of 12 aliases** | omits `rm`, `mv`, `cp`, `mkdir`, and **`alias grep='grep -i'`** | `grep -i` silently changes DSCI 511 exercise answers, in the card students consult |
| **IRkernel recipe cannot work** | `assignment-workflow-uv.md:320-324` runs `IRkernel::installspec()`; IRkernel is installed nowhere, and `check-setup-mds.sh:361` says its absence is *deliberate* | Already handed to the teaching team |
| **`renv/settings.json` is `snapshot.type: "all"`** | 41 packages incl. 15 base/recommended; `make` prints `The project is out-of-sync` on every student machine | Install-week scare in a step that already scares people. Fix: `implicit` + regenerate |
| **`README.md` has three false claims** | `:62-64` (LaTeX fonts — false), `:114-116` (renv.lock contents — false), `:121-122` (renv minor-version warning — **disproven** by test, not merely unverified) | — |
| **`mac:769`** | undocumented `sudo chown -R $(whoami) .config` in an inline code span, **relative path, no `cd`** | Recursive chown from an unknown working directory |
| **PG-1: the "same version" rationale is false** | `mac:989`/`win:1189` mandate 17 to keep the cohort aligned; `ubu:1005-1007` gives 16 or 18; checker accepts all three | mac/Windows students downgrade for no benefit. **Policy call needed** |
| **LOG-1: the sensitive-info warning is missing from 2 of 3 sample outputs** | present `ubu:1229`; truncated at `mac:1251-1253`, `win:1435-1437` | Two-thirds of the cohort never sees it, right before uploading the log |
| **ALIAS-1: `rm -vi` on macOS vs `rm -vI` elsewhere** | `mac:1131` vs `ubu:1107`/`win:1311`; BSD `rm` supports `-I` | `rm *.pdf` prompts per file on macOS only |
| **SYNC-1: cloud-sync warning is Windows-only** | `win:565-569`; no iCloud "Desktop & Documents" equivalent near `mac:477-481` | Same failure mode for `.venv`, `renv/`, `.git` |
| **DOCKER-1: Ubuntu never verifies Docker** | `ubu:1024-1026` outsources it; `mac:1011`/`win:1211` run `hello-world` inline | No success criterion for Ubuntu students |
| **GIT-1: the Git ≥ 2.23 floor is stated only on Ubuntu** | `ubu:194`; absent `mac:212-226`, `win:258-266`; checker accepts `git=2.*` | Missing on the platform where it's most likely |
| **OUT-1: `ubu:1168` psql sample doesn't match the Linux code path** | shows `psql (PostgreSQL) 16.9`; script prints `psql 16.9` | Copy-across from the mac/Windows format |
| **nbconvert `raw_mimetypes` asymmetry** | `text/latex` raw cells emitted by `--to latex`, silently dropped by `--to pdf` | Plausibly an upstream bug worth filing |
| **43 `# CI-EXTRA` lines** (once written) | each is a documented gap the docs do not cover | Needs a triage step, not just a marker |

## Appendix — evidence index

Claims in this document verified by **execution** on this machine (macOS 15, arm64, R 4.5.3,
Quarto 1.10.3, TeX Live 2026): the U+FFFD byte comparison and the font fix on all three
routes; `check-setup-mds.sh` exit codes and MISSING tallies in both directions; the regex
false-OK table; the `${sys_progs[@]}` glob expansion; the credential dump; the
`find_pandoc` selection and Rosetta probe; the renv 55-vs-357 measurement; the fence
inventory and retag application.

Verified by **live network check**: the site serving `MDS setup check 2025.1`;
`check-python-installs.sh` returning 404; the five stale prose version samples; lychee's
`--include-verbatim` behaviour in source.

**Read, not executed** — treat accordingly: all GitHub runner image contents; the container
job mechanics; TinyTeX-1's bundle contents (see the callout above); the Windows/`msys`
branch of the check script; Docker's release cadence (one interval, not a trend).
