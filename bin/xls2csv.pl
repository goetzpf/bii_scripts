#!/usr/bin/env perl
# Call xls2cvs from catdoc package with better error handling

# * xls2csv sometimes prints "Format a4 is redefined" on stderr. This message
#   is supressed.
# * xls2csv always returns with return code 0. This script returns 1 if xls2csv
#   printed something else than "Format a4 is redefined" on stderr.

use strict;
use IPC::Open3;

use vars qw($opt_help $opt_summary);

my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2014";


my $cmd= "xls2csv ".join(" ",@ARGV);

#print STDERR "call: $cmd\n";

my $pid = open3( \*WRITER, \*READER, \*ERROR, $cmd);
#if \*ERROR is 0, stderr goes to stdout

while( my $output = <READER> ) 
  {
    print STDOUT $output;
  }

my $error=0;
while( my $errout = <ERROR> ) 
  {
    if ($errout =~ /^Format a4 is redefined\s*$/)
      { next; }
    $error= 1;
    print STDERR $errout;
  }

waitpid( $pid, 0 ) or die "$!\n";
my $retval =  $? >> 8;
if ($retval!=0)
  { 
    exit($retval);
  }
exit($error);

