#!/usr/bin/env bash
# Checks that the system programs and R & Python packages the MDS program needs are
# installed at the right versions. Version numbering is <Year>.<Patch>.

# Use colors for headings for clarity
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# `uname -s` is the durable Windows signal: MINGW64_NT, MSYS_NT and CYGWIN_NT all mean
# Windows. Testing OSTYPE=msys alone broke every Windows check the day Git Bash started
# reporting cygwin, sending them all down the Linux branch. OSTYPE is a second opinion.
is_windows=''
case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) is_windows='yes' ;;
esac
case "$OSTYPE" in
    msys | cygwin) is_windows='yes' ;;
esac

# The path differs per POSIX layer, Windows language and drive. cygpath ships with both
# layers and is the only thing that knows; the literal is a last resort.
program_files=''
if [ -n "$is_windows" ]; then
    program_files=$(cygpath -u "${ProgramFiles:-C:\\Program Files}" 2> /dev/null)
    [ -n "$program_files" ] || program_files='/c/Program Files'
    program_files="${program_files%/}"
fi

# 0. Help message and OS info
echo ''
echo -e "${ORANGE}# MDS setup check v2026.08.18${NC}" | tee check-setup-mds.log
echo '' | tee -a check-setup-mds.log
echo 'If a program or package is marked as MISSING,'
echo 'this means that you are missing the required version of that program or package.'
echo 'Either it is not installed at all or the wrong version is installed.'
echo 'The required version is indicated with a number and an asterisk (*),'
echo 'e.g. 4.* means that all versions starting with 4 are accepted (4.0.1, 4.2.5, etc).'
echo ''
echo 'The "Document export" section is the exception. It tries several different ways of'
echo 'turning a document into a PDF, and you only need one of them to work, so lines'
echo 'marked FAILED there are fine. What matters is the summary at the end of that'
echo 'section, which says whether PDF export works at all.'
echo ''
echo 'You can run the following commands to find out which version'
echo 'of a program or package is installed (if any):'
echo '```'
echo 'name_of_program --version  # For system programs'
echo 'cd ~/mds-setup-check && uv pip list  # For Python packages'
echo 'R -q -e "as.data.frame(installed.packages()[,3])"  # For R packages'
echo '```'
echo ''
echo 'Checking program and package versions...'
echo -e "${ORANGE}## Operating system${NC}" >> check-setup-mds.log
if [[ "$(uname)" == 'Linux' ]]; then
    # /etc/os-release rather than hostnamectl: systemd translates hostnamectl's labels,
    # so grepping "Operating" reports no OS at all on a non-English desktop. sed aligns.
    sys_info=$(hostnamectl 2> /dev/null)
    if [ -r /etc/os-release ]; then
        os_version="Operating System: $(. /etc/os-release && echo "$PRETTY_NAME")"
    else
        os_version=$(grep "Operating" <<< "$sys_info" | sed 's/^[[:blank:]]*//')
    fi
    echo "$os_version" >> check-setup-mds.log
    grep "Architecture" <<< "$sys_info" | sed 's/^[[:blank:]]*//;s/:/:    /' >> check-setup-mds.log
    grep "Kernel" <<< "$sys_info" | sed 's/^[[:blank:]]*//;s/:/:          /' >> check-setup-mds.log
    file_browser="xdg-open"
    if [ -z "$os_version" ]; then
        echo '' >> check-setup-mds.log
        echo "Your Ubuntu version could not be detected, so it was not checked." >> check-setup-mds.log
    elif ! grep -Eiq "24\.04|26\.04" <<< "$os_version"; then
        echo '' >> check-setup-mds.log
        echo "MISSING You are recommended to use Ubuntu 24.04 LTS or 26.04 LTS." >> check-setup-mds.log
    fi
elif [[ "$(uname)" == 'Darwin' ]]; then
    sw_vers >> check-setup-mds.log
    file_browser="open"
    # Accept macOS 14 (Sonoma) and every later release, including the 26.x naming scheme
    if ! $(sw_vers -productVersion | grep -Eq "^(1[4-9]|[2-9][0-9])\."); then
        echo '' >> check-setup-mds.log
        echo "MISSING You need macOS Sonoma (14) or greater." >> check-setup-mds.log
    fi
elif [ -n "$is_windows" ]; then
    # Queried with tools Git Bash reaches directly. `wmic` was removed from Windows 11.
    # Git Bash reports the version in `uname`, e.g. MINGW64_NT-10.0-26100.
    os_version_full=$(uname -s | grep -Eo '[0-9]+\.[0-9]+-[0-9]+$' | tr '-' '.')
    os_build=${os_version_full##*.}    # Build number (after the last dot)
    # The whole key, so no `/v` flag: Git Bash rewrites a leading slash into a file
    # path. `tr -d '\r'` strips the carriage returns Windows programs add.
    win_reg=$(reg query "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion" 2> /dev/null | tr -d '\r')
    # `EditionID`, not `ProductName`, which still reads "Windows 10" on Windows 11.
    # Matched exactly so `CompositionEditionID` is not picked up too.
    os_edition=$(awk '$1 == "EditionID" {print $NF}' <<< "$win_reg")
    os_release=$(awk '$1 == "DisplayVersion" {print $NF}' <<< "$win_reg")
    if [[ -z "$os_version_full" ]]; then
        os_name="Windows"
    elif [[ $os_build -ge 22000 ]]; then
        os_name="Windows 11"
    else
        os_name="Windows 10"
    fi
    echo "$os_name $os_edition $os_release" >> check-setup-mds.log
    echo "${PROCESSOR_ARCHITECTURE:-$(uname -m)}" >> check-setup-mds.log
    echo $os_version_full >> check-setup-mds.log
    file_browser="explorer"

    # These minimum builds are the ones Docker Desktop requires,
    # which is the strictest requirement anywhere in the MDS stack.
    if [[ -z "$os_version_full" ]]; then
        echo '' >> check-setup-mds.log
        echo "The Windows version could not be detected." >> check-setup-mds.log
    elif [[ $os_build -ge 22000 ]]; then
        if [[ $os_build -lt 22631 ]]; then
            echo '' >> check-setup-mds.log
            echo "MISSING You need Windows 11 23H2 (build 22631) or newer. Please run Windows update and then try running this script again." >> check-setup-mds.log
        fi
    elif [[ $os_build -lt 19045 ]]; then
        echo '' >> check-setup-mds.log
        echo "MISSING You need Windows 10 22H2 (build 19045) or newer. Please run Windows update and then try running this script again." >> check-setup-mds.log
    else
        echo '' >> check-setup-mds.log
        echo "NOTE      Windows 10 stopped receiving security updates in October 2025." >> check-setup-mds.log
        echo "          The MDS software stack still installs on Windows 10 22H2, but we recommend upgrading to Windows 11." >> check-setup-mds.log
    fi
else
    echo "Operating system verison could not be detected." >> check-setup-mds.log
fi

# A screenshot of the section below is usually all an instructor gets, and this line
# turns "three things are missing" into "your bash identifies as cygwin".
echo "Shell: $(uname -s) / $(bash --version 2> /dev/null | head -1)" >> check-setup-mds.log
echo '' >> check-setup-mds.log

# 1. System programs
# Runs each program and greps its version string. Both "not installed" and "wrong
# version" are marked MISSING.
echo -e "${ORANGE}## System programs${NC}" >> check-setup-mds.log

# What a MISSING line should say. Printing a raw regex at a first-week student is not a
# diagnostic. Anything not named here falls back to the pattern, readable for `R=4.*`.
requirement_text() {
    case "$1" in
        pandoc)   echo "pandoc 3.10 or newer" ;;
        uv)       echo "uv (any 0.x version)" ;;
        docker)   echo "docker 28 or 29" ;;
        positron) echo "positron 2026.*" ;;
        rstudio)  echo "rstudio 2026.*" ;;
        psql)     echo "postgreSQL 16, 17 or 18" ;;
        tlmgr)    echo "tlmgr (installed with TinyTeX)" ;;
        latex)    echo "a LaTeX engine (TinyTeX installs one)" ;;
        *)        echo "$2" ;;
    esac
}

