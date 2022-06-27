#!/bin/bash

FULLHOSTNAME=$(hostname -f)
HOSTNAME=$(echo $FULLHOSTNAME | sed -e 's/\..*//')
DOMAINNAME=$(echo $FULLHOSTNAME | sed -e 's/^[^\.]\+\.\?//')

if [ "$1" = "-h" -o "$1" = "--help" ]; then
    echo "usage: $0 [install-directory]"
    exit 
fi

if [ -z "$1" ]; then
    CONFIG="config.$FULLHOSTNAME"
    if [ ! -e "$CONFIG" ]; then
        if [ -n "$DOMAINNAME" ]; then
            CONFIG="config.$DOMAINNAME"
        fi
    fi
    if [ ! -e "$CONFIG" ]; then
        echo "usage: $0 [install-directory]"
        exit 
    fi
    echo "darcs pull is executed in order to prevent"
    echo "you from installing old program versions by accident"
    darcs pull
    # force bii_scripts.config to be remade:
    rm -f out/script/bii_scripts.config
    BII_CONFIG="$CONFIG" make -sj install
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

