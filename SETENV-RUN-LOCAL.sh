# Source this script in order to run the scripts locally!

BII_SCRIPTS_TOP=$PWD

BII_SCRIPTS_BIN="$BII_SCRIPTS_TOP/bin"
BII_SCRIPTS_LIB_PERL="$BII_SCRIPTS_TOP/lib/perl"
BII_SCRIPTS_LIB_PYTHON="$BII_SCRIPTS_TOP/lib/python"

# check if we are in the right directory:
dir_ok="yes"
if [ ! -d "$BII_SCRIPTS_BIN" ]; then
    dir_ok=""
fi
if [ ! -d "$BII_SCRIPTS_LIB_PERL" ]; then
    dir_ok=""
fi
if [ ! -d "$BII_SCRIPTS_LIB_PYTHON" ]; then
    dir_ok=""
fi

if [ -z "$dir_ok" ]; then
    echo "error: Your current working directory must be the"
    echo "       bii_scripts project, aborting."
else
    # make scripts executable:
    chmod u+rwx $BII_SCRIPTS_BIN/*

    # set environment:
    export PERL5LIB=$BII_SCRIPTS_LIB_PERL:$PERL5LIB
    export PYTHONPATH=$BII_SCRIPTS_LIB_PYTHON:$PYTHONPATH
    PATH=$BII_SCRIPTS_BIN:$PATH

    # set prompt:
    PS1="bii-scr $PS1"
fi