# Writing a MISSING line and recording which program it was for are one event, so they
# are one call. Grepping the finished log instead would switch the note below off
# silently the day a requirement string is reworded.
gui_apps_missing=''
report_missing() {
    echo "MISSING   $(requirement_text "$1" "$2")" >> check-setup-mds.log
    case "$1" in
        rstudio)  gui_apps_missing="${gui_apps_missing:+$gui_apps_missing and }RStudio" ;;
        positron) gui_apps_missing="${gui_apps_missing:+$gui_apps_missing and }Positron" ;;
    esac
}

# `--version` does not work for .app programs on macOS, and not everything is on PATH,
# so the executable's location is tested instead.
if [[ "$(uname)" == 'Darwin' ]]; then

    # checking psql (postgresql)

    # psql is not added to path by default
    psql_found=false
    psql_version=""

    # Check for the newest supported major version first
    for pg_major in 18 17 16; do
        if [ -x "$(command -v /Library/PostgreSQL/${pg_major}/bin/psql)" ]; then
            psql_found=true
            psql_version=$(/Library/PostgreSQL/${pg_major}/bin/psql --version)
            break
        fi
    done

    if [ "$psql_found" = true ]; then
        echo "OK        $psql_version" >> check-setup-mds.log
    else
        echo "MISSING   postgreSQL 16.*, 17.*, or 18.*" >> check-setup-mds.log
    fi

    # rstudio is installed as an .app
    if ! $(grep -iq "= \"2026\..*" <<< "$(mdls -name kMDItemVersion /Applications/RStudio.app)"); then
        report_missing rstudio
    else
        # This is what is needed instead of --version
        installed_version_tmp=$(grep -io "= \"2026\..*" <<< "$(mdls -name kMDItemVersion /Applications/RStudio.app)")
        # Tidy strangely formatted version number
        installed_version=$(sed "s/= //;s/\"//g" <<< "$installed_version_tmp")
        echo "OK        "rstudio $installed_version >> check-setup-mds.log
    fi

    # rstudio and psql are checked separately, not with the --version test.
    # Every element is quoted: unquoted, `R=4.*` is a glob that bash expands against the
    # working directory, so a stray `R=4.txt` would become the version test.
    sys_progs=("R=4.*" "uv=0\.[0-9]+\.[0-9]+" "bash=3.*" "git=2.*" "make=3.*" "latex=3.*" "tlmgr=revision.*" \
        "docker=2[89].*" "positron=2026\..*" "quarto=1.*" pandoc="(^|[[:space:]])(3\.(1[0-9]|[2-9][0-9])|[4-9]\.[0-9]+|[1-9][0-9]+\.[0-9]+)(\.[0-9]+)*")
# psql and Rstudio are not on PATH in windows
elif [ -n "$is_windows" ]; then

    # checking psql (postgresql)
    psql_found=false
    psql_version=""

    # Check for the newest supported major version first
    for pg_major in 18 17 16; do
        if [ -x "$(command -v "$program_files/PostgreSQL/${pg_major}/bin/psql")" ]; then
            psql_found=true
            psql_version=$("$program_files/PostgreSQL/${pg_major}/bin/psql" --version)
            break
        fi
    done

    if [ "$psql_found" = true ]; then
        echo "OK        $psql_version" >> check-setup-mds.log
    else
        echo "MISSING   psql 16.*, 17.*, or 18.*" >> check-setup-mds.log
    fi

    # Rstudio on windows does not accept the --version flag when run interactively
    # so this section can only be troubleshot from the script
    rstudio_version=$("$program_files/RStudio/rstudio" --version 2> /dev/null)
    if ! $(grep -iq "2026\..*" <<< "$rstudio_version"); then
        report_missing rstudio
    else
        echo "OK        rstudio $rstudio_version" >> check-setup-mds.log
    fi
    # tlmgr needs .bat appended on windows and it cannot be tested as an exectuable with `-x`
    if ! [ "$(command -v tlmgr.bat)" ]; then
        echo "MISSING   tlmgr revision.*" >> check-setup-mds.log
    else
        echo "OK        "$(tlmgr.bat --version | head -1) >> check-setup-mds.log
    fi
    # Remove rstudio from the programs to be tested using the normal --version test
    sys_progs=("R=4.*" "uv=0\.[0-9]+\.[0-9]+" "bash=5.*" "git=2.*" "make=4.*" "latex=3.*" \
        "docker=2[89].*" "positron=2026\..*" "quarto=1.*" pandoc="(^|[[:space:]])(3\.(1[0-9]|[2-9][0-9])|[4-9]\.[0-9]+|[1-9][0-9]+\.[0-9]+)(\.[0-9]+)*")
