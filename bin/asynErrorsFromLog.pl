#!/usr/bin/env perl
## asynErrorsFromLog.pl:

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Bernhard Kuner <Bernhard.Kuner@helmholtz-berlin.de>
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

$usage = "USAGE: asynErrorsFromLog.pl sioc_N_.log\n\nparse logfile and show statistic of timouts\n";
use Data::Dumper;

if($ARGV[0] eq "-h") {
    print $usage;
    exit(0);
}

print "asynErrorsFromLog.pl: $ARGV[0]\n";
open(IN_FILE, "<$ARGV[0]") or die "can't open input file '$ARGV[0]': $!";

%conn;
%dev;
while(<IN_FILE>) {
    if($_=~/ (IP\d+||L\d+) (.*?): No reply from device/) {
        $dev{$1}{$2} += 1;
        $conn{$1} += 1;
    }
}
print "Device Errors:\n",Dumper(\%dev),"\nConnection Errors:\n";
foreach $con (sort(keys(%conn))) {
    print "$con\t$conn{$con}\n";
}
