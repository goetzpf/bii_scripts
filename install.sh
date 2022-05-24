#!/bin/bash

HOSTNAME=$(hostname -f)

if [ -z "$1" ]; then
    if echo $HOSTNAME| grep -E '(elbe|stretch|bullseye)\.acc\.bessy\.de' -q ; then
        SHORTHOST=$(echo $HOSTNAME | sed -e 's/\..*//')
        echo "darcs pull is executed in order to prevent"
        echo "you from installing old program versions by accident"
        darcs pull
        # force bii_scripts.config to be remade:
        rm -f out/script/bii_scripts.config
        BII_CONFIG=config.$SHORTHOST.acc make -sj install
        exit
    fi
    echo "usage: $0 [install-directory]"
    exit 
fi

if [ "$1" = "-h" -o "$1" = "--help" ]; then
    echo "usage: $0 [install-directory]"
    exit 
fi

INSTALLDIR=$1

if [ ! -d $INSTALLDIR ]; then
    echo "error: directory $INSTALLDIR doesn't exist"
    exit 1
fi

ABS_INSTALLDIR=$(readlink -e "$INSTALLDIR")

#mkdir -p $INSTALLDIR/bin $INSTALLDIR/share/html/bii_scripts $INSTALLDIR/lib/perl $INSTALLDIR/lib/python

# force bii_scripts.config to be remade:
rm -f out/script/bii_scripts.config
INSTALL_PREFIX=$INSTALLDIR make -sj install

