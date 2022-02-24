#!/bin/bash

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.
# activate if the script should abort on error:
# set -e

SCRIPT_FULL_NAME=$(readlink -e $0)
MYDIR=$(dirname $SCRIPT_FULL_NAME)
MYNAME=$(basename $SCRIPT_FULL_NAME)

DARCS_HELPER="$MYDIR/darcs-fastimport-convert.py"

# let python (mercurial) not fail on encoding errors:
export HGENCODINGMODE="replace"

destformat="git"
yes=""

verbose=""
dryrun=""

DSTREPOTYPE="git"

cmdret=""
cmddata=""

function CMD {
    # execute a shell command
    # arguments:
    #   $1: command
    # returns:
    #   cmdret (global variable): the return code of the command
    if [ -n "$verbose" -o -n "$dryrun" ]; then
        echo "$1"
    fi
    if [ -z "$dryrun" ]; then
        bash -c "$1"
        cmdret=$?
    else
        cmdret=0
    fi
}

function CMDRET {
    # execute a shell command and catch standard out
    # arguments:
    #   $1: command
    # returns:
    #   cmdret (global variable): the return code of the command
    #   cmddata (global variable): the stdout output of the command
    if [ -n "$verbose" -o -n "$dryrun" ]; then
        echo "$1"
    fi
    cmdret=0
    # without '|| ...' the script will exit right here
    # in case of an error:
    cmddata=$(bash -c "$1") || cmdret=$?
}

function CD {
    # change directory but not when dryrun is set
    # $1: dir
    if [ -n "$verbose" -o -n "$dryrun" ]; then
        echo "cd $1"
    fi
    if [ -z "$dryrun" ]; then
        cd "$1" > /dev/null
    fi
}

function python_bin {
    # get name of python binary
    CMD "python3 --version >/dev/null 2>&1"
    if [ $cmdret == 0 ]; then
        echo "python3"
    else
        echo "python"
    fi
}

function python_check_module {
    # $1: module name
    # $2: module name in pip
    _python=$(python_bin)
    CMD "$_python -c 'import $1' 2>/dev/null"
    if [ $cmdret -ne 0 ]; then
        echo "error, you must run pip install --user $2 first"
        exit 1
    fi
}

function hg_check_command {
    # $1: command
    # $2: name of extension that must be activated
    CMD "hg help $1 >/dev/null 2>&1"
    if [ $cmdret -ne 0 ]; then
        echo "error, in $HOME/.hgrc you must add the line:"
        echo "$2="
        exit 1
    fi
}

function repotype {
    # determine the repository type
    # $1: directory
    if [ -d "$1/_darcs" ]; then
        echo "darcs"
    elif [ -d "$1/.hg" ]; then
        echo "mercurial"
    elif [ -d "$1/.git" ]; then
        echo "git"
    elif [ -d "$1/branches" -a -d "$1/objects" -a -d "$1/refs" ]; then
        # probably git bare repo
        echo "git"
    else
        echo "error, $1 is not one of the supported repository types"
        echo "git, mercurial or darcs."
        exit 1
    fi
}

function dest_repo_create {
    # create destination repository if it doesn't exist.
    # $1: name of directory
    # $2: repotype
    if [ ! -d "$1" ]; then
        if [ -z "$yes" ]; then
            echo "Directory $1 doesn't exist."
            read -p "Enter 'y' or 'Y' to create it, everything else aborts " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        if [ "$2" == "git" ]; then
            CMD "git init --bare \"$DST\""
        elif [ "$2" == "mercurial" ]; then
            CMD "hg init \"$DST\""
        else
            echo "assertion: unknown repo type: $2"
        fi
    fi
}

function print_short_help {
  echo "$MYNAME : maintain a mirror of a repository in a different repo format"
  echo "usage: $MYNAME SOURCE DEST"
  echo
  echo "The type of the source repository is automatically recognized,"
  echo "supported source repositories:"
  echo "    git mercurial darcs"
  echo ""
  echo "supported destination repositories:"
  echo "    git mercurial"
  echo
  #echo "For some conversions, a *.marks file in the source repository tracks"
  #echo "which patches were already converted."
  #echo ""
  echo "options:"
  echo "-h --help   : this help"
  echo "-t --repotype REPOTYPE:"
  echo "              Specify the repository type of the destination."
  echo "              Note: This is only needed if the destination doesn't exist."
  echo "              Possible values of REPOTYPE:"
  echo "                  git        : git (the default)"
  echo "                  hg         : mercurial"
  echo "                  mercurial  : mercurial"
  echo "--enc ENCODING:"
  echo "              Set environment encoding to this value."
  echo "              This may be needed to convert repositories that"
  echo "              are not UTF-8 encoded. Example:"
  echo "                iso8859-1 : ISO8850-1 encoding"
  echo "--hgrc HGRCFILE:"
  echo "              Specify the .hgrc file. This sets the environment"
  echo "              variable HGRCPATH (see mercurial documentation)."
  echo 
  echo "-y --yes    : Create destination reposity if it doesn't exist"
  echo "              without prompting the user"
  echo "-v --verbose: Show what the script does"
  echo "-n --dry-run: Just show what the script would do"
  exit 0
}

declare -a ARGS
skip_options=""

