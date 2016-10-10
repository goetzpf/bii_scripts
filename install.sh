#!/bin/sh


HOSTNAME=$(hostname -f)

if [ -z "$1" ]; then
    if echo $HOSTNAME| grep '\(aragon\|jalon\|elbe\)\.acc\.bessy\.de' -q ; then
        echo "darcs pull is executed in order to prevent"
        echo "you from installing old program versions by accident"
        darcs pull
        make all
        sg scrptdev -c "make install"
        exit
    fi
    echo "usage: $0 [install-directory]"
    exit 
fi

INSTALLDIR=$1

if [ ! -d $INSTALLDIR ]; then
    echo "error: directory $INSTALLDIR doesn't exist"
    exit 1
fi

mkdir -p $INSTALLDIR/bin $INSTALLDIR/share/html/bii_scripts $INSTALLDIR/lib/perl $INSTALLDIR/lib/python
USE_RSYNC=no INSTALL_PREFIX=$INSTALLDIR make -s -e install
