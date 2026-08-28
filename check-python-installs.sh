#!/usr/bin/env bash
# Reports every Python installation on this machine, so students can decide what to
# clean up before installing uv. Version numbering is <Year>.<Patch>.
#
# It only looks: it never uninstalls, never edits a config file and never prompts. Where
# a clean-up is worth doing it prints the command for you to run yourself.
#
# Run by students before installing uv, and again from the end of check-setup-mds.sh.
# Written for bash 3.2, which is what macOS still ships.

ORANGE='\033[0;33m'
NC='\033[0m' # No Color

# Findings are collected as they are discovered and printed together at the end,
# so that the advice is not scattered through the inventory.
confusing=''
remove=''
fixnow=''

note_confusing() { confusing="${confusing}  - ${1}"$'\n'; }
note_remove()    { remove="${remove}  - ${1}"$'\n'; }
note_fixnow()    { fixnow="${fixnow}  - ${1}"$'\n'; }

# `type -a` is a bash builtin, so it is always available,
# and unlike `which` it also reveals aliases and shell functions.
list_command() {
    if type -a "$1" > /dev/null 2>&1; then
        type -a "$1" 2>/dev/null | sed 's/^/    /'
    else
        echo "    $1 is not on your PATH"
    fi
}

# Report a directory only when it actually exists.
report_dir() {
    # $1 = path, $2 = description, $3 = one of expected|confusing|remove
    if [ -e "$1" ]; then
        echo "    found: $1  ($2)"
        case "$3" in
            confusing) note_confusing "$2 at $1" ;;
            remove)    note_remove "$2 at $1" ;;
        esac
    fi
}

echo ''
# Credential-looking values are masked: the grep below matches "anaconda", and
# ANACONDA_API_TOKEN is a real variable that would ride into a submitted log.
redact_secrets() {
    awk '
    BEGIN { split("key token secret password passwd credential auth", kw, " ")
            MASK = "<redacted by check-python-installs>" }
    { out = ""; rest = $0
      while (match(rest, /[A-Za-z_][A-Za-z0-9_]*=/)) {
          name = substr(rest, RSTART, RLENGTH - 1)
          out = out substr(rest, 1, RSTART + RLENGTH - 1)
          rest = substr(rest, RSTART + RLENGTH)
          lower = tolower(name); hit = 0
          for (i in kw) if (index(lower, kw[i])) hit = 1
          # "pat" only as a whole word: as a substring it is inside PATH.
          if (lower ~ /(^|_)pat(_|$)/) hit = 1
          if (!hit) continue
          if (match(rest, /^[^[:space:]]*/)) len = RLENGTH; else len = 0
          out = out MASK; rest = substr(rest, len + 1)
      }
      print out rest }
    '
}

# A level-1 heading on its own, demoted via MDS_EMBEDDED when called from
# check-setup-mds.sh, where a second level-1 heading reads as a second report.
if [ -n "$MDS_EMBEDDED" ]; then
    echo -e "${ORANGE}### Python installations already on this computer (v2026.08.18)${NC}"
else
    echo -e "${ORANGE}# Python installations already on this computer (v2026.08.18)${NC}"
fi
echo ''
echo 'This is a report only. Nothing below has been changed or removed.'
echo 'uv will work even if you change nothing at all.'
echo ''

# --------------------------------------------------------------------------
echo -e "${ORANGE}## Python and pip commands on your PATH${NC}"
echo ''
echo 'When a name is listed more than once, the first one wins and the rest are'
echo 'shadowed. That is the most common reason a package seems to disappear.'
echo ''
for cmd in python python3 pip pip3; do
    echo "  $cmd"
    list_command "$cmd"
done
echo ''

# --------------------------------------------------------------------------
echo -e "${ORANGE}## Python version and environment managers${NC}"
echo ''
found_manager=''
for mgr in conda mamba micromamba pyenv asdf mise rye poetry pipx virtualenv uv; do
    if command -v "$mgr" > /dev/null 2>&1; then
        found_manager='yes'
        printf '    %-12s %s\n' "$mgr" "$(command -v "$mgr")"
        case "$mgr" in
            conda|mamba|micromamba)
                note_remove "$mgr — MDS no longer uses conda; see the clean-up notes below" ;;
            pyenv|asdf|mise|rye)
                note_confusing "$mgr manages Python versions too and can shadow the interpreter uv picks" ;;
        esac
    fi
