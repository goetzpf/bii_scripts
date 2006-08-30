eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

# @STATUS: release
# @PLATFORM: home bessy
# @CATEGORY: search


# for the format of the macros, see the documentation of expander.pm
# (e.g. man expander or 
#  perldoc expander.pm)

use strict;
use Data::Dumper;

use FindBin;

# enable this if you want to search modules like dbitable.pm
# relative to the location of THIS script:
# ------------------------------------------------------------
# use lib "$FindBin::RealBin/../lib/perl";

BEGIN
  { # search the arguments for the "--locallibs"
    # option. If it is found, remove the option
    # and add $FindBin::Bin to the head of the
    # module search-path.
    if (exists $ENV{MYPERLLIBS})
      { my @dirs=split(/:/,$ENV{MYPERLLIBS});
        unshift @INC,split(/:/,$ENV{MYPERLLIBS});
      };
  };

use Getopt::Long;

use expander;

use vars qw($opt_help $opt_summary @opt_file $opt_roundbrackets);


my $sc_version= "1.0";

my $sc_name= $FindBin::Script;
my $sc_summary= "performs expansion of macros in a file"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2005";

my $debug= 0; # global debug-switch

# global parameter hash:
                  
#Getopt::Long::config(qw(no_ignore_case));

my @files;
my @macros;

if (!GetOptions("help|h","summary",
		"file|f=s" => \@files, 
		"macros|m=s" => \@macros,
		"roundbrackets|b",
                ))
  { die "parameter error!\n"; };

if ($opt_help)
  { help();
    exit;
  };

my %expand_options;

if ($opt_roundbrackets)
  { $expand_options{roundbrackets}= 1; }

if ($opt_summary)
  { print_summary();
    exit;
  };

if (!@files)
  { die "-f option is mandatory\n"; };

if (@macros)
  { foreach my $mac (@macros)
      { my @items= split(/,/,$mac);
        foreach my $m (@items)
          { my($name,$val)= split(/=/,$m);
            die "not recognized: $m" if (!defined $val);
	    expander::set_var($name,$val);
	  };  
      };
  }
# ------------------------------------------------

foreach my $f (@files)
  { 
    expander::parse_file($f,%expand_options); 
  
  };


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

Usage:
  $sc_name {options}

  options:
    -h: help
    -f [file]: process file(s)
    -b: allow round brackets for variables like in \$(myvar)
    --summary: give a summary of the script
    -m [name=value] define a macros 
      more than one -m option is allowed

Short (incomplete) syntax description (see also manpage of expander.pm)

\$name			-> macro replacement
\$name[index]		-> indexed macro replacement
\$set(<expression>)	-> evaluate without printing

\$set(\$name1= "value1";
     \$name2= "value2")  -> macro definition

\$eval(<expression>)	-> evaluate with printing

\$perl(<expression>)    -> evaluate a plain perl-expression. Access
			   to variables is only possible with 
			   get_var() and set_var() but this construct
			   can be used import perl-modules or define
			   functions. 

\$if (<expression>)
\$else
\$endif			-> conditional parsing
		
\$for(<init-expr>;<condition-expression>;<loop-expr)
\$endfor			
			-> parsing-loop

\$comment (comment)	-> comment

\$include (<expression>) -> include the specified file

<expression>: many simple expressions that are valid in perl
can be used here 

END
  }

