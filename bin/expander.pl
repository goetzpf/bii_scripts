eval 'exec perl -S $0 ${1+"$@"}' # -*- Mode: perl -*-
    if 0;
# the above is a more portable way to find perl
# ! /usr/bin/perl

#  This software is copyrighted by the BERLINER SPEICHERRING
#  GESELLSCHAFT FUER SYNCHROTRONSTRAHLUNG M.B.H., BERLIN, GERMANY.
#  The following terms apply to all files associated with the software.
#  
#  BESSY hereby grants permission to use, copy and modify this
#  software and its documentation for non-commercial, educational or
#  research purposes provided that existing copyright notices are
#  retained in all copies.
#  
#  The receiver of the software provides BESSY with all enhancements, 
#  including complete translations, made by the receiver.
#  
#  IN NO EVENT SHALL BESSY BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
#  SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE
#  OF THIS SOFTWARE, ITS DOCUMENTATION OR ANY DERIVATIVES THEREOF, EVEN 
#  IF BESSY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  
#  BESSY SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED
#  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#  PURPOSE, AND NON-INFRINGEMENT. THIS SOFTWARE IS PROVIDED ON AN "AS IS"
#  BASIS, AND BESSY HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT,
#  UPDATES, ENHANCEMENTS OR MODIFICATIONS.


# @STATUS: release
# @PLATFORM: home bessy
# @CATEGORY: search


# for the format of the macros, see the documentation of expander.pm
# (e.g. man expander or 
#  perldoc expander.pm)

use strict;
use Data::Dumper;
use Cwd;
use File::Spec;

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

use vars qw($opt_help $opt_summary @opt_file 
            $opt_roundbrackets $opt_force_brackets $opt_allow_not_defined
	    $opt_recursive);


my $sc_version= "1.4";

my $sc_name= $FindBin::Script;
my $sc_summary= "performs expansion of macros in a file"; 
my $sc_author= "Goetz Pfeiffer";
my $sc_year= "2005";

my $debug= 0; # global debug-switch

# global parameter hash:


my @files;
my @macros;
my @ipaths;

Getopt::Long::config(qw(no_ignore_case));

if (!GetOptions("help|h","summary",
		"file|f=s" => \@files, 
		"macros|m=s" => \@macros,
		"include|I=s" => \@ipaths,
		"roundbrackets|b",
		"force_brackets|F",
		"allow_not_defined|n",
		"recursive|r",
                ))
  { die "parameter error!\n"; };

if ($opt_help)
  { help();
    exit;
  };

my %expand_options;

if ($opt_recursive)
  { $expand_options{recursive}= 1; }

if ($opt_allow_not_defined)
  { $expand_options{allow_not_defined_vars}= 1; }

if ($opt_roundbrackets)
  { $expand_options{roundbrackets}= 1; }

if ($opt_force_brackets)
  { $expand_options{forbit_nobrackets} = 1; }

if (@ipaths)
  { $expand_options{includepaths}= \@ipaths; }

if ($opt_summary)
  { print_summary();
    exit;
  };

#if (!@files)
#  { die "-f option is mandatory\n"; };

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

if (@ARGV)
  { push @files, @ARGV; };

if (!@files)
  { local $/;
    undef $/;
    my $data=<>;
    expander::parse_scalar(\$data,%expand_options);
    exit(0);
  } 


foreach my $f (@files)
  { my $path= find_file($f,\@ipaths);
    if ((!defined $path) || (!-r $path))
      { die "error: file \"$f\" is not readable!"; };
    expander::parse_file(find_file($f,\@ipaths),%expand_options); 
  };


# ------------------------------------------------

sub find_file
  { my($file,$r_paths)= @_;

    return($file) if (-r $file);

    return if (!@$r_paths);

    my $test;
    for(my $i=0; $i<= $#$r_paths; $i++)
      { if (!-d $r_paths->[$i]) 
          { warn "warning: path \"$r_paths->[$i]\" is not valid"; 
            next;
          };
        $test= File::Spec->catfile($r_paths->[$i], $file);
	if (-r $test)
	  { # move the path that matched to the front
	    my $e=splice(@$r_paths,$i,1); unshift @$r_paths,$e;
            return($test);
	  };
      };
    return;
  }

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
      if the option is not defined, the input is 
      read from standard-input
      NOTE: -f can be omitted when the files are the last
      arguments given to $sc_name
    --summary: give a summary of the script
    -m [name=value] define a macros 
      more than one -m option is allowed
    -I [path] -I [path2]
      specify paths were to find the include-files (statement \$include())  
    -b allow round brackets for variables like in \$(myvar)
    -F all variables must be bracketed, so things like \$abc are
       no longer recognized
    -r allow recursive variable expansion
    -n allow that variables are not defined
       (usually this aborts the script, but then only an
        error message is printed to stdout)

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

\$begin
\$end			-> define a block with local variables

\$export(<var-list>)    -> export local variables to enclosing (outer)
 			   block

\$comment (comment)	-> comment

\$include (<expression>) -> include the specified file

<expression>: many simple expressions that are valid in perl
can be used here 

END
  }