done
if [ -z "$found_manager" ]; then
    echo '    none found'
fi
echo ''

# --------------------------------------------------------------------------
echo -e "${ORANGE}## Known installation locations${NC}"
echo ''
if [[ "$(uname)" == 'Darwin' ]]; then
    report_dir "/usr/bin/python3" "Apple's own Python, part of macOS" "expected"
    report_dir "/opt/homebrew/bin/python3" "Homebrew Python" "confusing"
    report_dir "/usr/local/bin/python3" "Homebrew (Intel) or a manual install" "confusing"
    report_dir "/opt/local/bin/python3" "MacPorts Python" "confusing"
    report_dir "/Library/Frameworks/Python.framework/Versions" "python.org installer builds" "confusing"
    report_dir "$HOME/.pyenv/versions" "pyenv-managed Pythons" "confusing"
    for d in "$HOME/miniforge3" "$HOME/anaconda3" "$HOME/miniconda3" "$HOME/opt/anaconda3" "$HOME/opt/miniconda3" "/opt/anaconda3" "/opt/miniconda3" \
             "/opt/homebrew/Caskroom/miniforge" "/opt/homebrew/Caskroom/miniconda" "/opt/homebrew/Caskroom/anaconda" \
             "/usr/local/Caskroom/miniforge" "/usr/local/Caskroom/miniconda" "/usr/local/Caskroom/anaconda"; do
        report_dir "$d" "conda installation" "remove"
    done
    report_dir "$HOME/.local/share/uv/python" "uv-managed Pythons" "expected"
elif [[ "$(uname)" == 'Linux' ]]; then
    report_dir "/usr/bin/python3" "Ubuntu's own Python — apt depends on it, do not remove" "expected"
    # Extra system interpreters usually mean the deadsnakes PPA or a source build.
    extra_sys=$(ls /usr/bin/python3.* 2>/dev/null | grep -Ev 'config|m$' | tr '\n' ' ')
    if [ -n "$extra_sys" ]; then
        echo "    system interpreters: $extra_sys"
    fi
    report_dir "/usr/local/bin/python3" "a manually built or 'make altinstall' Python" "confusing"
    report_dir "$HOME/.pyenv/versions" "pyenv-managed Pythons" "confusing"
    report_dir "/snap/bin/python3" "snap-installed Python" "confusing"
    for d in "$HOME/miniforge3" "$HOME/anaconda3" "$HOME/miniconda3" "/opt/anaconda3" "/opt/miniconda3"; do
        report_dir "$d" "conda installation" "remove"
    done
    report_dir "$HOME/.local/share/uv/python" "uv-managed Pythons" "expected"
else
    # Git Bash / MSYS on Windows.
    # `py -0` reads the Windows registry and is the single best source there.
    if command -v py > /dev/null 2>&1; then
        echo '    registered with the Windows py launcher:'
        py -0 2>/dev/null | sed 's/^/      /'
    fi
    report_dir "$LOCALAPPDATA/Programs/Python" "python.org installer builds" "confusing"
    report_dir "$LOCALAPPDATA/Microsoft/WindowsApps/python.exe" "Microsoft Store Python alias" "confusing"
    for d in "$USERPROFILE/miniforge3" "$USERPROFILE/anaconda3" "$USERPROFILE/miniconda3" "/c/ProgramData/anaconda3" "/c/ProgramData/miniconda3"; do
        report_dir "$d" "conda installation" "remove"
    done
    for d in /c/Python3*; do
        report_dir "$d" "a Python installed to the root of C:" "confusing"
    done
    report_dir "$USERPROFILE/AppData/Roaming/uv/data/python" "uv-managed Pythons" "expected"
fi
echo ''

