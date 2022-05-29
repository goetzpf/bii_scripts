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

function print_short_help {
  echo "$MYNAME : create a short repository hash file."
  echo "usage: $MYNAME REPOSITORY [HASHFILE]"
  echo
  echo "If HASHFILE is not given, print the hash to the console."
  echo "    Returns always returncode 0."
  echo
  echo "If HASHFILE is given:"
  echo "    Create HASHFILE if it doesn't exist of if the hash has changed"
  echo "    with respect to the existing file."
  echo "    Returns 0 if the hash has changed and 1 if it has not changed."
  echo
  echo "The type of the source repository is automatically recognized,"
  echo "supported repositories:"
  echo "    git mercurial darcs"
  echo ""
  #echo "For some conversions, a *.marks file in the source repository tracks"
  #echo "which patches were already converted."
  #echo ""
  echo "options:"
  echo "-h --help   : this help"
  echo "-v --verbose: Show what the script does"
  echo "-n --dry-run: Just show what the script would do"
  exit 0
}

REPOSITORY=""
HASHFILE=""

cmdret=""
cmddata=""

returncode=0

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

function githash {
    # create hash for git repo
    # $1: dir
    CMDRET "(cd $1 && git log --pretty=format:'%H' | md5sum | sed -e 's/ .*//')"
    echo "$cmddata"
}

function darcshash {
    # create hash for git repo
    # $1: dir
    CMDRET "(cd $1 && darcs log | grep patch | md5sum | sed -e 's/ .*//')"
    echo "$cmddata"
}

function hghash {
    # create hash for git repo
    # $1: dir
    CMDRET "(cd $1 && hg log --template '{node}\n' | md5sum | sed -e 's/ .*//')"
    echo "$cmddata"
}

function repohash {
    # hash for git repos
    # $1: directory
    # $2: hashfile (optional)
    local REPODIR="$1"
    local HASHFILE="$2"
    REPOTYPE=$(repotype "$REPODIR")
    if [ "$REPOTYPE" == "git" ]; then
        HASH="$(githash "$REPODIR")"
    elif [ "$REPOTYPE" == "mercurial" ]; then
        HASH="$(hghash "$REPODIR")"
    elif [ "$REPOTYPE" == "darcs" ]; then
        HASH="$(darcshash "$REPODIR")"
    else
        echo "internal error, unexpected REPOTYPE $REPOTYPE" >&2
        exit 1
    fi
    if [ -z "$HASHFILE" ]; then
        echo "$HASH"
        return
    fi
    OLDHASH=""
    if [ -e $HASHFILE ]; then
        OLDHASH=$(cat $HASHFILE)
    fi
    if [ "$OLDHASH" != "$HASH" ]; then
        CMD "echo \"$HASH\" > $HASHFILE"
    else
        returncode=1
    fi
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

for arg in "${ARGS[@]}"; do
    # examine extra args
    # match known args here like:
    # if [ "§arg" == "doit" ]; then ...
    #     continue
    # fi
    if [ -z "$REPOSITORY" ]; then
        REPOSITORY="$arg"
        continue
    fi
    if [ -z "$HASHFILE" ]; then
        HASHFILE="$arg"
        continue
    fi
    echo "unexpeced argument: $arg"
    exit 1
done

if [ -z "$REPOSITORY" ]; then
    echo "error, REPOSITORY is missing"
    exit 1
fi

if [ ! -d "$REPOSITORY" ]; then
    echo "error, not a directory: $REPOSITORY"
    exit 1
fi

repohash "$REPOSITORY" "$HASHFILE"
exit $returncode

