#! /usr/bin/env perl

# Copyright 2015 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
# <https://www.helmholtz-berlin.de>
#
# Author: Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
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

if ($#ARGV<1)
  { die "$0:\n    copies files and changes the extension\n".
        "    usage: [new-extension] [files]\n"; 
  }

my $newext= shift(@ARGV);
$newext=~ s/^\.//;
my @new;
foreach my $f (@ARGV)
  { if (!-e $f) { die "error: \"$f\" doesn't exist\n"; };
    if (-d $f)  { die "error: \"$f\" is a directory\n"; };
    my $new=$f;
    $new=~ s/\.[^\.]*$//;
    $new= "$new.$newext";
    if (-e $new) { die "error, \"$f\" already exists!\n"; };
    push @new,$new;
  }
for(my $i=0; $i<=$#ARGV; $i++)
  { my $cmd= "cp $ARGV[$i] $new[$i]";
    if (0!=system($cmd))
      { warn "warning: \"$cmd\" failed!\n"; }
    else
      { print "$cmd\n"; }
  }
print "finished\n";
    
