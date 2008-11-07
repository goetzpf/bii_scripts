#! /usr/bin/env perl

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
    
