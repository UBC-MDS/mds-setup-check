#!/usr/bin/env bash
# Checks that the correct version of all system programs and R & Python packages
# which are needed for the start of the MDS program are correctly installed.
# The version number represents <Year>.<Patch>
# since we usually iterate on the script once per year just before the semester starts.

# Use colors for headings for clarity
ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# Windows is reached through several POSIX layers and they do not identify themselves
# the same way. Git Bash -- what the install guides tell students to use -- reported
# OSTYPE=msys for years, and this script tested for exactly that. Git for Windows is a
# Cygwin fork, and a recent one ships a bash built against newer Cygwin that reports
# OSTYPE=cygwin instead. That single word silently took every Windows check down the
# Linux branch, where it looked for `rstudio` and `tlmgr` on PATH rather than
# `rstudio.exe` and `tlmgr.bat` and never scanned Program Files -- so a student with
# all three installed was told all three were missing.
#
# `uname -s` is the durable signal, and the OS-version parse below already depends on
# its shape: MINGW64_NT, MSYS_NT and CYGWIN_NT all mean Windows, whatever the bash
# inside was built against. OSTYPE is kept as a second opinion rather than the only
# one, so this does not break again the next time a triplet changes.
is_windows=''
case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) is_windows='yes' ;;
esac
case "$OSTYPE" in
    msys | cygwin) is_windows='yes' ;;
esac

# `/c/Program Files` under Git Bash, `/cygdrive/c/Program Files` under Cygwin, and
# somewhere else again if Windows is installed in another language or on another
# drive. cygpath ships with both layers and is the only thing that knows; $ProgramFiles
# comes from Windows itself. The literal is the last resort, not the first guess.
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
    # sed is for alignment purposes
    # /etc/os-release rather than hostnamectl: systemd translates hostnamectl's labels, so
    # grepping for the English word "Operating" reports no OS at all on a French or Chinese
    # desktop, and then tells the student to install a version of Ubuntu they already have.
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
    # MDS students work in Git Bash, so everything here is queried with tools that Git Bash
    # reaches directly. The previous version used `wmic`, which is disabled by default on
    # Windows 11 24H2 and removed in later releases.
    # Git Bash reports the Windows version in `uname`, e.g. MINGW64_NT-10.0-26100.
    os_version_full=$(uname -s | grep -Eo '[0-9]+\.[0-9]+-[0-9]+$' | tr '-' '.')
    os_build=${os_version_full##*.}    # Build number (after the last dot)
    # `reg` is asked for the whole key so that no `/v` flag is needed,
    # since Git Bash would rewrite a single leading slash into a file path.
    # `tr -d '\r'` strips the carriage returns that Windows programs add to each line.
    win_reg=$(reg query "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion" 2> /dev/null | tr -d '\r')
    # `EditionID` is used rather than the friendlier `ProductName`,
    # because `ProductName` still reads "Windows 10 ..." on Windows 11 machines.
    # The field names are matched exactly, so that `CompositionEditionID` is not picked up too.
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

# Which shell this ran under, on every platform. A screenshot of the section below is
# usually all an instructor gets, and this line is what turns "three things are missing"
# into "your bash identifies as cygwin, so the Windows checks were skipped". It is the
# fact that took the longest to establish the one time this went wrong.
echo "Shell: $(uname -s) / $(bash --version 2> /dev/null | head -1)" >> check-setup-mds.log
echo '' >> check-setup-mds.log

# 1. System programs
# Tries to run system programs and if successful greps their version string
# Currently marks both uninstalled and wrong verion number as MISSING
echo -e "${ORANGE}## System programs${NC}" >> check-setup-mds.log

# What a MISSING line should say. Printing the regex at a first-week student is not a
# diagnostic -- `MISSING pandoc=(^|[[:space:]])(3\.(1[0-9]|...` tells them nothing about
# what to install. Anything not named here falls back to the pattern, which is readable
# for the simple cases like `R=4.*`.
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

# Writing a MISSING line and recording which program it was for are the same event, so
# they are the same call. Both platform branches below report a missing RStudio too, and
# the alternative -- grepping the finished log for the two names further down -- would
# switch itself off silently the day one of those strings is reworded.
gui_apps_missing=''
report_missing() {
    echo "MISSING   $(requirement_text "$1" "$2")" >> check-setup-mds.log
    case "$1" in
        rstudio)  gui_apps_missing="${gui_apps_missing:+$gui_apps_missing and }RStudio" ;;
        positron) gui_apps_missing="${gui_apps_missing:+$gui_apps_missing and }Positron" ;;
    esac
}

