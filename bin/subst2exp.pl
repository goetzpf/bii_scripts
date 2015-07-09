eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

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


# @STATUS: release
# @PLATFORM: home bessy
# @CATEGORY: search


# [scriptname] -- describe the function here

use strict;

use FindBin;
use Getopt::Long;
use Text::ParseWords;
use parse_subst;

use vars qw($opt_help $opt_summary $opt_global $opt_simple $opt_reverse);


my $sc_version= "1.1";

my $sc_name= $FindBin::Script;
my $sc_summary= "convert substitution-files to expander format"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2006";

my $debug= 0; # global debug-switch


#Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary","global|g","simple|s","reverse|r"
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

# ------------------------------------------------

undef $/;
my $st= <>;

if (defined $opt_simple)
  { my $r_h= parse_simple(\$st); 
    print_hash($r_h);
    exit(0);
  }

my $r_templates= parse_subst::parse(\$st);


foreach my $k (sort keys %$r_templates)
  { my $r_l= $r_templates->{$k};

    print "\n# ","-" x 50,"\n"; 
    print "# instantiations of \"$k\"\n";
    print "# ","-" x 50,"\n\n"; 

    foreach my $r_h (@$r_l)
      { 
	print "\$begin\\\n" if (!$opt_global);

#    parse_subst::dump($r_h); die;
        print_hash($r_h); 

	print "\$include(\"$k\")\\\n";
	print "\$end\\\n" if (!$opt_global);
      }    
  }
# fit in program text here

sub print_hash
  { my($r_h)= @_;

    if (!$opt_reverse)
      { print "\$set(\n";
        my $val;
	foreach my $n (sort keys %$r_h)
	  { $val= $r_h->{$n};
	    $val=~ s/([\$\@])/\\\\$1/g;
	    printf "     \$%-15s = \"%s\";\n",$n,$val; 
	  }
        print "    )\\\n";
      }
    else
      {	print "\\\$set(\n";
        foreach my $n (sort keys %$r_h)
	  { printf "     \\\$%-15s = \"%s\";\n",$n,$r_h->{$n}; 
	  }
        print "    )\\\n";
      }
  }    

sub parse_simple
  { my($r_st)= @_;
    my @words;
    my %words;

    my @l= split(/\s*,\s*[\r\n]+/,$$r_st); 

    foreach my $l (@l) 
      { push @words, quotewords(q([\s\r\n]*[=,][\s\r\n]*),0,$l); }; 

    if ((($#words+1) & 1) == 1)
      { die "file cannot be parsed (odd number of words)"; };

    %words= @words;  

    return(\%words);
  }    

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
    -g use only global variables (no \$begin or \$end)
    -s --simple : the input is not a regular substitution-file 
      but a file containing name-value pairs, each one in a single line
      like in 
        MYVAR="MYCONTENT"
    -r : quote the dollar-signs in the variable names instead of 
         dollar-sings in the contents	

  example of usage:
  1. with global variables (more msi-compatible), searches template files
     in directory "template_dir", prints result to stdout:

    subst2exp.pl -g  < myapp.substitutions | expander.pl -I template_dir -b -n -F  

  2. like the example above but without global variables, warns when a 
     variable is not defined:

    subst2exp.pl   < myapp.substitutions | expander.pl -I template_dir -b -n -F  

  3. like the example above (2) but dies when a 
     variable is not defined. A good test to find undefined variables
     (a thing that msi cannot do) and correct these errors in the
     substitution-file:

    subst2exp.pl   < myapp.substitutions | expander.pl -I template_dir -b -F  


END
  }

