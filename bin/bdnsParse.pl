eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
  if 0;

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
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

use strict;
use BDNS;
use Data::Dumper;

if ($#ARGV < 0) {
    print "USAGE: bdnsParse.pl DEVNAME1 ...\n";
    exit(1);
}
#my @tags = qw(Member Index-ALL Index SubIndex Family Counter Subdomain-All Subdomain Subdomain-Pre Subdomain-Number Domain Facility);

foreach my $devname (@ARGV) {
	my @parts = BDNS::parse($devname);
#    print map{"$_->[1]\t$_->[0]\n"} map {[$tags[$_], $parts[$_]]} (0 .. $#parts);


    print   "$devname:\n".
            "\tMember    $parts[0]\n".
            "\tIndex     $parts[1]\n".
            "\tFamily    $parts[4]\n".
            "\tCounter   $parts[5]\n".
            "\tSubdomain $parts[8]$parts[9]\n".
            "\tDomain    $parts[10]\n".
            "\tFacility  $parts[11]\n";
}