# There is an esoteric case for .app programs on macOS where `--version` does not work.
# Also, not all programs are added to path,
# so easier to test the location of the executable than having students add it to PATH.
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

    # Remove rstudio and psql from the programs to be tested using the normal --version test
    # Every element is quoted. Unquoted, `R=4.*` and `docker=2[89].*` are globs:
    # bash expands them against the working directory as the array is built, so a
    # student with a file called `R=4.txt` sitting there silently gets that
    # filename used as the version test instead of the pattern.
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
    # Note that a single equal sign is used throughout for `<name>=<version regex>`,
    # for system programs, Python packages and R packages alike.
    # There is deliberately no bare `python` here: MDS installs Python per project
    # rather than machine-wide, so it is checked further down from inside the
    # `mds-setup-check` project instead.
fi

for sys_prog in "${sys_progs[@]}"; do
    sys_prog_no_version=$(sed "s/=.*//" <<< "$sys_prog")
    regex_version=$(sed "s/.*=//" <<< "$sys_prog")
    # Check if the command exists and is is executable
    if ! [ -x "$(command -v "$sys_prog_no_version")" ]; then
        # If the executable does not exist
        report_missing "$sys_prog_no_version" "$sys_prog"
    else
        # Check if the version regex string matches the installed version
        # Use `head` because `R --version` prints an essay...
        # Unfortunately (and inexplicably) R on windows and Python2 on macOS
        # prints version info to stderr instead of stdout
        # Therefore I use the `&>` redirect of both streams,
        # I don't like chopping of stderr with `head` like this,
        # but we should be able to tell if something is wrong from the first line
        # and troubleshoot from there
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

# RStudio and Positron are the only two programs above that a student never types into a
# terminal -- they are used entirely by double-clicking them -- which makes them the only
# two this check can be wrong about in a way that is safe to ignore. It finds them by name
# on PATH, or at one standard install location, and a working installation is not always
# in either place: Positron only puts `positron` on PATH if you ask it to, and either
# application can be installed somewhere else. Everything else here is a command the
# student will actually run, so a MISSING line for one of those is real work even when a
# desktop application of the same name opens. `docker` is the one that catches people.
#
# The note goes next to the lines it explains rather than into the help text at the top,
# and only when there is a line to explain. It is written before the dump at the end, so
# the student reads the same copy the instructor is sent.
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
# MDS does not install a machine-wide Python environment any more. Every project carries
# its own, so there is no machine-wide interpreter to check. The Python half of this script
# runs inside a small project we ship for the purpose, `mds-setup-check`, in the home folder.
#
# The installation instructions no longer walk students through creating that project by
# hand -- that is now this script's job. It asks before doing it rather than helping itself
# to a few hundred megabytes of somebody's disk unannounced. Declining is not fatal: the
# checks that need the project report themselves as skipped, and everything else still runs.
# The answer defaults to no, including when nothing is attached to stdin.
#
# `uv run` is given `--project`, but `uv pip list` is given `--directory` — see the comment
# at the inventory below for why the two differ. Neither changes this script's own working
# directory, so `check-setup-mds.log` stays where the student ran the script.
# `--no-sync` is used on every `uv run`, so that the check reports what is actually
# installed instead of quietly installing the missing pieces (or hanging while offline).
mds_project="$HOME/mds-setup-check"
# Overridable so that CI can point this at the branch under test rather than at main.
# Students never set it; the default is the only address they are ever given, and it is
# the same one the install guides publish.
mds_project_url="${MDS_PROJECT_URL:-https://github.com/UBC-MDS/mds-setup-check.git}"
# Where the other student-facing scripts are served from, and the URL quoted back to a
# student who ran this one in a way that could not prompt. Overridable so that both can be
# exercised against a pull request preview deploy; students never need to set it.
MDS_BASE_URL="${MDS_BASE_URL:-https://ubc-mds.github.io/mds-setup-check}"
mds_project_ok=''

