#!/bin/sh

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
# 
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

. lockfile.sh

dir=_darcs/third-party/darcs-monitor
recipients=$(cat $dir/recipients | tr '\n' ',')
lockfile=$dir/lock

with_lock $lockfile 10
/opt/csr/bin/darcs-monitor "$@" -q email $recipients
