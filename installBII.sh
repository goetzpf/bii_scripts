#!/bin/sh
INSTALL=opiadm@opic11c.ctl.bessy.de:/opt/OPI/bii_scripts
rsync -e ssh --chmod a+r --delete -avz ./lib/	$INSTALL/lib/
rsync -e ssh --chmod a+r --delete -avz ./bin/	$INSTALL/bin/