else
    # For Linux everything is sane and consistent so all packages can be tested the same way
    sys_progs=("psql=(16|17|18).*" "rstudio=2026\..*" "R=4.*" "uv=0\.[0-9]+\.[0-9]+" "bash=5.*" \
        "git=2.*" "make=4.*" "latex=3.*" "tlmgr=revision.*" "docker=2[89].*" "positron=2026\..*" "quarto=1.*" pandoc="(^|[[:space:]])(3\.(1[0-9]|[2-9][0-9])|[4-9]\.[0-9]+|[1-9][0-9]+\.[0-9]+)(\.[0-9]+)*")
    # `<name>=<version regex>` throughout, for programs and packages alike. No bare
    # `python`: it is per project now, and is checked from inside the project below.
fi

for sys_prog in "${sys_progs[@]}"; do
    sys_prog_no_version=$(sed "s/=.*//" <<< "$sys_prog")
    regex_version=$(sed "s/.*=//" <<< "$sys_prog")
    # Check if the command exists and is is executable
    if ! [ -x "$(command -v "$sys_prog_no_version")" ]; then
        # If the executable does not exist
        report_missing "$sys_prog_no_version" "$sys_prog"
    else
        # `head` because `R --version` prints an essay, and `&>` because R on Windows
        # and Python2 on macOS print their version to stderr.
        if ! $(grep -Eiq "$regex_version" <<< "$($sys_prog_no_version --version &> >(head -1))"); then
            # If the version is wrong
            report_missing "$sys_prog_no_version" "$sys_prog"
        else
            # Since programs like rstudio and vscode don't print the program name with `--version`,
            # we need one extra step before logging
            installed_version=$(grep -Eio "$regex_version" <<< "$($sys_prog_no_version --version &> >(head -1))")
            echo "OK        "$sys_prog_no_version $installed_version >> check-setup-mds.log
        fi
    fi
done

# RStudio and Positron are the only two programs here a student never types into a
# terminal, so they are the only two this check can be safely wrong about -- neither is
# reliably on PATH or at a standard location. Everything else is a command the student
# will run, `docker` included. The note sits beside the lines it explains, only when
# there are any, and before the dump so the student sees the copy the instructor gets.
if [ -n "$gui_apps_missing" ]; then
    echo '' >> check-setup-mds.log
    echo "NOTE      $gui_apps_missing marked MISSING above: if you can open the application by" >> check-setup-mds.log
    echo "          double-clicking it, then it is installed and this check simply failed to" >> check-setup-mds.log
    echo "          find it. You can ignore that line. The check goes looking by name on your" >> check-setup-mds.log
    echo "          PATH and at one standard install location, and a working install is not" >> check-setup-mds.log
    echo "          always in either place." >> check-setup-mds.log
    echo "          Two things to keep in mind. Confirm the version in the application's own" >> check-setup-mds.log
    echo "          About window, since an out-of-date install is reported the same way. And" >> check-setup-mds.log
    echo "          this applies to RStudio and Positron only, because they are the only" >> check-setup-mds.log
    echo "          programs here you never run from a terminal -- every other MISSING line" >> check-setup-mds.log
    echo "          is real, even when a desktop application of that name opens fine." >> check-setup-mds.log
fi

# 2. Python packages
# There is no machine-wide Python any more, so this half runs inside a small project in
# the home folder that the script creates. It asks first, rather than taking a few
# hundred megabytes of disk unannounced; declining skips only the checks that need it.
# The answer defaults to no, including with nothing attached to stdin.
#
# `--no-sync` on every `uv run`, so the check reports what is installed rather than
# quietly installing it (or hanging while offline). Neither `--project` nor `--directory`
# moves this script, so check-setup-mds.log stays where the student ran it.
mds_project="$HOME/mds-setup-check"
# Overridable so CI can point at the branch under test. Students never set it.
mds_project_url="${MDS_PROJECT_URL:-https://github.com/UBC-MDS/mds-setup-check.git}"
# Where the other student-facing scripts are served from. Overridable for CI.
MDS_BASE_URL="${MDS_BASE_URL:-https://ubc-mds.github.io/mds-setup-check}"
mds_project_ok=''

# Where playwright keeps its browsers. Read by the setup below and by the WebPDF check.
if [[ "$(uname)" == 'Darwin' ]]; then
    playwright_cache="$HOME/Library/Caches/ms-playwright"
elif [ -n "$is_windows" ]; then
    playwright_cache="$LOCALAPPDATA/ms-playwright"
else
    playwright_cache="$HOME/.cache/ms-playwright"
fi

# Asked at most once per run, however many of the steps below turn out to need an answer.
mds_setup_reply=''
confirm_project_setup() {
    if [ -z "$mds_setup_reply" ]; then
        mds_setup_reply='no'
        if [ -t 0 ]; then
            echo
            echo "The Python checks run inside a small project in $mds_project."
            echo 'Setting it up downloads a few hundred megabytes: a repository from GitHub,'
            echo 'the Python packages it lists, and the copy of chromium that JupyterLab'
            echo 'exports PDFs through. Nothing outside that folder and the usual package'
            echo 'caches is touched, and you can delete it once you are done.'
            read -r -p 'Set up the MDS check project now? [y/N] ' mds_setup_input
            # Lower-cased first so that y, Y, yes, Yes and YES are all accepted, and so that
            # anything else at all -- including a bare Enter -- leaves the answer at no.
            mds_setup_input=$(printf '%s' "$mds_setup_input" | tr '[:upper:]' '[:lower:]')
            case "$mds_setup_input" in y | yes) mds_setup_reply='yes' ;; esac
        fi
    fi
    [ "$mds_setup_reply" = 'yes' ]
}

# An existing folder is never adopted: it could be last year's copy or an interrupted
# clone, and either would be reported as though this script had made it.
mds_project_preexisting=''
[ -e "$mds_project" ] && mds_project_preexisting='yes'

