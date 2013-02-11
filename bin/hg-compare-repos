#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ] || [ "$1" = "-h" ]; then
        echo "This script compares the logs of two mercurial repositories."
        echo "usage: $0 [directory1] [directory2]"
        exit 1
fi

HGTEMPLATE="--------------------------------------------------\n{desc}\n\nFiles:\n{files}\n"


TMPFILE1=`mktemp /tmp/hg-compare.XXXXXXXXXX` || exit 1
TMPFILE2=`mktemp /tmp/hg-compare.XXXXXXXXXX` || exit 1

echo "creating $TMPFILE1 and $TMPFILE2"

hg log --template $HGTEMPLATE -R $1 > $TMPFILE1
#hg log -R $1 > $TMPFILE1
if [ $? -ne 0 ] ; then
        rm -f $TMPFILE1 $TMPFILE2
        exit 1
fi

hg log --template $HGTEMPLATE -R $2 > $TMPFILE2
#hg log -R $2 > $TMPFILE2
if [ $? -ne 0 ] ; then
        rm -f $TMPFILE1 $TMPFILE2
        exit 1
fi

tkdiff $TMPFILE1 $TMPFILE2 -L $1 -L $2

rm -f $TMPFILE1 $TMPFILE2
