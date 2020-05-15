# Source this script in order to run the scripts locally!

BII_SCRIPTS_TOP=$(dirname $(readlink -e $0))

# make scripts executable:
chmod u+rwx $BII_SCRIPTS_TOP/bin/*

# set environment:
export PERL5LIB=$BII_SCRIPTS_TOP/lib/perl:$PERL5LIB
export PYTHONPATH=$BII_SCRIPTS_TOP/lib/python:$PYTHONPATH
PATH=$BII_SCRIPTS_TOP/bin:$PATH
export BII_SCRIPTS_SHARE_DIR=$BII_SCRIPTS_TOP/share

# set prompt:
PS1="bii-scr $PS1"
