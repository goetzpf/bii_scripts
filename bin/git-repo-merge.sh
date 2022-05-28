#!/bin/bash

SCRIPT_FULL_NAME=$(readlink -e $0)
MYDIR=$(dirname $SCRIPT_FULL_NAME)
MYNAME=$(basename $SCRIPT_FULL_NAME)

if [ "$1" == "-h" -o "$1" == "--help" -o -z "$1" ]; then
    echo "Usage: $MYNAME MYREPO OTHERREPO BRANCHNAME"
    echo
    echo "Puts all commits from OTHERREPO that are not part of MYREPO"
    echo "into MYREPO at a new branch BRANCHNAME"
    echo
    echo "Note: MYREPO *must be* a working tree repository, not a bare repository."
    exit 1
fi

MYREPO="$1"
OTHERREPO="$2"
BRANCHNAME="$3"
if [ -z "$BRANCHNAME" ]; then
    echo "error, too few parameters"
fi

if [ ! -d "$MYREPO" ]; then
    echo "error, $MYREPO doesn't exist"
fi
if [ ! -d "$OTHERREPO" ]; then
    echo "error, $OTHERREPO doesn't exist"
fi

OTHERREPO=$(readlink -e $OTHERREPO)

# get the last common commit hash of the two repos:
COMMIT=$(comm --nocheck-order -12 <(git -C "$MYREPO" log --reverse --pretty=format:"%H") <(git -C "$OTHERREPO" log --reverse --pretty=format:"%H") | tail -n 1)

cd $MYREPO
# go to last common commit:
git checkout $COMMIT

# add OTHERREPO under name "other":
git remote add other $OTHERREPO

# create branch BRANCHNAME:
git checkout -b $BRANCHNAME

# fetch all commits from OTHERREPO:
git fetch other

# now set branch BRANCHNAME to track branch "master" from OTHERREPO:
git branch --set-upstream-to=other/master $BRANCHNAME

# pull all commits to new branch BRANCHNAME:
git pull

# remove entry "other", this is no longer needed:
git remote remove other

# go back to "master":
git checkout master

# garbage collection:
git gc