# Deleting it is the student's call, so it is its own question defaulting to no.
# Agreeing to a download is not agreeing to lose whatever is in that folder.
confirm_project_replace() {
    [ -t 0 ] || return 1
    echo
    echo "$mds_project already exists, and this script cannot check a folder it did not"
    echo 'make -- it has no way to tell a fresh copy from last year, an interrupted'
    echo 'download, or something unrelated that happens to share the name.'
    echo
    echo "Deleting it removes that folder AND EVERYTHING IN IT. If you have saved any"
    echo 'work of your own in there, answer no and move it somewhere else first.'
    read -r -p "Delete $mds_project and download a fresh copy? [y/N] " replace_input
    # Same shape as every other prompt here: lower-cased so y/Y/yes/YES all count, and
    # anything else at all -- including a bare Enter -- leaves the answer at no.
    replace_input=$(printf '%s' "$replace_input" | tr '[:upper:]' '[:lower:]')
    case "$replace_input" in y | yes) ;; *) return 1 ;; esac

    # Belt and braces before an rm -rf built from a variable: it has to be a real
    # directory, and it has to be the path this script computed rather than $HOME or /.
    if [ -z "$mds_project" ] || [ "$mds_project" != "$HOME/mds-setup-check" ] \
       || [ ! -d "$mds_project" ]; then
        echo "Refusing to delete '$mds_project': that is not the folder this script makes."
        return 1
    fi
    echo "Deleting $mds_project ..."
    rm -rf "$mds_project" || return 1
    mds_project_preexisting=''
    # "and download a fresh copy" was in the question, so consent is already given;
    # without this the student is asked to set up the project twice.
    mds_setup_reply='yes'
    return 0
}

# Clone, install packages, download chromium. Each step prints progress, because a
# silent multi-minute pause looks like a hang. Failures are left for the checks below,
# so a student who cannot download still gets the rest of their log.
setup_mds_project() {
    if [ -n "$mds_project_preexisting" ] && ! confirm_project_replace; then
        # Said here as well as in the log, because this is the moment the student is
        # watching the terminal, and it is the one outcome they have to act on themselves.
        if [ -t 0 ]; then
            echo
            echo "Leaving $mds_project alone, so the Python checks were skipped."
            echo 'To run them, delete that folder yourself and run this script again:'
            echo "    rm -rf $mds_project"
        fi
        return
    fi
    if ! [ -x "$(command -v git)" ] || ! confirm_project_setup; then
        return
    fi
    echo
    echo "Downloading the MDS check project into $mds_project ..."
    git clone --quiet "$mds_project_url" "$mds_project" || return
    echo
    echo "Installing the check project's Python packages, this takes a few minutes ..."
    uv sync --directory "$mds_project" || return
    # Chromium lives in a cache of its own outside the project, so it survives the folder
    # being deleted and is only ever downloaded once.
    if ! ls -d "$playwright_cache"/chromium-* > /dev/null 2>&1; then
        echo
        echo 'Downloading chromium for JupyterLab WebPDF export ...'
        uv run --no-sync --project "$mds_project" playwright install chromium || return
    fi
}
if [ -x "$(command -v uv)" ]; then
    setup_mds_project
fi
echo "" >> check-setup-mds.log
echo -e "${ORANGE}## Python packages${NC}" >> check-setup-mds.log
if ! [ -x "$(command -v uv)" ]; then  # Check that uv exists as an executable program
    echo "Please install 'uv' to check Python package versions." >> check-setup-mds.log
    echo "See the 'Python and uv' section of the installation instructions." >> check-setup-mds.log
elif [ -n "$mds_project_preexisting" ]; then
    # Still set means the replace offer was declined or never made (no terminal).
    echo "$mds_project was already on this computer before the script ran," >> check-setup-mds.log
    echo "so the Python package and document conversion checks were skipped." >> check-setup-mds.log
    echo "This script needs to make that folder itself, otherwise it reports on whatever" >> check-setup-mds.log
    echo "happens to be in there rather than on the version everyone else is checked against." >> check-setup-mds.log
    if [ -t 0 ]; then
        echo "You were offered the chance to replace it and chose not to. To run these" >> check-setup-mds.log
        echo "checks, move anything you want to keep out of that folder, then delete it" >> check-setup-mds.log
        echo "and run this script again:" >> check-setup-mds.log
    else
        echo "This script had no terminal attached, so it could not ask whether to replace" >> check-setup-mds.log
        echo "it. Delete it and run this script again from a terminal:" >> check-setup-mds.log
    fi
    echo "    rm -rf $mds_project" >> check-setup-mds.log
elif ! [ -f "$mds_project/pyproject.toml" ] || ! [ -d "$mds_project/.venv" ]; then
    echo "The MDS check project at $mds_project is not set up," >> check-setup-mds.log
    echo "so the Python package and document conversion checks were skipped." >> check-setup-mds.log
    # Piping the script into bash skips both prompts, so "answer yes next time" would
    # name an offer that student was never made.
    if [ -t 0 ]; then
        echo "Run this script again and answer yes when it offers to set the project up." >> check-setup-mds.log
    else
        echo "This script had no terminal attached, so it could not ask you anything." >> check-setup-mds.log
        echo "That happens when it is run as \`curl ... | bash\`. Run it this way instead:" >> check-setup-mds.log
        echo "    bash <(curl -Ssf $MDS_BASE_URL/check-setup-mds.sh)" >> check-setup-mds.log
    fi
else
    mds_project_ok='yes'
    # There is no machine-wide `python` to check, so the interpreter is checked from
    # inside the project instead.
    py_version=$(uv run --no-sync --project "$mds_project" python --version 2> /dev/null)
    if ! $(grep -Eq "3\.14" <<< "$py_version"); then
        echo "MISSING   python 3.14.* inside $mds_project" >> check-setup-mds.log
    else
        echo "OK        $py_version" >> check-setup-mds.log
    fi

    # Quoted for the same reason as sys_progs above: these are patterns, not filenames.
    py_pkgs=("otter-grader=7" "pandas=3" "nbconvert=7" "playwright=1" "jupyterlab=4" "jupyterlab-git=0" \
        "jupyterlab-spellchecker=0" "jupytext=1" "ipykernel=7")
    # `--format=freeze` because the default prints a header row that reads as package
    # names. `--directory` rather than `--project`, because `uv pip` finds the
    # environment from its own working directory -- and it moves only the uv process.
    installed_py_pkgs=$(uv pip list --directory "$mds_project" --format=freeze 2> /dev/null | sed 's/==/=/')
    for py_pkg in "${py_pkgs[@]}"; do
        # Anchored to line start or space, so `markdown` is not satisfied by
        # `rmarkdown`; the version stops at the next whitespace.
        py_pkg_match=$(grep -Eio "(^|[[:space:]])${py_pkg}[^[:space:]]*" <<< "$installed_py_pkgs" | tr -d '[:space:]')
        if [ -z "$py_pkg_match" ]; then
            echo "MISSING   ${py_pkg}.*" >> check-setup-mds.log
        else
            echo "OK        $py_pkg_match" >> check-setup-mds.log
        fi
    done
