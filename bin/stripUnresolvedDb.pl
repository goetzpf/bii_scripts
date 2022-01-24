#!/usr/bin/env perl

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Bernhard Kuner <bernhard.kuner@helmholtz-berlin.de>
# Contributions by:
#         Benjamin Franksen <Benjamin.Franksen@helmholtz-berlin.de>
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

## stripUnresolvedDb.pl
#  ******************************
#  
#     USAGE:  stripUnresolvedDb.pl inputFile.substitutions
#  
#  remove all unresolved fields from a database. Means all fields 
#  that contain some variables $(VARIABLE).
#
  use strict;
  no strict "refs";
  
  my $filename = shift @ARGV; # input file

  die "missing paramter: inputFile\n USAGE:  stripUnresolvedDb.pl inputFile.substitutions \n" unless defined $filename;

  #print "strip unresolved fields from: $filename \n";

  my( $file, $r_substData);
  open(IN_FILE, "<$filename");

  my @lines;
  my @sortedNames;
  my $templateName;
  while( <IN_FILE> )
  { if( ! /\$\(/ )
    { push @lines, $_;
    };
  }
  close IN_FILE;
  open(OUT_FILE, ">$filename") or die "can't open output file: $filename";
  foreach (@lines)
  { print OUT_FILE $_;
  }
  close OUT_FILE;
