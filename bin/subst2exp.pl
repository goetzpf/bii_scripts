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
use Getopt::Long;
use parse_subst;

use vars qw($opt_help $opt_summary $opt_global);


my $sc_version= "1.0";

my $sc_name= $FindBin::Script;
my $sc_summary= "convert substitution-files to expander format"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2006";

my $debug= 0; # global debug-switch


#Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary","global|g",
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

my $r_templates= parse_subst::parse($st);


foreach my $k (sort keys %$r_templates)
  { my $r_l= $r_templates->{$k};

    print "\n# ","-" x 50,"\n"; 
    print "# instantiations of \"$k\"\n";
    print "# ","-" x 50,"\n\n"; 

    foreach my $r_h (@$r_l)
      { 
	print "\$begin\\\n" if (!$opt_global);

#    parse_subst::dump($r_h); die;

	print "\$set(\n";
	foreach my $n (sort keys %$r_h)
	  { my $val= $r_h->{$n};
	    $val=~ s/([\$\@])/\\\\$1/g;
	    printf "     \$%-15s = \"%s\";\n",$n,$val; 
	  }
	print "    )\\\n";
	print "\$include(\"$k\")\\\n";
	print "\$end\\\n" if (!$opt_global);
      }    
  }
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
    -g use only global variables (no \$begin or \$end)
    
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