fi

# 3. R packages
# Same shape as the Python section above.
echo "" >> check-setup-mds.log
echo -e "${ORANGE}## R packages${NC}" >> check-setup-mds.log
if ! [ -x "$(command -v R)" ]; then  # Check that R exists as an executable program
    echo "Please install 'R' to check R package versions." >> check-setup-mds.log
else
    # IRkernel is deliberately absent: R and Python are kept as separate ecosystems, and the
    # R kernel for Jupyter is registered per assignment repo by the courses that need it.
    r_pkgs=(tidyverse=2 markdown=2 rmarkdown=2 renv=1 tinytex=0 janitor=2 gapminder=1 readxl=1 ottr=1 canlang=0)
    # R reads `.Rprofile` from wherever it starts, and this project ships one that
    # activates renv -- which would swap in a small project library and report every
    # package MISSING. Asked from a neutral directory, inside a subshell so this script
    # does not move.
    r_neutral_dir=$(mktemp -d) || r_neutral_dir=""
    if [ -z "$r_neutral_dir" ]; then
        echo "MISSING   R packages could not be checked: no temporary directory could be created." >> check-setup-mds.log
    fi
    installed_r_pkgs=$([ -n "$r_neutral_dir" ] && cd "$r_neutral_dir" && R -q -e "print(format(as.data.frame(installed.packages()[,c('Package', 'Version')]), justify='left'), row.names=FALSE)" | grep -v "^>" | tail -n +2 | sed 's/^ //;s/ *$//' | tr -s ' ' '=')
    for r_pkg in "${r_pkgs[@]}"; do
        # Anchored the same way as the Python check above, so that `markdown` is not
        # reported as installed just because `rmarkdown` is.
        r_pkg_match=$(grep -Eio "(^|[[:space:]])${r_pkg}[^[:space:]]*" <<< "$installed_r_pkgs" | tr -d '[:space:]')
        if [ -z "$r_pkg_match" ]; then
            echo "MISSING   $r_pkg.*" >> check-setup-mds.log
        else
            echo "OK        $r_pkg_match" >> check-setup-mds.log
        fi
    done
    rm -rf "$r_neutral_dir"
fi

# 4. Document export
# Every assignment is handed in as a rendered document, so each route is exercised here
# against the project's fixtures, copied to a temporary folder. The fixtures contain
# markdown, a code chunk and non-ASCII characters, so pandoc, the kernel and the fonts
# are all genuinely tested -- an empty document tests none of them.
#
# Five routes, failing independently: three go through LaTeX, Typst and WebPDF do not.
# A student needs only one, so a failed route is FAILED and MISSING is written only when
# every route failed. That keeps MISSING meaning "fix this before class".
echo "" >> check-setup-mds.log
echo -e "${ORANGE}## Document export${NC}" >> check-setup-mds.log
echo 'You only need ONE of the PDF routes below to work.' >> check-setup-mds.log
echo 'A FAILED line here is not a problem by itself -- read the summary at the end.' >> check-setup-mds.log

# The tally behind that summary. Every PDF route reports through one of these two, so the
# count cannot drift out of step with what was printed.
pdf_ok_count=0
pdf_try_count=0
pdf_pass() {
    pdf_try_count=$((pdf_try_count + 1))
    pdf_ok_count=$((pdf_ok_count + 1))
    echo "OK        $1" >> check-setup-mds.log
}
pdf_fail() {
    pdf_try_count=$((pdf_try_count + 1))
    echo "FAILED    $1" >> check-setup-mds.log
}

if [ -z "$mds_project_ok" ]; then
    echo "Skipping the document export checks, see the note in the Python packages section." >> check-setup-mds.log
else
    # An interrupted earlier run leaves these behind, and the report at the end appends
    # whatever it finds. Clearing them first keeps this run's errors this run's.
    rm -f quarto-typst-error.log quarto-pdf-error.log jupyter-pdf-error.log \
          jupyter-webpdf-error.log jupyter-html-error.log \
          rmarkdown-pdf-error.log rmarkdown-html-error.log
    scratch=$(mktemp -d)
    # Not silenced: a renamed fixture shows up here first. mds-logo.png is not
    # optional -- both fixtures embed it, and a missing image is a hard error in every
    # PDF route.
    cp "$mds_project/render-checks/check-quarto-py.qmd" \
       "$mds_project/render-checks/check-notebook.ipynb" \
       "$mds_project/render-checks/mds-logo.png" "$scratch"

    # Typst is bundled with Quarto and needs no LaTeX, so it is the route most likely to
    # work where the LaTeX install went wrong. `--to typst` overrides the fixture's YAML.
    if ! [ -x "$(command -v quarto)" ]; then
        pdf_fail 'quarto Typst PDF-generation could not be tested since quarto was not found.'
    elif ! [ -f "$scratch/check-quarto-py.qmd" ]; then
        pdf_fail 'quarto Typst PDF-generation could not be tested since check-quarto-py.qmd was not found in the project.'
    elif ! uv run --no-sync --project "$mds_project" quarto render "$scratch/check-quarto-py.qmd" --to typst &> quarto-typst-error.log; then
        pdf_fail 'quarto Typst PDF-generation failed. Check that quarto and the Python packages are marked OK above, then read the detailed error message below.'
    else
        pdf_pass 'quarto Typst PDF-generation was successful.'
        # Quarto reports normal progress on stderr, so this file is never empty and a
        # successful render would otherwise be printed back under an "errors" heading.
        rm -f quarto-typst-error.log
    fi

    # The route MDS asks students to use. The fixture has a Python chunk, so success
    # also proves Quarto found this project's Python and started a kernel.
    if ! [ -x "$(command -v quarto)" ]; then
        pdf_fail 'quarto LaTeX PDF-generation could not be tested since quarto was not found.'
    elif ! [ -f "$scratch/check-quarto-py.qmd" ]; then
        pdf_fail 'quarto LaTeX PDF-generation could not be tested since check-quarto-py.qmd was not found in the project.'
    elif ! uv run --no-sync --project "$mds_project" quarto render "$scratch/check-quarto-py.qmd" --to pdf &> quarto-pdf-error.log; then
        pdf_fail 'quarto LaTeX PDF-generation failed. Check that quarto, latex and the Python packages are marked OK above, then read the detailed error message below.'
    else
        pdf_pass 'quarto LaTeX PDF-generation was successful.'
        rm -f quarto-pdf-error.log
    fi

    if ! [ -f "$scratch/check-notebook.ipynb" ]; then
        pdf_fail 'jupyterlab exports could not be tested since check-notebook.ipynb was not found in the project.'
        echo 'MISSING   jupyterlab HTML-generation could not be tested since check-notebook.ipynb was not found in the project.' >> check-setup-mds.log
    else
        # nbconvert via LaTeX. This route needs pandoc, which comes from the Quarto install.
        if ! uv run --no-sync --project "$mds_project" jupyter nbconvert "$scratch/check-notebook.ipynb" --to pdf --log-level 'ERROR' &> jupyter-pdf-error.log; then
            pdf_fail 'jupyterlab PDF-generation failed. Check that latex, pandoc and jupyterlab are marked OK above, then read the detailed error message below.'
        else
            pdf_pass 'jupyterlab PDF-generation was successful.'
        fi

        # Prints through chromium instead of LaTeX. The browser cache is inspected
        # directly rather than starting a download to find out whether one is needed.
        if ! ls -d "$playwright_cache"/chromium-* > /dev/null 2>&1; then
            pdf_fail 'jupyterlab WebPDF-generation failed. Chromium was not downloaded. Run `uv run --project ~/mds-setup-check playwright install chromium`, or run this script again and let it set the project up.'
        elif ! uv run --no-sync --project "$mds_project" jupyter nbconvert "$scratch/check-notebook.ipynb" --to webpdf --log-level 'ERROR' &> jupyter-webpdf-error.log; then
            pdf_fail 'jupyterlab WebPDF-generation failed. Check that jupyterlab, nbconvert, and playwright are marked OK above, then read the detailed error message below.'
        else
            pdf_pass 'jupyterlab WebPDF-generation was successful.'
        fi

        # HTML is not one of the PDF routes, and there is no fallback for it, so a failure
        # here is a genuine MISSING rather than one option out of several.
        if ! uv run --no-sync --project "$mds_project" jupyter nbconvert "$scratch/check-notebook.ipynb" --to html --log-level 'ERROR' &> jupyter-html-error.log; then
            echo 'MISSING   jupyterlab HTML-generation failed. Check that jupyterlab and nbconvert are marked OK above, then read the detailed error message below.' >> check-setup-mds.log
        else
            echo 'OK        jupyterlab HTML-generation was successful.' >> check-setup-mds.log
        fi
    fi
    # -r because quarto leaves a `.quarto` folder behind next to the rendered document
    rm -rf "$scratch"
