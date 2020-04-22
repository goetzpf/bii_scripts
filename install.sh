#!/bin/bash


HOSTNAME=$(hostname -f)

if [ -z "$1" ]; then
    if echo $HOSTNAME| grep '\(aragon\|jalon\|elbe\|stretch\)\.acc\.bessy\.de' -q ; then
        echo "darcs pull is executed in order to prevent"
        echo "you from installing old program versions by accident"
        darcs pull
        BII_CONFIG=config.acc make all
        sg scrptdev -c "BII_CONFIG=config.acc make -e install"
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
BII_CONFIG=config INSTALL_PREFIX=$INSTALLDIR make -s -e install

SETENV="$INSTALLDIR/setenv.sh"
echo "PATH=$ABS_INSTALLDIR/bin:\$PATH" > "$SETENV"
echo "PERL5LIB=$ABS_INSTALLDIR/lib/perl:\$PERL5LIB" >> "$SETENV"
echo "PYTHONPATH=$ABS_INSTALLDIR/lib/python:\$PYTHONPATH" >> "$SETENV"

echo "Installation finished."
echo "You may want to source file $SETENV to set your environment variables."
