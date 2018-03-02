#!/bin/sh
INSTALL=opiadm@nfs.ctl.bessy.de:/opt/OPI/bii_scripts
#INSTALL=opiadm@nfs.ctl.erl.site:/opt/OPI/bii_scripts
rsync -e ssh --chmod a+r --delete -avz ./lib/	$INSTALL/lib/
rsync -e ssh --chmod a+r --delete -avz ./bin/	$INSTALL/bin/