fi

# rmarkdown PDF and HTML generation, the fifth PDF route and the third HTML one.
if ! [ -x "$(command -v R)" ]; then  # Check that R exists as an executable program
    pdf_fail 'rmarkdown PDF-generation could not be tested since R was not found.'
    echo "Please install 'R' before testing PDF and HTML generation." >> check-setup-mds.log
else
    # find_pandoc has to run in the same R instance as the render, so it is defined once
    # and reused. Standalone locations come first, because that is the pandoc the install
    # guides have students install; the bundled copies are a fallback.
    find_pandoc_command="rmarkdown::find_pandoc(dir = c('/usr/local/bin', '/opt/homebrew/bin', '/usr/bin', 'C:/Program Files/Pandoc', '/opt/quarto/bin/tools/x86_64', '/opt/quarto/bin/tools/aarch64', '/opt/quarto/bin/tools', 'C:/Program Files/Quarto/bin/tools', '/usr/lib/rstudio/resources/app/bin/quarto/bin/tools', 'C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools', '/Applications/quarto/bin/tools/aarch64', '/Applications/quarto/bin/tools/x86_64', '/Applications/quarto/bin/tools', '/Applications/RStudio.app/Contents/MacOS/quarto/bin/tools', '/Applications/RStudio.app/Contents/MacOS/quarto/bin/tools/aarch64', '/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools', '/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools/aarch64', '/Applications/Positron.app/Contents/Resources/app/quarto/bin/tools', '/Applications/Positron.app/Contents/Resources/app/quarto/bin/tools/aarch64', '/Applications/Positron.app/Contents/Resources/app/quarto/bin/tools/x86_64', 'C:/Program Files/Positron/resources/app/quarto/bin/tools', '/usr/share/positron/resources/app/quarto/bin/tools'), cache = F)"
    # A scratch directory, for the same .Rprofile/renv reason as the package list above,
    # and to keep rmarkdown's intermediate files out of the student's folder.
    r_scratch=$(mktemp -d) || r_scratch=""
    # Prefer the project's fixture: an empty .Rmd never calls pandoc and never asks
    # LaTeX for a font, so it passes on machines that cannot render real work.
    if [ -z "$r_scratch" ]; then
        pdf_fail 'rmarkdown PDF-generation could not be tested: no temporary directory could be created.'
    elif [ -n "$mds_project_ok" ] && [ -f "$mds_project/render-checks/check-rmarkdown.Rmd" ]; then
        cp "$mds_project/render-checks/check-rmarkdown.Rmd" "$r_scratch/mds-knit-pdf-test.Rmd"
        # Not silenced: the fixture embeds this image and a missing one is a hard LaTeX
        # error. Silencing a load-bearing copy hid a fixture rename for three commits.
        cp "$mds_project/render-checks/mds-logo.png" "$r_scratch/"
    else
        # Small but real -- a heading, an R chunk and a character pdflatex cannot set.
        # An empty file would render on a machine that cannot render an assignment.
        echo 'NOTE      The R Markdown route used a built-in stand-in document, not check-rmarkdown.Rmd.' >> check-setup-mds.log
        cat > "$r_scratch/mds-knit-pdf-test.Rmd" <<'MDS_RMD_FIXTURE'
---
title: "MDS setup check"
output:
  pdf_document:
    latex_engine: xelatex
---

## Rendering

This line contains Montréal, 21 °C and an en dash -- all of which pdflatex cannot set.

