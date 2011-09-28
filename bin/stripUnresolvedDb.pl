#!/usr/bin/env perl
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
