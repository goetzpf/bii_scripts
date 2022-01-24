#!/usr/bin/perl

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

while (<>) {
  chomp;
  if (
    /
    ([A-Z]+)                  # member
    ([0-9]+(-[0-9]+)?)?       # index and subindex
    ([BCFGHIKLMNOPQRSTVWYZ])  # family
    ([0-9]*)                  # counter
    ([BCDEGKLMSTUX][0-9]*)    # subdomain
    ([BCDEGHILMRSTV])         # domain
    ([FP]?)                   # facility
    /x
  ) {
    print "input=$_ member=$1 index=$2 subindex=$3 family=$4 counter=$5 subdomain=$6 domain=$7 facility=$8\n";
  }
}