```{r}
R.version$version.string
```
MDS_RMD_FIXTURE
    fi
    if [ -n "$r_scratch" ]; then
        # stderr captured, not discarded: without it a broken R Markdown route gave a
        # verdict with no evidence. The redirect wraps the subshell so the log opens in
        # the current directory; inside the `cd` it would be deleted with the scratch.
        pandoc_version=$( (cd "$r_scratch" && Rscript -e "cat(paste($find_pandoc_command[['version']]))") 2> rmarkdown-pdf-error.log )
        if ! (cd "$r_scratch" && Rscript -e "$find_pandoc_command;rmarkdown::render('mds-knit-pdf-test.Rmd', output_format = 'pdf_document')") >> rmarkdown-pdf-error.log 2>&1; then
            pdf_fail 'rmarkdown PDF-generation failed. Check that quarto, rmarkdown, and latex are marked OK above, then read the detailed error message below.'
            if [ "$pandoc_version" = "0" ]; then
                echo "It seems that RMarkdown cannot find pandoc. The install guides have you install it from pandoc.org; check that 'pandoc --version' works and reports 3.10 or newer." >> check-setup-mds.log
            fi
        else
            pdf_pass 'rmarkdown PDF-generation was successful.'
        fi
        if ! (cd "$r_scratch" && Rscript -e "$find_pandoc_command;rmarkdown::render('mds-knit-pdf-test.Rmd', output_format = 'html_document')") > rmarkdown-html-error.log 2>&1; then
            echo "MISSING   rmarkdown HTML-generation failed. Check that quarto and rmarkdown are marked OK above, then read the detailed error message below." >> check-setup-mds.log
            if [ "$pandoc_version" = "0" ]; then
                echo "It seems that RMarkdown cannot find pandoc. The install guides have you install it from pandoc.org; check that 'pandoc --version' works and reports 3.10 or newer." >> check-setup-mds.log
            fi
        else
            echo 'OK        rmarkdown HTML-generation was successful.' >> check-setup-mds.log
        fi
        rm -rf "$r_scratch"
    fi
fi

# The verdict. One working route is the whole requirement, so this is the only line in the
# section that can say MISSING, and it says it only when nothing at all produced a PDF.
echo "" >> check-setup-mds.log
if [ "$pdf_ok_count" -eq 0 ]; then
    echo "MISSING   No PDF export route worked ($pdf_try_count tried)." >> check-setup-mds.log
    echo "          Read the detailed errors printed after this report." >> check-setup-mds.log
else
    echo "OK        PDF export works. $pdf_ok_count of $pdf_try_count routes succeeded," >> check-setup-mds.log
    echo "          and one is all you need. Ignore any FAILED lines above." >> check-setup-mds.log
    if [ -z "$mds_project_ok" ]; then
        echo "          Note that only the R Markdown route could be tested, because the" >> check-setup-mds.log
        echo "          check project is not set up. The Quarto and JupyterLab routes --" >> check-setup-mds.log
        echo "          including the one MDS asks you to use -- were never tried." >> check-setup-mds.log
    fi
fi

# Environment variables are recorded only on an explicit yes, defaulting to no
# including with nothing on stdin. This log is submitted, and environment variables
# routinely hold API keys -- students have published their own credentials this way.
include_env='no'
if [ -t 0 ]; then
    echo
    echo 'Your environment variables can help diagnose PATH problems, but they often hold'
    echo 'API keys and access tokens, and you are about to share this log with instructors.'
    read -r -p 'Include environment variables in the log? [y/N] ' include_env_reply
    # Lower-cased first so that y, Y, yes, Yes and YES are all accepted, and so that
    # anything else at all -- including a bare Enter -- leaves the answer at no.
    include_env_reply=$(printf '%s' "$include_env_reply" | tr '[:upper:]' '[:lower:]')
    case "$include_env_reply" in y | yes) include_env='yes' ;; esac
