#!/usr/bin/env perl

# Copyright 2022 Helmholtz-Zentrum Berlin für Materialien und Energie GmbH
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

# change msi output:
# $(xxx,undefined)  --> $(xxx)
# $(xxx,recursive)  --> $(xxx)
#
# Goetz Pfeiffer <Goetz.Pfeiffer@helmholtz-berlin.de>
# 2014

use strict;

my @new;
my $ofile= undef;
my $get_file= undef;
my $get_msi= undef;
my $msi= "msi";

my $help= undef;

foreach my $a  (@ARGV)
  {
    if ($get_file)
      {
        $ofile= $a;
        $get_file= undef;
        next;
      }
    if ($get_msi)
      {
        $msi= $a;
        $get_msi= undef;
        next;
      }
    if ($a eq "-o")
      { 
        $get_file= 1;
        next;
      }
    if ($a eq "-p")
      {
        $get_msi= 1;
        next;
      }
    if ($a eq "-h")
      {
        $help= 1;
      }
    # add all arguments quoted in case they contain spaces:
    if ($a=~/\s/)
      {
        push @new, qq("$a");
      }
    else
      {
        push @new, $a;
      }
  }

if (defined $help)
  {
    printf("msi.pl - an msi wrapper\n\n");
    printf("This program removes unwanted 'undefined' and 'recursive'\n");
    printf("strings from msi output.\n\n");
    printf("special options here:\n");
    printf("    -p <PATH> : specify MSI program\n\n");
    printf("original msi help follows:");
    system("msi -h");
    exit(0);
  }

if (defined $ofile)
  {
    open(FILE, ">$ofile") or die "can't create $ofile";
  }
else
  {
    *FILE= *STDOUT;
  }

my $cmd= "$msi ".join(" ",@new)." |";

open(MSI, $cmd) || die "can't fork: $!";

while (my $line=<MSI>) 
  {
    if ($line!~/\$/)
      {
        print FILE $line;
        next;
      }
    if ($line!~/,/)
      {
        print FILE $line;
        next;
      }
    $line=~ s/\$\(([^,]+),(?:undefined|recursive)\)/\$\($1\)/g;
    print FILE $line;
  }

if (defined $ofile)
  {
    close FILE;
  }