# --------------------------------------------------------------------------
# Named for what it is: check-setup-mds.sh has its own `## Environment` section, and two
# similarly-named headings in one log read as a contradiction.
echo -e "${ORANGE}## Python-related environment variables${NC}"
echo ''
found_var=''
for var in PYTHONPATH PYTHONHOME CONDA_PREFIX VIRTUAL_ENV PIP_TARGET PYTHONNOUSERSITE PYTHONSTARTUP; do
    # ${!var} is an indirect expansion: the value of the variable named by $var
    value="${!var}"
    if [ -n "$value" ]; then
        found_var='yes'
        printf '    %-18s %s\n' "$var" "$value"
        case "$var" in
            PYTHONPATH|PYTHONHOME)
                note_fixnow "$var is set to '$value'. It forces every Python on this machine to look in that folder, including the ones inside MDS projects. Remove it from your shell configuration file." ;;
            PIP_TARGET)
                note_fixnow "PIP_TARGET is set to '$value', which redirects installs away from the project. Remove it from your shell configuration file." ;;
        esac
    fi
done
if [ -z "$found_var" ]; then
    echo '    none set'
fi
echo ''

# --------------------------------------------------------------------------
echo -e "${ORANGE}## Python settings in your shell configuration files${NC}"
echo ''
found_config=''
for f in "$HOME/.bash_profile" "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile" "$HOME/.zprofile"; do
    [ -f "$f" ] || continue
    hits=$(grep -n -E -i "conda initialize|conda\.sh|pyenv init|PYTHONPATH|PYTHONHOME|anaconda|miniforge|miniconda" "$f" 2>/dev/null)
    if [ -n "$hits" ]; then
        found_config='yes'
        echo "  $f"
        redact_secrets <<< "$hits" | sed 's/^/    /' 
        if grep -q "conda initialize" "$f" 2>/dev/null; then
            note_fixnow "$f contains a 'conda initialize' block. If you remove conda, remove this block too (see the clean-up notes below), otherwise every new terminal will print an error."
        fi
    fi
done
if [ -z "$found_config" ]; then
    echo '    nothing Python-related found'
fi
echo ''

# --------------------------------------------------------------------------
echo -e "${ORANGE}## User site-packages${NC}"
echo ''
echo 'Packages installed with `pip install --user` live outside any project but are'
echo 'still visible to Python, which makes them a common source of surprises.'
echo ''
user_site=''
if command -v python3 > /dev/null 2>&1; then
    user_site=$(python3 -m site --user-site 2>/dev/null)
fi
if [ -n "$user_site" ] && [ -d "$user_site" ]; then
    n_user_pkgs=$(ls "$user_site" 2>/dev/null | grep -c 'dist-info\|egg-info')
    echo "    $user_site"
    echo "    contains roughly $n_user_pkgs installed package(s)"
    if [ "$n_user_pkgs" -gt 0 ] 2>/dev/null; then
        note_fixnow "You have packages installed into your user site-packages folder ($user_site). They are visible to Python outside of any project. Listing them: python3 -m pip list --user"
    fi
else
    echo '    none found'
fi
echo ''

# --------------------------------------------------------------------------
echo -e "${ORANGE}## What to do about it${NC}"
echo ''

if [ -z "$remove$confusing$fixnow" ]; then
    echo '  Nothing needs your attention. Carry on with the installation instructions.'
    echo ''
    exit 0
fi

if [ -n "$remove" ]; then
    echo 'Recommended to remove — MDS has moved off conda entirely:'
    echo ''
    printf '%s' "$remove"
    echo ''
    echo '  To remove a conda installation cleanly, undo its shell changes *first*,'
    echo '  otherwise every new terminal will complain about a missing conda:'
    echo ''
    echo '    conda init --reverse --all'
    echo '    # then close all terminals, open a new one, and delete the folder it lived in,'
    echo '    # for example:  rm -rf ~/miniforge3'
    echo ''
fi

if [ -n "$confusing" ]; then
    echo 'Likely to cause confusion later — you can leave these, but know they are there:'
    echo ''
    printf '%s' "$confusing"
    echo ''
    echo '  These provide their own `python` or `python3` command. Because MDS runs'
    echo '  everything through `uv run`, they will not break your assignments, but they'
    echo '  are why typing a bare `python` may appear to work while none of your'
    echo '  packages are there.'
    echo ''
fi

if [ -n "$fixnow" ]; then
    echo 'Worth fixing regardless:'
    echo ''
    printf '%s' "$fixnow"
    echo ''
fi

echo 'If you are unsure about any item above, leave it alone and bring this output'
echo 'to a TA or instructor. Never delete anything inside /usr/bin — your operating'
echo 'system depends on it.'
echo ''