fi
# Worth recording, because a leftover PATH edit or conda init block causes the failures
# above. Students keep tokens in these files, so credential-looking values are masked;
# `export PATH=` and `conda initialize` are left intact, as they are the point.
redact_secrets() {
    # awk rather than sed: matching is case-insensitive and BSD sed has no portable
    # flag. Deliberately over-redacting -- a masked harmless value costs little.
    awk '
    BEGIN {
        split("key token secret password passwd credential auth session private", kw, " ")
        MASK = "<redacted by check-setup-mds>"
    }
    # 1. NAME=VALUE where NAME contains a credential word in any capitalisation.
    #    Quoted values are consumed whole, so a multi-word secret cannot leak its tail.
    function redact_assignments(line,   out, rest, name, lower, i, hit, len) {
        out = ""
        rest = line
        while (match(rest, /[A-Za-z_][A-Za-z0-9_]*=/)) {
            name = substr(rest, RSTART, RLENGTH - 1)
            out = out substr(rest, 1, RSTART + RLENGTH - 1)
            rest = substr(rest, RSTART + RLENGTH)
            lower = tolower(name)
            hit = 0
            for (i in kw) if (index(lower, kw[i])) hit = 1
            # "pat" is matched as a whole word only. As a substring it is inside
            # PATH, and masking PATH would blind the most useful line in the file.
            if (lower ~ /(^|_)pat(_|$)/) hit = 1
            # 2. Any long opaque value, whatever it is called. Paths and URLs are
            #    excluded by the character class, so PATH and CONDA_PREFIX survive.
            if (!hit && match(rest, /^[A-Za-z0-9+_.=-]{24,}([[:space:]]|$)/)) hit = 1
            if (!hit) continue
            if (substr(rest, 1, 1) == "\"")      len = match(rest, /^"[^"]*"/)      ? RLENGTH : length(rest)
            else if (substr(rest, 1, 1) == "'"'"'") len = match(rest, /^'"'"'[^'"'"']*'"'"'/) ? RLENGTH : length(rest)
            else                                  len = match(rest, /^[^[:space:]]*/) ? RLENGTH : 0
            out = out MASK
            rest = substr(rest, len + 1)
        }
        return out rest
    }
    {
        line = redact_assignments($0)
        # 3. Values recognisable on their own: vendor token prefixes, and the
        #    user:password pair in a database URL.
        gsub(/(ghp_|gho_|ghu_|ghs_|ghr_|github_pat_|sk-|xox[baprs]-|AKIA|perm-)[A-Za-z0-9_.-]+/, MASK, line)
        gsub(/:\/\/[^\/[:space:]]*:[^@[:space:]]*@/, "://" MASK "@", line)
        print line
    }
    '
}

echo '' >> check-setup-mds.log
echo -e "${ORANGE}## Environment${NC}" >> check-setup-mds.log
if [ "$include_env" = 'yes' ]; then
    echo 'Included at your request. Values that look like credentials are masked, but the' >> check-setup-mds.log
    echo 'masking is not perfect -- review this section and remove anything private before sharing.' >> check-setup-mds.log
    # Redacted with more cause than the shell configs below: this is the section that
    # actually holds tokens, and it went in unfiltered while they were being filtered.
    env | redact_secrets >> check-setup-mds.log
else
    echo 'Not recorded. You were asked, and chose not to include them.' >> check-setup-mds.log
fi


# .bash_profile
echo '' >> check-setup-mds.log
echo -e "${ORANGE}## Content of .bash_profile${NC}" >> check-setup-mds.log
if ! [ -f ~/.bash_profile ]; then
    echo "~/.bash_profile not found" >> check-setup-mds.log
else
    redact_secrets < ~/.bash_profile >> check-setup-mds.log
fi

# .bashrc
echo '' >> check-setup-mds.log
echo -e "${ORANGE}## Content of .bashrc${NC}" >> check-setup-mds.log
if ! [ -f ~/.bashrc ]; then
    echo "~/.bashrc not found" >> check-setup-mds.log
else
    redact_secrets < ~/.bashrc >> check-setup-mds.log
fi


# Captured BEFORE the log is printed, so everything the student sends is everything
# they have seen. Anything appended after the screen dump is invisible to them.

# PDF and HTML error detail. After the OK/MISSING overview so the two are separate, but
# BEFORE the screen dump: these blocks are the largest thing in the log and carry
# absolute paths, so appending them after the dump would send what was never shown.
if [ -s quarto-typst-error.log ]; then
    echo '' >> check-setup-mds.log
    echo '======== You had the following errors during Quarto Typst PDF generation ========' >> check-setup-mds.log
    cat quarto-typst-error.log >> check-setup-mds.log
    echo '======== End of Quarto Typst PDF error ========' >> check-setup-mds.log
fi
if [ -s quarto-pdf-error.log ]; then
    echo '' >> check-setup-mds.log
    echo '======== You had the following errors during Quarto PDF generation ========' >> check-setup-mds.log
    cat quarto-pdf-error.log >> check-setup-mds.log
    echo '======== End of Quarto PDF error ========' >> check-setup-mds.log
fi
if [ -s jupyter-pdf-error.log ]; then
    echo '' >> check-setup-mds.log
    echo '======== You had the following errors during Jupyter PDF generation ========' >> check-setup-mds.log
    cat jupyter-pdf-error.log >> check-setup-mds.log
    echo '======== End of Jupyter PDF error ========' >> check-setup-mds.log
fi
if [ -s jupyter-webpdf-error.log ]; then
    echo '' >> check-setup-mds.log
    echo '======== You had the following errors during Jupyter WebPDF generation ========' >> check-setup-mds.log
    cat jupyter-webpdf-error.log >> check-setup-mds.log
    echo '======== End of Jupyter WebPDF error ========' >> check-setup-mds.log
fi
if [ -s jupyter-html-error.log ]; then
    echo '' >> check-setup-mds.log
    echo 'You had the following errors during Jupyter HTML generation:' >> check-setup-mds.log
    cat jupyter-html-error.log >> check-setup-mds.log
    echo '======== End of Jupyter HTML error ========' >> check-setup-mds.log
fi
if [ -s rmarkdown-pdf-error.log ]; then
    echo '' >> check-setup-mds.log
    echo '======== You had the following errors during R Markdown PDF generation ========' >> check-setup-mds.log
    cat rmarkdown-pdf-error.log >> check-setup-mds.log
    echo '======== End of R Markdown PDF error ========' >> check-setup-mds.log
fi
if [ -s rmarkdown-html-error.log ]; then
    echo '' >> check-setup-mds.log
    echo '======== You had the following errors during R Markdown HTML generation ========' >> check-setup-mds.log
    cat rmarkdown-html-error.log >> check-setup-mds.log
    echo '======== End of R Markdown HTML error ========' >> check-setup-mds.log
fi
# -f makes sure `rm` succeeds even when the file does not exists
rm -f jupyter-html-error.log jupyter-webpdf-error.log jupyter-pdf-error.log quarto-pdf-error.log \
    quarto-typst-error.log rmarkdown-pdf-error.log rmarkdown-html-error.log

# 5. Output the saved file to stdout, all at the end rather than progressively with
# `tee`, so students have time to read the help message at the beginning.
tail -n +2 check-setup-mds.log  # `tail` to skip rows already echoed to stdout

# 6. Every Python installation on the machine -- the same script students run before
# installing uv, so the log records the whole landscape. A subprocess, not sourced, so
# it cannot terminate this script. `tee` because the stdout dump has already happened.
echo '' | tee -a check-setup-mds.log
echo -e "${ORANGE}## Python installations${NC}" | tee -a check-setup-mds.log
if [ -x "$(command -v uv)" ]; then
    echo '' >> check-setup-mds.log
    echo 'Python versions known to uv:' >> check-setup-mds.log
    # tee, not >>: the screen dump has already happened by this point, so anything
    # merely appended from here is in the file the student sends and on no screen.
    uv python list 2>&1 | tee -a check-setup-mds.log
fi
# To a file first, not a process substitution, so a failed download is noticed rather
# than silently running an empty script.
py_audit=$(mktemp)
if curl -Ssf "$MDS_BASE_URL/check-python-installs.sh" -o "$py_audit" 2>&1; then
    MDS_EMBEDDED=1 bash "$py_audit" 2>&1 | tee -a check-setup-mds.log
else
    echo 'Could not download the Python installation report. The error printed above says why:' | tee -a check-setup-mds.log
    echo 'a network problem, a proxy, or the script having moved. The rest of this log is unaffected.' | tee -a check-setup-mds.log
fi
rm -f "$py_audit"

# Headings carry colour codes because the screen output IS this file dumped back out.
# They must not reach the copy an instructor opens, so they are stripped here, at the
# very end. awk rather than sed: the escape is matched literally and BSD sed has no
# portable \x1b, and ESC is passed in as a variable so no escape handling differs.
if strip_tmp=$(mktemp 2> /dev/null); then
    if awk -v esc="$(printf '\033')" '{ gsub(esc "\\[[0-9;]*m", ""); print }' \
           check-setup-mds.log > "$strip_tmp" 2> /dev/null; then
        cat "$strip_tmp" > check-setup-mds.log
    fi
    rm -f "$strip_tmp"
fi

echo
echo "The above output has been saved to the file $(pwd)/check-setup-mds.log"
echo "together with system configuration details and any detailed error messages about PDF and HTML generation."
echo "You can open this folder in your file browser by typing \`${file_browser} .\` (without the surrounding backticks)."
echo "Before sharing the log file, review that there is no SENSITIVE INFORMATION such as passwords or access tokens in it."