# Where playwright keeps the browsers it downloads. Needed in two places: the setup below
# downloads chromium when it is missing, and the WebPDF check reads the same path to decide
# whether the export is worth attempting.
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

# A folder that was already there is never adopted. It could be last year's copy, an
# interrupted clone, or an unrelated folder that happens to share the name, and any of
# those would be measured and reported as though this script had made it. Starting over
# is cheap: the clone is small and uv reinstalls the packages from its cache.
mds_project_preexisting=''
[ -e "$mds_project" ] && mds_project_preexisting='yes'

# Deleting it is the student's call, so it is asked as its own question with its own
# default of no. Kept separate from the setup prompt above deliberately: agreeing to
# download a project is not the same as agreeing to lose whatever is in that folder.
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
    # "and download a fresh copy" was in the question, so consent to the download has
    # already been given. Without this the student is asked whether to set the project
    # up immediately after agreeing to set the project up.
    mds_setup_reply='yes'
    return 0
}

# Clones the project, installs its packages, and downloads the chromium that JupyterLab
# exports PDFs through. Each step prints its own progress: together they are by far the
# slowest part of the check, and a silent multi-minute pause looks like a hang.
# Failures are left for the checks below to report, so that a student who cannot download
# still gets the rest of their log.
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
    # Still set means the offer to replace the folder was declined, or was never made
    # because there was no terminal to make it on. confirm_project_replace clears it
    # after a successful delete, so a student who accepted does not land here.
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
    # Which advice to give depends on whether the question was ever asked. Piping the
    # script into bash leaves stdin a pipe, the [ -t 0 ] guard skips both prompts, and
    # the answer stays at its safe default of no -- so telling that student to "answer
    # yes next time" names an offer they were never made and cannot act on.
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
    # `--format=freeze` is required here. The default `columns` format prints a header row
    # and a rule, which would be read as if they were package names.
    # `--directory` rather than `--project`: `uv pip` finds the environment from its own
    # working directory, and `--project` would leave it looking at the wrong one and
    # quietly reporting an unrelated set of packages. `--directory` only changes the
    # working directory of the `uv` process itself, so this script's own location, and
    # therefore where check-setup-mds.log is written, is unaffected.
    installed_py_pkgs=$(uv pip list --directory "$mds_project" --format=freeze 2> /dev/null | sed 's/==/=/')
    for py_pkg in "${py_pkgs[@]}"; do
        # The name is anchored to the start of a line or a space, so that a lookup for
        # `markdown` is not satisfied by `rmarkdown`, and the version is taken up to the
        # next whitespace so that the following packages are not swept up with it.
        py_pkg_match=$(grep -Eio "(^|[[:space:]])${py_pkg}[^[:space:]]*" <<< "$installed_py_pkgs" | tr -d '[:space:]')
        if [ -z "$py_pkg_match" ]; then
            echo "MISSING   ${py_pkg}.*" >> check-setup-mds.log
        else
            echo "OK        $py_pkg_match" >> check-setup-mds.log
        fi
    done
fi

# 3. R packages
# Format R package output similar to above for python and grep for correct version numbers
# Currently marks both uninstalled and wrong verion number as MISSING
echo "" >> check-setup-mds.log
echo -e "${ORANGE}## R packages${NC}" >> check-setup-mds.log
if ! [ -x "$(command -v R)" ]; then  # Check that R exists as an executable program
    echo "Please install 'R' to check R package versions." >> check-setup-mds.log
