#!/bin/sh
/opt/csr/bin/darcs-monitor "$@" -q email `cat _darcs/third-party/darcs-monitor/recipients | tr '\n' ','`