while true; do
    case "$1" in
        -h | --help)
            # if the "less" is present, use it:
            if less -V >/dev/null 2>&1; then
                # use less pager for help:
                $SCRIPT_FULL_NAME --help-raw | less
                exit 0
            else
                print_short_help
                exit 0
            fi
            ;;
        --help-raw)
            print_short_help
            exit 0
            ;;
        --enc)
            LANG=$(echo $LANG | sed -e "s/\..*/.$2/")
            shift 2
            ;;
        -t| --repotype)
            DSTREPOTYPE="$2"
            if [ "$DSTREPOTYPE" == "hg" ]; then
                DSTREPOTYPE="mercurial"
            fi
            shift 2
            ;;
        --hgrc)
            export HGRCPATH="$2"
            shift 2
            ;;
        -y | --yes)
            yes="yes"
            shift
            ;;
        -v | --verbose)
            verbose="yes"
            shift
            ;;
        -n | --dry-run)
            verbose="yes"
            dryrun="yes"
            shift
            ;;
        -- )
            skip_options="yes"
            shift;
            break
            ;;
        *)
            if [ -z "$1" ]; then
                break;
            fi
            if [[ $1 =~ ^- ]]; then
                echo "unknown option: $1"
                exit 1
            fi
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [ -n "$skip_options" ]; then
    while true; do
        if [ -z "$1" ]; then
            break;
        fi
        ARGS+=("$1")
        shift
    done
fi

SRC=""
DST=""

for arg in "${ARGS[@]}"; do
    # examine extra args
    # match known args here like:
    # if [ "§arg" == "doit" ]; then ...
    #     continue
    # fi
    if [ -z "$SRC" ]; then
        SRC="$arg"
        continue
    fi
    if [ -z "$DST" ]; then
        DST="$arg"
        continue
    fi
    echo "unexpeced argument: $arg"
    exit 1
done

if [ -z "$SRC" ]; then
    echo "error, SOURCE is missing"
    exit 1
fi
if [ -z "$DST" ]; then
    echo "error, DEST is missing"
    exit 1
fi

if [ ! -d "$SRC" ]; then
    echo "error, not a directory: $SRC"
    exit 1
fi

SRC_ABS=$(readlink -e "$SRC")

SRCREPOTYPE=$(repotype "$SRC")

if [ -d "$DST" ]; then
    DSTREPOTYPE=$(repotype "$DST")
else
    dest_repo_create "$DST" "$DSTREPOTYPE"
fi

if [ "$DSTREPOTYPE" == "git" ]; then
    # make path absolute:
    DST=$(readlink -e "$DST")
    CD "$SRC"

    if [ "$SRCREPOTYPE" == "darcs" ]; then
        #CMD "touch $DST/darcs2git.marks"
        #CMD "darcs convert export --read-marks darcs2git.marks --write-marks darcs2git.marks | (cd \"$DST\" && git fast-import --import-marks=darcs2git.marks --export-marks=darcs2git.marks)"
        CMD "darcs convert export | $DARCS_HELPER | (cd \"$DST\" && git fast-import)"
    elif [ "$SRCREPOTYPE" == "mercurial" ]; then
        python_check_module "hggit" "hg-git"
        hg_check_command "hggit" "hggit"
        CMD "hg bookmarks -r default master"
        CMD "hg update -r master"
        CMD "hg push \"$DST\""
    elif [ "$SRCREPOTYPE" == "git" ]; then
        echo "error, cannot convert git to git."
        exit 1
    fi

elif [ "$DSTREPOTYPE" == "mercurial" ]; then
    # make path absolute:
    DST=$(readlink -e "$DST")
    CD "$SRC"
    if [ "$SRCREPOTYPE" == "darcs" ]; then
        python_check_module "hgext3rd.fastimport" "hg-fastimport"
        hg_check_command "fastimport" "fastimport"
        # note: python fastimport doesn't work when 
        # the export command uses --import-marks and --export-marks:
        CMD "darcs convert export | $DARCS_HELPER > \"$DST/FASTIMPORT\""
        # Note: Currently mercurial fastimport has a problem here:
        #   If the mercurial repo already exists and the darcs
        #   repo has just one new tag, nothing else, that tag 
        #   is not imported. New Tags are only imported when they are 
        #   accompanied by other new regular patches.
        CMD "(cd \"$DST\" && hg fastimport --traceback FASTIMPORT && rm -f FASTIMPORT)"
    elif [ "$SRCREPOTYPE" == "git" ]; then
        python_check_module "hggit" "hg-git"
        hg_check_command "hggit" "hggit"
        CMD "(cd \"$DST\" && hg pull -u \"$SRC_ABS\")"
        #python_check_module "hgext3rd.fastimport" "hg-fastimport"
        #hg_check_command "fastimport" "fastimport"
        ## note: python fastimport doesn't work when 
        ## the export command uses --import-marks and --export-marks:
        #CMD "git fast-export --all > \"$DST/FASTIMPORT\""
        #CMD "(cd \"$DST\" && hg fastimport FASTIMPORT && rm -d FASTIMPORT)"
    elif [ "$SRCREPOTYPE" == "mercurial" ]; then
        echo "error, cannot convert mercurial to mercurial."
        exit 1
    fi
else
    echo "unsupported destination repository type: $DSTREPOTYPE"
    exit 1
fi