else
    # IRkernel is deliberately absent: R and Python are kept as separate ecosystems, and the
    # R kernel for Jupyter is registered per assignment repo by the courses that need it.
    r_pkgs=(tidyverse=2 markdown=2 rmarkdown=2 renv=1 tinytex=0 janitor=2 gapminder=1 readxl=1 ottr=1 canlang=0)
    # R reads a `.Rprofile` from whichever directory it starts in, and the MDS check project
    # ships one that activates renv. If the student happens to run this script from inside
    # that project, renv replaces the library path with the project's own small library and
    # every package below is reported MISSING. Asking R from a neutral directory avoids that,
    # and the surrounding subshell means this script's own working directory, and therefore
    # where check-setup-mds.log is written, is unaffected.
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
# Every assignment is handed in as a rendered document, so each route that produces one is
# exercised here against the fixtures that ship with the `mds-setup-check` project, copied
# into a temporary folder so that nothing is written into the student's project. The
# fixtures deliberately contain markdown, a code chunk and non-ASCII characters, so that
# pandoc, the kernel and the document fonts are all genuinely tested.
#
# There are five ways to reach a PDF and they fail independently. Three of them go through
# LaTeX; Quarto's Typst engine and nbconvert's WebPDF do not, so a broken LaTeX install
# cannot take all five down at once. A student needs only one that works, so a route that
# fails is reported as FAILED rather than MISSING, and a MISSING is written at the end only
# when every route failed. That keeps MISSING meaning "you have to fix this before class".
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
    # Not silenced: if a fixture is missing or has been renamed, the copy failing
    # is the earliest and clearest signal of it. The per-route guards below still
    # report it to the student in their own words.
    # mds-logo.png is not optional: both fixtures embed it, and a missing image is a
    # hard error in every PDF route, not a warning. Verified by removing it.
    cp "$mds_project/check-quarto-py.qmd" "$mds_project/check-notebook.ipynb" \
       "$mds_project/mds-logo.png" "$scratch"

    # Quarto via Typst. Typst is bundled with Quarto and needs no LaTeX whatsoever, so this
    # is the route most likely to work on a machine where the LaTeX install went wrong.
    # `--to typst` overrides whatever the fixture's own YAML asks for.
    if ! [ -x "$(command -v quarto)" ]; then
        pdf_fail 'quarto Typst PDF-generation could not be tested since quarto was not found.'
    elif ! [ -f "$scratch/check-quarto-py.qmd" ]; then
        pdf_fail 'quarto Typst PDF-generation could not be tested since check-quarto-py.qmd was not found in the project.'
    elif ! uv run --no-sync --project "$mds_project" quarto render "$scratch/check-quarto-py.qmd" --to typst &> quarto-typst-error.log; then
        pdf_fail 'quarto Typst PDF-generation failed. Check that quarto and the Python packages are marked OK above, then read the detailed error message below.'
    else
        pdf_pass 'quarto Typst PDF-generation was successful.'
        # Quarto reports its normal progress on stdout and stderr, so this file is never
        # empty. Without removing it, every successful render would be printed back to the
        # student under an "errors" heading.
        rm -f quarto-typst-error.log
    fi

    # Quarto via LaTeX, the route MDS asks students to use for assignments.
    # `check-quarto-py.qmd` contains a Python chunk, so a successful render also proves that
    # Quarto can find this project's Python and start a kernel in it.
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

        # nbconvert via WebPDF, which prints through chromium instead of LaTeX.
        # Rather than starting a download to find out whether one is needed, the browser
        # cache is inspected directly. That is both faster and free of the timeout tricks
        # this check used to need to stay portable across the three operating systems.
        # `playwright_cache` is set once further up, next to the setup that fills it.
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
    # The find_pandoc command need to be run in the same R instance
    # as at the rendering of the PDF and HTML docs,
    # so we define it once here and run it twice below
    # (plus one to explicitly check if pandoc was found
    # and give a more informative error message)
    # The standalone locations come first, because that is the pandoc the install guides
    # have students install and therefore the one worth testing. The bundled copies inside
    # Quarto, RStudio and Positron stay as a fallback for a machine that skipped that step.
    find_pandoc_command="rmarkdown::find_pandoc(dir = c('/usr/local/bin', '/opt/homebrew/bin', '/usr/bin', 'C:/Program Files/Pandoc', '/opt/quarto/bin/tools/x86_64', '/opt/quarto/bin/tools/aarch64', '/opt/quarto/bin/tools', 'C:/Program Files/Quarto/bin/tools', '/usr/lib/rstudio/resources/app/bin/quarto/bin/tools', 'C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools', '/Applications/quarto/bin/tools/aarch64', '/Applications/quarto/bin/tools/x86_64', '/Applications/quarto/bin/tools', '/Applications/RStudio.app/Contents/MacOS/quarto/bin/tools', '/Applications/RStudio.app/Contents/MacOS/quarto/bin/tools/aarch64', '/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools', '/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools/aarch64', '/Applications/Positron.app/Contents/Resources/app/quarto/bin/tools', '/Applications/Positron.app/Contents/Resources/app/quarto/bin/tools/aarch64', '/Applications/Positron.app/Contents/Resources/app/quarto/bin/tools/x86_64', 'C:/Program Files/Positron/resources/app/quarto/bin/tools', '/usr/share/positron/resources/app/quarto/bin/tools'), cache = F)"
    # Rendered in a scratch directory rather than the current one, for the same reason as the
    # package list above: the MDS check project's `.Rprofile` would otherwise put renv's small
    # project library in front of the user library this section is meant to be testing.
    # It also keeps rmarkdown's intermediate files out of the student's folder.
    r_scratch=$(mktemp -d) || r_scratch=""
    # Prefer the fixture that ships with the MDS check project, since it contains real
    # markdown, an R chunk and non-ASCII characters. An empty .Rmd never calls pandoc and
    # never asks LaTeX for a font, so it passes on machines that cannot render real work.
    if [ -z "$r_scratch" ]; then
        pdf_fail 'rmarkdown PDF-generation could not be tested: no temporary directory could be created.'
    elif [ -n "$mds_project_ok" ] && [ -f "$mds_project/check-rmarkdown.Rmd" ]; then
        cp "$mds_project/check-rmarkdown.Rmd" "$r_scratch/mds-knit-pdf-test.Rmd"
        cp "$mds_project/mds-logo.png" "$r_scratch/" 2> /dev/null
    else
        # Not an empty file. An empty .Rmd never calls pandoc and never asks LaTeX for a
        # font, so it renders on machines that cannot render an actual assignment, and the
        # log then says PDF export works when it does not. This inline stand-in is small
        # but real: a heading, an R chunk and a character pdflatex cannot set.
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
        # stderr captured rather than discarded, on both of these and on the probe above.
        # Every other route in this section writes an error log that the report prints;
        # these two were the exception, so a student whose R Markdown route broke got a
        # verdict with no evidence, and R's own "there is no package called 'rmarkdown'"
        # printed itself live, mid-run, attached to no section.
        # The redirect wraps the subshell rather than sitting after the Rscript, so the
        # error log is opened in the current directory beside the others. Inside the
        # `cd` it would be written into the scratch directory and deleted with it.
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

