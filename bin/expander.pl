eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

# @STATUS: release
# @PLATFORM: home bessy
# @CATEGORY: search


# [scriptname] -- describe the function here

# syntax:
# expands ${name} to the content of <name>
# expressions:
# $if (expression)
# $else
# $endif
# $eval(expression) : evaluate expression
# quoting:
# '\$' expands to '$', no special replacements are made


use strict;
use Data::Dumper;

use FindBin;
use Getopt::Long;

use lib ".";
use expander;

use vars qw($opt_help $opt_summary $opt_file $opt_lazy $opt_arrays);


my $sc_version= "0.9";

my $sc_name= $FindBin::Script;
my $sc_summary= "performs expansion of macros in a file"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2005";

my $debug= 0; # global debug-switch

# global parameter hash:
                  
#Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary",
		"file|f", "lazy|l", "arrays|a",
                ))
  { die "parameter error!\n"; };

if ($opt_help)
  { help();
    exit;
  };

if ($opt_lazy)
  { $expander::is_lazy=1; };

if ($opt_arrays)
  { $expander::use_arrays=1; };

if ($opt_summary)
  { print_summary();
    exit;
  };

# ------------------------------------------------

expander::parse_file($opt_file,\*STDOUT);


# ------------------------------------------------

sub print_summary
  { printf("%-20s: $sc_summary\n",
           $sc_name);
  }

sub h_center
  { my($st)= @_;
    return( (' ' x (38 - length($st)/2)) . $st );
  }

sub help
  { my $l1= h_center("**** $sc_name $sc_version -- $sc_summary ****");
    my $l2= h_center("$sc_author $sc_year");
    print <<END;

$l1
$l2

Syntax:
  $sc_name {options} [arg1] [arg2]

  options:
    -h: help
    --summary: give a summary of the script
    -l : lazy syntax, allow \$name instead of \${name}
    -a : allow arrays
    -f [file]: process file
END
  }

