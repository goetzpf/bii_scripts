#!/bin/sh

. lockfile.sh

dir=_darcs/third-party/darcs-monitor
recipients=$(cat $dir/recipients | tr '\n' ',')
lockfile=$dir/lock

with_lock $lockfile 10
/opt/csr/bin/darcs-monitor "$@" -q email $recipients