# Environment variables are recorded only if the student answers yes to this prompt.
#
# This log gets submitted as part of the setup check, and environment variables routinely
# hold API keys and access tokens. A log that quietly carries secrets the student never saw
# is a breach of their trust -- students have unknowingly published their own credentials
# exactly this way. The question is asked here rather than hidden behind a variable to set,
# because a student who is told to set one during installation will set it without
# understanding what it does, which is the same outcome we are trying to avoid.
# The answer defaults to no, including when nothing is attached to stdin.
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
# Shell configuration files are worth recording, because a leftover PATH edit or conda init
# block is a common cause of the failures above. Students do keep tokens in these files
# though, so any value whose variable name looks like a credential is masked. `export PATH=`
# and `conda initialize` markers are deliberately left intact -- they are what makes this
# section worth having.
redact_secrets() {
    # awk rather than sed, because the matching has to be case-insensitive and BSD sed
    # (macOS) has no portable flag for that. Three passes, deliberately over-redacting:
    # the cost of masking a harmless value is a slightly less useful log, and the cost of
    # missing one is a student's credential in an instructor's inbox.
    awk '
    BEGIN {
        split("key token secret password passwd credential auth session private", kw, " ")
        MASK = "<redacted by check-setup-mds>"
    }
    # 1. NAME=VALUE where NAME contains a credential word, glued or underscored,
    #    in any capitalisation: PGPASSWORD, my_password, GITHUB_TOKEN, APIKEY.
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
    # Redacted for the same reason .bash_profile and .bashrc below are, and with more
    # cause: this is the section that actually holds tokens. It went in unfiltered while
    # the shell-config sections -- mostly aliases -- were being filtered.
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


# The environment and shell-configuration capture happens BEFORE the log is printed, so
# that everything the student is about to send is also everything they have seen. A
# section appended after the screen dump is invisible to them, and this file gets mailed
# to an instructor.

# Output details about PDF and HTML creation errors
# This is written after all the package OK/MISSING info, to separate the detailed error
# message from the overview of which packages installed correctly -- but BEFORE the screen
# dump below, because these blocks are the largest thing in the log and they carry
# absolute paths. Appending them after the dump put them in the file the student mails to
# an instructor without ever showing them on screen, which is the one thing the ordering
# comment above forbids.
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

# 5. Ouput the saved file to stdout
# I am intentionally showing the entire output in the end,
# instead of progressively with `tee` throughout
# so that students have time to read the help message in the beginning.
tail -n +2 check-setup-mds.log  # `tail` to skip rows already echoed to stdout

# 6. Report every Python installation on the machine.
# This is the same script students are asked to run before installing uv, invoked here so
# that the finished log records the whole Python landscape and not just the MDS part of it.
# It is run as a subprocess rather than sourced, so that it cannot terminate this script
# and does not leak its variables into it. `tee` is needed because the stdout dump above
# has already happened, so anything merely appended to the log from here on is never seen.
echo '' | tee -a check-setup-mds.log
echo -e "${ORANGE}## Python installations${NC}" | tee -a check-setup-mds.log
if [ -x "$(command -v uv)" ]; then
    echo '' >> check-setup-mds.log
    echo 'Python versions known to uv:' >> check-setup-mds.log
    # tee, not >>: the screen dump has already happened by this point, so anything
    # merely appended from here is in the file the student sends and on no screen.
    uv python list 2>&1 | tee -a check-setup-mds.log
fi
# Downloaded to a file first rather than run straight from a process substitution, so that
# a failed download is actually noticed instead of silently running an empty script.
# The base URL is overridable so that this section can be exercised against a pull request
# preview deploy before it is merged; students never need to set it.
py_audit=$(mktemp)
if curl -Ssf "$MDS_BASE_URL/check-python-installs.sh" -o "$py_audit" 2>&1; then
    MDS_EMBEDDED=1 bash "$py_audit" 2>&1 | tee -a check-setup-mds.log
else
    echo 'Could not download the Python installation report. The error printed above says why:' | tee -a check-setup-mds.log
    echo 'a network problem, a proxy, or the script having moved. The rest of this log is unaffected.' | tee -a check-setup-mds.log
fi
rm -f "$py_audit"

# The headings are written to the log with their colour codes attached, because the
# screen output IS this file dumped back out and the colour has to survive that. It
# must not survive into the copy an instructor opens, though: a submitted log full of
# `^[[0;33m## System programs^[[0m` is unreadable, and this repository's own CI has to
# sed them out to assert on it. So they are stripped here, at the very end, after
# everything has been written and after the screen has already had them.
#
# awk rather than sed: the escape has to be matched literally, and BSD sed (macOS) has
# no portable \x1b. The ESC is passed in as a variable so no shell or awk escape
# handling differs between platforms.
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
