eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

# @STATUS: release
# @PLATFORM: home bessy
# @CATEGORY: search


# [scriptname] -- describe the function here

use strict;

use FindBin;
use File::Spec;
use Getopt::Long;

use parse_subst;

use vars qw($opt_help $opt_summary $opt_file);

my $sc_version= "1.0";

my $sc_name= $FindBin::Script;
my $sc_summary= "pretty-print a substitution file";
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2007";

my $debug= 0; # global debug-switch

my $tmpdir= "$ENV{HOME}/tmp";


Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary","file|f=s", 
                ))
  { die "parameter error!\n"; };

if ($opt_help)
  { help();
    exit;
  };

if ($opt_summary)
  { print_summary();
    exit;
  };

my $r_h;

$r_h= parse_subst::parse_file($opt_file);
parse_subst::create($r_h);

exit(0);
# ------------------------------------------------

# fit in program text here

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
    -f --file [file] : read that substitution file
END
  }

